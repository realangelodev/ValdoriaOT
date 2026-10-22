@echo off
rem Starts Hollowmere: the database and website in the background, then the game server in this window.
rem Stop it with Ctrl+C: the server saves every player, then the database and website shut down too.
rem Options are passed on, e.g. start.bat -XamppPath D:\xampp
title Hollowmere server
cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0windows\start.ps1" %*
pause
