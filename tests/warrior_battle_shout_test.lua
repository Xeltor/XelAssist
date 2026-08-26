-- Battle Shout is valued only through exact projected AP consequences. The
-- test deliberately removes every live API after root attachment.
table.getn = table.getn or function(value) return #value end
XelAssist = { Game = { Player = {} }, Graph = {} }

local function triple(first, second, third)
    return { first or 0, second or 0, third or 0 }
end

local function shoutRow(rank)
    return {
        school = 0, category = 0, castUI = 0, dispel = 0, mechanic = 0,
        attributes = 327696, attributesEx = 0, attributesEx2 = 0,
        attributesEx3 = 0, attributesEx4 = 0, stances = 0, stancesNot = 0,
        targets = 0, targetCreatureType = 0, requiresSpellFocus = 0,
        casterAuraState = 0, targetAuraState = 0, castingTimeIndex = 1,
        recoveryTime = 0, categoryRecoveryTime = 0, interruptFlags = 0,
        auraInterruptFlags = 0, channelInterruptFlags = 0, procFlags = 0,
        procChance = 101, procCharges = 0, maxLevel = rank.maxLevel,
        baseLevel = rank.baseLevel, spellLevel = rank.spellLevel,
        durationIndex = 4, powerType = 1, manaCost = 100,
        manaCostPerlevel = 0, manaPerSecond = 0,
        manaPerSecondPerLevel = 0, rangeIndex = 1, speed = 0,
        modalNextSpell = 0, stackAmount = 0, equippedItemClass = -1,
        equippedItemSubClassMask = -1, equippedItemInventoryTypeMask = 0,
        manaCostPercentage = 0, startRecoveryCategory = 133,
        startRecoveryTime = 1500, maxTargetLevel = 0, spellFamilyName = 4,
        spellFamilyFlags = 65536, maxAffectedTargets = 0, dmgClass = 1,
        preventionType = 1, effect = triple(6), effectDieSides = triple(1),
        effectBaseDice = triple(1), effectDicePerLevel = triple(),
        effectRealPointsPerLevel = triple(rank.perLevel),
        effectBasePoints = triple(rank.basePoints), effectMechanic = triple(),
        effectImplicitTargetA = triple(20), effectImplicitTargetB = triple(),
        effectRadiusIndex = triple(9), effectApplyAuraName = triple(99),
        effectAmplitude = triple(), effectMultipleValue = triple(),
        effectChainTarget = triple(), effectItemType = triple(),
        effectMiscValue = triple(), effectTriggerSpell = triple(),
        effectPointsPerComboPoint = triple(),
    }
end

local ranks = {
    [6673] = { rank = 1, baseLevel = 1, spellLevel = 1, maxLevel = 11,
        basePoints = 14, perLevel = 0.5, flatThreat = 1 },
    [5242] = { rank = 2, baseLevel = 12, spellLevel = 12, maxLevel = 21,
        basePoints = 34, perLevel = 0.5, flatThreat = 12 },
    [6192] = { rank = 3, baseLevel = 22, spellLevel = 22, maxLevel = 31,
        basePoints = 54, perLevel = 0.5, flatThreat = 22 },
    [11549] = { rank = 4, baseLevel = 32, spellLevel = 32, maxLevel = 41,
        basePoints = 84, perLevel = 1, flatThreat = 32 },
    [11550] = { rank = 5, baseLevel = 42, spellLevel = 42, maxLevel = 51,
        basePoints = 129, perLevel = 1, flatThreat = 42 },
    [11551] = { rank = 6, baseLevel = 52, spellLevel = 52, maxLevel = 61,
        basePoints = 184, perLevel = 1, flatThreat = 52 },
    [25289] = { rank = 7, baseLevel = 60, spellLevel = 60, maxLevel = 61,
        basePoints = 231, perLevel = 1, flatThreat = 60 },
}
local records = {}
local spellId, rank
for spellId, rank in pairs(ranks) do records[spellId] = shoutRow(rank) end
records[78] = { dmgClass = 2, attributesEx3 = 0, effect = triple(17) }
records[845] = { dmgClass = 2, attributesEx3 = 0, effect = triple(121) }
records[9000] = { effectApplyAuraName = triple(0, 99, 0) }

