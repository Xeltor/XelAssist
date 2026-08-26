-- Distracting Shot must remain a numeric, threat-only graph consequence.
table.getn = table.getn or function(value) return #value end
XelAssist = { Game = { Player = {} }, Graph = {} }
XelAssistCharDB = { petThreat = "tank" }

local function triple(first, second, third)
    return { first or 0, second or 0, third or 0 }
end

local ranks = {
    [20736] = { rank = 1, level = 12, maxLevel = 19,
        cost = 20, base = 109, perLevel = 1.5, threat = 110 },
    [14274] = { rank = 2, level = 20, maxLevel = 29,
        cost = 30, base = 159, perLevel = 2, threat = 160 },
    [15629] = { rank = 3, level = 30, maxLevel = 39,
        cost = 50, base = 249, perLevel = 2.5, threat = 250 },
    [15630] = { rank = 4, level = 40, maxLevel = 49,
        cost = 70, base = 349, perLevel = 3, threat = 350 },
    [15631] = { rank = 5, level = 50, maxLevel = 59,
        cost = 90, base = 464, perLevel = 3.5, threat = 465 },
    [15632] = { rank = 6, level = 60, maxLevel = 69,
        cost = 110, base = 599, perLevel = 4, threat = 600 },
}

local function row(rank)
    return {
        school = 6, category = 911, castUI = 0, dispel = 0, mechanic = 0,
        attributes = 65538, attributesEx = 131072,
        attributesEx2 = 131072, attributesEx3 = 0, attributesEx4 = 0,
        stances = 0, stancesNot = 0, targets = 0, targetCreatureType = 0,
        requiresSpellFocus = 0, casterAuraState = 0, targetAuraState = 0,
        castingTimeIndex = 18, recoveryTime = 0, categoryRecoveryTime = 8000,
        interruptFlags = 0, auraInterruptFlags = 0, channelInterruptFlags = 0,
        procFlags = 0, procChance = 101, procCharges = 0,
        maxLevel = rank.maxLevel, baseLevel = rank.level,
        spellLevel = rank.level, durationIndex = 0, powerType = 0,
        manaCost = rank.cost, manaCostPerlevel = 0, manaPerSecond = 0,
        manaPerSecondPerLevel = 0, rangeIndex = 114, speed = 40,
        modalNextSpell = 75, stackAmount = 0, equippedItemClass = 2,
        equippedItemSubClassMask = 262156,
        equippedItemInventoryTypeMask = 0, manaCostPercentage = 0,
        startRecoveryCategory = 133, startRecoveryTime = 1500,
        maxTargetLevel = 0, spellFamilyName = 9,
        spellFamilyFlags = 65536, maxAffectedTargets = 0,
        dmgClass = 3, preventionType = 2,
        effect = triple(63), effectDieSides = triple(1),
        effectBaseDice = triple(1), effectDicePerLevel = triple(),
        effectRealPointsPerLevel = triple(rank.perLevel),
        effectBasePoints = triple(rank.base), effectMechanic = triple(),
        effectImplicitTargetA = triple(6), effectImplicitTargetB = triple(),
        effectRadiusIndex = triple(), effectApplyAuraName = triple(),
        effectAmplitude = triple(), effectMultipleValue = triple(),
        effectChainTarget = triple(), effectItemType = triple(),
        effectMiscValue = triple(), effectTriggerSpell = triple(),
        effectPointsPerComboPoint = triple(),
    }
end

local records, spellId, rank = {}, nil, nil
for spellId, rank in pairs(ranks) do records[spellId] = row(rank) end
local reads, class = 0, "HUNTER"
local modifierValues = { [8] = { 0, 0, 0 }, [2] = { 0, 0, 0 } }
function UnitClass()
    reads = reads + 1
    return "localized class deliberately ignored", class
end
function GetSpellRecField(id, field, copied)
    reads = reads + 1
    local value = records[id] and records[id][field]
    if copied and type(value) == "table" then
        return { value[1], value[2], value[3] }
    end
    return value
end
function GetSpellRangeData(index)
    reads = reads + 1
    assert(index == 114)
    return 8, 35
end
function GetSpellModifiers(_, kind)
    reads = reads + 1
    local found = modifierValues[kind]
    return found[1], found[2], found[3]
end

dofile("Game/Player/HunterDistractingShot.lua")
local Runtime = XelAssist.Game.Player.HunterDistractingShot
for spellId, rank in pairs(ranks) do
    local found, reason, handled = Runtime:Classify(spellId)
    assert(found and handled and reason == nil and found.valid and found.exact
        and found.rank == rank.rank and found.level == rank.level
        and found.maxLevel == rank.maxLevel and found.cost == rank.cost
        and found.basePoints == rank.base
        and found.realPointsPerLevel == rank.perLevel
        and found.baseThreat == rank.threat and found.effectOpcode == 63
        and found.minRange == 8 and found.maxRange == 35
        and found.consumesAmmunition and found.usesWeaponSkill,
        "every installed rank must retain its exact effect-63 topology")
end
local unknown, _, unknownHandled = Runtime:Classify(99999)
assert(unknown == nil and not unknownHandled,
    "unrelated numeric identities must remain outside the portfolio")

local facts, reason, handled = Runtime:InferKnowledge(14274)
assert(facts and handled and reason == nil and facts.kind == "utility"
    and facts.kindExact and facts.hostile and facts.ranged
    and facts.weaponRanged and facts.ammunition
    and facts.deliveryModel == "physical"
    and facts.deliverySubtype == "ranged" and facts.usesWeaponSkill
    and facts.effectMinRange == 8 and facts.effectMaxRange == 35
    and facts.targetLocalFlatThreat and facts.threatOnly
    and facts.preferred == nil and facts.order == nil,
    "inference must expose causal threat, range, hit, and ammo facts only")

