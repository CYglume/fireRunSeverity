@echo off

setlocal enabledelayedexpansion
@REM Find the current file location (which can be used to call python script in the same folder)
set drive=%~dp0
set drivep=%drive%
echo %drivep%
cd %drivep%

set VENV_PATH=%userprofile%/mapGee
set PATH=%VENV_PATH%/Scripts/;%PATH%
poetry run python severityCalc.py

cmd /k