# Bitácora harness (append-only)

---

## Plantilla

Al cerrar una feature, append aquí: fecha, id, resumen, evidencia (`progress/impl_<id>.md`).

---

## 2026-09-30 — fase-4-deam-sheets-oracle — **done**

- **Qué:** ETL Google Sheets "Matriz Evaluación Ambiental" (`1hbepbbmTcUe80wCH3vjJiqKAVxpVliXF2jy2PCsqfx0`, 11 tabs) → `STG_DEAM_*` (H2) → `DW_DEAM_*` (Oracle `REPOCSEP@10.6.0.15:1532/dvoefacore`). Truncate + full reload, todo VARCHAR2(4000) + `FECHA_CARGA`.
- **Tabs (nombres reales):** General, Ubicación, Documentos, Componente ambiental, ISIM, EAS - EAF, IPASH, Participaciones, Ecosistemas frágiles, FLORA, FAUNA. Fuera: Diccionario, DESPLEGABLE, Metas.
- **Nuevos:** `python/io/extraer_sheets.py`, `python/io/escribir_oracle.py`, `logica/deam.py` (reemplaza `demo.py`), `init.bat` + `python/validate_feature_list.py` (Windows), backoff 429 en `introspect/sheets.py`.
- **Cambios:** `main.py` + `CONTRATO.md` soportan `SALIDAS_ORACLE`; `init.sh` paso extract + grep ORACLE; `switch-env.ps1` crea config si falta; `environments/remote.json` con `DB_ORA_DW_*` reales (¡revisar secretos antes de commitear!).
- **Evidencia:** `init.bat` → `HARNESS OK`. Conteos Oracle = Sheets: GENERAL 2791, UBICACION 1984, DOCUMENTOS 9815, COMPONENTE_AMBIENTAL 2098, ISIM 257, EAS_EAF 18043, IPASH 1161, PARTICIPANTES 190, ECOSISTEMAS_FRAGILES 49, FLORA 2999, FAUNA 1077. Detalle: `progress/impl_fase-4-deam-sheets-oracle.md`.
- **Pendiente opcional:** extract vía Hop (plugin Google Sheets) en vez de fallback Python.
