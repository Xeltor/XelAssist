XelAssist = { Game = { Player = {} } }

local now, mask = 12.5, 0
local fields = {
    [7384] = { casterAuraState = 2 },
    [6572] = { casterAuraState = 3 },
    [9999] = { casterAuraState = 0 },
}
function GetTime() return now end
function GetUnitField(unit, field)
    assert(unit == "player" and field == "auraState",
        "reactive evidence must read only the local player aura-state field")
    return mask
end
function GetSpellRecField(spellId, field)
    assert(field == "casterAuraState",
        "reactive evidence must read only the DBC caster requirement")
    return fields[spellId] and fields[spellId][field]
end

dofile("Game/Player/ReactiveEvidence.lua")
local Evidence = XelAssist.Game.Player.ReactiveEvidence

local overpower = { spellId = 7384, facts = { reactive = true } }
local revenge = { spellId = 6572, facts = { reactive = true } }
local opaque = { spellId = 9999, facts = { reactive = true } }

local snapshot = Evidence:Snapshot()
assert(snapshot.exact and snapshot.mask == 0 and snapshot.observedAt == now,
    "the exact live zero mask must not be confused with missing evidence")
local available, stateID = Evidence:Available(snapshot, overpower)
assert(available == false and stateID == 2,
    "a missing exact required bit must reject the reactive action")

mask = 2
snapshot = Evidence:Snapshot()
available, stateID = Evidence:Available(snapshot, overpower)
assert(available == true and stateID == 2,
    "the exact DBC-required bit must admit its reactive action")
assert(Evidence:Available(snapshot, revenge) == false,
    "one active reactive state must not legalize a different state")

mask = 6
snapshot = Evidence:Snapshot()
assert(Evidence:Available(snapshot, overpower) == true
    and Evidence:Available(snapshot, revenge) == true,
    "combined aura-state flags must be decoded independently")
assert(Evidence:Available(snapshot, opaque) == nil,
    "a reactive action with no DBC requirement must fail closed")

GetUnitField = function() return "6" end
assert(not Evidence:Snapshot().exact,
    "coerced aura-state values must not become exact")
GetUnitField = function() error("unavailable") end
assert(not Evidence:Snapshot().exact,
    "failed optional aura-state reads must remain non-fatal and inexact")

GetSpellRecField = function() return "2" end
Evidence:Invalidate()
assert(Evidence:Available({ mask = 2, exact = true }, overpower) == nil,
    "coerced DBC requirements must not become exact")
GetSpellRecField = nil
Evidence:Invalidate()
assert(Evidence:Available({ mask = 2, exact = true }, overpower) == nil,
    "missing DBC requirement access must fail closed")

print("ok: exact name-independent player reactive aura-state evidence")
