<#
.SYNOPSIS
  Saves the whole database (accounts, characters, houses, website) to backups\valdoria_<date>.sql.
  Starts MySQL for the backup if it isn't running, and stops it again afterwards. Run it through backup.bat.
#>
param([string]$XamppPath = 'C:\xampp')

$ErrorActionPreference = 'Stop'
$Root = Split-Path -Parent $PSScriptRoot
. (Join-Path $PSScriptRoot 'common.ps1')

try { $startedDb = Start-Database } catch { Write-Host $_.Exception.Message -ForegroundColor Red; exit 1 }
try {
  $folder = Join-Path $Root 'backups'
  New-Item -ItemType Directory -Force $folder | Out-Null
  $file = Join-Path $folder ('valdoria_' + (Get-Date -Format 'yyyy-MM-dd_HH-mm') + '.sql')
  $ErrorActionPreference = 'Continue' # see the note in common.ps1
  & (Join-Path $MysqlBin 'mysqldump.exe') @UserAuth "--result-file=$file" $DbName
  $ErrorActionPreference = 'Stop'
  if ($LASTEXITCODE -ne 0) { throw 'mysqldump failed.' }
  Write-Host "Saved $file" -ForegroundColor Green
} catch {
  Write-Host "The backup failed: $($_.Exception.Message) Has setup.bat been run?" -ForegroundColor Red
} finally {
  if ($startedDb) { Stop-Database }
}
