-- Hawk value must emerge only through exact ranged-weapon damage deltas.
table.getn = table.getn or function(value) return #value end
XelAssist = { Game = { Player = {} }, Graph = {} }

local function triple(first, second, third)
    return { first or 0, second or 0, third or 0 }
end

local ranks = {
    [13165] = { rank = 1, level = 10, cost = 20, base = 19, amount = 20 },
    [14318] = { rank = 2, level = 18, cost = 35, base = 34, amount = 35 },
    [14319] = { rank = 3, level = 28, cost = 50, base = 49, amount = 50 },
    [14320] = { rank = 4, level = 38, cost = 70, base = 69, amount = 70 },
    [14321] = { rank = 5, level = 48, cost = 90, base = 89, amount = 90 },
    [14322] = { rank = 6, level = 58, cost = 110, base = 109, amount = 110 },
    [25296] = { rank = 7, level = 60, cost = 120, base = 119, amount = 120 },
}

local function row(rank)
    return {
        school = 3, category = 0, castUI = 0, dispel = 0, mechanic = 0,
        attributes = 327680, attributesEx = 0, attributesEx2 = 16,
        attributesEx3 = 0, attributesEx4 = 0, stances = 0, stancesNot = 0,
        targets = 0, targetCreatureType = 0, requiresSpellFocus = 0,
        casterAuraState = 0, targetAuraState = 0, castingTimeIndex = 1,
        recoveryTime = 0, categoryRecoveryTime = 0, interruptFlags = 0,
        auraInterruptFlags = 0, channelInterruptFlags = 0, procFlags = 0,
        procChance = 0, procCharges = 0, maxLevel = 0,
        baseLevel = rank.level, spellLevel = rank.level, durationIndex = 21,
        powerType = 0, manaCost = rank.cost, manaCostPerlevel = 0,
        manaPerSecond = 0, manaPerSecondPerLevel = 0, rangeIndex = 1,
        speed = 0, modalNextSpell = 0, stackAmount = 0,
        equippedItemClass = -1, equippedItemSubClassMask = -1,
        equippedItemInventoryTypeMask = 0, spellVisual = 0,
        spellIconID = 112, activeIconID = 122, spellPriority = 0,
        manaCostPercentage = 0, startRecoveryCategory = 133,
        startRecoveryTime = 1500, maxTargetLevel = 0,
        spellFamilyName = 9, spellFamilyFlags = 1048576,
        maxAffectedTargets = 0, dmgClass = 1, preventionType = 1,
        effect = triple(6), effectDieSides = triple(1),
        effectBaseDice = triple(1), effectDicePerLevel = triple(),
        effectRealPointsPerLevel = triple(),
        effectBasePoints = triple(rank.base), effectMechanic = triple(),
        effectImplicitTargetA = triple(1), effectImplicitTargetB = triple(),
        effectRadiusIndex = triple(), effectApplyAuraName = triple(124),
        effectAmplitude = triple(), effectMultipleValue = triple(),
        effectChainTarget = triple(), effectItemType = triple(),
        effectMiscValue = triple(), effectTriggerSpell = triple(),
        effectPointsPerComboPoint = triple(),
    }
end

local records = {}
local spellId, rank
for spellId, rank in pairs(ranks) do records[spellId] = row(rank) end
local reads, class, playerGUID, auras = 0, "HUNTER", "Player-1", {}
local modifiers = { [8] = { 0, 0, 0 }, [3] = { 0, 0, 0 } }
function UnitClass()
    reads = reads + 1
    return "localized class deliberately ignored", class
end
function UnitExists(unit)
    reads = reads + 1
    return unit == "player" and 1 or nil, unit == "player" and playerGUID or nil
end
function GetSpellRecField(id, field, copied)
    reads = reads + 1
    local value = records[id] and records[id][field]
    if copied and type(value) == "table" then
        return { value[1], value[2], value[3] }
    end
    return value
end
function GetSpellModifiers(_, kind)
    reads = reads + 1
    local found = modifiers[kind]
    return found[1], found[2], found[3]
end
C_UnitAuras = { GetUnitAuras = function(unit, filter)
    reads = reads + 1
    assert(unit == "player" and filter == "HELPFUL")
    return auras
end }

