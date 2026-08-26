#!/usr/bin/env python3
"""Summarize automatic XelAssist runtime evidence from WoW SavedVariables."""

from __future__ import annotations

import argparse
import json
import os
from pathlib import Path
import subprocess


LUA_READER = r'''
local env = {}
local chunk, detail = loadfile(os.getenv("XELASSIST_SMOKE_FILE"), "t", env)
if not chunk then io.stderr:write(detail); os.exit(2) end
local ok, failure = pcall(chunk)
if not ok then io.stderr:write(failure); os.exit(3) end
local db, log = env.XelAssistCharDB or {}, env.XelAssistLog or {}
local rt, session = db.runtime or {}, (db.runtime or {}).session or {}
local function safe(value)
    if value == nil then return "" end
    local cleaned = string.gsub(tostring(value), "[\t\r\n]", " ")
    return cleaned
end
local maxLogSlice, budgetLog = 0, 0
for _, row in pairs(log) do
    maxLogSlice = math.max(maxLogSlice, tonumber(row.graphMaxSliceMs) or 0)
    if row.graphBudgetLimited then budgetLog = budgetLog + 1 end
end
local values = { safe(rt.version), safe(rt.class), safe(rt.level), safe(rt.role),
    safe(session.startedAt), safe(session.decisions), safe(session.maxSliceMs),
    safe(session.budgetLimited), safe(session.errors), safe(rt.lastErrorAt),
    safe(#log), safe(maxLogSlice), safe(budgetLog) }
io.write(table.concat(values, "\t"))
'''

FIELDS = ("version", "class", "level", "role", "startedAt", "decisions",
          "maxSliceMs", "budgetLimited", "errors", "lastErrorAt",
          "retainedDecisions", "retainedMaxSliceMs", "retainedBudgetLimited")
NUMERIC = {"level", "startedAt", "decisions", "maxSliceMs", "budgetLimited",
           "errors", "lastErrorAt", "retainedDecisions",
           "retainedMaxSliceMs", "retainedBudgetLimited"}


def read(path: Path, lua: str) -> dict[str, object]:
    environment = dict(os.environ)
    environment["XELASSIST_SMOKE_FILE"] = str(path)
    result = subprocess.run([lua, "-e", LUA_READER], env=environment,
                            capture_output=True, text=True)
    if result.returncode:
        return {"file": str(path), "error": result.stderr.strip()
                or f"Lua reader exited {result.returncode}"}
    values = result.stdout.split("\t")
    if len(values) != len(FIELDS):
        return {"file": str(path), "error":
                f"unexpected evidence field count {len(values)}: {result.stdout!r}"}
    record: dict[str, object] = {"file": str(path)}
    record.update(zip(FIELDS, values))
    for field in NUMERIC:
        value = str(record[field])
        record[field] = float(value) if "." in value else int(value or 0)
    observed_max = max(float(record["maxSliceMs"]),
                       float(record["retainedMaxSliceMs"]))
    record["sliceCeilingExceeded"] = observed_max > 3.23
    parts = path.parts
    if len(parts) >= 4:
        record["character"] = path.parents[1].name
        record["realm"] = path.parents[2].name
    return record


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("wtf", type=Path, help="WoW WTF account directory")
    parser.add_argument("--lua", default="lua")
    parser.add_argument("--expected-version")
    args = parser.parse_args()
    paths = [path for path in sorted(args.wtf.rglob(
        "SavedVariables/XelAssist.lua"))
        if len(path.relative_to(args.wtf).parts) == 4]
    records = [read(path, args.lua) for path in paths]
    for record in records:
        if "error" not in record and args.expected_version:
            record["expectedVersion"] = record["version"] == args.expected_version
            record["readyForReview"] = record["expectedVersion"] \
                and int(record["decisions"]) > 0 \
                and int(record["errors"]) == 0 \
                and not record["sliceCeilingExceeded"]
    print(json.dumps({"source": str(args.wtf), "count": len(records),
                      "sessions": records}, indent=2, sort_keys=True))
    return 1 if any("error" in record for record in records) else 0


if __name__ == "__main__":
    raise SystemExit(main())
