#!/usr/bin/env python3
"""Architecture contracts plus execution of the real Lua graph scenarios."""
from pathlib import Path
import re
import subprocess

ROOT = Path(__file__).resolve().parents[1]
actions = (ROOT / "XelAssist_Actions.lua").read_text()
graph = (ROOT / "XelAssist_Graph.lua").read_text()
core = (ROOT / "XelAssist_Core.lua").read_text()
capabilities = (ROOT / "XelAssist_Capabilities.lua").read_text()

assert not (ROOT / "XelAssist_Profiles.lua").exists(), "typed rotations must not remain"
assert "XelAssistProfiles" not in graph + actions
assert "priority" not in actions.lower()

representative_spells = ["Mortal Strike", "Holy Strike", "Steady Shot", "Sinister Strike",
    "Mind Flay", "Lightning Bolt", "Frostbolt", "Shadow Bolt", "Shred"]
for spell in representative_spells:
    assert f'["{spell}"]' in actions, spell
for semantic in ["kind", "threat", "execute", "recovery", "channel", "aoe"]:
    assert re.search(rf"\b{semantic}\s*=", actions), semantic

assert "local MAX_STATES = 80" in graph
assert "local MAX_MS = 3" in graph
assert "local WIDTH = 4" in graph and "local MAX_DEPTH = 5" in graph
assert "XelAssistActors:Actions()" in graph
assert "XelAssistActors:Facts(action)" in graph
assert "candidate.tooltip.cooldown" in graph
assert "s.hasAggro" in graph and "s.tank" in graph and "threat" in graph
assert 's.role == "healer"' in graph and 's.role == "damage"' in graph
assert "s.moving and cast" in graph
assert "math.min(power, missing)" in graph
assert "math.min(expectedPower, s.targetHealth)" in graph
assert "resistance = XelAssistResistance:Estimate" in graph
assert "power = expectedPower" in graph and "threatPower" in graph
assert "s.targetHealthExact" in graph and "function C:Health" in capabilities
assert "XelAssistCharDB.graphDepth" in graph
assert "TargetNearestEnemy" not in graph + core
assert "TargetUnit(" not in graph + core
assert "ClearTarget(" not in graph + core
assert 'CastSpellByName(castName, "CLICK")' in core
assert "QueueSpellByName(castName)" in core
assert 'plan.target == "target" and QueueSpellByName' in core
assert "fallback=conservative hold" in core
assert "function XA:RuntimeAudit" in core and "function XA:RecordError" in core
assert "function UI:Refresh" not in core
assert "function C:Distance" in capabilities
assert "function C:Facts" in capabilities
assert "function C:CastName" in capabilities
assert "function C:BonusDamage" in capabilities and "function C:RangedDamage" in capabilities
assert "function C:TalentPoints" in capabilities
assert "function C:InferKnowledge" in capabilities and "IsPassiveSpell" in capabilities
assert 'event == "CHARACTER_POINTS_CHANGED"' in core
assert 'XelAssistResistance:IsOwnedCaster(arg1)' in core
assert re.search(r"SpellMiss\(\s*arg3, arg2, arg4, arg1\)", core)
assert 'NP_EnableAuraCastEvents' in core
assert 'NP_EnableSpellStartEvents' in core and 'NP_EnableSpellGoEvents' in core
assert 'NP_EnableSpellDamageEvents' not in core and 'NP_EnableSpellMissEvents' not in core

subprocess.run(["lua", str(ROOT / "tests/graph_scenarios.lua")], cwd=ROOT, check=True)
print("ok: semantic action graph contracts and Lua scenarios")
