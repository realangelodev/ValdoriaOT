@echo off
rem Stops the server, database and website. Accounts, characters and the website are kept.
cd /d "%~dp0"
docker compose stop
pause
