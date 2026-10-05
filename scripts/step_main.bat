@echo off
REM Paso: python\main.py -> logica\deam.py -> Oracle DW_DEAM_*.
setlocal
cd /d "%~dp0.."
call "%~dp0_py.bat"
if errorlevel 1 exit /b 1
"%PY%" python\main.py
exit /b %errorlevel%
