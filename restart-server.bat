@echo off
rem Restarts only the game server, e.g. after you edit config.lua or files in server\data.
rem The server saves all players before it shuts down.
cd /d "%~dp0"
docker compose restart server
pause
