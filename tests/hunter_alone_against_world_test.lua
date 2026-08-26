XelAssist = { Game = { Player = {}, Pets = { State = {} } }, Graph = {} }
table.getn = table.getn or function(value)
    local count = 0
    while value[count + 1] ~= nil do count = count + 1 end
    return count
end
local rank, aura, lifecycle, present, hasUI = 52892, 52892,
    "dismissed", false, false
local percent = { [52891] = 3, [52892] = 6 }
local triples = {
    effect = { 6, 6, 0 }, effectApplyAuraName = { 79, 4, 0 },
    effectImplicitTargetA = { 1, 1, 0 }, effectImplicitTargetB = { 0, 0, 0 },
    effectMiscValue = { 127, 0, 0 }, effectTriggerSpell = { 0, 0, 0 },
    effectBaseDice = { 1, 0, 0 }
}
function GetSpellRecField(id, field, array)
    if array then
        if field == "effectBasePoints" then return { percent[id] - 1, 0, 0 } end
        local value = triples[field]
        return value and { value[1], value[2], value[3] } or nil
    end
    local scalars = { spellFamilyName = 9, durationIndex = 21,
        powerType = 0, manaCost = 0, rangeIndex = 1 }
    return scalars[field]
end
IsPlayerSpell = function(id) return id == rank end
GetPlayerBuff = function(index) return index == 0 and 1 or -1 end
GetPlayerBuffID = function() return aura end
function XelAssist.Game.Pets.State:Snapshot()
    return { supported = true, lifecycle = lifecycle, present = present,
        hasPetUIKnown = true, hasPetUI = hasUI }
end

dofile("Game/Player/HunterAloneAgainstWorld.lua")
dofile("Graph/HunterAloneAgainstWorld.lua")
local Runtime = XelAssist.Game.Player.HunterAloneAgainstWorld
local Graph = XelAssist.Graph.HunterAloneAgainstWorld

local found = Runtime:Snapshot("HUNTER")
assert(found.active and found.damageMultiplier == 1.06,
    "rank 2 must require and expose the matching engine-active aura")
local state = {}
assert(Graph:Attach(state, "HUNTER"))
local damage = { state = state, action = { actor = "player" }, kind = "dot",
    power = 100, expectedPower = 80 }
assert(Graph:AdjustDamage(damage) and math.abs(damage.power - 106) < 0.0001
    and math.abs(damage.expectedPower - 84.8) < 0.0001,
    "the exact root modifier must affect player periodic damage")
local petDamage = { state = state, action = { actor = "pet" }, kind = "damage",
    power = 100, expectedPower = 100 }
assert(not Graph:AdjustDamage(petDamage) and petDamage.power == 100,
    "the owner talent must never amplify controlled-pet damage")

present, lifecycle, hasUI = true, "alive", true
assert(not Runtime:Snapshot("HUNTER").active,
    "a controlled pet must suppress the passive")
present, lifecycle, hasUI = false, "unknown", false
assert(not Runtime:Snapshot("HUNTER").active,
    "ambiguous pet disappearance must fail closed")
present, lifecycle, hasUI, aura = false, "dismissed", false, nil
assert(not Runtime:Snapshot("HUNTER").active,
    "pet absence alone must not manufacture the server predicate")

aura, rank = 52891, 52891
Runtime:ResetCache()
assert(Runtime:Snapshot("HUNTER").damageMultiplier == 1.03,
    "rank 1 must retain its exact installed three-percent modifier")

local original = GetSpellRecField
GetSpellRecField = function(id, field, array)
    local value = original(id, field, array)
    if array and field == "effect" then value[4] = 9 end
    return value
end
Runtime:ResetCache()
assert(Runtime:Snapshot("HUNTER").available == false,
    "non-triple topology must be rejected")

print("ok: exact Alone Against the World ownership, pet predicate and damage")