local action = { name = "localized action deliberately ignored",
    spellId = 14274, actor = "player", facts = facts }
local state = { playerLevel = 25, resourceMax = 100,
    groupSize = 0, pet = true, tank = false, hasAggro = false,
    targetPlayerThreatDeltaExact = true }
facts = Runtime:CaptureFacts(action, facts, state)
action.facts = facts
local profile = Runtime:Profile(action)
assert(profile and profile.playerLevel == 25 and profile.effectiveLevel == 25
    and profile.unmodifiedThreat == 170 and profile.effectiveThreat == 170
    and facts.baseFlatThreatBySpellId[14274] == 170,
    "root capture must apply exact level scaling before graph search")

modifierValues[8], modifierValues[2] = { 10, 10, 1 }, { 2, 20, 1 }
local modified = Runtime:CaptureFacts(action,
    Runtime:InferKnowledge(14274), state)
assert(Runtime:Profile(modified).effectiveThreat == 240
    and modified.baseFlatThreatBySpellId[14274] == 240,
    "ALL_EFFECTS then THREAT modifiers must follow server execution order")
modified.hunterDistractingShotProfile.effectiveThreat = 999
assert(Runtime:Profile(modified) == nil,
    "a forged effective threat packet must not cross the graph boundary")
modifierValues[8], modifierValues[2] = { 0, 0, 0 }, { 0, 0, 0 }

class = "ROGUE"
local foreign = Runtime:InferKnowledge(14274)
assert(foreign == nil, "another class must not claim the Hunter action")
class = "HUNTER"

dofile("Graph/HunterDistractingShot.lua")
local Graph = XelAssist.Graph.HunterDistractingShot
local descriptor = { unit = "target", relation = "hostile",
    source = "selected", guid = "target-guid", key = "target-guid" }
local context = { action = action, facts = facts, descriptor = descriptor,
    power = 170, expectedPower = 170, effectivePower = 170,
    targetEffect = false, damageKind = true }
local saved = { GetSpellRecField, GetSpellRangeData,
    GetSpellModifiers, UnitClass }
GetSpellRecField = function() error("DBC read during graph search") end
GetSpellRangeData = function() error("range read during graph search") end
GetSpellModifiers = function() error("modifier read during graph search") end
UnitClass = function() error("class read during graph search") end
local prepared, prepareReason, prepareHandled = Graph:Prepare(context)
assert(prepared and prepareHandled and prepareReason == nil
    and context.targetEffect and not context.damageKind
    and context.power == 0 and context.expectedPower == 0
    and context.threatSchool == 6 and context.hunterDistractingShot,
    "search preparation must expose delivery without inventing damage")

dofile("Graph/PlayerThreat.lua")
dofile("Graph/ThreatScoring.lua")
context.state, context.kind, context.cost = state, "utility", 30
context.effectDelivery, context.value = 0.5, 0
XelAssist.Graph.ThreatScoring:Apply(context)
assert(context.threat == 85 and math.abs(context.value + 82.06) < 0.00001
    and context.reason == "lower threat for the group",
    "pet-tank policy must price landed player threat and mana causally")

XelAssist.Graph.State = { ActiveHostile = function(_, out) return out.record end }
dofile("Graph/PrimaryThreatEffects.lua")
local record = { guid = "target-guid" }
local out = { record = record }
local candidate = { targetRelation = "hostile", targetGUID = "target-guid",
    threat = context.threat, playerThreatExact = context.playerThreatExact }
assert(XelAssist.Graph.PrimaryThreatEffects:Apply(out, candidate, context)
    and record.projectedThreat.player == 85
    and record.threat.playerDelta == 85
    and record.threat.playerDeltaExact == false
    and record.threat.containsEstimatedBaseThreat,
    "the exact rank packet must become a target-local projected threat delta")

dofile("Graph/ActionConsumption.lua")
assert(XelAssist.Graph.ActionConsumption:SpendsAmmunition(action),
    "the DmgClass-3 ranged cast must consume one shared projectile")

local wrongTarget = { action = action, facts = facts,
    descriptor = { relation = "hostile" } }
local wrong, wrongReason, wrongHandled = Graph:Prepare(wrongTarget)
assert(wrong == nil and wrongHandled
    and wrongReason == "Distracting Shot requires an exact hostile recipient",
    "recipient uncertainty must fail closed")

GetSpellRecField, GetSpellRangeData, GetSpellModifiers, UnitClass =
    saved[1], saved[2], saved[3], saved[4]
modifierValues[8] = { 0, 0, 1 }
local incomplete = Runtime:CaptureFacts(action,
    Runtime:InferKnowledge(14274), state)
local failed, failedReason, failedHandled = Graph:Prepare({ action = {
    spellId = 14274, actor = "player", facts = incomplete },
    facts = incomplete, descriptor = descriptor })
assert(failed == nil and failedHandled
    and failedReason == "exact Distracting Shot threat evidence unavailable",
    "inconsistent mutable modifier evidence must fail closed")

modifierValues[8] = { 0, 0, 0 }
Runtime:Invalidate()
records[20736].effect = triple(2)
local drift, driftReason, driftHandled = Runtime:Classify(20736)
assert(drift and not drift.valid and driftHandled
    and driftReason == "Distracting Shot DBC topology is incomplete",
    "a damage or otherwise drifted opcode must fail closed")

assert(reads > 0, "the root evidence test must exercise live DBC adapters")
print("hunter_distracting_shot_test: ok")
