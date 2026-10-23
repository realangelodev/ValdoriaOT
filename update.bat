@echo off
rem Gets the latest Valdoria files from GitHub, then runs setup.bat to apply them.
rem Your .env, the server program, logs and backups are not part of the repository, so they are kept.
rem Your own edits to the server files are kept too, as long as they don't clash with the update.
cd /d "%~dp0"
where git >nul 2>nul
if errorlevel 1 (
  echo Git is not installed. Get it from https://git-scm.com/download/win, then run update.bat again.
  pause
  exit /b 1
)
set REPO=https://github.com/realangelodev/ValdoriaOT.git
if not exist ".git" (
  echo First update: linking this folder to %REPO%
  git init -q
  git remote add origin %REPO%
  git fetch -q origin main || goto :failed
  git reset -q --hard origin/main || goto :failed
  git branch -q -M main
  git branch -q --set-upstream-to=origin/main main
) else (
  git -c user.name=Valdoria -c user.email=valdoria@localhost pull --rebase --autostash origin main || goto :failed
)
echo.
echo Up to date. Running setup to apply the changes...
call "%~dp0setup.bat"
exit /b 0

:failed
echo.
echo The update did not finish. Check your internet connection, or if you edited files that the
echo update also changed, see "Updating" in README.md.
pause
exit /b 1
