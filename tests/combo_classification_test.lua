XelAssist = { Game = {} }
table.getn = table.getn or function(value)
    local count = 0
    while value[count + 1] ~= nil do count = count + 1 end
    return count
end

dofile("Game/SpellClassification.lua")
local Classification = XelAssist.Game.SpellClassification

local function classify(record)
    local out = {}
    Classification:Apply({}, out,
        function(field) return record[field] end,
        function(field) return record[field] end)
    return out
end

local builder = classify({ attributes = 0, attributesEx = 0,
    attributesEx2 = 0, attributesEx4 = 0, stances = 0,
    effect = { 80, 2, 0 }, effectBasePoints = { 0, 2, 0 },
    effectBaseDice = { 1, 1, 1 }, effectDieSides = { 1, 1, 1 },
    effectDicePerLevel = { 0, 0, 0 },
    effectRealPointsPerLevel = { 0, 0, 0 } })
assert(builder.comboGain == 1 and not builder.comboSpendAll,
    "effect 80 must expose the exact deterministic combo gain")

local multiBuilder = classify({ attributes = 0, attributesEx = 0,
    attributesEx2 = 0, attributesEx4 = 0, stances = 0,
    effect = { 80, 80, 0 }, effectBasePoints = { 0, 1, 0 },
    effectBaseDice = { 1, 1, 0 }, effectDieSides = { 1, 0, 0 },
    effectDicePerLevel = { 0, 0, 0 },
    effectRealPointsPerLevel = { 0, 0, 0 } })
assert(multiBuilder.comboGain == 3,
    "multiple deterministic combo effects must add")

local damageFinisher = classify({ attributes = 0, attributesEx = 1048576,
    attributesEx2 = 0, attributesEx4 = 0, stances = 0 })
local durationFinisher = classify({ attributes = 0, attributesEx = 4194304,
    attributesEx2 = 0, attributesEx4 = 0, stances = 0 })
assert(damageFinisher.comboSpendAll and durationFinisher.comboSpendAll,
    "both damage and duration finishing flags must consume all combo points")

local uncertain = classify({ attributes = 0, attributesEx = 0,
    attributesEx2 = 0, attributesEx4 = 0, stances = 0,
    effect = { 80, 0, 0 }, effectBasePoints = { 0, 0, 0 },
    effectBaseDice = { 1, 0, 0 }, effectDieSides = { -1, 0, 0 },
    effectDicePerLevel = { 0, 0, 0 },
    effectRealPointsPerLevel = { 0, 0, 0 } })
assert(uncertain.comboGain == nil and uncertain.comboGainUnknown,
    "negative, random or scaled combo generation must remain explicitly unknown")

local stealth = classify({ attributes = 0, attributesEx = 0,
    attributesEx2 = 0, attributesEx4 = 0, stances = 0,
    effect = { 6, 0, 0 }, effectApplyAuraName = { 16, 0, 0 } })
assert(stealth.appliesStealth,
    "the DBC stealth aura must expose a projected stealth state")

print("ok: DBC-native combo, finisher, and stealth classification")