dofile("Game/Player/HunterHawk.lua")
local Runtime = XelAssist.Game.Player.HunterHawk
for spellId, rank in pairs(ranks) do
    local found, reason, handled = Runtime:Classify(spellId)
    assert(found and handled and reason == nil and found.valid and found.exact
        and found.rank == rank.rank and found.level == rank.level
        and found.cost == rank.cost
        and found.baseRangedAttackPower == rank.amount,
        "every installed Hawk rank must retain its exact aura consequence")
end
local unknown, _, unknownHandled = Runtime:Classify(99999)
assert(unknown == nil and not unknownHandled,
    "an unrelated numeric identity must remain outside the portfolio")

local facts, reason, handled = Runtime:InferKnowledge(13165)
assert(facts and handled and reason == nil and facts.kind == "buff"
    and facts.kindExact and facts.self and facts.fixedTarget == "player"
    and facts.hunterAspect and facts.hunterHawk
    and facts.hunterAspectEffectRepresented
    and facts.exclusiveFamily == "hunterAspect"
    and facts.preferred == nil and facts.order == nil,
    "inference must expose consequences without a rank or aspect priority")
local action = { name = "localized action deliberately ignored",
    spellId = 13165, actor = "player", facts = facts }
facts = Runtime:CaptureFacts(action, facts)
action.facts = facts
local profile = Runtime:Profile(action)
assert(profile and profile.rangedAttackPower == 20,
    "root action capture must seal the effective ranged AP")
facts.hunterHawkProfile.rangedAttackPower = 999
assert(Runtime:Profile(facts) == nil,
    "a forged ranged AP magnitude must not cross the graph boundary")
facts = Runtime:CaptureFacts(action, Runtime:InferKnowledge(13165))
action.facts = facts

modifiers[8] = { 5, 0, 1 }
modifiers[3] = { 0, 10, 1 }
local modified = Runtime:CaptureFacts(action,
    Runtime:InferKnowledge(13165))
assert(Runtime:Profile(modified).rangedAttackPower == 27.5,
    "ALL_EFFECTS then ATTACK_POWER modifiers must follow server order")
modifiers[8], modifiers[3] = { 0, 0, 0 }, { 0, 0, 0 }

class = "ROGUE"
local foreign = Runtime:InferKnowledge(13165)
assert(foreign == nil, "another class must not claim the Hunter action")
class = "HUNTER"

local function graphState(activeSpellId)
    local player = { unit = "player", guid = "Player-1", relation = "self" }
    local out = { friendlies = { byUnit = { player = "self" },
        byKey = { self = player } }, hunterMarkRoot = { valid = true,
        exact = true, portfolio = "hunterMark", lane = { valid = true,
            exact = true, speed = 2.8, damageMultiplier = 1.1,
            damageMultiplierUnits = "factor" } } }
    auras = activeSpellId and { { spellId = activeSpellId } } or {}
    return out, player
end

dofile("Graph/HunterHawk.lua")
local Graph = XelAssist.Graph.HunterHawk
local clean = graphState(nil)
assert(Graph:Attach(clean) and clean.hunterHawk.exact
    and clean.hunterHawk.activeSpellId == nil
    and clean.hunterHawk.deltaRangedAttackPower == 0,
    "a complete numeric scan must prove the inactive root")
local lower = graphState(13165)
assert(Graph:Attach(lower) and lower.hunterHawk.activeSpellId == 13165
    and lower.hunterHawk.baselineRangedAttackPower == 20
    and lower.hunterHawk.deltaRangedAttackPower == 0,
    "a live Hawk aura already included by UnitRangedDamage must be neutral")

local rankTwoFacts = Runtime:CaptureFacts({ spellId = 14318, actor = "player" },
    Runtime:InferKnowledge(14318))
local rankTwo = { name = "second localized action deliberately ignored",
    spellId = 14318, actor = "player", facts = rankTwoFacts }
local descriptor = { unit = "player", relation = "self", key = "self",
    guid = "Player-1" }
local projection, projectionReason, projectionHandled = Graph:Prepare(
    rankTwo, lower, descriptor)
assert(projection and projectionHandled and projectionReason == nil
    and projection.effect.currentChange == 15
    and projection.effect.projectedDelta == 15,
    "a higher rank must contribute only the delta over the live baseline")
