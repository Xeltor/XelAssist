#!/usr/bin/env python3
"""Architecture contracts plus execution of the real Lua graph scenarios."""
from pathlib import Path
import re
import subprocess

ROOT = Path(__file__).resolve().parents[1]
GRAPH_FUNCTION_CEILING = 100


def lua_tokens(text):
    """Yield Lua identifiers and structural tokens without strings/comments."""
    index = 0
    line = 1
    length = len(text)
    while index < length:
        char = text[index]
        if char in " \t\r\f\v":
            index += 1
        elif char == "\n":
            line += 1
            index += 1
        elif text.startswith("--", index):
            long_comment = re.match(r"\[(=*)\[", text[index + 2:])
            if long_comment:
                equals = long_comment.group(1)
                close = "]" + equals + "]"
                start = index + 2 + len(long_comment.group(0))
                finish = text.find(close, start)
                finish = length if finish < 0 else finish + len(close)
                line += text[index:finish].count("\n")
                index = finish
            else:
                finish = text.find("\n", index + 2)
                index = length if finish < 0 else finish
        elif char in {'"', "'"}:
            quote = char
            index += 1
            while index < length:
                if text[index] == "\\":
                    if index + 1 < length and text[index + 1] == "\n":
                        line += 1
                    index += 2
                elif text[index] == quote:
                    index += 1
                    break
                else:
                    if text[index] == "\n":
                        line += 1
                    index += 1
        elif char == "[":
            long_string = re.match(r"\[(=*)\[", text[index:])
            if long_string:
                equals = long_string.group(1)
                close = "]" + equals + "]"
                start = index + len(long_string.group(0))
                finish = text.find(close, start)
                finish = length if finish < 0 else finish + len(close)
                line += text[index:finish].count("\n")
                index = finish
            else:
                yield char, line
                index += 1
        elif char.isalpha() or char == "_":
            finish = index + 1
            while finish < length and (text[finish].isalnum() or text[finish] == "_"):
                finish += 1
            yield text[index:finish], line
            index = finish
        else:
            yield char, line
            index += 1


def top_level_function_spans(text):
    """Return (label, start, end) for chunk-level Lua function bodies."""
    tokens = list(lua_tokens(text))
    blocks = []
    spans = []
    for index, (token, line) in enumerate(tokens):
        if token == "function":
            label = f"anonymous function at line {line}"
            if index + 1 < len(tokens) and re.match(r"^[A-Za-z_]\w*$", tokens[index + 1][0]):
                parts = [tokens[index + 1][0]]
                cursor = index + 2
                while cursor + 1 < len(tokens) and tokens[cursor][0] in {".", ":"}:
                    if not re.match(r"^[A-Za-z_]\w*$", tokens[cursor + 1][0]):
                        break
                    parts.extend([tokens[cursor][0], tokens[cursor + 1][0]])
                    cursor += 2
                label = "".join(parts)
            record = (label, line) if not blocks else None
            blocks.append(["function", record])
        elif token in {"if", "repeat"}:
            blocks.append([token, None])
        elif token in {"for", "while"}:
            blocks.append([token + "_pending", None])
        elif token == "do":
            if blocks and blocks[-1][0] in {"for_pending", "while_pending"}:
                blocks[-1][0] = blocks[-1][0].replace("_pending", "")
            else:
                blocks.append(["do", None])
        elif token == "until":
            if blocks and blocks[-1][0] == "repeat":
                blocks.pop()
        elif token == "end":
            if not blocks:
                continue
            kind, record = blocks.pop()
            if kind == "function" and record:
                spans.append((record[0], record[1], line))
    return spans


actions = (ROOT / "Combat/Knowledge.lua").read_text()
pet_knowledge = (ROOT / "Combat/PetKnowledge.lua").read_text()
graph_files = sorted((ROOT / "Graph").glob("*.lua"))
graph = "\n".join(path.read_text() for path in graph_files)
engine = (ROOT / "Graph/Engine.lua").read_text()
core = "\n".join(path.read_text() for path in sorted((ROOT / "Core").glob("*.lua")))
engaged_target_config = (ROOT / "Core/EngagedTargetConfig.lua").read_text()
target_guard = (ROOT / "Core/TargetGuard.lua").read_text()
capabilities = (ROOT / "Game/Capabilities.lua").read_text()
resistance = (ROOT / "Combat/Resistance.lua").read_text()
target_modifiers = (ROOT / "Combat/TargetModifiers.lua").read_text()
delivery = (ROOT / "Combat/Delivery.lua").read_text()
hostile_target_policy = (ROOT / "Graph/HostileTargetPolicy.lua").read_text()

assert not (ROOT / "XelAssist_Profiles.lua").exists(), "typed rotations must not remain"
assert "XelAssistProfiles" not in graph + actions
assert "priority" not in actions.lower()
assert "priority" not in pet_knowledge.lower(), "pet knowledge must not become a rotation"
assert "XelAssist.Combat.PetKnowledge" in pet_knowledge
for pet_action in ["Growl", "Cower", "Bite", "Claw", "Screech", "Dash",
        "Dive", "Charge", "Prowl", "Thunderstomp", "Lightning Breath"]:
    assert f'"{pet_action}"' in pet_knowledge, pet_action
assert "BY_ID[spellId]" in pet_knowledge and "BY_NAME[ownerClass][name]" in pet_knowledge
actors = (ROOT / "Game/Actors.lua").read_text()
assert "PET_KNOWLEDGE" not in actors
assert "PetKnowledge:Facts(" in actors and "actionSpellId, candidate.name, ownerClass" in actors

