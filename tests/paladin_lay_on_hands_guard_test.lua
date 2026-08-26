table.getn = table.getn or function(value)
    local count = 0
    while value and value[count + 1] ~= nil do
        count = count + 1
    end
    return count
end
XelAssist = { Game = { Player = {} }, Graph = {} }
local token = "PALADIN"
UnitClass = function()
    return "Paladin", token
end
local ranks = {
    [633] = { level = 10, mana = 0 },
    [2800] = { level = 30, mana = 250 },
    [10310] = { level = 50, mana = 550 },
}
local function triple(first, second, third)
    return { first or 0, second or 0, third or 0 }
end
local records = {}
for id, rank in pairs(ranks) do
    local hasTargetMana = rank.mana > 0
    local secondEffect = hasTargetMana and 30 or 0
    local secondDice = hasTargetMana and 1 or 0
    local secondTarget = hasTargetMana and 21 or 0
    local secondBasePoint = hasTargetMana and rank.mana - 1 or 0
    records[id] = {
        school = 1,
        category = 56,
        attributes = 327680,
        attributesEx = 131074,
        attributesEx2 = 0,
        attributesEx3 = 0,
        attributesEx4 = 0,
        castingTimeIndex = 1,
        recoveryTime = 0,
        categoryRecoveryTime = 3600000,
        baseLevel = rank.level,
        spellLevel = rank.level,
        durationIndex = 0,
        powerType = 0,
        manaCost = 0,
        manaCostPerlevel = 0,
        manaCostPercentage = 0,
        rangeIndex = 5,
        equippedItemClass = 4294967295,
        spellIconID = 79,
        startRecoveryCategory = 133,
        startRecoveryTime = 1500,
        spellFamilyName = 10,
        spellFamilyFlags = 32768,
        maxAffectedTargets = 0,
        dmgClass = 1,
        preventionType = 1,
        effect = triple(67, secondEffect),
        effectDieSides = triple(1, secondDice),
        effectBaseDice = triple(1, secondDice),
        effectBasePoints = triple(4294967295, secondBasePoint),
        effectImplicitTargetA = triple(),
        effectImplicitTargetB = triple(21, secondTarget),
        effectApplyAuraName = triple(),
        effectMiscValue = triple(),
        effectTriggerSpell = triple(),
    }
end
GetSpellRecField = function(id, field, copied)
    local value = records[id] and records[id][field]
    if copied == 1 and type(value) == "table" then
        return { value[1], value[2], value[3] }
    end
    return value
end
dofile("Game/Player/PaladinLayOnHands.lua")
local Guard = XelAssist.Game.Player.PaladinLayOnHands
for id, rank in pairs(ranks) do
    local found = Guard:Profile(id)
    assert(found and found.valid and found.exact and found.maximumHealthHeal
        and found.privateAllManaDrain and found.targetMana == rank.mana,
        "each exact rank must retain its private resource boundary")
    local facts, reason, handled = Guard:InferKnowledge(id)
    assert(facts == nil and handled == true
        and reason == "Lay on Hands private all-mana drain is unavailable",
        "Lay on Hands must fail closed before generic free-heal inference")
end
dofile("Game/ActionInference.lua")
local inferred, inferenceReason, inferenceHandled =
    XelAssist.Game.ActionInference:ExactKnowledge(633)
assert(inferred == nil and inferenceHandled == true
    and inferenceReason == "Lay on Hands private all-mana drain is unavailable",
    "root class inference must stop before typed free-heal fallback")
local facts, reason, handled = Guard:InferKnowledge(99999)
assert(facts == nil and handled == false,
    "unrelated spells must remain unclaimed")
records[2800].effect[2] = 0
Guard:Invalidate()
facts, reason, handled = Guard:InferKnowledge(2800)
assert(facts == nil and handled == true
    and reason == "Lay on Hands installed topology is incomplete",
    "changed target-mana topology must fail closed")
records[2800].effect[2] = 30
token = "PRIEST"
Guard:Invalidate()
facts, reason, handled = Guard:InferKnowledge(633)
assert(facts == nil and handled == false,
    "another class must never inherit the Paladin guard")
print("ok: exact Lay on Hands ranks cannot become zero-cost generic heals")