assert(Graph:Blocker(action, lower, descriptor)
        == "same Hawk rank already active",
    "the same active rank must suppress duplicate recommendations")

local saved = { GetSpellRecField, GetSpellModifiers, UnitClass,
    UnitExists, C_UnitAuras.GetUnitAuras }
GetSpellRecField = function() error("DBC read during graph search") end
GetSpellModifiers = function() error("modifier read during graph search") end
UnitClass = function() error("class read during graph search") end
UnitExists = function() error("identity read during graph search") end
C_UnitAuras.GetUnitAuras = function() error("aura read during graph search") end

local context = { action = rankTwo, state = lower }
assert(Graph:Score(context, projection) and context.value == 0
    and context.power == 0 and context.kind == "classMechanic"
    and context.reason == "changes exact ranged weapon damage",
    "the aspect edge must have no fixed or role-typed utility")
dofile("Graph/ClassEvidence.lua")
dofile("Graph/ClassState.lua")
dofile("Graph/ClassMechanics.lua")
local integrated, integratedReason, integratedHandled =
    XelAssist.Graph.ClassMechanics:Prepare(
        rankTwo, lower, descriptor, rankTwoFacts)
local integratedContext = { action = rankTwo, state = lower }
assert(integrated and integratedHandled and integratedReason == nil
    and XelAssist.Graph.ClassMechanics:Score(
        integratedContext, integrated)
    and integratedContext.value == 0,
    "the production class boundary must preserve consequence-only Hawk scoring")
assert(Graph:Apply(lower, { action = rankTwo,
    classMechanicProjection = projection })
    and lower.hunterHawk.activeSpellId == 14318
    and lower.hunterHawk.activeRangedAttackPower == 35
    and lower.hunterHawk.deltaRangedAttackPower == 15,
    "rank replacement must retain the exact root-relative AP delta")
local auto = Graph:AutoShotBonus(lower)
assert(math.abs(auto - 15 / 14 * 2.8 * 1.1) < 0.00001,
    "Auto Shot must receive current-speed ranged AP damage")
local weapon = { spellId = 19434, actor = "player" }
local weaponFacts = { weaponCoefficient = 1.5, weaponNormalized = false,
    hunterRangedWeaponEvidence = { valid = true, exact = true,
        portfolio = "hunterMark", attackType = "ranged",
        weaponEffectCount = 1, normalized = false,
        spellId = 19434, weaponCoefficient = 1.5 } }
local special = Graph:WeaponActionBonus(weapon, weaponFacts, lower, {})
assert(math.abs(special - auto * 1.5) < 0.00001,
    "self ranged AP must pass through the action weapon coefficient")
XelAssist.Graph.HunterMark = {
    AutoShotBonus = function() return 5, false, nil end,
    WeaponActionBonus = function() return 7, false, nil end,
}
dofile("Graph/HunterRangedPower.lua")
local composedAuto = XelAssist.Graph.HunterRangedPower:AutoShotPower(
    100, lower, "target-guid")
local composedWeapon = XelAssist.Graph.HunterRangedPower:WeaponPower(
    100, weapon, weaponFacts, lower, "target-guid", {})
assert(math.abs(composedAuto - 105 - auto) < 0.00001
    and math.abs(composedWeapon - 107 - special) < 0.00001,
    "production Hunter power must compose target Mark and signed self Hawk AP")

local branch = {}
assert(Graph:Copy(lower, branch) and branch.hunterHawk ~= lower.hunterHawk
    and branch.hunterHawk.deltaRangedAttackPower == 15,
    "graph branches must not share mutable aspect lifecycle")

GetSpellRecField, GetSpellModifiers, UnitClass, UnitExists,
    C_UnitAuras.GetUnitAuras = saved[1], saved[2], saved[3], saved[4], saved[5]
Runtime:Invalidate()
records[13165].effectApplyAuraName = triple(99)
local drift, driftReason, driftHandled = Runtime:Classify(13165)
assert(drift and not drift.valid and driftHandled
    and driftReason == "Hawk DBC topology is incomplete",
    "a melee-AP or otherwise drifted rank must fail closed")

print("hunter_hawk_test: ok")
