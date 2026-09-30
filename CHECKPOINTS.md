# CHECKPOINTS — arquetipo mínimo

Criterios para marcar features `done` en [`feature_list.json`](feature_list.json).  
Verificación: [`./init.sh`](init.sh).

---

## Global

- [ ] `./init.sh` termina con **`HARNESS OK`**.
- [ ] Sin passwords reales en `project-config.json` / `environments/`.
- [ ] Log sin literales `${VAR}`.
- [ ] Un solo `.py` en `logica/`.
- [ ] Máximo **una** feature `in_progress`.

---

## Fase 1 — Entorno {#fase-1}

- [ ] H2 levanta en puerto 9092 (`reset_and_create.sh`).
- [ ] `python/create_stg.py` OK (puede ser no-op con `sources: []`).
- [ ] `python/main.py` OK con `logica/demo.py`.
- [ ] `wf_main.hwf` ejecutable en Hop GUI.

---

## Fase 2 — Fuentes STG {#fase-2}

- [ ] Al menos una fuente en `inputs.yaml`.
- [ ] Tabla `STG_*` creada en H2.
- [ ] Pipeline `pl_stage_*.hpl` cableado en `wf_main.hwf`.
- [ ] Hop carga filas en STG (conteo > 0 en log).

Ver skill `hop-python-etl` e [`inputs.example.yaml`](.agents/skills/hop-python-etl/inputs.example.yaml).

---

## Fase 3 — Lógica {#fase-3}

- [ ] Claves STG en `python/io/leer_h2.py`.
- [ ] `logica/<tu_logica>.py` produce `RESULTADO` con filas > 0.
- [ ] `output/resultado.xlsx` generado (si se usa salida Excel).

Contrato: [`python/CONTRATO.md`](python/CONTRATO.md).

---

## Fase 4 — DEAM: Google Sheets → Oracle {#fase-4}

- [x] Sheet `1hbepbbm...` compartido con `drive-sheets-monitor@gdrive-csep.iam.gserviceaccount.com` (Lector).
- [x] 11 fuentes en `inputs.yaml` (`type: sheets`; tabs reales: General, Ubicación, Documentos, Componente ambiental, ISIM, EAS - EAF, IPASH, Participaciones, Ecosistemas frágiles, FLORA, FAUNA — quedan fuera Diccionario, DESPLEGABLE, Metas).
- [x] `STG_DEAM_*` creadas en H2 y aterrizadas (extract Python fallback con backoff 429; pipelines Hop `pl_stage_*` pendientes de GUI).
- [x] 11 tablas `DW_DEAM_*` creadas en Oracle `REPOCSEP` (VARCHAR2(4000) + `FECHA_CARGA` DATE).
- [x] Carga truncate + full reload; conteos Oracle = filas Sheets por tab (verificado 2026-09-30).
- [x] `main.py` acepta salida `SALIDAS_ORACLE` (contrato extendido en `python/CONTRATO.md`).
- [ ] Opcional: extraer vía Hop (paso Google Sheets) en vez de Python fallback.

---

## Fuera de alcance del cascarón

- Modelo dimensional Oracle (`cargar_dw.py`) → copiar cuando el proyecto lo pida.
- Fases Kimball / indicadores → no vienen en esta plantilla.
