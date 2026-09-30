@echo off
REM Harness - smoke demo del arquetipo (equivalente Windows de init.sh).
setlocal EnableExtensions EnableDelayedExpansion
cd /d "%~dp0"

set "PY=.venv\Scripts\python.exe"
set "LOG=%TEMP%\init_harness_%RANDOM%.log"

call :step "Validando feature_list.json"
%PY% python\validate_feature_list.py || goto :fail

call :step "Prerrequisitos"
java -version >nul 2>&1 || (echo FAIL: java no esta en PATH & goto :fail)
if not exist "h2\lib\h2-2.4.240.jar" (echo FAIL: jar H2 no encontrado & goto :fail)
if not exist "%PY%" (echo FAIL: venv ausente o roto. Crear: python -m venv .venv y .venv\Scripts\python -m pip install -r python\requirements.txt & goto :fail)
%PY% -c "import yaml, pandas, jaydebeapi" >nul 2>&1 || (echo FAIL: el .venv no tiene dependencias. %PY% -m pip install -r python\requirements.txt & goto :fail)
if not exist "project-config.json" (
    call :step "Generando project-config.json"
    %PY% -c "import json,sys; from pathlib import Path; env=json.loads(Path('environments/local.json').read_text(encoding='utf-8')); out={'metadataBaseFolder':'${PROJECT_HOME}/metadata','unitTestsBasePath':'${PROJECT_HOME}','dataSetsCsvFolder':'${PROJECT_HOME}/datasets','enforcingExecutionInHome':True,'parentProjectName':'default','config':{'variables':env['variables']}}; Path('project-config.json').write_text(json.dumps(out,indent=2,ensure_ascii=False),encoding='utf-8')"
)

call :step "Reset H2 + DDL"
call h2\scripts\reset_and_create.bat >nul || (echo FAIL: reset_and_create.bat & goto :fail)

call :step "Python create STG"
%PY% python\create_stg.py || goto :fail

call :step "Python extract Sheets -^> H2"
%PY% python\io\extraer_sheets.py || goto :fail

call :step "Python main"
%PY% python\main.py > "%LOG%" 2>&1
if errorlevel 1 (
    type "%LOG%"
    echo FAIL: python\main.py termino con error
    goto :fail
)
type "%LOG%"

call :step "Comprobando salidas"
findstr /c:"Salida RESULTADO" "%LOG%" >nul || findstr /c:"Salida ORACLE" "%LOG%" >nul || (echo FAIL: no hay Salida RESULTADO/ORACLE en el log & goto :fail)
findstr /r /c:"\${[A-Za-z0-9_]*}" "%LOG%" >nul && (echo FAIL: log contiene variables Hop sin resolver & goto :fail)

echo.
echo HARNESS OK - ver CHECKPOINTS.md
del "%LOG%" >nul 2>&1
exit /b 0

:fail
if exist "%LOG%" type "%LOG%"
del "%LOG%" >nul 2>&1
exit /b 1

:step
echo ==^> %~1
exit /b 0
