#!/usr/bin/env python3
from pathlib import Path
import subprocess
import sys
import xml.etree.ElementTree as ET

root = Path(__file__).resolve().parents[1]
toc = root / "XelAssist.toc"
for raw in toc.read_text().splitlines():
    line = raw.strip()
    if line and not line.startswith("##"):
        path = root / line.replace("\\", "/")
        if not path.exists(): raise SystemExit(f"missing TOC entry: {line}")
ET.parse(root / "Bindings.xml")
for path in root.glob("XelAssist*.lua"):
    text = path.read_text()
    forbidden = ["string.match", "string.gmatch", "SecureActionButton", "TargetNearestEnemy"]
    for token in forbidden:
        if token in text: raise SystemExit(f"{path.name}: forbidden {token}")
subprocess.run([sys.executable, str(root / "tests/evaluator_test.py")], check=True)
print("ok: TOC, XML, Lua 5.0 policy, pure evaluator")

