@echo off
REM Paso: Google Sheets -> STG_DEAM_* en H2. Necesita client_secret.json.
setlocal
cd /d "%~dp0.."
call "%~dp0_py.bat"
if errorlevel 1 exit /b 1
"%PY%" python\io\extraer_sheets.py
exit /b %errorlevel%
