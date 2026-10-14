@echo off
REM Nombre pedido para el Programador de tareas. La plantilla del arquetipo es run_wf_main.bat.
call "%~dp0run_wf_main.bat" %*
exit /b %ERRORLEVEL%
