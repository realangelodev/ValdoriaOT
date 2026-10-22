@echo off
rem Saves a copy of the whole database (accounts, characters, houses, website) into the backups folder.
rem If XAMPP is not installed in C:\xampp, change the next line.
set XAMPP=C:\xampp
cd /d "%~dp0"
if not exist "%XAMPP%\mysql\bin\mysqldump.exe" (
  echo Could not find XAMPP at %XAMPP%. Edit backup.bat and set XAMPP to where it is installed.
  pause & exit /b 1
)
if not exist backups mkdir backups
for /f %%i in ('powershell -NoProfile -Command "Get-Date -Format yyyy-MM-dd_HH-mm"') do set STAMP=%%i
"%XAMPP%\mysql\bin\mysqldump.exe" -h 127.0.0.1 -uforgottenserver -phollowmere forgottenserver > "backups\hollowmere_%STAMP%.sql" || (
  echo The backup failed. Is MySQL running in the XAMPP Control Panel?
  pause & exit /b 1
)
echo Saved backups\hollowmere_%STAMP%.sql
pause
