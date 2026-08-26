XelAssist = { Game = { Player = {} }, Graph = {} }
table.getn = table.getn or function(value)
    local count = 0
    while value[count + 1] ~= nil do count = count + 1 end
    return count
end

local row = {
    school = 1, durationIndex = 31, spellFamilyName = 10,
    spellFamilyFlags = 32, spellLevel = 20, baseLevel = 20, maxLevel = 0,
    effect = { 27, 0, 0 }, effectApplyAuraName = { 3, 0, 0 },
    effectImplicitTargetA = { 18, 0, 0 },
    effectImplicitTargetB = { 16, 0, 0 },
    effectRadiusIndex = { 14, 0, 0 }, effectAmplitude = { 1000, 0, 0 },
    effectBasePoints = { 8, 0, 0 }, effectBaseDice = { 1, 0, 0 },
    effectDieSides = { 1, 0, 0 }, effectDicePerLevel = { 0, 0, 0 },
    effectRealPointsPerLevel = { 0, 0, 0 },
    effectBonusCoefficient = { 0.33, 0, 0 },
}

function GetSpellRecField(_, field, array)
    local value = row[field]
    if array and type(value) == "table" then
        local out, key = {}, nil
        for key in pairs(value) do out[key] = value[key] end
        return out
    end
    return value
end
function GetSpellDuration() return 8000 end
function UnitLevel() return 20 end

dofile("Game/Player/PaladinConsecration.lua")
local Consecration = XelAssist.Game.Player.PaladinConsecration
local profile = assert(Consecration:Inspect(26573))
assert(profile.rank == 1 and profile.duration == 8 and profile.interval == 1
    and profile.ticks == 8 and profile.radius == 8
    and profile.spellBonusCoefficient == 0.33,
    "installed rank one must seal its complete ground-pulse shape")
assert(profile.nominalUniformPulses == true
    and profile.runtimePulseWeightsVerified == false
    and profile.persistsOnTarget == false and profile.tickWeights == nil
    and not string.find(profile.source, "Turtle"),
    "unproven server pulse weights must not be presented as exact Octowow data")

local action = { spellId = 26573, facts = { kind = "dot",
    ground = true, paladinConsecration = true } }
action.facts = Consecration:CaptureFacts(action, action.facts)
local tooltip = { duration = 8, periodicInterval = 1 }
local descriptor = { relation = "hostile", guid = "Target-1", key = "target" }
local selected = { targetGUID = "Target-1", targetDistance = 7.5,
    hostiles = { selectedKey = "target",
        byKey = { target = { guid = "Target-1" } } } }
local blocker, handled = Consecration:Blocker(action,
    selected, descriptor, tooltip)
assert(handled and blocker == nil,
    "one selected hostile inside the cast-time ground radius must be bounded")
blocker = Consecration:Blocker(action,
    { targetGUID = "Target-1", targetDistance = 8.1,
        hostiles = { selectedKey = "target",
            byKey = { target = { guid = "Target-1" } } } }, descriptor, tooltip)
assert(blocker == "Consecration recipient outside ground radius",
    "a selected hostile outside the ground must not receive invented pulses")
blocker = Consecration:Blocker(action,
    { targetGUID = "Target-1", hostiles = { selectedKey = "target",
        byKey = { target = { guid = "Target-1" } } } },
    descriptor, tooltip)
assert(blocker == "Consecration recipient range unknown",
    "unknown ground membership must fail closed")
blocker = Consecration:Blocker(action, selected,
    { relation = "hostile", guid = "Target-2", key = "other" }, tooltip)
assert(blocker == "Consecration recipient is not the selected hostile",
    "selected-target geometry must never be attributed to another hostile")

local context = { facts = action.facts, power = 72, expectedPower = 64 }
assert(Consecration:Prepare(context) == true
    and context.power == 9 and context.expectedPower == 8
    and context.dotRawPeriodicPower == 72
    and context.dotPeriodicExpectedPower == 64
    and context.consecrationRuntimePulseWeightsUnverified == true,
    "only one nominal cast-time pulse may be target-owned")

row.effectAmplitude[1] = 999
local malformed, reason = Consecration:Inspect(26573)
assert(malformed == nil and reason == "Consecration DBC topology is incomplete",
    "malformed cadence evidence must fail closed")
row.effectAmplitude[1] = 1000
row.effectAmplitude[4] = 0
malformed, reason = Consecration:Inspect(26573)
assert(malformed == nil and reason == "Consecration DBC topology is incomplete",
    "extra DBC array fields must fail closed")
row.effectAmplitude[4] = nil
row.effectBonusCoefficient[1] = 0
malformed, reason = Consecration:Inspect(26573)
assert(malformed == nil and reason == "Consecration DBC topology is incomplete",
    "missing spell-power coefficient evidence must fail closed")
row.effectBonusCoefficient[1] = 0.33

dofile("Game/SpellTiming.lua")
assert(XelAssist.Game.SpellTiming:DamageInterval(action) == 1,
    "persistent-area periodic damage must expose its one-second cadence")

dofile("Game/SpellEffectPower.lua")
local power = { duration = 8 }
local function scalar(field) return row[field] end
local function array(field)
    local value = row[field]
    return type(value) == "table" and { value[1], value[2], value[3] } or nil
end
XelAssist.Game.SpellEffectPower:Apply(action, power, scalar, array)
assert(power.dbcEffectPeriodicDamage == 72 and power.dbcEffectAverage == 72,
    "rank-one persistent area damage must total eight exact nine-damage pulses")

print("ok: DBC-bounded Consecration ground pulse ownership")
