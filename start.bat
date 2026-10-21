@echo off
rem Starts the Hollowmere game server, database and website with Docker Desktop.
cd /d "%~dp0"

where docker >nul 2>nul || (
  echo Docker Desktop is not installed. Get it from https://www.docker.com/products/docker-desktop/
  pause & exit /b 1
)
docker info >nul 2>nul || (
  echo Docker Desktop is not running. Start it, wait until it says "Engine running", then run this again.
  pause & exit /b 1
)

if not exist .env (
  copy .env.example .env >nul
  echo Created .env with the default admin login. Notepad will open so you can change it.
  echo Save and close Notepad to continue.
  notepad .env
)

docker compose up -d --build || (pause & exit /b 1)

echo.
echo Hollowmere is starting. The very first start compiles the server and takes a few minutes.
echo   Website:      http://localhost
echo   Game server:  127.0.0.1, port 7171
echo Run logs.bat to watch it start up.
start "" http://localhost
pause
