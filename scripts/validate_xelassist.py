#!/usr/bin/env python3
from pathlib import Path
import re
import subprocess
import sys
import xml.etree.ElementTree as ET
import tempfile
import zipfile

from addon_manifest import production_lua_files, toc_entries

root = Path(__file__).resolve().parents[1]


def lua_code_without_comments_or_strings(text: str) -> str:
    """Enough lexical stripping to reject syntax added after the 1.12 Lua 5.0 VM."""
    text = re.sub(r"--\[\[.*?\]\]", "", text, flags=re.DOTALL)
    text = re.sub(r"--[^\n]*", "", text)
    text = re.sub(r'"(?:\\.|[^"\\])*"', '""', text)
    text = re.sub(r"'(?:\\.|[^'\\])*'", "''", text)
    return text


def lua_tokens(text: str):
    """Yield identifiers, strings, and punctuation while ignoring Lua comments."""
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
            start_line = line
            value = []
            index += 1
            while index < length:
                if text[index] == "\\":
                    value.append(text[index:index + 2])
                    if index + 1 < length and text[index + 1] == "\n":
                        line += 1
                    index += 2
                elif text[index] == quote:
                    index += 1
                    break
                else:
                    value.append(text[index])
                    if text[index] == "\n":
                        line += 1
                    index += 1
            yield "string", "".join(value), start_line
        elif char == "[":
            long_string = re.match(r"\[(=*)\[", text[index:])
            if long_string:
                equals = long_string.group(1)
                close = "]" + equals + "]"
                start_line = line
                start = index + len(long_string.group(0))
                finish = text.find(close, start)
                content_end = length if finish < 0 else finish
                index = length if finish < 0 else finish + len(close)
                value = text[start:content_end]
                line += value.count("\n")
                yield "string", value, start_line
            else:
                yield "symbol", char, line
                index += 1
        elif char.isalpha() or char == "_":
            finish = index + 1
            while finish < length and (text[finish].isalnum() or text[finish] == "_"):
                finish += 1
            yield "identifier", text[index:finish], line
            index = finish
        else:
            yield "symbol", char, line
            index += 1


def dotted_createframe_names(text: str):
    """Find literal dotted names passed as CreateFrame's global-name argument."""
    tokens = list(lua_tokens(text))
    found = []
    pairs = {")": "(", "]": "[", "}": "{"}
    for index, token in enumerate(tokens):
        if token[:2] != ("identifier", "CreateFrame"):
            continue
        if index + 1 >= len(tokens) or tokens[index + 1][:2] != ("symbol", "("):
            continue
        nesting = ["("]
        argument = 1
        for kind, value, line in tokens[index + 2:]:
            if kind == "symbol" and value in {"(", "[", "{"}:
                nesting.append(value)
            elif kind == "symbol" and value in pairs:
                if nesting and nesting[-1] == pairs[value]:
                    nesting.pop()
                if not nesting:
                    break
            elif kind == "symbol" and value == "," and len(nesting) == 1:
                argument += 1
            elif argument == 2 and kind == "string" and "." in value:
                found.append((value, line))
                break
    return found


toc = root / "XelAssist.toc"
toc_text = toc.read_text()
toc_version = re.search(r"^## Version:\s*(\S+)\s*$", toc_text, re.MULTILINE)
bootstrap_version = re.search(
    r'^XelAssist\.version\s*=\s*"([^"]+)"\s*$',
    (root / "Core/Bootstrap.lua").read_text(), re.MULTILINE)
readme_version = re.search(
    r"^# XelAssist\s+(\S+)\s*$", (root / "README.md").read_text(), re.MULTILINE)
versions = [match.group(1) if match else None
    for match in (toc_version, bootstrap_version, readme_version)]
if None in versions or len(set(versions)) != 1:
    raise SystemExit(
        "release version mismatch across TOC, Bootstrap, and README: "
        + ", ".join(str(version) for version in versions))
for entry in toc_entries(root):
    path = root / entry
    if not path.exists(): raise SystemExit(f"missing TOC entry: {entry.as_posix()}")
ET.parse(root / "Bindings.xml")
root_modules = sorted(path.name for path in root.glob("XelAssist_*.lua"))
if root_modules:
    raise SystemExit("prefixed root Lua modules are forbidden: " + ", ".join(root_modules))

