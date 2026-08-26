-- Exact Octo Frostfire resistance selection, with no graph-time API reads.
table.getn = table.getn or function(values)
    local count = 0
    while values and values[count + 1] ~= nil do count = count + 1 end
    return count
end

local row = { school = 4, attributes = 65536, spellFamilyName = 3,
    spellFamilyFlags = 1073741857, effect = { 2, 6, 0 },
    effectApplyAuraName = { 0, 3, 0 },
    effectImplicitTargetA = { 6, 6, 0 },
    effectAmplitude = { 0, 2000, 0 } }
local reads = 0
function GetSpellRecField(id, field, array)
    reads = reads + 1
    if id ~= 45400 then return nil end
    local value = row[field]
    if array and type(value) == "table" then
        return { value[1], value[2], value[3] }
    end
    return value
end
function GetSpellDuration(id) return id == 45400 and 8000 or nil end

XelAssist = { Game = { Player = {} } }
dofile("Game/Player/MageFrostfire.lua")
local Frostfire = XelAssist.Game.Player.MageFrostfire

local base = { kind = "damage", ranged = true,
    repeatablePersistentDamage = true }
local action = { spellId = 45400, facts = base }
local sealed = Frostfire:CaptureFacts(action, base)
assert(sealed ~= base and sealed.kind == "damage" and sealed.ranged
    and sealed.repeatablePersistentDamage
    and sealed.mageFrostfireResistance.exact
    and sealed.mageFrostfireResistance.policy == "lower-effective-resistance",
    "the root must preserve ordinary spell facts and seal Frostfire identity")
assert(base.mageFrostfireResistance == nil,
    "root Frostfire capture must not mutate catalogue facts")
action.facts = sealed

local readsAtRoot = reads
GetSpellRecField = function() error("DBC read during graph search") end
GetSpellDuration = function() error("duration read during graph search") end
UnitResistance = function() error("unit read during graph search") end

local state = { targetResistance = { liveTrusted = true,
    live = { [2] = 40, [4] = 100 } } }
local school, handled, source = Frostfire:ResistanceSchool(action, state)
assert(school == 2 and handled and source == "lower effective Fire resistance",
    "Frostfire must use the lower trusted Fire resistance")

state.targetResistance.live[2], state.targetResistance.live[4] = 120, 60
school, handled = Frostfire:ResistanceSchool(action, state)
assert(school == 4 and handled,
    "Frostfire must retain Frost when Frost resistance is lower")

state.targetResistance.live[2], state.targetResistance.live[4] = 100, 80
state.targetResistance.projectedReduction = { [2] = 30 }
school, handled = Frostfire:ResistanceSchool(action, state)
assert(school == 2 and handled,
    "projected resistance reductions must change future Frostfire selection")

state.targetResistance.live[2], state.targetResistance.live[4] = 20, 20
state.targetResistance.projectedReduction = nil
school, handled, source = Frostfire:ResistanceSchool(action, state)
assert(school == 4 and handled
    and source == "equal Fire/Frost resistance; DBC Frost fallback",
    "an equal pair may use the equivalent DBC Frost resistance lane")

state.targetResistance.liveTrusted = false
school, handled, source = Frostfire:ResistanceSchool(action, state)
assert(school == nil and handled and source == "trusted target resistance unavailable",
    "untrusted resistance must fail closed rather than assume DBC Frost")

local ordinary = { spellId = 116, facts = { kind = "damage" } }
assert(Frostfire:CaptureFacts(ordinary, ordinary.facts) == ordinary.facts,
    "ordinary Mage spells must remain untouched")
assert(Frostfire:ResistanceSchool(ordinary, state) == nil,
    "ordinary Mage spells must remain available to normal resistance logic")
assert(reads == readsAtRoot,
    "Frostfire graph selection must use only sealed root evidence")

Frostfire:Invalidate()
row.spellFamilyFlags = 1
GetSpellRecField = function(id, field, array)
    local value = id == 45400 and row[field] or nil
    if array and type(value) == "table" then
        return { value[1], value[2], value[3] }
    end
    return value
end
GetSpellDuration = function(id) return id == 45400 and 8000 or nil end
local shifted = Frostfire:CaptureFacts({ spellId = 45400 }, base)
assert(shifted.mageFrostfireResistance.exact == false
    and shifted.mageFrostfireResistance.reason
        == "Frostfire Bolt DBC topology is incomplete",
    "a shifted installed row must fail closed")

print("ok: Mage Frostfire selects the lower proven effective resistance")
