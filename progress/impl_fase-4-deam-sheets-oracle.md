# impl fase-4-deam-sheets-oracle

Fecha: 2026-09-30 · Estado: **DONE** (`init.bat` → HARNESS OK)

## Resultado (evidencia final)

- Corrida `init.bat` completa: reset H2 → DDL 11 `STG_DEAM_*` → extract Sheets (backoff 429) → `main.py` → Oracle reload. **HARNESS OK**.
- Verificación Oracle: 11/11 tablas, conteos = filas Sheets, `FECHA_CARGA` 100%, tipos VARCHAR2(4000).
  GENERAL 2791 · UBICACION 1984 · DOCUMENTOS 9815 · COMPONENTE_AMBIENTAL 2098 · ISIM 257 ·
  EAS_EAF 18043 · IPASH 1161 · PARTICIPANTES 190 · ECOSISTEMAS_FRAGILES 49 · FLORA 2999 · FAUNA 1077.
- Round-trip previo con `DW_TMP_TEST` (CREATE/TRUNCATE/INSERT/FECHA_CARGA/vacíos→NULL/DROP). OK.
- Fix en corrida: cuota Sheets `429` → `con_backoff` en `introspect/sheets.py` (usado por create_stg y extraer_sheets; espera 45/90/180/360s).

## Archivos tocados

| Archivo | Cambio |
|---|---|
| `feature_list.json` | Feature `fase-4-deam-sheets-oracle` `in_progress` |
| `CHECKPOINTS.md` | Sección Fase 4 |
| `inputs.yaml` | 11 fuentes `type: sheets` → `STG_DEAM_*` (General, Ubicacion, Documentos, Componente ambiental, ISIM, EAS - EAF, IPASH, Participantes, Ecosistemas Fragiles, Flora, Fauna) |
| `python/io/extraer_sheets.py` | **Nuevo**: extract gspread → H2 (fallback; Hop sin plugin verificado en esta máquina) |
| `python/io/escribir_oracle.py` | **Nuevo**: DDL `DW_DEAM_*` (VARCHAR2(4000) + `FECHA_CARGA` DATE DEFAULT SYSDATE), truncate + batch insert vía `oracle_dw` |
| `python/io/leer_h2.py` | `LECTURAS` += 11 claves `DEAM_*` |
| `logica/deam.py` | **Reemplaza `demo.py`** (borrado): passthrough → `SALIDAS_ORACLE` |
| `python/main.py` | Acepta `SALIDAS_ORACLE` (dict tabla→DF) → `escribir_oracle.cargar`; `RESULTADO` → Excel; exigir uno de los dos |
| `python/CONTRATO.md` | Contrato extendido (salidas Oracle) |
| `init.sh` | Paso extract Sheets + grep `Salida (RESULTADO\|ORACLE)` |
| `switch-env.ps1` | Crea `project-config.json` base si falta (igual que `switch-env.sh`) |
| `environments/remote.json` | `DB_ORA_DW_*` con credenciales de `docs/credenciales/remote.txt` |

## Evidencia

- Oracle `REPOCSEP@10.6.0.15:1532/dvoefacore`: conexión OK; 0 tablas `DW_DEAM_*` previas.
- Round-trip `DW_TMP_TEST` (creada/cargada/drop): CREATE + TRUNCATE + INSERT + `FECHA_CARGA=SYSDATE` + NaN/`""`→NULL. OK.
- Alineación headers/filas de `extraer_sheets` probada offline (headers vacíos, duplicados, filas cortas). OK.
- `project-config.json` generado (remote), 24 variables.

## Resueltos en el camino

1. Acceso al sheet: concedido tras compartir con la SA (validado con `Drive files.get` 200).
2. Nombres de tabs difieren de la lista inicial (acentos/plurales): corregidos en `inputs.yaml`.
3. Cuota Sheets 429: backoff exponencial.
4. ORA-00913 en INSERT (faltaba `FECHA_CARGA` en la lista de columnas): corregido.
5. Textos >4000 chars: truncados a 4000 con contador global (`_truncados`).

## Pendiente opcional

- Extract vía Hop (paso Google Sheets) + pipelines `pl_stage_deam_*.hpl` en `wf_main.hwf` — requiere Hop GUI.
- Tipos reales por columna (hoy todo VARCHAR2(4000)).

## Riesgos / decisiones

- **Secretos:** `environments/remote.json` tiene password real y `.gitignore` no cubre
  `environments/` (regla de AGENTS.md dice placeholders). Antes del primer commit: gitignore
  `docs/credenciales/` + `environments/*.json` con valores, o mover credenciales.
- `switch-env.ps1` no ejecutable en esta máquina (política GPO, script sin firma);
  workaround manual documentado en `progress/current.md`; `init.bat` genera config si falta (local).
- Los tabs pueden tener headers en fila distinta de 1 → ajustar `header_row` por fuente.