legacy_line_ceilings = {
    "Combat/Resistance.lua": 1850,
    "Game/Capabilities.lua": 1004,
    "UI/HUD.lua": 598,
}
production_files = list(production_lua_files(root))
for path in production_files:
    text = path.read_text()
    dotted_names = dotted_createframe_names(text)
    if dotted_names:
        raise SystemExit(
            f"{path.relative_to(root)}: dotted CreateFrame global names are forbidden: {dotted_names}")
    forbidden = ["string.match", "string.gmatch", "SecureActionButton", "TargetNearestEnemy"]
    for token in forbidden:
        if token in text: raise SystemExit(f"{path.relative_to(root)}: forbidden {token}")
    code = lua_code_without_comments_or_strings(text)
    for loader in ["require(", "dofile("]:
        if loader in code:
            raise SystemExit(f"{path.relative_to(root)}: production code must use TOC loading, not {loader[:-1]}")
    flat_module = re.search(r"^\s*(XelAssist[A-Z][A-Za-z]+)\s*=", code, re.MULTILINE)
    if flat_module and flat_module.group(1) not in {"XelAssistDB", "XelAssistCharDB", "XelAssistLog"}:
        raise SystemExit(f"{path.relative_to(root)}: flat addon global {flat_module.group(1)} is forbidden")
    if "%" in code: raise SystemExit(f"{path.relative_to(root)}: Lua 5.1 modulo operator is not valid in Lua 5.0")
    if "#" in code: raise SystemExit(f"{path.relative_to(root)}: Lua 5.1 length operator is not valid in Lua 5.0")
    relative = path.relative_to(root).as_posix()
    semantic_consumers = {"Game/SpellSemantics.lua",
        "Game/Player/DruidFormState.lua", "Game/Player/TotemState.lua",
        "Game/Player/ShamanActions.lua",
        "Graph/DispelDecision.lua"}
    if relative not in semantic_consumers and "SpellSemantics" in code:
        raise SystemExit(
            f"{relative}: unaudited recommendation caller for SpellSemantics")
    lines = len(text.splitlines())
    ceiling = legacy_line_ceilings.get(relative, 450)
    if lines > ceiling:
        raise SystemExit(f"{relative}: {lines} lines exceeds architecture ceiling {ceiling}")

# Keep new functions reviewable while recording the few inherited long-function
# ceilings explicitly. The listing comes from the same Lua compiler used by the
# local suite and reports exact source spans for nested functions as well.
legacy_function_ceilings = {
    "Combat/Resistance.lua": 494,
    "Core/Runtime.lua": 198,
    "UI/Settings.lua": 189,
    "UI/HUD.lua": 187,
    "Game/Capabilities.lua": 181,
    "Combat/Delivery.lua": 148,
    "Game/SpellClassification.lua": 133,
}
relative_files = [path.relative_to(root).as_posix() for path in production_files]
listing = subprocess.run(
    ["luac", "-l", "-p", *relative_files], cwd=root,
    check=True, capture_output=True, text=True).stdout
function_pattern = re.compile(r"^function <(.+):(\d+),(\d+)>", re.MULTILINE)
for match in function_pattern.finditer(listing):
    relative, start, finish = match.group(1), int(match.group(2)), int(match.group(3))
    length = finish - start + 1
    ceiling = legacy_function_ceilings.get(relative, 100)
    if length > ceiling:
        raise SystemExit(
            f"{relative}:{start}: function is {length} lines; ceiling is {ceiling}")
