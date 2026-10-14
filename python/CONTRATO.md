# Contrato logica/ (arquetipo mínimo)

## Flujo

```
python/main.py
  → io/leer_h2.py     (H2 → DataFrames)
  → logica/*.py       (un solo archivo)
  → io/escribir_excel.py    (si hay RESULTADO)
  → io/escribir_oracle.py   (si hay SALIDAS_ORACLE)
```

## Entrada

DataFrames con nombres = claves de `LECTURAS` en `python/io/leer_h2.py`.

Demo: `DEMO` ← `PUBLIC.DEMO_TABLA_EJEMPLO`. DEAM: `DEAM_*` ← `STG_DEAM_*`.

## Salidas

| Nombre | Descripción |
|---|---|
| `RESULTADO` | DataFrame principal → `output/resultado.xlsx` (opcional si hay Oracle) |
| `SALIDAS_ORACLE` | dict {tabla → DataFrame} → Oracle `oracle_dw`, truncate + reload, `FECHA_CARGA` |

Salidas opcionales reconocidas por main: prefijos `INT_`, `QA_`, `PROF_`, `DF_`.
Debe existir `RESULTADO` o `SALIDAS_ORACLE` (o ambos).

## Reglas

- Un solo `.py` en `logica/`.
- Sin conexiones ni drivers en `logica/` (I/O en `python/io/`).
- `pandas` inyectado como `pd`.

Plantilla: `python/plantilla_logica.py`.
