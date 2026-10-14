@echo off
REM Resuelve el interprete Python del proyecto y deja %PY%.
REM call "%~dp0_py.bat"
set "ROOT=%~dp0.."
set "PY=%ROOT%\.venv\Scripts\python.exe"
if not exist "%PY%" set "PY=python"
if "%PY%"=="python" (
  python -c "import yaml,pandas,jaydebeapi" >nul 2>&1
  if errorlevel 1 (
    echo FAIL: no hay .venv con dependencias ^(python\requirements.txt^). 1>&2
    exit /b 1
  )
)
exit /b 0
