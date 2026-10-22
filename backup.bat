@echo off
rem Saves the whole database (accounts, characters, houses, website) into the backups folder.
rem Works whether or not the server is running. Options are passed on, e.g. backup.bat -XamppPath D:\xampp
cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0windows\backup.ps1" %*
pause
