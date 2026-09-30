"""Lógica DEAM: passthrough staging -> Oracle DW_DEAM_*.

Entrada: DataFrames DEAM_* (inyectados por main.py desde LECTURAS en
python/io/leer_h2.py). Salida: dict SALIDAS_ORACLE {tabla -> DataFrame};
escribir_oracle añade FECHA_CARGA y hace truncate + full reload.
Sin conexiones ni drivers aquí (regla de contrato).
"""

TABS = [
    "GENERAL",
    "UBICACION",
    "DOCUMENTOS",
    "COMPONENTE_AMBIENTAL",
    "ISIM",
    "EAS_EAF",
    "IPASH",
    "PARTICIPANTES",
    "ECOSISTEMAS_FRAGILES",
    "FLORA",
    "FAUNA",
]

SALIDAS_ORACLE = {}
for _tab in TABS:
    _df = globals().get(f"DEAM_{_tab}")
    if _df is not None and len(_df):
        SALIDAS_ORACLE[f"DW_DEAM_{_tab}"] = _df
    else:
        print(f"AVISO: DEAM_{_tab} vacía o ausente; no se carga")
