import importlib.util
import struct
import tempfile
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location(
    "audit", ROOT / "scripts/audit_octo_spell_topology.py")
AUDIT = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(AUDIT)


def record(spell_id, name_offset, family, attributes=0, trigger=0,
           effect=0, aura=0, proc_chance=0):
    values = [0] * 173
    values[0], values[6], values[61] = spell_id, attributes, effect
    values[25] = proc_chance
    values[91], values[109], values[120], values[160] = (
        aura, trigger, name_offset, family)
    return struct.pack("<173I", *values)


strings = b"\0Class Passive\0Triggered Child\0Unrelated\0"
rows = [
    record(50001, 1, 6, 0x40, 50002, 6, 42, 50),
    record(50002, 15, 0, 0, 0, 30, 0),
    record(50003, 31, 0, 0x40, 0, 6, 42),
]
blob = struct.pack("<4s4I", b"WDBC", len(rows), 173, 692, len(strings))
blob += b"".join(rows) + strings

with tempfile.TemporaryDirectory() as directory:
    path = Path(directory) / "Spell.dbc"
    path.write_bytes(blob)
    loaded = AUDIT.load(path)
    found = AUDIT.inventory(loaded, 40000)

assert [item["id"] for item in found] == [50001, 50002]
assert found[0]["passive"] and found[0]["triggerSpellIds"] == [50002]
assert found[0]["procChance"] == 50
assert found[1]["effects"] == [30, 0, 0]

print("ok: installed Octo spell topology audit ranks class and linked rows")
