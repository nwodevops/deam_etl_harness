#!/usr/bin/env python3
"""Valida feature_list.json: maximo una feature in_progress (uso de init.bat)."""

import json
import sys
from pathlib import Path

data = json.loads(Path("feature_list.json").read_text(encoding="utf-8"))
active = [f for f in data.get("features", []) if f.get("status") == "in_progress"]
if len(active) > 1:
    print(f"FAIL: mas de una in_progress: {', '.join(f['id'] for f in active)}", file=sys.stderr)
    sys.exit(1)
print(f"features: {len(data.get('features', []))}, in_progress: {len(active)}")