local reads, class, level, actualDuration = 0, "WARRIOR", 10, 120000
local party, raid, clock, auras, modifierKind = 0, 0, 100, {}, nil
function GetSpellRecField(id, field, copied)
    reads = reads + 1
    local value = records[id] and records[id][field]
    if copied and type(value) == "table" then
        return { value[1], value[2], value[3] }
    end
    return value
end
function GetSpellDuration(_, ignoreModifiers)
    reads = reads + 1
    return ignoreModifiers and 120000 or actualDuration
end
function GetSpellModifiers(_, kind)
    reads = reads + 1
    if kind == modifierKind then return 1, 0, 1 end
    return 0, 0, 0
end
function UnitClass() reads = reads + 1; return "localized", class end
function UnitLevel() reads = reads + 1; return level end
function UnitAttackSpeed() reads = reads + 1; return 2.5, nil end
function UnitDamage()
    reads = reads + 1
    return 30, 40, 0, 0, 5, -2, 1.1
end
function GetNumPartyMembers() reads = reads + 1; return party end
function GetNumRaidMembers() reads = reads + 1; return raid end
function GetTime() reads = reads + 1; return clock end
C_UnitAuras = { GetUnitAuras = function(unit, filter)
    reads = reads + 1
    assert(unit == "player" and filter == "HELPFUL")
    return auras
end }

dofile("Game/Player/WarriorBattleShoutRoot.lua")
dofile("Game/Player/WarriorBattleShout.lua")
local Runtime = XelAssist.Game.Player.WarriorBattleShout
for spellId, rank in pairs(ranks) do
    local found, reason, handled = Runtime:Classify(spellId)
    assert(found and found.valid and found.exact and handled and reason == nil
        and found.rank == rank.rank
        and found.baseAttackPower == rank.basePoints + 1
        and found.attackPowerPerLevel == rank.perLevel
        and found.flatThreat == rank.flatThreat and found.flatThreatExact
        and found.cost == 10 and found.powerType == 1
        and found.baseDuration == 120 and found.gcd == 1.5
        and found.recipient == "solo-player-through-party-area",
        "every installed Battle Shout rank must retain exact AP and threat evidence")
end
local unrelated, _, unrelatedHandled = Runtime:Classify(99999)
assert(unrelated == nil and not unrelatedHandled,
    "an unrelated numeric identity must remain outside the portfolio")

local inferred, reason, handled = Runtime:InferKnowledge(6673)
assert(inferred and handled and reason == nil and inferred.kind == "buff"
    and inferred.kindExact and inferred.warriorBattleShout
    and inferred.self and inferred.fixedTarget == "player"
    and inferred.meleeAttackPower and inferred.partyArea
    and inferred.requiresExactBattleShoutDownstream
    and inferred.preferred == nil and inferred.order == nil,
    "inference must expose consequences without a rotation or rank priority")
class = "ROGUE"
local foreign, _, foreignHandled = Runtime:InferKnowledge(6673)
assert(foreign == nil and not foreignHandled,
    "another class must not claim Battle Shout inference")
class = "WARRIOR"

local action = { name = "localized shout deliberately ignored", spellId = 6673,
    actor = "player", facts = inferred }
local captured = Runtime:CaptureFacts(action, inferred)
local profile, profileReason, profileHandled = Runtime:CapturedEvidence(captured)
assert(profile and profileHandled and profileReason == nil
    and profile.playerLevel == 10 and profile.effectiveLevel == 10
    and profile.attackPower == 19.5 and profile.duration == 120
    and profile.cost == 10 and profile.flatThreat == 1,
    "level-scaled AP must use the exact server effect-value formula")

actualDuration = 180000
local extended = Runtime:CaptureFacts(action, inferred)
assert(extended.warriorBattleShoutProfile.valid
    and extended.warriorBattleShoutProfile.duration == 180,
    "the live modified duration must be sealed rather than replaced by a proxy")
