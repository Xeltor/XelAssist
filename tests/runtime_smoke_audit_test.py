#!/usr/bin/env python3
import json
from pathlib import Path
import subprocess
import tempfile

root = Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory() as directory:
    account_root = Path(directory) / "Account" / "TEST"
    shared = account_root / "SavedVariables"
    shared.mkdir(parents=True)
    (shared / "XelAssist.lua").write_text(
        'XelAssistCharDB = { runtime = { class = "" } }')
    account = account_root / "Realm" / "Testmage" / "SavedVariables"
    account.mkdir(parents=True)
    (account / "XelAssist.lua").write_text('''
XelAssistCharDB = { role = "damage", runtime = {
  version = "0.8.test", class = "MAGE", level = 32,
  session = { startedAt = 100, decisions = 4, maxSliceMs = 2.1,
    budgetLimited = 1, errors = 0 } } }
XelAssistLog = {
  { graphMaxSliceMs = 1.8, graphBudgetLimited = false },
  { graphMaxSliceMs = 2.1, graphBudgetLimited = true } }
''')
    result = subprocess.run(
        ["python3", str(root / "scripts/audit_runtime_smoke.py"), directory],
        capture_output=True, text=True)
    assert result.returncode == 0, result.stdout + result.stderr
    report = json.loads(result.stdout)
    row = report["sessions"][0]
    assert report["count"] == 1 and row["class"] == "MAGE"
    assert row["level"] == 32 and row["decisions"] == 4
    assert row["maxSliceMs"] == 2.1 and row["retainedBudgetLimited"] == 1
    assert not row["sliceCeilingExceeded"]
    assert row["character"] == "Testmage" and row["realm"] == "Realm"
print("ok: automatic runtime smoke evidence is extracted without addon commands")
