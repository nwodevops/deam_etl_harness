# AGENTS.md — mapa para agentes (cascarón Hop + H2 + Python)

ETL **Apache Hop + H2 in-memory + Python**. Arquitectura: [`docs/arquitectura.md`](docs/arquitectura.md).

**Verificación:** `./init.sh` (Linux) o `init.bat remote` (Windows) debe terminar en **`HARNESS OK`**. Criterios: [`CHECKPOINTS.md`](CHECKPOINTS.md).

## Harness

| Archivo | Propósito |
|---|---|
| [`feature_list.json`](feature_list.json) | Alcance; **una** `in_progress` a la vez |
| [`progress/current.md`](progress/current.md) | Plan de sesión activa |
| [`progress/history.md`](progress/history.md) | Bitácora append-only |
| [`docs/harness/workflow.md`](docs/harness/workflow.md) | Roles líder / implementador / revisor |
| [`docs/harness/platform.md`](docs/harness/platform.md) | Hop, H2, variables |

## Skills

- [`.agents/skills/hop-python-etl/SKILL.md`](.agents/skills/hop-python-etl/SKILL.md) — capas Hop / H2 / Python
- [`.agents/skills/linux-windows-parity/SKILL.md`](.agents/skills/linux-windows-parity/SKILL.md) — el cambio de Linux se espeja en `init.bat`, `wf_main_windows.hwf` y `run_wf_main.bat`
- [`.agents/skills/etl-run-logs/SKILL.md`](.agents/skills/etl-run-logs/SKILL.md) — cada corrida deja bitácora en `logs/`

## Inicio rápido

### Linux (desarrollo, entorno `local`)

```bash
./switch-env.sh local
./init.sh
~/apps/hop/hop-gui.sh   # → wf_main.hwf
```

### Windows (este equipo, entorno `remote`)

```bat
powershell -ExecutionPolicy Bypass -File switch-env.ps1 remote
init.bat remote
REM Programador de tareas → run_wf_main.bat
REM Hop GUI → workflows\wf_main_windows.hwf
```

## Entornos

Host, servicio y esquema no van en este archivo. Viven en `environments/local.json` y `environments/remote.json` (placeholders `<...>`). El esquema destino es `DB_ORA_DW_SCHEMA`. Credenciales reales solo en `docs/credenciales/*.txt` (gitignored), sobrepuestas por `switch-env.sh` / `switch-env.ps1`.

## Reglas críticas

1. **Un solo `.py`** en `logica/` (el cascarón trae `demo.py`).
2. **Sin secretos** en git (`project-config.json` es generado).
3. **Sin `${VAR}` literal** en logs Hop = variable mal definida.
4. `logica/` no abre conexiones. I/O en `python/io/`.
5. **No solapar corridas**: `mem:csep`:9092 es compartido con los repos hermanos y todos hacen `DROP ALL OBJECTS`.
6. **Corrida en `logs/`**: `logs/init_YYYYMMDD.log` y `logs/wf_main_YYYYMMDD.log`. stdout o un temporal que se borra no cuentan. Skill `etl-run-logs`.

## Nuevo proyecto

Este repo es un cascarón. Fuentes → `inputs.yaml`. Lecturas → `python/io/leer_h2.py`. Transformación → `logica/<tu>.py`. Destino demo → Excel.
