@echo off
rem Shows the live output of the game server and website. Close the window to stop watching; the server keeps running.
cd /d "%~dp0"
docker compose logs -f --tail 100 server web
