#!/usr/bin/env python3
"""EXTRACT Google Sheets -> tablas STG_* en H2 (fallback mientras no hay
plugin Google Sheets verificado en Hop remote-windows).

Lee inputs.yaml (type: sheets), descarga cada worksheet con gspread
(client_secret.json, service account) y aterrizan filas en H2.

Uso (H2 ya levantado y DDL aplicado por create_stg.py):
  .venv/bin/python python/io/extraer_sheets.py
"""

from __future__ import annotations

import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
PY = HERE.parent
if str(PY) not in sys.path:
    sys.path.insert(0, str(PY))

from config import load_sources, load_vars, project_root  # noqa: E402
from h2_conn import connect_h2  # noqa: E402
from introspect.sheets import _columns_from_names, con_backoff  # noqa: E402


def _filas_a_insertar(
    headers: list[str], rows: list[list[str]], header_row: int
) -> tuple[list[str], list[list[str]]]:
    """Columnas sanitizadas (iguales a create_stg) + filas alineadas a ellas."""
    # _columns_from_names descarta headers vacíos en orden; los índices a
    # aterrizar son exactamente los de headers no vacíos.
    idx = [i for i, h in enumerate(headers) if h is not None and str(h).strip() != ""]
    cols = _columns_from_names(headers)
    if not cols or len(cols) != len(idx):
        return [], []
    data = []
    for row in rows[header_row:]:  # get_all_values incluye la fila de headers
        if not any(str(c).strip() for c in row if c is not None):
            continue
        data.append([(row[i] if i < len(row) else "") for i in idx])
    return [c.name for c in cols], data


def extraer_sheets(root: Path, variables: dict[str, str]) -> None:
    try:
        import gspread
    except ImportError as exc:
        raise SystemExit("Falta gspread. Instala: pip install -r python/requirements.txt") from exc

    sources = [s for s in load_sources(root, variables) if s["type"] == "sheets"]
    if not sources:
        print("extraer_sheets: no hay fuentes type: sheets; no-op")
        return

    secret = root / "client_secret.json"
    if not secret.is_file():
        raise FileNotFoundError(f"No se encuentra {secret} (service account Google, gitignored)")
    gc = gspread.service_account(filename=str(secret))

    conn = connect_h2(root, variables)
    try:
        cur = conn.cursor()
        try:
            for src in sources:
                stg = src["stg_table"]
                worksheet = str(src["worksheet"])
                header_row = int(src.get("header_row", 1))
                sheet = gc.open_by_key(src["spreadsheet_key"]).worksheet(worksheet)
                valores = con_backoff(sheet.get_all_values)
                if not valores or len(valores) < header_row:
                    raise ValueError(f"Sheets '{worksheet}': sin fila de headers {header_row}")
                cols, data = _filas_a_insertar(valores[header_row - 1], valores, header_row)
                if not cols:
                    raise ValueError(f"Sheets '{worksheet}': headers no usables")

                cur.execute(f'DELETE FROM "{stg}"')
                if data:
                    placeholders = ",".join("?" * len(cols))
                    col_list = ",".join(f'"{c}"' for c in cols)
                    cur.executemany(
                        f'INSERT INTO "{stg}" ({col_list}) VALUES ({placeholders})',
                        data,
                    )
                conn.commit()
                print(f"{stg}: {len(data)} filas desde '{worksheet}'")
        finally:
            cur.close()
    finally:
        conn.close()


def main() -> int:
    root = project_root()
    variables = load_vars(root)
    extraer_sheets(root, variables)
    print("Extract Sheets -> H2 listo.")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (FileNotFoundError, ValueError, KeyError) as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        raise SystemExit(1)
