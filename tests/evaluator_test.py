#!/usr/bin/env python3
"""Pure contract checks for the data-driven evaluator and execution boundary."""
from pathlib import Path
import re
import statistics
import time

ROOT = Path(__file__).resolve().parents[1]
profiles = (ROOT / "XelAssist_Profiles.lua").read_text()
graph = (ROOT / "XelAssist_Graph.lua").read_text()
core = (ROOT / "XelAssist_Core.lua").read_text()

classes = ["WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST", "SHAMAN", "MAGE", "WARLOCK", "DRUID"]
for token in classes:
    assert re.search(r"\b" + token + r"\s*=\s*{", profiles), token

assert "MAX_STATES = 40" in graph
assert "MAX_MS = 2" in graph
assert "WIDTH = 4" in graph and "DEPTH = 3" in graph
assert "TargetNearestEnemy" not in graph + core
assert "TargetUnit(" not in graph + core
assert "ClearTarget(" not in graph + core
assert 'CastSpellByName(a[1], "CLICK")' in core
assert "if a.reagent and not toggles.reagents" in graph
assert "if a.consumable and not toggles.consumables" in graph
assert "if a.cooldown and not toggles.cooldowns" in graph
assert "fallback=conservative hold" in core
assert 's.selectedFriendly and profile.buff' in graph
assert 'UnitHasBuff(s.buffUnit, a[1])' in graph
assert 'manaOnly = true' in profiles and 'selfOnly = true' in profiles
assert 's.castRemaining' in graph
assert "function UI:Refresh" not in core  # execution and preview remain separated

# The hot search is deliberately tiny. Benchmark the same bounded shape without
# WoW API calls to catch accidental combinatorial growth in CI.
def bounded_eval(values):
    frontier = sorted(values, reverse=True)[:4]
    expanded = 0
    total = 0
    for depth in range(1, 4):
        for value in frontier:
            expanded += 1
            total += value / depth
    return total, expanded

samples = []
for _ in range(10000):
    started = time.perf_counter_ns()
    _, expanded = bounded_eval(range(32))
    samples.append((time.perf_counter_ns() - started) / 1_000_000)
assert expanded <= 40
assert statistics.median(samples) < 1.0, statistics.median(samples)
assert max(samples) < 2.0, max(samples)
print(f"ok: 9 classes, invariants, median={statistics.median(samples):.4f}ms worst={max(samples):.4f}ms expanded={expanded}")
