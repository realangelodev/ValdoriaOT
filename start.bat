@echo off
rem Starts Valdoria: the database and website in the background, then the game server in this window.
rem Stop it with Ctrl+C: the server saves every player, then the database and website shut down too.
rem Options are passed on, e.g. start.bat -XamppPath D:\xampp
title Valdoria server
cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0windows\start.ps1" %*
pause