representative_spells = ["Mortal Strike", "Holy Strike", "Steady Shot", "Sinister Strike",
    "Mind Flay", "Lightning Bolt", "Frostbolt", "Shadow Bolt", "Shred"]
for spell in representative_spells:
    assert f'["{spell}"]' in actions, spell
for semantic in ["kind", "threat", "execute", "recovery", "channel", "aoe"]:
    assert re.search(rf"\b{semantic}\s*=", actions), semantic

search_policy = (ROOT / "Graph/SearchPolicy.lua").read_text()
assert "P.MIN_STATES = 256" in search_policy and "P.MEDIUM_STATES = 512" in search_policy
assert "P.MAX_STATES = 768" in search_policy
assert "P.MIN_MS = 8" in search_policy and "P.MEDIUM_MS = 12" in search_policy
assert "P.MAX_MS = 18" in search_policy
assert "P.WIDTH = 5" in search_policy and "P.MAX_DECISIONS = 24" in search_policy
assert "P.MAX_SECONDS = 45" in search_policy and "P.DISCOUNT_SECONDS = 4.5" in search_policy
assert "level > 2" in engine and "level >= 2" in engine
assert '"graph budget exceeded"' not in engine
assert "budgetLimited" in engine
assert "XelAssist.Game.Actors:Actions()" in graph
assert "XelAssist.Game.Actors:Facts(action)" in graph
assert "candidate.tooltip.cooldown" in graph
assert ".hasAggro" in graph and ".tank" in graph and "threat" in graph
assert '.role == "healer"' in graph and '.role == "damage"' in graph
assert ".moving and cast" in graph
assert "math.min(power, missing)" in graph
assert re.search(r"math\.min\(expected(?:Power)?,\s*targetHealth\)", graph)
assert "targetHealthAtImpact" in graph and "ambient attack resolves first" in graph
assert "resistance = XelAssist.Combat.Resistance:Estimate" in graph
assert re.search(r"power\s*=\s*(?:context\.)?expectedPower", graph) and "threatPower" in graph
assert ".targetHealthExact" in graph and "function C:Health" in capabilities
assert "XelAssistCharDB.graphDepth" in search_policy
assert "XelAssistCharDB.visibleSteps" in (ROOT / "UI/HUD.lua").read_text()
assert "TargetNearestEnemy" not in graph + core
assert "TargetUnit(" not in graph + core
assert "ClearTarget(" not in graph + core
assert 'CastSpellByName(castName, "CLICK")' in core
assert "QueueSpellByName(castName, guid)" in core
assert "QueueSpellByName(castName)" not in core
assert "context.usesHostileQueue" in core and "context.hostilePlan" in core
assert 'context.hostilePlan and plan.targetSource ~= "engaged"' in core
assert "XelAssistCharDB.toggles.engagedTargets = false" in engaged_target_config
assert "XelAssistCharDB.toggles.engagedTargets == true" in hostile_target_policy
assert "QueueSpellByName ~= nil" in hostile_target_policy
assert "function G:GuidHostileAnchor" in target_guard
assert "HostileEngagement:Validate(castRef)" in target_guard
assert 'plan.targetSource ~= "engaged"' in target_guard
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
assert "resistance:IsOwnedCaster(casterGuid)" in core
assert re.search(r"SpellMiss\(\s*arg3, arg2, arg4, arg1\)", core)
assert 'NP_EnableAuraCastEvents' in core
assert 'NP_EnableSpellStartEvents' in core and 'NP_EnableSpellGoEvents' in core
assert 'NP_EnableSpellDamageEvents' not in core and 'NP_EnableSpellMissEvents' not in core
assert "XelAssist.Graph" not in resistance, "resistance observations must not depend on graph search"
assert "XelAssist.Combat.TargetModifiers:Active" in resistance
assert "function M:Active" in target_modifiers
assert "function M:AggregateReductions" in target_modifiers
assert "function M:AggregateDamageTaken" in target_modifiers
assert not any(name in delivery for name in
    ["XelAssist.Combat.Resistance", "XelAssist.Graph", "XelAssist.Game.Encounter"]), \
    "stateless delivery mechanics must not depend on storage, graph, or encounter modules"
for contract in ["function D:SpellTraits", "function D:Record",
    "function D:PhysicalContext", "function D:AutoAttackEvidence"]:
    assert contract in delivery, contract
assert "trimDelivery" not in resistance and "physicalHitFromSkills" not in resistance

graph_modules = ["State", "Targets", "Effects", "AutoShotEffects", "Scoring", "OngoingEffects",
    "ActionEffects", "Timeline", "Transitions"]
for module in graph_modules:
    module_path = ROOT / "Graph" / f"{module}.lua"
    assert module_path.exists(), f"missing graph module file: {module_path.relative_to(ROOT)}"
    assert f"XelAssist.Graph.{module}" in module_path.read_text(), \
        f"missing graph module namespace: {module}"
for path in graph_files:
    source = path.read_text()
    assert len(source.splitlines()) <= 450, \
        f"{path.relative_to(ROOT)} regressed past the graph module ceiling"
    oversized = [(label, start, end) for label, start, end in top_level_function_spans(source)
        if end - start + 1 > GRAPH_FUNCTION_CEILING]
    assert not oversized, \
        f"{path.relative_to(ROOT)} has top-level functions over {GRAPH_FUNCTION_CEILING} lines: {oversized}"
assert "XelAssist.Graph = {}" not in graph, "graph modules must extend the bootstrap namespace"
assert len(engine.splitlines()) <= 450, "graph facade/search regressed into a monolith"

subprocess.run(["lua", str(ROOT / "tests/graph_scenarios.lua")], cwd=ROOT, check=True)
print("ok: semantic action graph contracts and Lua scenarios")
