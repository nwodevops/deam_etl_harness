# Paridad Linux / Windows — qué comprobar en Windows

Linux ya corre `./init.sh` contra `local` (`docs/credenciales/local.txt` → Oracle `localhost:1524/BD_CURSOR`, usuario `app`).

Windows no se ejecutó aquí. Comprobar:

1. `docs/credenciales/remote.txt` con Host, Port, Service, User, Password. `switch-env.ps1 remote` no debe dejar `DB_ORA_DW_*` en `<...>`.
2. `init.bat remote` termina en `HARNESS OK`. Bitácora `logs/init_YYYYMMDD.log` con las 11 `STG_DEAM_*` y `Salida ORACLE DW_DEAM_*` al mismo conteo.
3. Programador de tareas apunta a `wf_main_win.bat` (delega en `run_wf_main.bat`). Proyecto Hop `deam_etl_harness`, workflow `workflows\wf_main_windows.hwf`, log `logs\wf_main_YYYYMMDD.log`.
4. Pasos del workflow: `scripts\step_reset_h2.bat`, `step_create_stg.bat`, `step_extraer_sheets.bat`, `step_main.bat`. H2 compartido `mem:csep` puerto 9092: no solapar con otro ETL.
