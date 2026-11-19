@echo off
setlocal
set "TOUCHPATTERN_ROOT=%~dp0."
set "TOUCHPATTERN_GODOT=%~dp0.tools\Godot_v4.7.2-stable_win64.exe"
if not exist "%TOUCHPATTERN_GODOT%" (
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\setup-godot.ps1"
    if errorlevel 1 (
        pause
        exit /b 1
    )
)
"%TOUCHPATTERN_GODOT%" --headless --path "%TOUCHPATTERN_ROOT%" --editor --quit
if errorlevel 1 (
    pause
    exit /b 1
)
"%TOUCHPATTERN_GODOT%" --path "%TOUCHPATTERN_ROOT%" -- %*