actualDuration = 120000
modifierKind = Runtime.ALL_EFFECTS_MOD
local modified = Runtime:CaptureFacts(action, inferred)
local rejected, rejectedReason, rejectedHandled =
    Runtime:CapturedEvidence(modified)
assert(rejected == nil and rejectedHandled
    and rejectedReason == "modified Battle Shout magnitude or cost is unresolved",
    "unreconstructed player spell modifiers must fail closed")
modifierKind = nil

local weaponAction = { name = "localized strike ignored", spellId = 78,
    actor = "player", facts = { kind = "damage", melee = true } }
local weaponFacts = Runtime:CaptureFacts(weaponAction, {
    kind = "damage", melee = true, weaponCoefficient = 1,
    weaponNormalized = false,
    weaponFormulaSource = "OctoWoW VMaNGOS weapon effects" })
assert(weaponFacts.warriorMainHandWeaponEvidence
    and weaponFacts.warriorMainHandWeaponEvidence.attackType == "main"
    and not weaponFacts.warriorMainHandWeaponEvidence.normalized,
    "an exact main-hand weapon effect must expose the projected AP lane")
local normalizedAction = { name = "localized normalized strike ignored",
    spellId = 845, actor = "player", facts = { kind = "damage", melee = true } }
local normalizedFacts = Runtime:CaptureFacts(normalizedAction, {
    kind = "damage", melee = true, weaponCoefficient = 1.5,
    weaponNormalized = true,
    weaponFormulaSource = "OctoWoW VMaNGOS weapon effects" })
assert(normalizedFacts.warriorMainHandWeaponEvidence
    and normalizedFacts.warriorMainHandWeaponEvidence.normalized
    and normalizedFacts.warriorMainHandWeaponEvidence.weaponCoefficient == 1.5,
    "normalized speed and the weapon coefficient must remain distinct")

XelAssist.Graph.PlayerThreat = { Scale = function(_, _, actor, amount)
    assert(actor == "player")
    return amount * 1.3, true, 1.3
end }
dofile("Graph/WarriorBattleShout.lua")
local Graph = XelAssist.Graph.WarriorBattleShout
local function state(inCombat)
    local out = { inCombat = inCombat, targetPlayerThreatDeltaExact = true,
        hostiles = { order = { "one" }, byKey = { one = { dead = false,
            threat = { playerDelta = 0, playerDeltaExact = true } } } } }
    Graph:Attach(out)
    return out
end
local clean, idle = state(true), state(false)
local descriptor = { unit = "player", relation = "friendly" }
local projection = Graph:Prepare(action, clean, descriptor, captured)
assert(projection and projection.attackPower == 19.5
    and projection.duration == 120 and projection.flatThreat == 1,
    "a clean solo root must prepare the exact AP consequence")

dofile("Graph/ClassEvidence.lua")
dofile("Graph/ClassState.lua")
dofile("Graph/ClassMechanics.lua")
local integrated, integratedReason, integratedHandled =
    XelAssist.Graph.ClassMechanics:Prepare(
        action, clean, descriptor, captured)
local integratedContext = { action = action, state = clean,
    descriptor = descriptor, tooltip = captured }
assert(integrated and integratedHandled and integratedReason == nil
    and XelAssist.Graph.ClassMechanics:Score(integratedContext, integrated)
    and integratedContext.value == 0,
    "the production class-mechanic boundary must preserve consequence-only scoring")

party = 1
local grouped = state(true)
party = 0
assert(Graph:Blocker(action, grouped, descriptor, captured)
        == "Battle Shout group fanout is unresolved",
    "unfrozen party recipients must fail closed")
auras = { { spellId = 9000, expirationTime = 130 } }
local competing = state(true)
auras = {}
local competingBlocker = Graph:Blocker(action, competing, descriptor, captured)
assert(competingBlocker == "competing melee attack-power aura is active",
    "exclusive AP aura competition must not invent stacking: "
        .. tostring(competingBlocker))
auras = { { spellId = 6673, expirationTime = 200 } }
local live = state(true)
auras = {}
assert(live.warriorBattleShoutRoot.activeRemaining == 100
    and live.warriorBattleShoutRoot.activeProfile.spellId == 6673
    and Graph:Blocker(action, live, descriptor, captured)
        == "live Battle Shout baseline is already active",
    "a live aura must carry causal expiration and block an inexact refresh")

