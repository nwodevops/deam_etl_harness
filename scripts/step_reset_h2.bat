@echo off
REM Paso: reset H2 mem:csep + DDL. No mata el servicio Windows; reset_and_create.bat comprueba el puerto.
setlocal
cd /d "%~dp0.."
call h2\scripts\reset_and_create.bat
exit /b %errorlevel%
