@echo off
rem One-time setup for Windows: downloads the official TFS 1.4.2 Windows build and sets up
rem the database and website in XAMPP. Safe to run again. Options are passed on, e.g. setup.bat -XamppPath D:\xampp
cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0windows\setup.ps1" %*
pause
