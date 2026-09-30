"""Introspección Google Sheets: fila de headers. Todo VARCHAR. No extrae filas.

Si la fuente declara `catalog` (F1 ODs), el DDL sale del JSON (sin llamar a la API).
"""

from __future__ import annotations

import time
from pathlib import Path

from .h2_ddl import Column, map_h2_type, sanitize_ident


def con_backoff(fn, *args, intentos: int = 5, **kwargs):
    """Ejecuta una llamada a la API de Sheets con reintentos ante cuota (429)."""
    from gspread.exceptions import APIError

    for i in range(intentos):
        try:
            return fn(*args, **kwargs)
        except APIError as exc:
            if "429" not in str(exc) or i == intentos - 1:
                raise
            espera = 45 * (2**i)
            print(f"  cuota Sheets (429); espero {espera}s (intento {i + 1}/{intentos})")
            time.sleep(espera)
    raise RuntimeError("inaccesible")


def _columns_from_names(names: list[str]) -> list[Column]:
    used: set[str] = set()
    cols: list[Column] = []
    for header in names:
        if header is None or str(header).strip() == "":
            continue
        cols.append(
            Column(
                name=sanitize_ident(str(header), used),
                h2_type=map_h2_type("VARCHAR", sheets=True),
            )
        )
    return cols


def introspect(source: dict, variables: dict[str, str], root: Path | None = None) -> list[Column]:
    if root is None:
        raise ValueError("sheets: falta root del proyecto")

    catalog_rel = (source.get("catalog") or "").strip()
    if catalog_rel:
        familia = (source.get("familia") or "").strip().lower()
        if familia == "f2_csep" or "f2_csep" in catalog_rel:
            from f2_csep_catalog import load_catalog, stg_columns
        else:
            from f1_ods_catalog import load_catalog, stg_columns

        catalog = load_catalog(root, catalog_rel)
        cols = _columns_from_names(stg_columns(catalog))
        if not cols:
            raise ValueError(f"{source.get('stg_table')}: catálogo sin columns")
        return cols

    try:
        import gspread
    except ImportError as exc:
        raise SystemExit(
            "Falta gspread. Instala: pip install -r python/requirements.txt"
        ) from exc

    secret = root / "client_secret.json"
    if not secret.is_file():
        raise FileNotFoundError(
            f"No se encuentra {secret} (service account Google, gitignored)"
        )

    key = (source.get("spreadsheet_key") or "").strip()
    worksheet = source.get("worksheet")
    if not key:
        raise ValueError(f"{source.get('stg_table')}: falta spreadsheet_key")
    if not worksheet:
        raise ValueError(f"{source.get('stg_table')}: falta worksheet")
    if key.startswith("${"):
        raise ValueError(
            f"spreadsheet_key no resuelta: {key}. "
            "Define la variable en project-config.json"
        )

    header_raw = source.get("header_row", 1)
    try:
        header_row = int(header_raw)
    except (TypeError, ValueError) as exc:
        raise ValueError(
            f"{source.get('stg_table')}: header_row debe ser entero, recibido {header_raw!r}"
        ) from exc
    if header_row < 1:
        raise ValueError(f"{source.get('stg_table')}: header_row debe ser >= 1")

    gc = gspread.service_account(filename=str(secret))
    book = gc.open_by_key(key)
    sheet = book.worksheet(str(worksheet))
    headers = con_backoff(sheet.row_values, header_row)
    if not headers:
        raise ValueError(f"Sheets '{worksheet}': fila {header_row} vacía")

    cols = _columns_from_names([str(h) for h in headers])
    if not cols:
        raise ValueError(f"Sheets '{worksheet}': fila {header_row} sin headers usables")
    return cols