local saved = { GetSpellRecField, GetSpellDuration, GetSpellModifiers,
    UnitClass, UnitLevel, UnitAttackSpeed, UnitDamage, GetNumPartyMembers,
    GetNumRaidMembers, GetTime, C_UnitAuras.GetUnitAuras }
GetSpellRecField = function() error("DBC read during graph search") end
GetSpellDuration = function() error("duration read during graph search") end
GetSpellModifiers = function() error("modifier read during graph search") end
UnitClass = function() error("class read during graph search") end
UnitLevel = function() error("level read during graph search") end
UnitAttackSpeed = function() error("speed read during graph search") end
UnitDamage = function() error("damage read during graph search") end
GetNumPartyMembers = function() error("party read during graph search") end
GetNumRaidMembers = function() error("raid read during graph search") end
GetTime = function() error("clock read during graph search") end
C_UnitAuras.GetUnitAuras = function() error("aura read during graph search") end

assert(Graph:Advance(live, 100) == 0,
    "a root Battle Shout must expire on its captured remaining lifetime")
local expiredLive = Graph:MainHandWhiteBonus(live)
assert(math.abs(expiredLive + 19.5 / 14 * 2.5 * 1.1) < 0.00001
    and Graph:Prepare(action, live, descriptor, captured),
    "expiry must subtract root AP and make a refresh causally legal")
local refreshed = { action = action, tooltip = captured, target = "player",
    targetRelation = "friendly", classMechanicProjection = projection }
assert(Graph:Apply(live, refreshed)
    and Graph:MainHandWhiteBonus(live) == 0,
    "refreshing the same rank must restore, not double, root attack power")

assert(Graph:Advance(competing, 30) == 0
    and Graph:Blocker(action, competing, descriptor, captured)
        == "competing attack-power baseline expired without exact magnitude",
    "competing aura expiry must become explicit unknown baseline correction")
local expiredCompeting, _, competingReason =
    Graph:MainHandWhiteBonus(competing)
assert(expiredCompeting == nil
    and competingReason
        == "competing attack-power baseline expired without exact magnitude",
    "an expired unknown competing AP magnitude must fail closed")

local context = { action = action, state = clean, descriptor = descriptor,
    tooltip = captured }
local malformed = { warriorBattleShoutRoot = clean.warriorBattleShoutRoot }
assert(Graph:Blocker(action, malformed, descriptor, captured)
        == "Battle Shout projection state unavailable",
    "a missing projection component must fail closed before application")
assert(Graph:Score(context, projection) and context.value == 0
    and context.power == 0 and context.expectedPower == 0
    and context.kind == "classMechanic"
    and context.reason == "enables exact main-hand attack-power damage",
    "Battle Shout must not receive fixed or typed utility")
local candidate = { action = action, tooltip = captured, target = "player",
    targetRelation = "friendly", classMechanicProjection = projection }
assert(Graph:Apply(clean, candidate), "the exact self projection must apply")
local component = clean.warriorBattleShout
assert(component.active and component.remaining == 120
    and component.attackPower == 19.5
    and component.flatThreatEvidence == 1
    and component.flatThreatMinimum == 0
    and math.abs(component.flatThreatMaximum - 1.3) < 0.00001
    and component.flatThreatApplicationExact == false
    and clean.hostiles.byKey.one.threat.playerDeltaExact == false
    and clean.hostiles.byKey.one.threat.containsUnresolvedBattleShoutThreat
    and clean.targetPlayerThreatDeltaExact == false,
    "hidden hostile-ref fanout must invalidate per-hostile threat, not distribute it")
local white = Graph:MainHandWhiteBonus(clean)
assert(math.abs(white - 19.5 / 14 * 2.5 * 1.1) < 0.00001,
    "ordinary white damage must use current speed and the sealed factor")
local special = Graph:WeaponActionBonus(weaponAction, weaponFacts, clean, {})
assert(math.abs(special - white) < 0.00001,
    "a 1.0 current-speed weapon effect must receive the same AP delta")
