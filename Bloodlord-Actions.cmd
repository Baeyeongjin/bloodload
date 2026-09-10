@echo off
cd /d "%~dp0"
if not exist "%~dp0build\Bloodlord-actions.pck" (
  echo Missing build\Bloodlord-actions.pck
  pause
  exit /b 1
)
set "BLOODLORD_RUNTIME=%USERPROFILE%\Downloads\Godot_v4.7-stable_win64.exe\Godot_v4.7-stable_win64.exe"
if not exist "%BLOODLORD_RUNTIME%" (
  echo Godot 4.7 runtime was not found in Downloads.
  pause
  exit /b 1
)
start "" "%BLOODLORD_RUNTIME%" --main-pack "%~dp0build\Bloodlord-actions.pck"
