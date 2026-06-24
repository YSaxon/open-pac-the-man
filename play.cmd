@echo off
setlocal
set "ROOT=%~dp0"
set "ARCHIVE=%ROOT%..\clone\pacx151a.zip"
set "GODOT=%USERPROFILE%\scoop\apps\godot\current\godot.exe"

if not exist "%ARCHIVE%" (
  echo Missing original archive: "%ARCHIVE%"
  pause
  exit /b 1
)

if exist "%GODOT%" goto launch
for %%G in (godot.exe godot) do (
  where %%G >nul 2>nul && set "GODOT=%%G" && goto launch
)

echo Godot 4.7 or newer was not found.
echo Install it with: scoop install godot
pause
exit /b 1

:launch
start "Maze Engine" "%GODOT%" --path "%ROOT%" -- "--archive=%ARCHIVE%" %*
