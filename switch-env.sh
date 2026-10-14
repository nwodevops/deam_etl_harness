#!/usr/bin/env bash
# Copia environments/<env>.json -> project-config.json y sobrepone DB_ORA_DW_*
# desde docs/credenciales/<env>.txt. No copia SysPassword. No pisa un valor
# real ya presente con un placeholder <...>.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
ENV="${1:-local}"
SRC="$ROOT/environments/${ENV}.json"
DST="$ROOT/project-config.json"
CRED="$ROOT/docs/credenciales/${ENV}.txt"
if [[ ! -f "$SRC" ]]; then
  echo "No existe: $SRC" >&2
  exit 1
fi
python3 - "$SRC" "$DST" "$CRED" "$ENV" <<'PY'
import json, re, sys
from pathlib import Path

src, dst, cred, env = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4]
data = json.load(open(src, encoding="utf-8"))
template = data.get("variables") or data.get("config", {}).get("variables") or []

PH = re.compile(r"<[^>]+>")

def is_placeholder(value) -> bool:
    if value is None or str(value).strip() == "":
        return True
    return PH.search(str(value)) is not None

def parse_cred(path: Path) -> dict[str, str]:
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"Falta o está vacío: {path}")
    wanted: dict[str, str] = {}
    for line in path.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if not line or line.startswith("#") or ":" not in line:
            continue
        key, val = line.split(":", 1)
        key, val = key.strip(), val.strip()
        if key == "SysPassword":
            continue
        if key in ("Host", "Port", "Service", "User", "Password"):
            wanted[key] = val
    missing = [k for k in ("Host", "Port", "Service", "User", "Password") if not wanted.get(k)]
    if missing:
        raise SystemExit(f"Faltan {', '.join(missing)} en {path}")
    return wanted

wanted = parse_cred(Path(cred))
host, port, service = wanted["Host"], wanted["Port"], wanted["Service"]
overlay = {
    "DB_ORA_DW_HOST": host,
    "DB_ORA_DW_PORT": port,
    "DB_ORA_DW_DATABASE": service,
    "DB_ORA_DW_USERNAME": wanted["User"],
    "DB_ORA_DW_PASSWORD": wanted["Password"],
    "DB_ORA_DW_URL": f"jdbc:oracle:thin:@//{host}:{port}/{service}",
}
for item in template:
    name = item.get("name")
    if name in overlay:
        item["value"] = overlay[name]

existing: dict[str, dict] = {}
dst_path = Path(dst)
if dst_path.is_file():
    prev = json.loads(dst_path.read_text(encoding="utf-8"))
    for item in (prev.get("config") or {}).get("variables") or []:
        name = item.get("name")
        if name and name not in existing:
            existing[name] = item

merged = []
for item in template:
    name = item.get("name")
    value = item.get("value")
    old = existing.get(name)
    if (
        is_placeholder(value)
        and old is not None
        and not is_placeholder(old.get("value"))
    ):
        value = old.get("value")
    merged.append({
        "name": name,
        "value": value,
        "description": item.get("description", ""),
    })

out = {
    "metadataBaseFolder": "${PROJECT_HOME}/metadata",
    "unitTestsBasePath": "${PROJECT_HOME}",
    "dataSetsCsvFolder": "${PROJECT_HOME}/datasets",
    "enforcingExecutionInHome": True,
    "parentProjectName": "default",
    "config": {"variables": merged},
}
dst_path.write_text(json.dumps(out, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
print(f"DW: {host}:{port}/{service} user={wanted['User']}")
print(f"OK: {src} + {cred} -> {dst} (env={env})")
PY
