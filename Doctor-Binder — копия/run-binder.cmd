@echo off
setlocal

set "AHK=C:\Program Files\AutoHotkey\v2\AutoHotkey64.exe"
if not exist "%AHK%" (
    echo AutoHotkey v2 was not found.
    echo Install it from https://www.autohotkey.com/
    pause
    exit /b 1
)

start "Doctor Binder" "%AHK%" "%~dp0google.ahk"
