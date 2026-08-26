-- Installed Shield Wall must earn value only through exact incoming damage.
table.getn = table.getn or function(value)
    local count = 0
    while value and value[count + 1] ~= nil do count = count + 1 end
    return count
end

XelAssist = { Game = { Player = {} }, Graph = {} }

local function triple(first, second, third)
    return { first or 0, second or 0, third or 0 }
end

local row = {
    school = 0, category = 132, castUI = 0, dispel = 0, mechanic = 0,
    attributes = 327696, attributesEx = 131072, attributesEx2 = 0,
    attributesEx3 = 0, attributesEx4 = 0,
    stances = 131072, stancesNot = 0, targets = 0,
    targetCreatureType = 0, requiresSpellFocus = 0,
    casterAuraState = 0, targetAuraState = 0, castingTimeIndex = 1,
    recoveryTime = 0, categoryRecoveryTime = 1800000,
    interruptFlags = 0, auraInterruptFlags = 0,
    channelInterruptFlags = 0, procFlags = 0, procChance = 101,
    procCharges = 0, maxLevel = 0, baseLevel = 28, spellLevel = 28,
    durationIndex = 1, powerType = 1, manaCost = 0,
    manaCostPerlevel = 0, manaPerSecond = 0,
    manaPerSecondPerLevel = 0, rangeIndex = 1, speed = 0,
    modalNextSpell = 0, stackAmount = 0, equippedItemClass = 4,
    equippedItemSubClassMask = 64, equippedItemInventoryTypeMask = 0,
    manaCostPercentage = 0, startRecoveryCategory = 133,
    startRecoveryTime = 1500, maxTargetLevel = 0,
    spellFamilyName = 4, spellFamilyFlags = 8192,
    maxAffectedTargets = 0, dmgClass = 2, preventionType = 2,
    effect = triple(6), effectDieSides = triple(1),
    effectBaseDice = triple(1), effectDicePerLevel = triple(),
    effectRealPointsPerLevel = triple(), effectBasePoints = triple(-76),
    effectMechanic = triple(), effectImplicitTargetA = triple(1),
    effectImplicitTargetB = triple(), effectRadiusIndex = triple(),
    effectApplyAuraName = triple(87), effectAmplitude = triple(),
    effectMultipleValue = triple(), effectChainTarget = triple(),
    effectItemType = triple(), effectMiscValue = triple(127),
    effectTriggerSpell = triple(), effectPointsPerComboPoint = triple(),
}

local classToken, now, aura = "WARRIOR", 100, nil
local dbcCalls, durationCalls, modifierCalls, auraCalls = 0, 0, 0, 0
local effectiveDuration, dirtyMagnitude = 12000, false

function UnitClass()
    return classToken == "WARRIOR" and "Warrior" or "Priest", classToken
end

function GetSpellRecField(spellId, field, copied)
    dbcCalls = dbcCalls + 1
    if spellId ~= 871 or row[field] == nil then error("unexpected DBC read") end
    local value = row[field]
    if copied and type(value) == "table" then
        return { value[1], value[2], value[3] }
    end
    return value
end

function GetSpellDuration(spellId, ignoreModifiers)
    durationCalls = durationCalls + 1
    assert(spellId == 871)
    return ignoreModifiers and 10000 or effectiveDuration
end

function GetSpellModifiers(spellId, operation)
    modifierCalls = modifierCalls + 1
    assert(spellId == 871 and operation == 8)
    return dirtyMagnitude and 1 or 0, 0, dirtyMagnitude and 1 or 0
end

function GetTime() return now end
C_UnitAuras = { GetPlayerAuraBySpellID = function(spellId)
    auraCalls = auraCalls + 1
    assert(spellId == 871)
    return aura
end }

dofile("Game/Player/WarriorShieldWall.lua")
local Runtime = XelAssist.Game.Player.WarriorShieldWall

local facts, reason, handled = Runtime:InferKnowledge(871)
assert(facts and handled and reason == nil and facts.kind == "defensive"
    and facts.kindExact and facts.self and facts.fixedTarget == "player"
    and facts.warriorShieldWall and facts.cooldown
    and facts.stances == 131072 and facts.equippedItemClass == 4
    and facts.equippedItemSubClassMask == 64
    and facts.warriorShieldWallEvidence.damageTakenPercent == -75
    and facts.warriorShieldWallEvidence.damageTakenMultiplier == 0.25,
    "installed identity must seal stance, shield, and mitigation topology")
assert(facts.priority == nil and facts.rotation == nil
    and facts.preferred == nil and facts.flatUtility == nil,
    "inference must contain no typed order or proxy defensive utility")

