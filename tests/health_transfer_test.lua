XelAssist = { Game = {}, Graph = {}, Combat = {} }
table.getn = table.getn or function(value)
    local count = 0
    while value[count + 1] ~= nil do count = count + 1 end
    return count
end
UnitLevel = function() return 60 end

local ranks = {
    [755] = { level = 12, heal = 12, initial = 3, upkeep = 6, total = 120, health = 63 },
    [3698] = { level = 20, heal = 24, initial = 5, upkeep = 10, total = 240, health = 105 },
    [3699] = { level = 28, heal = 43, initial = 9, upkeep = 18, total = 430, health = 189 },
    [3700] = { level = 36, heal = 64, initial = 12, upkeep = 24, total = 640, health = 252 },
    [11693] = { level = 44, heal = 89, initial = 17, upkeep = 34, total = 890, health = 357 },
    [11694] = { level = 52, heal = 119, initial = 21, upkeep = 42, total = 1190, health = 441 },
    [11695] = { level = 60, heal = 153, initial = 26, upkeep = 52, total = 1530, health = 546 },
}

local records = {}
local function record(values)
    return {
        powerType = 4294967294, attributesEx2 = 2056,
        spellLevel = values.level, baseLevel = values.level, maxLevel = 0,
        manaCost = values.initial, manaPerSecond = values.upkeep,
        effect = { 6, 6, 0 }, effectApplyAuraName = { 8, 88, 0 },
        effectImplicitTargetA = { 5, 1, 0 },
        effectBasePoints = { values.heal - 1, -101, 0 },
        effectBaseDice = { 1, 1, 0 }, effectDieSides = { 1, 1, 0 },
        effectDicePerLevel = { 0, 0, 0 },
        effectRealPointsPerLevel = { 0, 0, 0 },
        effectAmplitude = { 1000, 0, 0 },
    }
end

local spellId, values
for spellId, values in pairs(ranks) do records[spellId] = record(values) end
-- Same-name rows must never be inferred, even if a malformed fixture copies
-- the cast signature. These cover trainer, hidden learn, and NPC IDs.
for _, spellId in ipairs({ 730, 3701, 3702, 3703, 3704, 3705, 3706,
    3707, 11696, 11697, 11698, 16569 }) do
    records[spellId] = record(ranks[755])
end

GetSpellRecField = function(id, field, array)
    local found = records[id]
    if not found then return nil end
    if array then return found[field] end
    return found[field]
end

dofile("Combat/Knowledge.lua")
dofile("Game/HealthTransfer.lua")
local H = XelAssist.Game.HealthTransfer

for spellId, values in pairs(ranks) do
    local inferred = H:InferDBC(spellId)
    assert(inferred and inferred.healthFundedChannel
        and inferred.kind == "petHeal" and inferred.fixedTarget == "pet",
        "cast rank " .. spellId .. " must match the exact DBC signature")
    local action = { name = "Health Funnel", spellId = spellId,
        actor = "player", facts = XelAssist.Combat.Knowledge["Health Funnel"] }
    local out = { duration = 10, cost = values.initial }
    local function scalar(field) return records[spellId][field] end
    local function array(field) return records[spellId][field] end
    local transfer = H:Apply(action, out, scalar, array)
    assert(transfer and transfer.exact and transfer.ticks == 10
        and transfer.interval == 1 and transfer.healPerTick == values.heal
        and transfer.initialHealthCost == values.initial
        and transfer.periodicHealthCost == values.upkeep
        and transfer.totalHealing == values.total
        and transfer.totalHealthCost == values.health
        and out.cost == 0,
        "rank " .. spellId .. " must preserve its exact tick and health costs")
end

for _, spellId in ipairs({ 730, 3701, 3702, 3703, 3704, 3705, 3706,
    3707, 11696, 11697, 11698, 16569 }) do
    assert(H:InferDBC(spellId) == nil,
        "same-name non-cast row " .. spellId .. " must be excluded")
end

local wrong = record(ranks[755])
wrong.effectImplicitTargetA = { 21, 1, 0 }
records[755] = wrong
assert(H:InferDBC(755) == nil,
    "a non-pet periodic heal must fail the Health Funnel signature")
records[755] = record(ranks[755])
records[755].effectAmplitude = nil
local ok, incomplete = pcall(H.InferDBC, H, 755)
assert(ok and incomplete == nil,
    "incomplete client array evidence must fail closed without a Lua error")

print("ok: exact installed-client Health Funnel rank semantics")
