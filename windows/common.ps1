# Shared by setup.ps1 and start.ps1: where XAMPP's programs live, and how to start, check and
# stop its MySQL and Apache without opening the XAMPP Control Panel.

# Must match mysqlUser / mysqlPass / mysqlDatabase in server\config.lua.
$DbName = 'forgottenserver'
$DbUser = 'forgottenserver'
$DbPass = 'hollowmere'

$MysqlBin = Join-Path $XamppPath 'mysql\bin'
$MysqlExe = Join-Path $MysqlBin 'mysql.exe'
$MysqlAdmin = Join-Path $MysqlBin 'mysqladmin.exe'
$Mysqld = Join-Path $MysqlBin 'mysqld.exe'
$Httpd = Join-Path $XamppPath 'apache\bin\httpd.exe'
$UserAuth = @('-h', '127.0.0.1', '-u', $DbUser, "-p$DbPass")

# Background programs run without a window on Windows. (-WindowStyle only exists there.)
$Background = @{}
if ($env:OS -eq 'Windows_NT') { $Background.WindowStyle = 'Hidden' }

function Test-Database([string[]]$auth = $UserAuth) {
  $null = & $MysqlAdmin @auth --connect-timeout=2 ping 2>&1
  return $LASTEXITCODE -eq 0
}

# True once MySQL answers at all, even before our user exists (an "access denied" reply still means it's up).
function Test-DatabaseUp {
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

# Starts XAMPP's MySQL in the background, the same way XAMPP's own mysql_start.bat does.
# Returns $true if this call started it (so the caller knows to stop it again).
function Start-Database {
  if (Test-DatabaseUp) { return $false }
  if (-not (Test-Path $Mysqld)) { throw "Can't find MySQL at $Mysqld. Is XAMPP installed in $XamppPath?" }
  Start-Process -FilePath $Mysqld -ArgumentList "--defaults-file=`"$(Join-Path $MysqlBin 'my.ini')`"", '--standalone' `
    -WorkingDirectory $XamppPath @Background | Out-Null
  if (-not (Wait-Until { Test-DatabaseUp } 60)) {
    throw 'MySQL did not start. Another program may be using port 3306; check C:\xampp\mysql\data\mysql_error.log.'
  }
  return $true
}

function Stop-Database {
  & $MysqlAdmin @UserAuth shutdown 2>&1 | Out-Null
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
