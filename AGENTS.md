# AGENTS.md — mapa para agentes (cascarón Hop + H2 + Python)

ETL **Apache Hop + H2 in-memory + Python**. Arquitectura: [`docs/arquitectura.md`](docs/arquitectura.md).

**Verificación:** [`./init.sh`](init.sh) debe terminar en **`HARNESS OK`**. Criterios: [`CHECKPOINTS.md`](CHECKPOINTS.md).

## Harness

| Archivo | Propósito |
|---|---|
| [`feature_list.json`](feature_list.json) | Alcance; **una** `in_progress` a la vez |
| [`progress/current.md`](progress/current.md) | Plan de sesión activa |
| [`progress/history.md`](progress/history.md) | Bitácora append-only |
| [`docs/harness/workflow.md`](docs/harness/workflow.md) | Roles líder / implementador / revisor |
| [`docs/harness/platform.md`](docs/harness/platform.md) | Hop, H2, variables |

## Skill

- [`.agents/skills/hop-python-etl/SKILL.md`](.agents/skills/hop-python-etl/SKILL.md)

## Inicio rápido

```bash
./switch-env.sh local
./init.sh
~/apps/hop/hop-gui.sh   # → wf_main.hwf
```

**Windows:** `switch-env.ps1` hace lo mismo que `switch-env.sh` (`.\switch-env.ps1 local`). Los `.sh` (`init.sh`, `h2/scripts/`) requieren Git Bash/WSL y asumen venv Linux (`.venv/bin/python`; en Windows el venv es `.venv\Scripts\`).

Smoke sin Hop (equivalente a `init.sh`, sin chequeos del harness):

```bash
./h2/scripts/reset_and_create.sh && .venv/bin/python python/create_stg.py && .venv/bin/python python/main.py
```

## Reglas críticas

1. **Un solo `.py`** en `logica/` (reemplazar `demo.py` al escribir la lógica real). `python/main.py` lo auto-descubre; entrada = DataFrames de `LECTURAS` en `python/io/leer_h2.py`; salida obligatoria = DataFrame `RESULTADO` (contrato: [`python/CONTRATO.md`](python/CONTRATO.md)).
2. **Sin secretos** en git (`project-config.json` y `client_secret.json` son generados/gitignored; `environments/` solo placeholders `<...>`).
3. **Sin `${VAR}` literal** en logs Hop = variable mal definida.
4. `logica/` no abre conexiones. I/O en `python/io/`.

## Nuevo proyecto

Este repo es un cascarón. Fuentes → `inputs.yaml`. Lecturas → `python/io/leer_h2.py`. Transformación → `logica/<tu>.py`. Destino demo → Excel.

Nueva fuente: crear `pipelines/pl_stage_*.hpl` y cablearla en `wf_main.hwf` **después** del paso Python create STG (ejemplo en `.agents/skills/hop-python-etl/inputs.example.yaml`).
