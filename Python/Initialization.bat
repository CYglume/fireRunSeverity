@echo off

setlocal enabledelayedexpansion
@REM Find the current file location (which can be used to call python script in the same folder)
set drive=%~dp0
set drivep=%drive%
echo %drivep%
cd %drivep%

set VENV_PATH=%userprofile%/mapGee
python -m venv %VENV_PATH%

echo "------ Check poetry installation... ------"
%VENV_PATH%/Scripts/pip show setuptools >nul 2>&1
IF %ERRORLEVEL% NEQ 0 (
    echo setuptools not found
    echo -- Installing setuptools... --
    %VENV_PATH%/Scripts/python.exe -m pip install -U pip setuptools
) ELSE (
    echo -- setuptools exists --
)

%VENV_PATH%/Scripts/pip show poetry >nul 2>&1
IF %ERRORLEVEL% NEQ 0 (
    echo poetry not found
    echo -- Installing poetry... --
    %VENV_PATH%/Scripts/pip install poetry
) ELSE (
    echo -- poetry exists --
)



echo "------ Updating Packages... ------"
set PATH=%VENV_PATH%/Scripts/;%PATH%
poetry config virtualenvs.in-project true
poetry install

cmd /k