@echo off
cd /d "%~dp0"
set "BLOODLORD_LIBRESPRITE=%USERPROFILE%\.codex\visualizations\2026\09\08\01a07e55-b2df-7a43-8f72-3c0ab6c255d7\libresprite-api-portable\libresprite.exe"
if not exist "%BLOODLORD_LIBRESPRITE%" (
  echo LibreSprite portable was not found.
  pause
  exit /b 1
)
if "%~1"=="" (
  start "" "%BLOODLORD_LIBRESPRITE%" "%~dp0art\boss_vfx\wraith_knight.aseprite"
) else (
  start "" "%BLOODLORD_LIBRESPRITE%" "%~f1"
)
