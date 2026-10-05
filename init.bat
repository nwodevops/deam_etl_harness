@echo off
REM init.bat — Harness Windows DEAM. Equivalente de init.sh.
REM Uso: init.bat [local|remote]   (default: remote)
REM H2 mem:csep puerto 9092 es compartido. Encadena los pasos en un proceso.
setlocal EnableExtensions EnableDelayedExpansion
cd /d "%~dp0"

set "ENV=%~1"
if "%ENV%"=="" set "ENV=remote"
echo ==^> Harness Windows DEAM: entorno %ENV%

set "PY=%~dp0.venv\Scripts\python.exe"
if not exist "%PY%" set "PY=python"

set "LOGDIR=%~dp0logs"
if not exist "%LOGDIR%" mkdir "%LOGDIR%"
for /f %%a in ('powershell -NoProfile -Command "Get-Date -Format yyyyMMdd"') do set "STAMP=%%a"
set "LOGFILE=%LOGDIR%\init_%STAMP%.log"
set "RUNLOG=%TEMP%\deam_run_%RANDOM%.log"
set "STEPLOG=%TEMP%\deam_step_%RANDOM%.log"
echo === inicio %date% %time% env=%ENV% === > "%RUNLOG%"
echo === inicio %date% %time% env=%ENV% ===

echo ==^> Validando feature_list.json
"%PY%" python\validate_feature_list.py
if errorlevel 1 (
  echo FAIL: feature_list.json
  echo FAIL: feature_list.json>> "%RUNLOG%"
  goto :fail
)

echo ==^> Prerrequisitos
java -version >nul 2>&1
if errorlevel 1 (
  echo FAIL: java no esta en PATH
  echo FAIL: java no esta en PATH>> "%RUNLOG%"
  goto :fail
)
if not exist "%~dp0h2\lib\h2-2.4.240.jar" (
  echo FAIL: jar H2 no encontrado
  echo FAIL: jar H2 no encontrado>> "%RUNLOG%"
  goto :fail
)
"%PY%" -c "import yaml,pandas,jaydebeapi,oracledb,gspread" >nul 2>&1
if errorlevel 1 (
  echo FAIL: %PY% no tiene las dependencias de python\requirements.txt
  echo FAIL: dependencias>> "%RUNLOG%"
  goto :fail
)
if not exist "%~dp0client_secret.json" (
  echo FAIL: falta client_secret.json
  echo FAIL: falta client_secret.json>> "%RUNLOG%"
  goto :fail
)

echo ==^> switch-env %ENV%
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0switch-env.ps1" %ENV%
if errorlevel 1 (
  echo FAIL: switch-env %ENV%
  echo FAIL: switch-env %ENV%>> "%RUNLOG%"
  goto :fail
)

set "SCHEMA="
for /f "usebackq delims=" %%v in (`powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\get_var.ps1" "%~dp0project-config.json" DB_ORA_DW_SCHEMA`) do set "SCHEMA=%%v"
if "%SCHEMA%"=="" for /f "usebackq delims=" %%u in (`powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\get_var.ps1" "%~dp0project-config.json" DB_ORA_DW_USERNAME`) do set "SCHEMA=%%u"
if "%SCHEMA%"=="" (
  echo FAIL: no pude resolver el esquema destino
  echo FAIL: esquema destino>> "%RUNLOG%"
  goto :fail
)
echo ==^> Esquema destino Oracle: %SCHEMA%
echo ==^> Esquema destino Oracle: %SCHEMA%>> "%RUNLOG%"

echo ==^> Paso 1/4: Reset H2
echo ==^> Paso 1/4: Reset H2>> "%RUNLOG%"
call :runstep "%~dp0scripts\step_reset_h2.bat"
if errorlevel 1 (
  echo FAIL: reset H2
  echo FAIL: reset H2>> "%RUNLOG%"
  goto :fail
)

echo ==^> Paso 2/4: Python create STG
echo ==^> Paso 2/4: Python create STG>> "%RUNLOG%"
call :runstep "%~dp0scripts\step_create_stg.bat"
if errorlevel 1 (
  echo FAIL: python\create_stg.py
  echo FAIL: python\create_stg.py>> "%RUNLOG%"
  goto :fail
)

echo ==^> Paso 3/4: Extract Sheets
echo ==^> Paso 3/4: Extract Sheets>> "%RUNLOG%"
call :runstep "%~dp0scripts\step_extraer_sheets.bat"
if errorlevel 1 (
  echo FAIL: python\io\extraer_sheets.py
  echo FAIL: extraer_sheets>> "%RUNLOG%"
  goto :fail
)

echo ==^> Paso 4/4: Python main
echo ==^> Paso 4/4: Python main>> "%RUNLOG%"
call :runstep "%~dp0scripts\step_main.bat"
if errorlevel 1 (
  echo FAIL: python\main.py
  echo FAIL: python\main.py>> "%RUNLOG%"
  goto :fail
)

findstr /c:"Salida ORACLE" "%RUNLOG%" >nul || findstr /c:"Salida RESULTADO" "%RUNLOG%" >nul
if errorlevel 1 (
  echo FAIL: no hay Salida RESULTADO/ORACLE en el log
  echo FAIL: sin Salida ORACLE>> "%RUNLOG%"
  goto :fail
)
findstr /c:"${" "%RUNLOG%" >nul 2>&1
if not errorlevel 1 (
  echo FAIL: el log contiene variables Hop sin resolver
  echo FAIL: variables Hop sin resolver>> "%RUNLOG%"
  goto :fail
)

echo.
echo HARNESS OK - ver CHECKPOINTS.md. Bitacora: %LOGFILE%
echo.>> "%RUNLOG%"
echo HARNESS OK esquema %SCHEMA%>> "%RUNLOG%"
call :savelog
endlocal
exit /b 0

:runstep
call "%~1" > "%STEPLOG%" 2>&1
set "RC=%ERRORLEVEL%"
type "%STEPLOG%"
type "%STEPLOG%" >> "%RUNLOG%"
exit /b %RC%

:savelog
if exist "%RUNLOG%" type "%RUNLOG%" >> "%LOGFILE%"
if exist "%RUNLOG%" del /q "%RUNLOG%" >nul 2>&1
if exist "%STEPLOG%" del /q "%STEPLOG%" >nul 2>&1
exit /b 0

:fail
echo.
echo HARNESS FAIL. Bitacora: %LOGFILE%
echo HARNESS FAIL>> "%RUNLOG%"
call :savelog
endlocal
exit /b 1
