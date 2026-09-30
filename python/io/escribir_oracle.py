"""DESTINO Oracle: DataFrames -> tablas DW_* (truncate + full reload).

Conexión vía connection id `oracle_dw` (DB_ORA_DW_* en project-config.json).
Las tablas destino se crean si no existen: columnas VARCHAR2(4000) +
FECHA_CARGA DATE DEFAULT SYSDATE.
"""

from __future__ import annotations

import math
from pathlib import Path

import pandas as pd

from config import conn_vars, require_live_conn  # noqa: F401  (conn_vars usado por callers)
from introspect.h2_ddl import sanitize_ident


def _connect_oracle_dw(root: Path, variables: dict[str, str]):
    try:
        import oracledb
    except ImportError as exc:
        raise SystemExit("Falta oracledb. Instala: pip install -r python/requirements.txt") from exc
    cv = require_live_conn("oracle_dw", variables)
    return oracledb.connect(
        user=cv["username"],
        password=cv["password"],
        host=cv["host"],
        port=int(cv["port"]),
        service_name=cv["database"],
    )


MAX_VARCHAR2 = 4000


def _cell(val) -> str | None:
    if val is None:
        return None
    if isinstance(val, float) and math.isnan(val):
        return None
    if val is pd.NaT:
        return None
    if hasattr(val, "isoformat"):
        return str(val)
    s = str(val).strip()
    if not s:
        return None
    if len(s) > MAX_VARCHAR2:
        global _truncados
        _truncados += 1
        return s[:MAX_VARCHAR2]
    return s


_truncados = 0


def _ddl(tabla: str, df: pd.DataFrame) -> str:
    used: set[str] = set()
    cols = ",\n  ".join(f'"{sanitize_ident(str(c), used)}" VARCHAR2(4000)' for c in df.columns)
    return (
        f'CREATE TABLE {tabla} (\n'
        f'  {cols},\n'
        f'  "FECHA_CARGA" DATE DEFAULT SYSDATE NOT NULL\n'
        f')'
    )


def cargar(root: Path, variables: dict[str, str], salidas: dict[str, pd.DataFrame]) -> None:
    if not salidas:
        return
    conn = _connect_oracle_dw(root, variables)
    try:
        cur = conn.cursor()
        try:
            for tabla, df in salidas.items():
                if len(df.columns) == 0:
                    print(f"AVISO: {tabla} sin columnas (STG ausente?); se omite")
                    continue
                used: set[str] = set()
                nombres = [sanitize_ident(str(c), used) for c in df.columns]
                cur.execute(
                    "select count(*) from user_tables where table_name = :t", t=tabla
                )
                existe = cur.fetchone()[0] > 0
                if not existe:
                    cur.execute(_ddl(tabla, df))
                    print(f"Oracle CREATE {tabla}")

                cur.execute(f'TRUNCATE TABLE {tabla}')
                if len(df):
                    filas = [[_cell(v) for v in row] for row in df.itertuples(index=False, name=None)]
                    placeholders = ",".join(f":{i+1}" for i in range(len(nombres)))
                    col_list = ",".join(f'"{c}"' for c in nombres)
                    cur.executemany(
                        f'INSERT INTO {tabla} ({col_list}, "FECHA_CARGA") '
                        f'VALUES ({placeholders}, SYSDATE)',
                        filas,
                    )
                conn.commit()
                print(f"Salida ORACLE {tabla}: {len(df)} filas")
        finally:
            cur.close()
    finally:
        conn.close()
