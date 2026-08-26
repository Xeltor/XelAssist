-- Exact Druid Prowl discovery must be locale-free, Cat-gated, combat-forbidden
-- and carry the installed rank's real movement penalty into graph facts.
table.getn = table.getn or function(value)
    local count = 0
    while value and value[count + 1] ~= nil do count = count + 1 end
    return count
end

XelAssist = { Game = { Player = {} } }
local classToken = "DRUID"
UnitClass = function(unit)
    assert(unit == "player")
    return "localized class", classToken
end

local function triple(first, second, third)
    return { first or 0, second or 0, third or 0 }
end

local records = {}
local function rank(spellId, movementBase)
    records[spellId] = {
        spellFamilyName = 7, spellFamilyFlags = 16384,
        attributes = 437518352, stances = 1, stancesNot = 0,
        powerType = 3, manaCost = 0, durationIndex = 21,
        auraInterruptFlags = 15367,
        effect = triple(6, 6), effectApplyAuraName = triple(16, 33),
        effectImplicitTargetA = triple(1, 1),
        effectImplicitTargetB = triple(),
        effectBasePoints = triple(99, movementBase),
        effectBaseDice = triple(1, 1), effectDieSides = triple(1, 1),
        effectDicePerLevel = triple(0, 0),
        effectRealPointsPerLevel = triple(5, 0),
        effectPointsPerComboPoint = triple(0, 0),
    }
end
rank(5215, -41)
rank(6783, -36)
rank(9913, -31)
records[5176] = { spellFamilyName = 7, spellFamilyFlags = 1 }

local reads = 0
GetSpellRecField = function(spellId, field, copied)
    reads = reads + 1
    local record = records[spellId]
    local value = record and record[field]
    if copied == 1 and type(value) == "table" then
        return { value[1], value[2], value[3] }
    end
    return value
end

dofile("Game/Player/DruidProwl.lua")
local Prowl = XelAssist.Game.Player.DruidProwl
dofile("Game/ActionInference.lua")

local expected = { [5215] = 0.60, [6783] = 0.65, [9913] = 0.70 }
assert(XelAssist.Game.ActionInference:ClassKnowledge(5215).druidProwl,
    "the class catalogue must dispatch exact Prowl evidence")
local spellId, multiplier
for spellId, multiplier in pairs(expected) do
    local facts, reason, handled = Prowl:InferKnowledge(spellId)
    assert(handled == true and reason == nil and facts
        and facts.kind == "buff" and facts.self == true
        and facts.outOfCombat == true and facts.stealthPreparation == true
        and facts.appliesStealth == true and facts.druidProwl == true
        and math.abs(facts.movementSpeedMultiplier - multiplier) < 0.000001
        and facts.druidProwlFormMask == 1 and facts.persistentBuff == true,
        "each exact installed rank must publish its own Prowl mechanics")
end

local before = reads
GetSpellRecField = function()
    error("cached Prowl facts performed a live DBC read")
end
local cached = Prowl:InferKnowledge(9913)
assert(cached and cached.movementSpeedMultiplier == 0.70 and reads == before,
    "search-ready Prowl facts must survive without installed-data reads")

XelAssist.Graph = {}
dofile("Graph/StealthSetup.lua")
local context = { facts = cached, state = {}, value = 0 }
XelAssist.Graph.StealthSetup:Score(context)
assert(context.value == 350,
    "generic stealth scoring must price the exact rank-three movement loss")
local projected = { inCombat = false, hostile = true,
    targetGUID = "hostile-guid", targetReaction = 2 }
XelAssist.Graph.StealthSetup:Apply(projected, {
    action = { facts = cached }, tooltip = {}, targetRelation = "self" })
assert(projected.playerStealthed == true
    and projected.playerStealthKnown == true
    and projected.stealthApproachTargetGUID == "hostile-guid",
    "generic stealth projection must consume the locale-free Prowl facts")
GetSpellRecField = function(spellId, field, copied)
    reads = reads + 1
    local record = records[spellId]
    local value = record and record[field]
    if copied == 1 and type(value) == "table" then
        return { value[1], value[2], value[3] }
    end
    return value
end

local facts, reason, handled = Prowl:InferKnowledge(5176)
assert(facts == nil and reason == nil and handled == false,
    "ordinary Druid spells must remain outside the Prowl classifier")

records[5215].stances = 0
Prowl:Invalidate()
facts, reason, handled = Prowl:InferKnowledge(5215)
assert(facts == nil and handled == true
    and reason == "Prowl form or resource evidence is incomplete",
    "a changed Cat-form gate must be recognized but fail closed")
records[5215].stances = 1

records[5215].attributes = 168296464
Prowl:Invalidate()
facts, reason, handled = Prowl:InferKnowledge(5215)
assert(facts == nil and handled == true
    and reason == "Prowl lifecycle evidence is incomplete",
    "a combat-castable or changed lifecycle must never retain Prowl policy")
records[5215].attributes = 437518352

records[5215].effectRealPointsPerLevel[2] = 1
Prowl:Invalidate()
facts, reason, handled = Prowl:InferKnowledge(5215)
assert(facts == nil and handled == true
    and reason == "Prowl movement modifier is not deterministic",
    "scaled movement evidence must not be promoted to an exact multiplier")
records[5215].effectRealPointsPerLevel[2] = 0

classToken = "ROGUE"
Prowl:Invalidate()
facts, reason, handled = Prowl:InferKnowledge(5215)
assert(facts == nil and reason == nil and handled == false,
    "non-Druids must never receive Druid Prowl actions")

print("ok: exact Druid Prowl discovery and movement mechanics")
