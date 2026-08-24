#!/usr/bin/env python3
from pathlib import Path
import subprocess
import sys
import xml.etree.ElementTree as ET
import tempfile
import zipfile

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
subprocess.run(["lua", str(root / "tests/capabilities_test.lua")], cwd=root, check=True)
subprocess.run(["lua", str(root / "tests/actors_test.lua")], cwd=root, check=True)
subprocess.run(["lua", str(root / "tests/observations_test.lua")], cwd=root, check=True)
subprocess.run(["lua", str(root / "tests/inventory_test.lua")], cwd=root, check=True)
subprocess.run(["lua", str(root / "tests/load_test.lua")], cwd=root, check=True)
with tempfile.TemporaryDirectory() as directory:
    package = Path(directory) / "XelAssist.zip"
    subprocess.run([sys.executable, str(root / "scripts/package_xelassist.py"), str(package)], check=True)
    with zipfile.ZipFile(package) as archive:
        names = set(archive.namelist())
        if "XelAssist/XelAssist.toc" not in names: raise SystemExit("package missing TOC")
        if any(name.startswith("XelAssist/tests/") or name.startswith("XelAssist/.git") for name in names):
            raise SystemExit("package contains development files")
print("ok: TOC, XML, Lua 5.0 policy, graph scenarios and mocked full load")