XelAssist.Combat = {}
XelAssist.Game.Capabilities = { BonusDamage = function() return 0 end }
XelAssist.Graph.RootObservation = { Power = function()
    return { weaponBasisCaptured = true, weaponBasis = 100,
        weaponEvidence = { exact = true, damagePercent = 1 } }, "known"
end }
dofile("Graph/ActionPower.lua")
local integratedPower, integratedEstimated, integratedEvidence =
    XelAssist.Graph.ActionPower:Estimate(
        weaponAction, weaponFacts, clean, nil, false, nil)
assert(math.abs(integratedPower - 100 - white) < 0.00001
    and integratedEstimated and integratedEvidence.exact,
    "production weapon power must add the signed Battle Shout AP consequence")
local normalized = Graph:WeaponActionBonus(normalizedAction, normalizedFacts,
    clean, { exact = true, normalized = true,
        normalizedSpeed = 2.4, damagePercent = 1.1 })
assert(math.abs(normalized - 19.5 / 14 * 2.4 * 1.1 * 1.5) < 0.00001,
    "normalized AP must use normalized speed before the weapon coefficient")
clean.playerForm = { available = true, formID = 18, projected = true }
local staleWhite, _, staleReason = Graph:MainHandWhiteBonus(clean)
local staleWeapon, _, staleWeaponReason = Graph:WeaponActionBonus(
    weaponAction, weaponFacts, clean, {})
assert(staleWhite == nil and staleWeapon == nil
    and staleReason == "projected Warrior stance melee lane unavailable"
    and staleWeaponReason == staleReason,
    "a projected stance must not reuse the root stance damage multiplier")
clean.playerForm.projected = false

local branch = {}
assert(Graph:Copy(clean, branch) and branch.warriorBattleShout.active
    and branch.warriorBattleShout ~= clean.warriorBattleShout,
    "branch copies must not share mutable aura lifecycle")
assert(Graph:Blocker(action, clean, descriptor, captured)
        == "projected Battle Shout is active",
    "an active projection must suppress duplicate recommendations")
assert(Graph:Advance(clean, 60) == 60 and Graph:MainHandWhiteBonus(clean) > 0,
    "the AP consequence must remain active until its actual expiration")
assert(Graph:Advance(clean, 61) == 0 and Graph:MainHandWhiteBonus(clean) == 0
    and Graph:Prepare(action, clean, descriptor, captured),
    "expiration must remove AP and make a refresh causally legal")

local idleProjection = Graph:Prepare(action, idle, descriptor, captured)
local idleCandidate = { action = action, tooltip = captured, target = "player",
    targetRelation = "friendly", classMechanicProjection = idleProjection }
assert(Graph:Apply(idle, idleCandidate)
    and idle.warriorBattleShout.flatThreatMinimum == 0
    and idle.warriorBattleShout.flatThreatMaximum == 0
    and idle.warriorBattleShout.flatThreatApplicationExact
    and idle.hostiles.byKey.one.threat.playerDeltaExact,
    "out-of-combat application must preserve the exact zero-threat consequence")

GetSpellRecField, GetSpellDuration, GetSpellModifiers, UnitClass, UnitLevel,
    UnitAttackSpeed, UnitDamage, GetNumPartyMembers, GetNumRaidMembers,
    GetTime, C_UnitAuras.GetUnitAuras = saved[1], saved[2], saved[3], saved[4],
    saved[5], saved[6], saved[7], saved[8], saved[9], saved[10], saved[11]
Runtime:Invalidate()
records[6673].effectImplicitTargetA = triple(1)
local invalid, invalidReason, invalidHandled = Runtime:Classify(6673)
local cachedInvalid, cachedReason, cachedHandled = Runtime:Classify(6673)
assert(invalid and not invalid.valid and invalidHandled
    and invalidReason == "Battle Shout DBC topology is incomplete"
    and cachedInvalid and not cachedInvalid.valid and cachedHandled
    and cachedReason == invalidReason,
    "invalid recognized rows must stay handled through the bounded cache")

print("warrior_battle_shout_test: ok")