local cachedCalls = dbcCalls
assert(Runtime:InferKnowledge(871) and dbcCalls == cachedCalls,
    "validated installed topology must be cached")
local ordinary, ordinaryReason, ordinaryHandled = Runtime:InferKnowledge(2565)
assert(ordinary == nil and not ordinaryHandled
    and ordinaryReason == "spell is not installed Shield Wall",
    "Shield Block must remain outside this isolated mechanic")

local action = { name = "localized name ignored", spellId = 871,
    actor = "player", executor = "playerSpell", facts = facts }
local captured = Runtime:CaptureFacts(action, facts)
local profile = assert(Runtime:CapturedEvidence(captured))
assert(captured ~= facts and profile.duration == 12
    and profile.damageTakenMultiplier == 0.25
    and captured.cost == 0 and captured.powerType == 1
    and profile.runtimeVerified == false,
    "root capture must seal effective duration and clean magnitude")

dirtyMagnitude = true
local dirty = Runtime:CaptureFacts(action, facts)
local rejected, rejectedReason = Runtime:CapturedEvidence(dirty)
assert(rejected == nil
    and rejectedReason == "modified Shield Wall magnitude is unresolved",
    "an unmodeled magnitude modifier must fail closed")
dirtyMagnitude = false

XelAssist.Graph.IncomingConsequences = {
    RecipientGuid = function(_, cast)
        return cast.consequence and cast.consequence.targetGuid
            or cast.targetGuid
    end,
    Preview = function(_, _, cast)
        local consequence = cast.consequence
        if not (consequence and consequence.kind == "damage") then return nil end
        local probability = cast.probability or 1
        return { amount = consequence.amount * probability,
            rawAmount = consequence.amount, probability = probability,
            recipient = { kind = consequence.recipientKind or "player" } }
    end,
}

dofile("Graph/WarriorShieldWall.lua")
local Graph = XelAssist.Graph.WarriorShieldWall

local function root()
    return { time = 0, actors = { player = { guid = "player-guid",
        health = 300, healthMax = 300 } },
        hostileCasts = { order = {}, byCaster = {} } }
end

local state = root()
assert(Graph:Attach(state, "WARRIOR")
    and state.warriorShieldWall.exact
    and state.warriorShieldWall.active == false and auraCalls == 1,
    "an absent numeric aura must attach an exact inactive component")

local descriptor = { unit = "player", guid = "player-guid",
    relation = "self" }
local prepared, prepareReason, prepareHandled = Graph:Prepare(
    action, state, descriptor, captured)
assert(prepared and prepareHandled and prepareReason == nil
    and prepared.cost == 0 and prepared.powerType == 1
    and prepared.classMechanic == "warriorShieldWall"
    and prepared.warriorShieldWallTransition.duration == 12
    and prepared.warriorShieldWallTransition.damageTakenMultiplier == 0.25,
    "preparation must create only the sealed self mitigation transition")

local malformed, malformedReason, malformedHandled = Graph:Prepare(
    action, state, descriptor, dirty)
assert(malformed == nil and malformedHandled
    and malformedReason == "modified Shield Wall magnitude is unresolved",
    "graph preparation must not fall back to the static DBC magnitude")

state.hostileCasts = { order = { "one", "late", "other", "unknown" },
    byCaster = {
        one = { remaining = 3, probability = 1, consequence = {
            kind = "damage", amount = 100, school = 2,
            targetGuid = "player-guid", estimated = false } },
        late = { remaining = 12, probability = 1, consequence = {
            kind = "damage", amount = 1000, school = 0,
            targetGuid = "player-guid", estimated = false } },
        other = { remaining = 2, probability = 1, consequence = {
            kind = "damage", amount = 1000, school = 5,
            targetGuid = "other-guid", estimated = false } },
        unknown = { remaining = 4, probability = 1,
            targetGuid = "player-guid" },
    } }
local score = { action = action, state = state, descriptor = descriptor,
    tooltip = prepared, wait = 0, cast = 0,
    power = 999, expectedPower = 999, effectivePower = 999,
    value = 999, estimated = false }
assert(Graph:Score(score, prepared)
    and score.warriorShieldWallPreventedDamage == 75
    and score.warriorShieldWallIncomingCount == 1
    and score.warriorShieldWallUnresolvedIncoming == 1
    and score.value == 75 and score.power == 0 and score.estimated,
    "only an exact in-window player impact may create defensive value")

local quiet = root()
assert(Graph:Attach(quiet, "WARRIOR"))
local quietPrepared = assert(Graph:Prepare(action, quiet, descriptor, captured))
local quietScore = { state = quiet, tooltip = quietPrepared, wait = 0, cast = 0 }
assert(Graph:Score(quietScore, quietPrepared) and quietScore.value == 0
    and quietScore.warriorShieldWallIncomingCount == 0,
    "Shield Wall must have zero utility without a provable consumer")

