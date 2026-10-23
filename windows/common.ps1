# Shared by setup.ps1 and start.ps1: where XAMPP's programs live, and how to start, check and
# stop its MySQL and Apache without opening the XAMPP Control Panel.

# Must match mysqlUser / mysqlPass / mysqlDatabase in server\config.lua.
$DbName = 'forgottenserver'
$DbUser = 'forgottenserver'
$DbPass = 'valdoria'

$MysqlBin = Join-Path $XamppPath 'mysql\bin'
$MysqlExe = Join-Path $MysqlBin 'mysql.exe'
$MysqlAdmin = Join-Path $MysqlBin 'mysqladmin.exe'
$Mysqld = Join-Path $MysqlBin 'mysqld.exe'
$Httpd = Join-Path $XamppPath 'apache\bin\httpd.exe'
$UserAuth = @('-h', '127.0.0.1', '-u', $DbUser, "-p$DbPass")

# Windows PowerShell 5.1 turns anything a program writes to stderr into an error, and with
# $ErrorActionPreference = 'Stop' that ends the script. MySQL's tools write normal replies like
# "can't connect yet" to stderr, so every function that runs them relaxes that setting for itself.

# Background programs run without a window on Windows. (-WindowStyle only exists there.)
$Background = @{}
if ($env:OS -eq 'Windows_NT') { $Background.WindowStyle = 'Hidden' }

function Test-Database([string[]]$auth = $UserAuth) {
  $ErrorActionPreference = 'Continue'
  $null = & $MysqlAdmin @auth --connect-timeout=2 ping 2>&1
  return $LASTEXITCODE -eq 0
}

# True once MySQL answers at all, even before our user exists (an "access denied" reply still means it's up).
function Test-DatabaseUp {
  $ErrorActionPreference = 'Continue'
  $reply = & $MysqlAdmin -h 127.0.0.1 -u root --connect-timeout=2 ping 2>&1 | Out-String
  return ($LASTEXITCODE -eq 0) -or ($reply -match 'Access denied')
}

function Test-WebServer([string]$url) {
  try { Invoke-WebRequest -Uri "$url/" -UseBasicParsing -TimeoutSec 5 | Out-Null; return $true }
  catch { return [bool]$_.Exception.Response } # any HTTP answer, even an error page, means Apache is up
}

function Wait-Until([scriptblock]$check, [int]$seconds) {
  $deadline = (Get-Date).AddSeconds($seconds)
  while (-not (& $check)) {
    if ((Get-Date) -gt $deadline) { return $false }
    Start-Sleep -Seconds 1
  }
  return $true
}

function Get-MysqlProcess { Get-Process -Name mysqld -ErrorAction SilentlyContinue }

# Starts XAMPP's MySQL in the background, the same way XAMPP's own mysql_start.bat does.
# Returns $true if this call started it (so the caller knows to stop it again).
function Start-Database {
  if (Test-DatabaseUp) { return $false }
  if (-not (Test-Path $Mysqld)) { throw "Can't find MySQL at $Mysqld. Is XAMPP installed in $XamppPath?" }

  # A MySQL that is still shutting down (for example right after setup.bat) keeps its files locked,
  # and a second one started now would quit straight away. Let it finish first.
  if (Get-MysqlProcess) {
    Write-Host '   Waiting for the previous MySQL to finish closing...'
    Wait-Until { (Test-DatabaseUp) -or -not (Get-MysqlProcess) } 60 | Out-Null
    if (Test-DatabaseUp) { return $false }
  }

  # Whatever still holds MySQL's port (a stuck MySQL from an earlier run, or another program) would
  # make ours quit at once, so close it first.
  if (Get-Command Get-NetTCPConnection -ErrorAction SilentlyContinue) {
    $holders = Get-NetTCPConnection -LocalPort 3306 -State Listen -ErrorAction SilentlyContinue |
      Select-Object -ExpandProperty OwningProcess -Unique
    foreach ($id in $holders) {
      $owner = Get-Process -Id $id -ErrorAction SilentlyContinue
      if (-not $owner) { continue }
      Write-Host "   Closing $($owner.ProcessName) (process $id), which was holding port 3306..."
      try { Stop-Process -Id $id -Force -ErrorAction Stop }
      catch {
        $service = Get-CimInstance Win32_Service -Filter "ProcessId = $id" -ErrorAction SilentlyContinue | Select-Object -First 1
        $what = if ($service) { "the Windows service '$($service.Name)'" } else { "$($owner.ProcessName) (process $id)" }
        throw "Port 3306 is taken by $what, and Windows did not let this script close it. Stop it yourself (for a service: Windows key, type 'Services', find it, right-click, Stop, and set Startup type to Manual), then run start.bat again."
      }
    }
    if ($holders) {
      Wait-Until { -not (Get-NetTCPConnection -LocalPort 3306 -State Listen -ErrorAction SilentlyContinue) } 30 | Out-Null
    }
  }

  # Valdoria never uses MySQL replication, but MySQL still reads its bookkeeping files at start-up.
  # If one ends up holding junk (seen after a forced close), MySQL aborts with "Failed to initialize
  # multi master structures". Clear them out; MySQL recreates what it needs.
  $dataDir = Join-Path $XamppPath 'mysql\data'
  Get-ChildItem -Path $dataDir -File -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -in 'multi-master.info', 'master.info', 'relay-log.info' -or $_.Name -like 'master-*.info' -or $_.Name -like 'relay-log-*.info' -or $_.Name -like 'mysql-relay-bin*' } |
    Remove-Item -Force -ErrorAction SilentlyContinue

  # If MySQL quits during start-up (usually a lock left behind a moment longer), try once more.
  for ($try = 1; $try -le 2; $try++) {
    $proc = Start-Process -FilePath $Mysqld -ArgumentList "--defaults-file=`"$(Join-Path $MysqlBin 'my.ini')`"", '--standalone', '--skip-slave-start' `
      -WorkingDirectory $XamppPath -PassThru @Background
    Wait-Until { (Test-DatabaseUp) -or $proc.HasExited } 120 | Out-Null
    if (Test-DatabaseUp) { return $true }
    if (-not $proc.HasExited) { break }
    Start-Sleep -Seconds 5
  }

  $log = Join-Path $XamppPath 'mysql\data\mysql_error.log'
  $tail = if (Test-Path $log) { (Get-Content $log -Tail 12) -join "`n" } else { '(no log file found)' }
  throw "MySQL did not start. Another program may be using port 3306, or MySQL is still open in the XAMPP Control Panel. The last lines of $log are:`n$tail"
}

# Starts XAMPP's Apache in the background, the same way XAMPP's own apache_start.bat does.
function Start-WebServer([string]$url) {
  if (Test-WebServer $url) { return $false }
  if (-not (Test-Path $Httpd)) { throw "Can't find Apache at $Httpd. Is XAMPP installed in $XamppPath?" }
  Start-Process -FilePath $Httpd -WorkingDirectory $XamppPath @Background | Out-Null
  if (-not (Wait-Until { Test-WebServer $url } 30)) {
    throw 'Apache did not start. Another program (often IIS or Skype) may be using port 80.'
  }
  return $true
}

function Stop-WebServer {
  Get-Process -Name httpd -ErrorAction SilentlyContinue | Stop-Process -Force
}
