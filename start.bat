@echo off
rem Starts the Hollowmere game server. Keep MySQL running in the XAMPP Control Panel while it runs.
rem Stop it with Ctrl+C or by closing this window: it saves every player before shutting down.
title Hollowmere server
cd /d "%~dp0server"
if not exist theforgottenserver-x64.exe (
  echo The server is not set up yet. Run setup.bat first.
  pause & exit /b 1
)
theforgottenserver-x64.exe
echo.
echo The server has stopped.
pause
