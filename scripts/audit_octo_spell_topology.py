#!/usr/bin/env python3
"""Inventory recommendation-relevant relationships in Octo's Spell.dbc.

This is discovery tooling, not a mechanics oracle. It reports installed-client
topology and deliberately does not turn descriptions into graph arithmetic.
"""

from __future__ import annotations

import argparse
import json
import struct
from pathlib import Path


CLASS_FAMILIES = {
    3: "MAGE", 4: "WARRIOR", 5: "WARLOCK", 6: "PRIEST", 7: "DRUID",
    8: "ROGUE", 9: "HUNTER", 10: "PALADIN", 11: "SHAMAN",
}
PASSIVE_ATTRIBUTE = 0x40
RESOURCE_EFFECT = 30
PROC_TRIGGER_AURA = 42
SPELLMOD_AURAS = {107, 108}


def signed(value: int) -> int:
    return struct.unpack("<i", struct.pack("<I", value))[0]


def text(blob: bytes, start: int, size: int, offset: int) -> str | None:
    if offset >= size:
        return None
    end = blob.find(b"\0", start + offset)
    if end < 0:
        return None
    return blob[start + offset:end].decode("utf-8", "replace")


def load(path: Path) -> list[dict[str, object]]:
    blob = path.read_bytes()
    if len(blob) < 20:
        raise ValueError("Spell.dbc is truncated")
    magic, count, fields, row_size, strings_size = struct.unpack_from(
        "<4s4I", blob, 0)
    if magic != b"WDBC" or fields != 173 or row_size != fields * 4:
        raise ValueError("unsupported Spell.dbc layout; expected Octo 173 fields")
    records_end = 20 + count * row_size
    if records_end + strings_size > len(blob):
        raise ValueError("Spell.dbc record or string block is truncated")
    rows: list[dict[str, object]] = []
    for index in range(count):
        values = struct.unpack_from(f"<{fields}I", blob, 20 + index * row_size)
        rows.append({
            "id": values[0],
            "name": text(blob, records_end, strings_size, values[120]),
            "rank": text(blob, records_end, strings_size, values[129]),
            "description": text(blob, records_end, strings_size, values[138]),
            "familyId": values[160],
            "family": CLASS_FAMILIES.get(values[160], "FAMILY_%d" % values[160]),
            "familyFlags": list(values[161:163]),
            "attributes": values[6],
            "passive": bool(values[6] & PASSIVE_ATTRIBUTE),
            "procFlags": values[24],
            "procChance": values[25],
            "procCharges": values[26],
            "effects": list(values[61:64]),
            "basePoints": [signed(value) for value in values[76:79]],
            "targetsA": list(values[79:82]),
            "targetsB": list(values[82:85]),
            "auras": list(values[91:94]),
            "miscValues": [signed(value) for value in values[106:109]],
            "triggerSpellIds": [value for value in values[109:112] if value],
        })
    return rows


def relevance(row: dict[str, object], linked: set[int], minimum_id: int) -> int:
    spell_id = int(row["id"])
    family_id = int(row["familyId"])
    triggers = row["triggerSpellIds"]
    effects = row["effects"]
    auras = row["auras"]
    score = 0
    if family_id in CLASS_FAMILIES:
        score += 4
    elif spell_id not in linked:
        return 0
    if spell_id >= minimum_id:
        score += 3
    if row["passive"]:
        score += 3
    if int(row["procChance"]) > 0:
        score += 2
    if triggers:
        score += 5 + min(2, len(triggers) - 1)
    if PROC_TRIGGER_AURA in auras:
        score += 4
    if any(aura in SPELLMOD_AURAS for aura in auras):
        score += 3
    if RESOURCE_EFFECT in effects:
        score += 4
    if sum(effect != 0 for effect in effects) > 1:
        score += 2
    return score


def inventory(rows: list[dict[str, object]], minimum_id: int) -> list[dict[str, object]]:
    class_ids = {int(row["id"]) for row in rows
                 if int(row["familyId"]) in CLASS_FAMILIES}
    linked = set(class_ids)
    for row in rows:
        triggers = {int(value) for value in row["triggerSpellIds"]}
        if int(row["id"]) in class_ids or triggers & class_ids:
            linked.update(triggers)
            linked.add(int(row["id"]))
    found = []
    for row in rows:
        score = relevance(row, linked, minimum_id)
        if score:
            item = dict(row)
            item["relevance"] = score
            found.append(item)
    found.sort(key=lambda item: (-int(item["relevance"]),
                                 str(item["family"]), int(item["id"])))
    return found


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("spell_dbc", type=Path)
    parser.add_argument("--min-id", type=int, default=40000)
    parser.add_argument("--limit", type=int, default=0,
                        help="maximum rows after ranking; zero keeps all")
    parser.add_argument("--family", choices=sorted(CLASS_FAMILIES.values()))
    args = parser.parse_args()
    found = inventory(load(args.spell_dbc), args.min_id)
    if args.family:
        found = [item for item in found if item["family"] == args.family]
    if args.limit > 0:
        found = found[:args.limit]
    print(json.dumps({"source": str(args.spell_dbc), "count": len(found),
                      "candidates": found}, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
