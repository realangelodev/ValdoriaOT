<#
.SYNOPSIS
  Starts Hollowmere: XAMPP's MySQL and Apache in the background, then the game server in this window.
  When the server stops (Ctrl+C, /closeserver or a crash), it waits for the server to finish saving,
  then shuts MySQL and Apache down again. Run it through start.bat.

.PARAMETER XamppPath
  Where XAMPP is installed. Defaults to C:\xampp.

.PARAMETER WebUrl
  Where Apache answers on this PC. Change it if Apache uses another port, e.g. http://127.0.0.1:8080
#>
param(
  [string]$XamppPath = 'C:\xampp',
  [string]$WebUrl = 'http://127.0.0.1'
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
$Server = Join-Path (Split-Path -Parent $PSScriptRoot) 'server'
. (Join-Path $PSScriptRoot 'common.ps1')

$exe = Join-Path $Server 'theforgottenserver-x64.exe'
if (-not (Test-Path $exe)) {
  Write-Host 'The server is not set up yet. Run setup.bat first.' -ForegroundColor Red
  exit 1
}

Write-Host 'Starting the database...'
try { $startedDb = Start-Database } catch { Write-Host $_.Exception.Message -ForegroundColor Red; exit 1 }
if (-not (Test-Database)) {
  Write-Host 'MySQL is running, but the Hollowmere database user is missing. Run setup.bat first.' -ForegroundColor Red
  if ($startedDb) { $ErrorActionPreference = 'Continue'; & $MysqlAdmin -h 127.0.0.1 -u root shutdown 2>&1 | Out-Null }
  exit 1
}

Write-Host 'Starting the website...'
$startedWeb = $false
try { $startedWeb = Start-WebServer $WebUrl }
catch { Write-Host "$($_.Exception.Message) The game server will still start, without the website." -ForegroundColor Yellow }

Write-Host 'Starting the game server. Press Ctrl+C to save and stop it.' -ForegroundColor Green
Write-Host ''
Push-Location $Server
try {
  & $exe
} finally {
  # Ctrl+C reaches the server too, and it saves every player before exiting. Wait for that to
  # finish before taking the database away.
  Get-Process -Name 'theforgottenserver-x64' -ErrorAction SilentlyContinue | Wait-Process
  Pop-Location
  Write-Host ''
  Write-Host 'The game server has stopped.'
  if ($startedWeb) { Stop-WebServer; Write-Host 'Stopped the website.' }
  if ($startedDb) { Stop-Database; Write-Host 'Stopped the database.' }
}