subprocess.run([sys.executable, str(root / "tests/evaluator_test.py")], check=True)
subprocess.run(["lua", str(root / "tests/playability_low_band_test.lua")], cwd=root, check=True)
subprocess.run(["lua", str(root / "tests/playability_mid_band_test.lua")], cwd=root, check=True)
subprocess.run(["lua", str(root / "tests/playability_mid_casters_test.lua")], cwd=root, check=True)
subprocess.run(["lua", str(root / "tests/playability_mid_hybrids_test.lua")], cwd=root, check=True)
subprocess.run(["lua", str(root / "tests/playability_level60_physical_test.lua")], cwd=root, check=True)
subprocess.run(["lua", str(root / "tests/playability_level60_casters_test.lua")], cwd=root, check=True)
subprocess.run(["lua", str(root / "tests/playability_level60_hybrids_test.lua")], cwd=root, check=True)
subprocess.run(["lua", str(root / "tests/search_policy_test.lua")], cwd=root, check=True)
subprocess.run(["lua", str(root / "tests/search_session_test.lua")], cwd=root, check=True)
subprocess.run(["lua", str(root / "tests/combat_revision_test.lua")], cwd=root, check=True)
subprocess.run(["lua", str(root / "tests/combat_revision_events_test.lua")], cwd=root, check=True)
subprocess.run(["lua", str(root / "tests/search_lifecycle_test.lua")], cwd=root, check=True)
subprocess.run(["lua", str(root / "tests/search_preparation_test.lua")], cwd=root, check=True)
subprocess.run(["lua", str(root / "tests/publication_guard_test.lua")], cwd=root, check=True)
subprocess.run(["lua", str(root / "tests/spell_topology_test.lua")], cwd=root, check=True)
subprocess.run(["lua", str(root / "tests/spell_semantics_test.lua")], cwd=root, check=True)
subprocess.run(["lua", str(root / "tests/dispel_decision_test.lua")], cwd=root, check=True)
subprocess.run(["lua", str(root / "tests/geometry_test.lua")], cwd=root, check=True)
subprocess.run(["lua", str(root / "tests/capabilities_test.lua")], cwd=root, check=True)
subprocess.run(["lua", str(root / "tests/target_modifier_facts_test.lua")], cwd=root, check=True)
subprocess.run(["lua", str(root / "tests/resource_exchange_test.lua")], cwd=root, check=True)
subprocess.run(["lua", str(root / "tests/health_transfer_test.lua")], cwd=root, check=True)
subprocess.run(["lua", str(root / "tests/health_transfer_graph_test.lua")], cwd=root, check=True)
subprocess.run(["lua", str(root / "tests/mage_channel_tick_test.lua")], cwd=root, check=True)
subprocess.run(["lua", str(root / "tests/warlock_leech_channel_test.lua")], cwd=root, check=True)
subprocess.run(["lua", str(root / "tests/resource_investment_graph_test.lua")], cwd=root, check=True)
subprocess.run(["lua", str(root / "tests/mana_opportunity_test.lua")], cwd=root, check=True)
subprocess.run(["lua", str(root / "tests/wand_setup_investment_test.lua")], cwd=root, check=True)
subprocess.run(["lua", str(root / "tests/warlock_resource_semantics_test.lua")], cwd=root, check=True)
subprocess.run(["lua", str(root / "tests/warlock_dark_pact_test.lua")], cwd=root, check=True)
subprocess.run(["lua", str(root / "tests/warlock_soul_link_test.lua")], cwd=root, check=True)
subprocess.run(["lua", str(root / "tests/warlock_nightfall_test.lua")], cwd=root, check=True)
subprocess.run(["lua", str(root / "tests/warlock_soul_fire_test.lua")], cwd=root, check=True)
subprocess.run(["lua", str(root / "tests/warlock_fel_domination_test.lua")], cwd=root, check=True)
subprocess.run(["lua", str(root / "tests/soul_shard_reserve_test.lua")], cwd=root, check=True)
subprocess.run(["lua", str(root / "tests/cooldown_ledger_test.lua")], cwd=root, check=True)
subprocess.run(["lua", str(root / "tests/wand_commitment_test.lua")], cwd=root, check=True)
subprocess.run(["lua", str(root / "tests/spell_power_test.lua")], cwd=root, check=True)
subprocess.run(["lua", str(root / "tests/spell_effect_power_test.lua")], cwd=root, check=True)
subprocess.run(["lua", str(root / "tests/caster_persistent_damage_test.lua")], cwd=root, check=True)
subprocess.run(["lua", str(root / "tests/weapon_power_test.lua")], cwd=root, check=True)
subprocess.run(["lua", str(root / "tests/range_test.lua")], cwd=root, check=True)
subprocess.run(["lua", str(root / "tests/action_resistance_semantics_test.lua")], cwd=root, check=True)
subprocess.run(["lua", str(root / "tests/actors_test.lua")], cwd=root, check=True)
subprocess.run(["lua", str(root / "tests/hunter_pet_state_test.lua")], cwd=root, check=True)
subprocess.run(["lua", str(root / "tests/hunter_pet_actions_test.lua")], cwd=root, check=True)
subprocess.run(["lua", str(root / "tests/pet_command_state_test.lua")], cwd=root, check=True)
subprocess.run(["lua", str(root / "tests/hunter_pet_resources_test.lua")], cwd=root, check=True)
subprocess.run(["lua", str(root / "tests/hunter_combat_semantics_test.lua")], cwd=root, check=True)
subprocess.run(["lua", str(root / "tests/hunter_ammunition_knowledge_test.lua")], cwd=root, check=True)
subprocess.run(["lua", str(root / "tests/hunter_ammunition_graph_test.lua")], cwd=root, check=True)
subprocess.run(["lua", str(root / "tests/hunter_aspect_knowledge_test.lua")], cwd=root, check=True)
subprocess.run(["lua", str(root / "tests/hunter_aspect_graph_test.lua")], cwd=root, check=True)
subprocess.run(["lua", str(root / "tests/hunter_mana_aspects_test.lua")], cwd=root, check=True)
subprocess.run(["lua", str(root / "tests/hunter_control_graph_test.lua")], cwd=root, check=True)
subprocess.run(["lua", str(root / "tests/hunter_mark_test.lua")], cwd=root, check=True)
subprocess.run(["lua", str(root / "tests/hunter_hawk_test.lua")], cwd=root, check=True)
subprocess.run(["lua", str(root / "tests/hunter_distracting_shot_test.lua")], cwd=root, check=True)
subprocess.run(["lua", str(root / "tests/hunter_rapid_fire_test.lua")], cwd=root, check=True)
subprocess.run(["lua", str(root / "tests/hunter_stinging_nettle_test.lua")], cwd=root, check=True)
subprocess.run(["lua", str(root / "tests/hunter_alone_against_world_test.lua")], cwd=root, check=True)
subprocess.run(["lua", str(root / "tests/shaman_earth_shock_test.lua")], cwd=root, check=True)
subprocess.run(["lua", str(root / "tests/shaman_stormstrike_test.lua")], cwd=root, check=True)
subprocess.run(["lua", str(root / "tests/shaman_divergent_actions_test.lua")], cwd=root, check=True)
subprocess.run(["lua", str(root / "tests/shaman_lightning_strike_test.lua")], cwd=root, check=True)
subprocess.run(["lua", str(root / "tests/shaman_chain_heal_timing_test.lua")], cwd=root, check=True)
subprocess.run(["lua", str(root / "tests/shaman_flame_shock_timing_test.lua")], cwd=root, check=True)
subprocess.run(["lua", str(root / "tests/druid_ancient_brutality_test.lua")], cwd=root, check=True)
subprocess.run(["lua", str(root / "tests/druid_blood_frenzy_test.lua")], cwd=root, check=True)
subprocess.run(["lua", str(root / "tests/shaman_earth_shock_wiring_test.lua")], cwd=root, check=True)
subprocess.run(["lua", str(root / "tests/attack_rounds_test.lua")], cwd=root, check=True)
subprocess.run(["lua", str(root / "tests/player_attack_test.lua")], cwd=root, check=True)
subprocess.run(["lua", str(root / "tests/player_engagement_test.lua")], cwd=root, check=True)
subprocess.run(["lua", str(root / "tests/player_form_evidence_test.lua")], cwd=root, check=True)
subprocess.run(["lua", str(root / "tests/form_requirements_test.lua")], cwd=root, check=True)
subprocess.run(["lua", str(root / "tests/equipment_requirements_test.lua")], cwd=root, check=True)
subprocess.run(["lua", str(root / "tests/action_context_requirements_test.lua")], cwd=root, check=True)
subprocess.run(["lua", str(root / "tests/warrior_charge_test.lua")], cwd=root, check=True)
subprocess.run(["lua", str(root / "tests/warrior_charge_combat_test.lua")], cwd=root, check=True)
subprocess.run(["lua", str(root / "tests/warrior_taunt_test.lua")], cwd=root, check=True)
subprocess.run(["lua", str(root / "tests/warrior_sunder_test.lua")], cwd=root, check=True)
subprocess.run(["lua", str(root / "tests/warrior_stance_effects_test.lua")], cwd=root, check=True)
subprocess.run(["lua", str(root / "tests/warrior_stances_test.lua")], cwd=root, check=True)
subprocess.run(["lua", str(root / "tests/warrior_rage_test.lua")], cwd=root, check=True)
subprocess.run(["lua", str(root / "tests/warrior_battle_shout_test.lua")], cwd=root, check=True)
subprocess.run(["lua", str(root / "tests/warrior_revenge_threat_test.lua")], cwd=root, check=True)
subprocess.run(["lua", str(root / "tests/warrior_heroic_strike_threat_test.lua")], cwd=root, check=True)
subprocess.run(["lua", str(root / "tests/warrior_execute_test.lua")], cwd=root, check=True)
subprocess.run(["lua", str(root / "tests/warrior_thunder_clap_test.lua")], cwd=root, check=True)
subprocess.run(["lua", str(root / "tests/warrior_overpower_test.lua")], cwd=root, check=True)
subprocess.run(["lua", str(root / "tests/warrior_shield_bash_test.lua")], cwd=root, check=True)
subprocess.run(["lua", str(root / "tests/warrior_devastate_test.lua")], cwd=root, check=True)
subprocess.run(["lua", str(root / "tests/warrior_demoralizing_shout_test.lua")], cwd=root, check=True)
subprocess.run(["lua", str(root / "tests/warrior_shield_wall_test.lua")], cwd=root, check=True)
subprocess.run(["lua", str(root / "tests/warrior_shield_wall_integration_test.lua")], cwd=root, check=True)
subprocess.run(["lua", str(root / "tests/warrior_shield_block_test.lua")], cwd=root, check=True)
subprocess.run(["lua", str(root / "tests/player_threat_graph_test.lua")], cwd=root, check=True)
subprocess.run(["lua", str(root / "tests/threat_drop_classification_test.lua")], cwd=root, check=True)
subprocess.run(["lua", str(root / "tests/hunter_feign_death_graph_test.lua")], cwd=root, check=True)
subprocess.run(["lua", str(root / "tests/hunter_feign_death_lifecycle_test.lua")], cwd=root, check=True)
subprocess.run(["lua", str(root / "tests/hunter_sting_exclusivity_test.lua")], cwd=root, check=True)
subprocess.run(["lua", str(root / "tests/rogue_priest_threat_drop_graph_test.lua")], cwd=root, check=True)
subprocess.run(["lua", str(root / "tests/rogue_feint_test.lua")], cwd=root, check=True)
subprocess.run(["lua", str(root / "tests/threat_drop_integration_test.lua")], cwd=root, check=True)
subprocess.run(["lua", str(root / "tests/healing_triage_test.lua")], cwd=root, check=True)
subprocess.run(["lua", str(root / "tests/healing_triage_evidence_test.lua")], cwd=root, check=True)
subprocess.run(["lua", str(root / "tests/healing_triage_integration_test.lua")], cwd=root, check=True)
subprocess.run(["lua", str(root / "tests/priest_healing_triage_test.lua")], cwd=root, check=True)
subprocess.run(["lua", str(root / "tests/channel_breakpoint_test.lua")], cwd=root, check=True)
subprocess.run(["lua", str(root / "tests/caster_channel_breakpoint_test.lua")], cwd=root, check=True)
subprocess.run(["lua", str(root / "tests/channel_runtime_test.lua")], cwd=root, check=True)
subprocess.run(["lua", str(root / "tests/paladin_aura_state_test.lua")], cwd=root, check=True)
subprocess.run(["lua", str(root / "tests/paladin_actions_test.lua")], cwd=root, check=True)
subprocess.run(["lua", str(root / "tests/paladin_divergent_guards_test.lua")], cwd=root, check=True)
subprocess.run(["lua", str(root / "tests/paladin_aura_projection_test.lua")], cwd=root, check=True)
subprocess.run(["lua", str(root / "tests/paladin_righteousness_test.lua")], cwd=root, check=True)
subprocess.run(["lua", str(root / "tests/paladin_blessing_threat_test.lua")], cwd=root, check=True)
subprocess.run(["lua", str(root / "tests/paladin_righteous_fury_test.lua")], cwd=root, check=True)
subprocess.run(["lua", str(root / "tests/paladin_hand_of_reckoning_test.lua")], cwd=root, check=True)
subprocess.run(["lua", str(root / "tests/paladin_holy_shock_modifiers_test.lua")], cwd=root, check=True)
subprocess.run(["lua", str(root / "tests/paladin_martyr_test.lua")], cwd=root, check=True)
subprocess.run(["lua", str(root / "tests/paladin_consecration_test.lua")], cwd=root, check=True)
subprocess.run(["lua", str(root / "tests/paladin_might_test.lua")], cwd=root, check=True)
subprocess.run(["lua", str(root / "tests/totem_state_test.lua")], cwd=root, check=True)
subprocess.run(["lua", str(root / "tests/shaman_actions_test.lua")], cwd=root, check=True)
subprocess.run(["lua", str(root / "tests/shaman_windfury_totem_test.lua")], cwd=root, check=True)
subprocess.run(["lua", str(root / "tests/shaman_mana_spring_test.lua")], cwd=root, check=True)
subprocess.run(["lua", str(root / "tests/shaman_clearcasting_test.lua")], cwd=root, check=True)
subprocess.run(["lua", str(root / "tests/shaman_molten_blast_refresh_test.lua")], cwd=root, check=True)
subprocess.run(["lua", str(root / "tests/class_mechanics_integration_test.lua")], cwd=root, check=True)
subprocess.run(["lua", str(root / "tests/mage_mana_shield_test.lua")], cwd=root, check=True)
subprocess.run(["lua", str(root / "tests/mage_evocation_test.lua")], cwd=root, check=True)
subprocess.run(["lua", str(root / "tests/mage_mana_shield_scoring_test.lua")], cwd=root, check=True)
subprocess.run(["lua", str(root / "tests/mage_clearcasting_test.lua")], cwd=root, check=True)
subprocess.run(["lua", str(root / "tests/mage_presence_of_mind_test.lua")], cwd=root, check=True)
subprocess.run(["lua", str(root / "tests/mage_cold_snap_test.lua")], cwd=root, check=True)
subprocess.run(["lua", str(root / "tests/mage_proc_windows_test.lua")], cwd=root, check=True)
subprocess.run(["lua", str(root / "tests/mage_frostfire_test.lua")], cwd=root, check=True)
subprocess.run(["lua", str(root / "tests/mage_accelerated_arcana_test.lua")], cwd=root, check=True)
subprocess.run(["lua", str(root / "tests/mage_arcane_surge_test.lua")], cwd=root, check=True)
subprocess.run(["python3", str(root / "tests/octo_spell_topology_audit_test.py")], cwd=root, check=True)
subprocess.run(["python3", str(root / "tests/runtime_smoke_audit_test.py")], cwd=root, check=True)
subprocess.run(["lua", str(root / "tests/priest_shield_test.lua")], cwd=root, check=True)
subprocess.run(["lua", str(root / "tests/priest_divergent_actions_test.lua")], cwd=root, check=True)
subprocess.run(["lua", str(root / "tests/priest_shadowform_test.lua")], cwd=root, check=True)
subprocess.run(["lua", str(root / "tests/priest_improved_shadowform_test.lua")], cwd=root, check=True)
subprocess.run(["lua", str(root / "tests/priest_ascendance_test.lua")], cwd=root, check=True)
subprocess.run(["lua", str(root / "tests/priest_resurgent_shield_test.lua")], cwd=root, check=True)
subprocess.run(["lua", str(root / "tests/priest_inner_focus_test.lua")], cwd=root, check=True)
subprocess.run(["lua", str(root / "tests/priest_power_infusion_test.lua")], cwd=root, check=True)
subprocess.run(["lua", str(root / "tests/priest_chastise_test.lua")], cwd=root, check=True)
subprocess.run(["lua", str(root / "tests/priest_fade_test.lua")], cwd=root, check=True)
subprocess.run(["lua", str(root / "tests/paladin_wisdom_test.lua")], cwd=root, check=True)
subprocess.run(["lua", str(root / "tests/shield_mechanics_integration_test.lua")], cwd=root, check=True)
subprocess.run(["lua", str(root / "tests/druid_form_state_test.lua")], cwd=root, check=True)
subprocess.run(["lua", str(root / "tests/druid_form_graph_test.lua")], cwd=root, check=True)
subprocess.run(["lua", str(root / "tests/druid_form_reachability_test.lua")], cwd=root, check=True)
subprocess.run(["lua", str(root / "tests/druid_shift_resources_test.lua")], cwd=root, check=True)
subprocess.run(["lua", str(root / "tests/druid_clearcasting_test.lua")], cwd=root, check=True)
subprocess.run(["lua", str(root / "tests/druid_bear_threat_test.lua")], cwd=root, check=True)
subprocess.run(["lua", str(root / "tests/druid_bear_attacks_test.lua")], cwd=root, check=True)
subprocess.run(["lua", str(root / "tests/druid_cat_threat_test.lua")], cwd=root, check=True)
subprocess.run(["lua", str(root / "tests/druid_prowl_test.lua")], cwd=root, check=True)
subprocess.run(["lua", str(root / "tests/druid_frenzied_regeneration_test.lua")], cwd=root, check=True)
subprocess.run(["lua", str(root / "tests/druid_caster_forms_test.lua")], cwd=root, check=True)
subprocess.run(["lua", str(root / "tests/strategic_setup_search_test.lua")], cwd=root, check=True)
subprocess.run(["lua", str(root / "tests/player_reactive_evidence_test.lua")], cwd=root, check=True)
subprocess.run(["lua", str(root / "tests/reactive_state_test.lua")], cwd=root, check=True)
subprocess.run(["lua", str(root / "tests/reactive_graph_integration_test.lua")], cwd=root, check=True)
subprocess.run(["lua", str(root / "tests/warrior_tank_guard_test.lua")], cwd=root, check=True)
subprocess.run(["lua", str(root / "tests/dispatch_readiness_test.lua")], cwd=root, check=True)
subprocess.run(["lua", str(root / "tests/combo_classification_test.lua")], cwd=root, check=True)
subprocess.run(["lua", str(root / "tests/combo_mechanics_test.lua")], cwd=root, check=True)
subprocess.run(["lua", str(root / "tests/combo_state_test.lua")], cwd=root, check=True)
subprocess.run(["lua", str(root / "tests/rogue_self_finisher_test.lua")], cwd=root, check=True)
subprocess.run(["lua", str(root / "tests/rogue_slice_and_dice_test.lua")], cwd=root, check=True)
subprocess.run(["lua", str(root / "tests/rogue_ruthlessness_test.lua")], cwd=root, check=True)
subprocess.run(["lua", str(root / "tests/rogue_combo_investment_test.lua")], cwd=root, check=True)
subprocess.run(["lua", str(root / "tests/rogue_surprise_attack_test.lua")], cwd=root, check=True)
subprocess.run(["lua", str(root / "tests/rogue_shiv_test.lua")], cwd=root, check=True)
subprocess.run(["lua", str(root / "tests/rogue_mark_for_death_test.lua")], cwd=root, check=True)
subprocess.run(["lua", str(root / "tests/rogue_preparation_test.lua")], cwd=root, check=True)
subprocess.run(["lua", str(root / "tests/hit_bonuses_test.lua")], cwd=root, check=True)
subprocess.run(["lua", str(root / "tests/recommendation_stability_test.lua")], cwd=root, check=True)
subprocess.run(["lua", str(root / "tests/recommendation_snapshot_test.lua")], cwd=root, check=True)
subprocess.run(["lua", str(root / "tests/recommendation_invalidation_coalescing_test.lua")], cwd=root, check=True)
subprocess.run(["lua", str(root / "tests/hud_cooldown_test.lua")], cwd=root, check=True)
subprocess.run(["lua", str(root / "tests/spatial_evidence_test.lua")], cwd=root, check=True)
subprocess.run(["lua", str(root / "tests/player_energy_resources_test.lua")], cwd=root, check=True)
subprocess.run(["lua", str(root / "tests/player_mana_evidence_test.lua")], cwd=root, check=True)
subprocess.run(["lua", str(root / "tests/player_mana_events_test.lua")], cwd=root, check=True)
subprocess.run(["lua", str(root / "tests/player_mana_resources_test.lua")], cwd=root, check=True)
subprocess.run(["lua", str(root / "tests/player_school_lockout_test.lua")], cwd=root, check=True)
subprocess.run(["lua", str(root / "tests/player_attack_rounds_test.lua")], cwd=root, check=True)
subprocess.run(["lua", str(root / "tests/player_offhand_attack_rounds_test.lua")], cwd=root, check=True)
subprocess.run(["lua", str(root / "tests/player_swing_graph_test.lua")], cwd=root, check=True)
subprocess.run(["lua", str(root / "tests/player_offhand_swing_graph_test.lua")], cwd=root, check=True)
subprocess.run(["lua", str(root / "tests/player_dual_wield_timeline_test.lua")], cwd=root, check=True)
subprocess.run(["lua", str(root / "tests/player_on_swing_queue_test.lua")], cwd=root, check=True)
subprocess.run(["lua", str(root / "tests/player_normal_queue_test.lua")], cwd=root, check=True)
subprocess.run(["lua", str(root / "tests/companion_event_threat_test.lua")], cwd=root, check=True)
subprocess.run(["lua", str(root / "tests/warlock_pet_threat_test.lua")], cwd=root, check=True)
subprocess.run(["lua", str(root / "tests/auto_shot_test.lua")], cwd=root, check=True)
subprocess.run(["lua", str(root / "tests/wand_test.lua")], cwd=root, check=True)
subprocess.run(["lua", str(root / "tests/wand_execution_test.lua")], cwd=root, check=True)
subprocess.run(["lua", str(root / "tests/auto_shot_hostile_locality_test.lua")], cwd=root, check=True)
subprocess.run(["lua", str(root / "tests/companion_threat_test.lua")], cwd=root, check=True)
subprocess.run(["lua", str(root / "tests/companion_events_test.lua")], cwd=root, check=True)
subprocess.run(["lua", str(root / "tests/companion_timeline_causality_test.lua")], cwd=root, check=True)
subprocess.run(["lua", str(root / "tests/friendlies_test.lua")], cwd=root, check=True)
subprocess.run(["lua", str(root / "tests/hostiles_test.lua")], cwd=root, check=True)
subprocess.run(["lua", str(root / "tests/hostile_casts_test.lua")], cwd=root, check=True)
subprocess.run(["lua", str(root / "tests/hostile_cast_graph_test.lua")], cwd=root, check=True)
subprocess.run(["lua", str(root / "tests/hostile_cast_timeline_test.lua")], cwd=root, check=True)
subprocess.run(["lua", str(root / "tests/cast_event_router_test.lua")], cwd=root, check=True)
subprocess.run(["lua", str(root / "tests/target_survival_test.lua")], cwd=root, check=True)
subprocess.run(["lua", str(root / "tests/hostile_state_test.lua")], cwd=root, check=True)
subprocess.run(["lua", str(root / "tests/engaged_hostile_targets_test.lua")], cwd=root, check=True)
subprocess.run(["lua", str(root / "tests/area_recipients_test.lua")], cwd=root, check=True)
subprocess.run(["lua", str(root / "tests/hostile_effects_test.lua")], cwd=root, check=True)
subprocess.run(["lua", str(root / "tests/hostile_execution_boundary_test.lua")], cwd=root, check=True)
subprocess.run(["lua", str(root / "tests/crowd_control_graph_test.lua")], cwd=root, check=True)
subprocess.run(["lua", str(root / "tests/crowd_control_timeline_test.lua")], cwd=root, check=True)
subprocess.run(["lua", str(root / "tests/crowd_control_integration_test.lua")], cwd=root, check=True)
subprocess.run(["lua", str(root / "tests/resistance_test.lua")], cwd=root, check=True)
subprocess.run(["lua", str(root / "tests/resistance_evidence_test.lua")], cwd=root, check=True)
subprocess.run(["lua", str(root / "tests/root_aura_evidence_test.lua")], cwd=root, check=True)
subprocess.run(["lua", str(root / "tests/root_power_evidence_test.lua")], cwd=root, check=True)
subprocess.run(["lua", str(root / "tests/delivery_test.lua")], cwd=root, check=True)
subprocess.run(["lua", str(root / "tests/observations_test.lua")], cwd=root, check=True)
subprocess.run(["lua", str(root / "tests/inventory_test.lua")], cwd=root, check=True)
subprocess.run(["lua", str(root / "tests/encounter_test.lua")], cwd=root, check=True)
subprocess.run(["lua", str(root / "tests/load_test.lua")], cwd=root, check=True)
with tempfile.TemporaryDirectory() as directory:
    package = Path(directory) / "XelAssist.zip"
    duplicate = Path(directory) / "XelAssist-again.zip"
    subprocess.run([sys.executable, str(root / "scripts/package_xelassist.py"), str(package)], check=True)
    subprocess.run([sys.executable, str(root / "scripts/package_xelassist.py"), str(duplicate)], check=True)
    if package.read_bytes() != duplicate.read_bytes():
        raise SystemExit("package is not byte-for-byte deterministic")
    with zipfile.ZipFile(package) as archive:
        names = set(archive.namelist())
        if "XelAssist/XelAssist.toc" not in names: raise SystemExit("package missing TOC")
        for required in ["XelAssist/Core/Bootstrap.lua", "XelAssist/Graph/Engine.lua",
                "XelAssist/UI/HUD.lua"]:
            if required not in names: raise SystemExit(f"package missing nested runtime file: {required}")
        if any(name.startswith("XelAssist/XelAssist_") and name.endswith(".lua") for name in names):
            raise SystemExit("package contains obsolete prefixed root Lua modules")
        if any(name.startswith("XelAssist/tests/") or name.startswith("XelAssist/.git") for name in names):
            raise SystemExit("package contains development files")
print("ok: TOC, XML, Lua 5.0 policy, graph scenarios and mocked full load")
