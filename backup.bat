@echo off
rem Saves a copy of the whole database (accounts, characters, houses, website) into the backups folder.
cd /d "%~dp0"
if not exist backups mkdir backups
for /f %%i in ('powershell -NoProfile -Command "Get-Date -Format yyyy-MM-dd_HH-mm"') do set STAMP=%%i
docker compose exec -T db mariadb-dump -uforgottenserver -phollowmere forgottenserver > "backups\hollowmere_%STAMP%.sql" || (
  echo The backup failed. Is the server running? Start it with start.bat first.
  pause & exit /b 1
)
echo Saved backups\hollowmere_%STAMP%.sql
pause
