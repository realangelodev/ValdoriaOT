@echo off
rem Lists the grounds in the client's Tibia.dat into dat-grounds.txt and opens it in Notepad.
cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0windows\dat-grounds.ps1" %*
if exist dat-grounds.txt start notepad dat-grounds.txt
pause