local saved = { GetSpellRecField, GetSpellDuration, GetSpellModifiers,
    UnitClass, GetTime, C_UnitAuras.GetPlayerAuraBySpellID }
GetSpellRecField = function() error("graph search reread DBC") end
GetSpellDuration = function() error("graph search reread duration") end
GetSpellModifiers = function() error("graph search reread modifiers") end
UnitClass = function() error("graph search reread class") end
GetTime = function() error("graph search reread time") end
C_UnitAuras.GetPlayerAuraBySpellID = function()
    error("graph search rescanned auras")
end

local child = root()
assert(Graph:Copy(state, child)
    and child.warriorShieldWall ~= state.warriorShieldWall,
    "each graph branch must own its Shield Wall component")
local candidate = { action = action, tooltip = prepared,
    classMechanicProjection = prepared, wait = 0, cast = 0,
    downtime = 1.5 }
assert(Graph:Apply(child, candidate)
    and child.warriorShieldWall.active
    and child.warriorShieldWall.remaining == 12,
    "successful action application must activate only the copied branch")
assert(Graph:Advance(child, 1.5)
    and child.warriorShieldWall.remaining == 10.5,
    "passage of time must age the projected aura")
assert(Graph:Apply(child, candidate)
    and child.warriorShieldWall.remaining == 10.5,
    "the later action-effects hook must be idempotent, not refresh duration")

local adjusted, adjustReason, adjustHandled = Graph:AdjustIncoming(
    child, { kind = "player" }, 100, 5)
assert(adjusted == 25 and adjustReason == nil and adjustHandled,
    "active Shield Wall must reduce every installed school by 75 percent")
adjusted, adjustReason, adjustHandled = Graph:AdjustIncoming(
    child, { kind = "pet" }, 100, 0)
assert(adjusted == 100 and adjustReason == nil and not adjustHandled,
    "player Shield Wall must never mitigate pet damage")
adjusted, adjustReason, adjustHandled = Graph:AdjustIncoming(
    child, { kind = "player" }, 100, nil)
assert(adjusted == 25 and adjustReason == nil and adjustHandled,
    "the complete all-school mask may cover an omitted school identity")
assert(Graph:Advance(child, 10.5)
    and child.warriorShieldWall.active == false,
    "expiry must close the mitigation window")
adjusted, adjustReason, adjustHandled = Graph:AdjustIncoming(
    child, { kind = "player" }, 100, 0)
assert(adjusted == 100 and not adjustHandled,
    "expired Shield Wall must not alter later damage")

GetSpellRecField, GetSpellDuration, GetSpellModifiers, UnitClass, GetTime,
    C_UnitAuras.GetPlayerAuraBySpellID = saved[1], saved[2], saved[3],
    saved[4], saved[5], saved[6]
aura = { spellId = 871, isHelpful = true, applications = 1,
    duration = 12, expirationTime = 107 }
local activeRoot = root()
assert(Graph:Attach(activeRoot, "WARRIOR")
    and activeRoot.warriorShieldWall.active
    and activeRoot.warriorShieldWall.remaining == 7,
    "a live numeric aura must retain its exact remaining window")
rejected, rejectedReason, prepareHandled = Graph:Prepare(
    action, activeRoot, descriptor, captured)
assert(rejected == nil and prepareHandled
    and rejectedReason == "Shield Wall already active",
    "active root evidence must suppress an impossible duplicate")

aura = { spellId = 871, isHelpful = true, applications = 1,
    duration = 12, expirationTime = 999 }
local invalidAura = root()
assert(not Graph:Attach(invalidAura, "WARRIOR")
    and invalidAura.warriorShieldWall.exact == false,
    "an incoherent active aura lifetime must fail closed")
aura = nil

Runtime:Invalidate()
row.effectMiscValue[1] = 1
rejected, rejectedReason, prepareHandled = Runtime:InferKnowledge(871)
assert(rejected == nil and prepareHandled
    and rejectedReason == "Shield Wall DBC topology is incomplete",
    "a recognized changed school mask must fail classification closed")
row.effectMiscValue[1] = 127
Runtime:Invalidate()

classToken = "PRIEST"
local readsBefore = dbcCalls
rejected, rejectedReason, prepareHandled = Runtime:InferKnowledge(871)
assert(rejected == nil and not prepareHandled and dbcCalls == readsBefore,
    "another class must be rejected before DBC discovery")

print("ok: exact Warrior Shield Wall hostile-cast mitigation")
