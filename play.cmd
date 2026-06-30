@echo off
setlocal
set "ROOT=%~dp0"
set "ARCHIVE=%ROOT%original\pacx151a.zip"
set "GODOT=%USERPROFILE%\scoop\apps\godot\current\godot.exe"

if exist "%ARCHIVE%" goto haveArchive
set "ARCHIVE=%ROOT%original\Pac the Man X.app"
if exist "%ARCHIVE%\Contents\Resources" goto haveArchive
set "ARCHIVE=%ROOT%..\clone\pacx151a.zip"
if exist "%ARCHIVE%" goto haveArchive

echo Missing original data.
echo Put pacx151a.zip at "%ROOT%original\pacx151a.zip"
echo or put an unpacked app bundle at "%ROOT%original\Pac the Man X.app"
echo or pass --archive=PATH after the script name.
pause
exit /b 1

:haveArchive
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
