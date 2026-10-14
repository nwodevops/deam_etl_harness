#!/usr/bin/env bash
# Harness Linux — Sheets DEAM → H2 STG_DEAM_* → Oracle DW_DEAM_*.
# Bitácora del día: logs/init_YYYYMMDD.log (append, no se borra).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

mkdir -p "$ROOT/logs"
DAILY="$ROOT/logs/init_$(date +%Y%m%d).log"
RUNLOG="$(mktemp)"

cleanup() {
  if [[ -f "${RUNLOG:-}" ]]; then
    cat "$RUNLOG" >> "$DAILY"
    rm -f "$RUNLOG"
  fi
}
trap cleanup EXIT

log() { printf '%s\n' "$*" | tee -a "$RUNLOG"; }
fail() { echo -e "${RED}FAIL:${NC} $*" | tee -a "$RUNLOG" >&2; exit 1; }
warn() { echo -e "${YELLOW}AVISO:${NC} $*" | tee -a "$RUNLOG"; }
step() { echo -e "${GREEN}==>${NC} $*" | tee -a "$RUNLOG"; }

run() {
  set +e
  "$@" 2>&1 | tee -a "$RUNLOG"
  local rc=${PIPESTATUS[0]}
  set -e
  return "$rc"
}

log "=== inicio $(date -Iseconds) env=local ==="

PY=python3
[ -x .venv/bin/python ] && PY=.venv/bin/python

step "Prerrequisitos"
command -v java >/dev/null 2>&1 || fail "java no está en PATH"
[ -f h2/lib/h2-2.4.240.jar ] || fail "jar H2 no encontrado"
if [ ! -x .venv/bin/python ]; then
  fail "venv ausente o roto. Desde el repo padre: ./scripts/nuevo_etl.sh lo crea. A mano: python3 -m venv .venv && .venv/bin/python -m pip install -r python/requirements.txt"
fi
"$PY" -c "import yaml, pandas, jaydebeapi, oracledb, gspread" >/dev/null 2>&1 \
  || fail "el .venv no tiene dependencias (¿venv sin pip?). .venv/bin/python -m pip install -r python/requirements.txt"
if [ ! -f client_secret.json ]; then
  fail "falta client_secret.json"
fi

step "switch-env local (docs/credenciales/local.txt)"
run ./switch-env.sh local || fail "switch-env local"

step "Esquema Oracle"
run "$PY" - <<'PY' || fail "no pude leer DB_ORA_DW_*"
import json
from pathlib import Path
vars_ = {v["name"]: str(v.get("value") or "") for v in json.loads(Path("project-config.json").read_text(encoding="utf-8"))["config"]["variables"]}
host, port, service = vars_.get("DB_ORA_DW_HOST"), vars_.get("DB_ORA_DW_PORT"), vars_.get("DB_ORA_DW_DATABASE")
user = vars_.get("DB_ORA_DW_USERNAME") or ""
schema = (vars_.get("DB_ORA_DW_SCHEMA") or user).upper()
if not host or host.startswith("<") or not user or user.startswith("<"):
    raise SystemExit("DB_ORA_DW_* sigue en placeholder. Revisa docs/credenciales/local.txt")
print(f"Oracle DW {host}:{port}/{service} user={user} esquema={schema}")
PY

step "Reset H2 + DDL"
run ./h2/scripts/reset_and_create.sh || fail "reset H2"

step "Python create STG"
run "$PY" python/create_stg.py || fail "python/create_stg.py terminó con error"

step "Python extract Sheets -> H2"
run "$PY" python/io/extraer_sheets.py || fail "python/io/extraer_sheets.py terminó con error"

step "Python main"
run "$PY" python/main.py || fail "python/main.py terminó con error"

grep -Eq "Salida (RESULTADO|ORACLE)" "$RUNLOG" || fail "no hay Salida RESULTADO/ORACLE en el log"
grep -q "Excel:" "$RUNLOG" || warn "no se escribió Excel (opcional si falla openpyxl)"
if grep -q '\${[A-Za-z0-9_]\+}' "$RUNLOG"; then
  fail "log contiene variables Hop sin resolver"
fi

echo "" | tee -a "$RUNLOG"
echo -e "${GREEN}HARNESS OK${NC} — ver CHECKPOINTS.md. Bitácora: $DAILY" | tee -a "$RUNLOG"
exit 0
