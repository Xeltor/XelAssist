-- Fel Domination is a zero-value setup whose exact cast/mana benefit exists
-- only through an admitted DBC-proven Warlock summon consumer.
XelAssist = { Game = { Player = {} }, Graph = {} }
table.getn = table.getn or function(values) return #values end

local function triple(a, b, c) return { a or 0, b or 0, c or 0 } end
local rows = {}
rows[18708] = {
    school = 5, category = 0, castUI = 0, dispel = 1, mechanic = 0,
    attributes = 65536, attributesEx = 131072, attributesEx2 = 0,
    attributesEx3 = 0, attributesEx4 = 0, castingTimeIndex = 1,
    recoveryTime = 300000, categoryRecoveryTime = 0, interruptFlags = 0,
    auraInterruptFlags = 0, channelInterruptFlags = 0, procFlags = 87376,
    procChance = 100, procCharges = 1, durationIndex = 8, powerType = 0,
    manaCost = 0, manaCostPerlevel = 0, manaCostPercentage = 0,
    rangeIndex = 1, startRecoveryCategory = 0, startRecoveryTime = 0,
    spellFamilyName = 5, spellFamilyFlags = 0, maxAffectedTargets = 0,
    dmgClass = 1, preventionType = 1, effect = triple(6, 6),
    effectDieSides = triple(1, 1, 1), effectBaseDice = triple(1, 1),
    effectDicePerLevel = triple(), effectRealPointsPerLevel = triple(),
    effectBasePoints = triple(-4501, -41),
    effectImplicitTargetA = triple(1, 1), effectImplicitTargetB = triple(),
    effectApplyAuraName = triple(107, 108), effectAmplitude = triple(),
    effectItemType = triple(536870912, 536870912, 536870912),
    effectMiscValue = triple(10, 14), effectTriggerSpell = triple(),
}

local masterRows = {
    [18709] = { points = { -2001, -31, -26 } },
    [18710] = { points = { -4001, -61, -51 } },
}
for id, rank in pairs(masterRows) do
    rows[id] = { school = 0, attributes = 464, attributesEx = 0,
        attributesEx2 = 0, attributesEx3 = 0, durationIndex = 21,
        castingTimeIndex = 1, recoveryTime = 0, powerType = 0,
        manaCost = 0, rangeIndex = 1, spellFamilyName = 5,
        spellFamilyFlags = 0, effect = triple(6, 6, 6),
        effectDieSides = triple(1, 1, 1), effectBaseDice = triple(1, 1, 1),
        effectRealPointsPerLevel = triple(),
        effectBasePoints = triple(rank.points[1], rank.points[2], rank.points[3]),
        effectImplicitTargetA = triple(1, 1),
        effectApplyAuraName = triple(107, 108, 108),
        effectItemType = triple(536870912, 536870912),
        effectMiscValue = triple(10, 14, 11) }
end

local function summonRow(costPercent, creature)
    return { school = 5, attributes = 65536, attributesEx = 131073,
        attributesEx2 = 0, attributesEx3 = 0, castingTimeIndex = 7,
        durationIndex = 21, powerType = 0, manaCost = 0,
        manaCostPerlevel = 0, manaCostPercentage = costPercent,
        spellFamilyName = 5, spellFamilyFlags = 536870912,
        effect = triple(56), effectImplicitTargetA = triple(32),
        effectApplyAuraName = triple(), effectTriggerSpell = triple(),
        effectMiscValue = triple(creature) }
end
rows[688], rows[691] = summonRow(80, 416), summonRow(100, 417)
rows[99901] = summonRow(80, 999)
rows[99901].effect = triple(112)
rows[99902] = { spellFamilyName = 3, spellFamilyFlags = 0 }

local class, masterRank, auraActive, badStack = "WARLOCK", 0, false, false
local dbcReads = 0
function UnitClass() return "Warlock", class end
function GetSpellRecField(spellId, field, copied)
    dbcReads = dbcReads + 1
    local value = rows[spellId] and rows[spellId][field]
    if copied and type(value) == "table" then
        return { value[1], value[2], value[3] }
    end
    return value
end
function IsPlayerSpell(spellId)
    if spellId == 18710 then return masterRank == 2 end
    if spellId == 18709 then return masterRank >= 1 end
    return false
end
local function masterCast()
    return masterRank == 2 and -4000 or masterRank == 1 and -2000 or 0
end
local function masterCost()
    return masterRank == 2 and -60 or masterRank == 1 and -30 or 0
end
function GetSpellModifiers(_, operation)
    local extra = auraActive and true or false
    if operation == 10 then
        return masterCast() + (extra and -4500 or 0)
            + (badStack and -100 or 0), 0, 1
    elseif operation == 14 then
        return 0, masterCost() + (extra and -40 or 0), 1
    end
    return 0, 0, 0
end
local zeros = { 0, 0, 0, 0, 0, 0, 0 }
function GetUnitField(unit, field)
    assert(unit == "player")
    if field == "baseMana" then return 1000 end
    if field == "modCastSpeed" then return 1 end
    if field == "powerCostModifier" or field == "powerCostMultiplier" then
        return zeros
    end
end
local function currentCost(spellId)
    local percent = rows[spellId].manaCostPercentage
    local modifier = masterCost() + (auraActive and -40 or 0)
    return math.max(0, math.floor(percent * 10 * (100 + modifier) / 100))
end
C_Spell = {
    GetSpellInfo = function(spellId)
        return { spellID = spellId, castTime = 10000 }
    end,
    GetSpellPowerCost = function(spellId)
        local cost = currentCost(spellId)
        return { { type = 0, name = "MANA", cost = cost, minCost = cost,
            costPercent = rows[spellId].manaCostPercentage, costPerSec = 0,
            requiredAuraID = 0, hasRequiredAura = false } }
    end,
}
function GetTime() return 100 end
C_UnitAuras = { GetPlayerAuraBySpellID = function(spellId)
    assert(spellId == 18708)
    if not auraActive then return nil end
    return { spellId = 18708, isHelpful = true, applications = 1,
        duration = 15, expirationTime = 110 }
end }

dofile("Game/Player/WarlockFelDomination.lua")
local Runtime = XelAssist.Game.Player.WarlockFelDomination
local inferred, reason, handled = Runtime:InferKnowledge(18708)
assert(handled and not reason and inferred.kind == "modifier"
    and inferred.kindExact and inferred.self and inferred.combatBuff
    and inferred.warlockFelDomination and inferred.submissionGuarded,
    "Fel Domination must be inferred only from its numeric exact profile")
local setupAction = { name = "lokalisierter Aufbau", spellId = 18708,
    actor = "player", executor = "playerSpell", facts = inferred }
local summonAction = { name = "appel localise", spellId = 688,
    actor = "player", executor = "playerSpell", facts = { kind = "summon" } }

local state = { time = 20 }
assert(Runtime:Attach(state, "WARLOCK")
    and state.warlockFelDomination.active == false,
    "root attach must prove the inactive numeric aura state")
local setupFacts = Runtime:CaptureFacts(setupAction, inferred, state)
local summonFacts = Runtime:CaptureFacts(summonAction,
    { kind = "summon", cast = 10, cost = 800 }, state)
local contract = summonFacts.warlockFelDominationSummon
assert(contract and contract.exact and contract.eligible
    and contract.summonEffect == 56 and contract.baselineCast == 10
    and contract.affectedCast == 5.5 and contract.savedCast == 4.5
    and contract.baselineCost == 800 and contract.affectedCost == 480
    and contract.savedMana == 320 and contract.masterSummonerRank == 0
    and not contract.stackVerified,
    "clean root evidence must seal both Fel Domination summon deltas")

masterRank = 1
local rankOne = Runtime:CaptureFacts(summonAction,
    { kind = "summon", cast = 8, cost = 560 }, state)
local one = rankOne.warlockFelDominationSummon
assert(one.exact and one.masterSummonerRank == 1 and one.stackVerified
    and one.baselineCast == 8 and one.affectedCast == 3.5
    and one.baselineCost == 560 and one.affectedCost == 240,
    "Master Summoner rank one must stack only after exact aggregate proof")

masterRank = 2
local rankTwo = Runtime:CaptureFacts(summonAction,
    { kind = "summon", cast = 6, cost = 320 }, state)
local two = rankTwo.warlockFelDominationSummon
assert(two.exact and two.masterSummonerRank == 2 and two.stackVerified
    and two.baselineCast == 6 and two.affectedCast == 1.5
    and two.baselineCost == 320 and two.affectedCost == 0,
    "Master Summoner rank two must causally reach zero mana and 1.5s cast")

auraActive = true
local activeState = { time = 20 }
assert(Runtime:Attach(activeState, "WARLOCK")
    and activeState.warlockFelDomination.active
    and activeState.warlockFelDomination.remaining == 10,
    "an active root aura must seal its exact remaining lifetime")
local activeFacts = Runtime:CaptureFacts(summonAction,
    { kind = "summon", cast = 1.5, cost = 0 }, activeState)
assert(activeFacts.warlockFelDominationSummon.exact
    and activeFacts.warlockFelDominationSummon.baselineCost == 320
    and activeFacts.warlockFelDominationSummon.affectedCost == 0,
    "active aggregate modifiers must reconstruct the same exact baseline")

badStack = true
local bad = Runtime:CaptureFacts(summonAction,
    { kind = "summon" }, activeState).warlockFelDominationSummon
assert(bad.claimed and not bad.exact and not bad.eligible
    and bad.reason == "Fel Domination modifier stack is not exact",
    "any unproved simultaneous cast modifier must fail closed")
badStack, auraActive, masterRank = false, false, 0

local malformedAction = { spellId = 99901, actor = "player",
    executor = "playerSpell", facts = { kind = "summon" } }
local malformed = Runtime:CaptureFacts(malformedAction,
    malformedAction.facts, state).warlockFelDominationSummon
assert(malformed.claimed and not malformed.exact
    and malformed.reason == "affected Warlock summon topology is incomplete",
    "a masked non-summon effect must be recognized and fail closed")
local unrelatedAction = { spellId = 99902, actor = "player",
    executor = "playerSpell", facts = { kind = "summon" } }
assert(not Runtime:CaptureFacts(unrelatedAction,
    unrelatedAction.facts, state).warlockFelDominationSummon,
    "unrelated family shapes must remain outside this mechanic")

local reads = dbcReads
class = "MAGE"
local wrong, wrongReason, wrongHandled = Runtime:InferKnowledge(18708)
assert(not wrong and not wrongHandled
    and wrongReason == "player is not an exactly identified Warlock"
    and dbcReads == reads,
    "wrong-class inference must neither claim nor reread the profile")
class = "WARLOCK"

dofile("Graph/WarlockFelDomination.lua")
local Graph = XelAssist.Graph.WarlockFelDomination
local saved = { UnitClass, GetSpellRecField, IsPlayerSpell,
    GetSpellModifiers, GetUnitField, GetTime,
    C_Spell.GetSpellInfo, C_Spell.GetSpellPowerCost,
    C_UnitAuras.GetPlayerAuraBySpellID }
UnitClass = function() error("class read during graph search") end
GetSpellRecField = function() error("DBC read during graph search") end
IsPlayerSpell = function() error("talent read during graph search") end
GetSpellModifiers = function() error("modifier read during graph search") end
GetUnitField = function() error("unit field read during graph search") end
GetTime = function() error("clock read during graph search") end
C_Spell.GetSpellInfo = function() error("spell info read during graph search") end
C_Spell.GetSpellPowerCost = function() error("cost read during graph search") end
C_UnitAuras.GetPlayerAuraBySpellID = function()
    error("aura read during graph search")
end

local projectedState = { time = 20,
    warlockFelDomination = state.warlockFelDomination }
local setupProjection, setupReason, setupHandled = Graph:PrepareSetup(
    setupAction, projectedState, setupFacts)
assert(setupHandled and not setupReason and setupProjection
    and setupProjection.cost == 0 and setupProjection.cast == 0,
    "setup preparation must consume only sealed zero-cost evidence")
local score = { action = setupAction, state = projectedState,
    tooltip = setupProjection }
assert(Graph:Score(score, setupProjection) and score.value == 0
    and score.power == 0 and not score.estimated,
    "Fel Domination setup must have no standalone utility")
local lane = Graph:StrategicSetup(setupProjection)
assert(lane and lane.consumerKey == Graph.CONSUMER_KEY
    and Graph:ConsumerKey(summonFacts) == Graph.CONSUMER_KEY,
    "only an exact affected summon may close the strategic setup lane")
assert(Graph:Apply(projectedState,
    { classMechanicProjection = setupProjection })
    and projectedState.warlockFelDomination.active
    and projectedState.warlockFelDomination.remaining == 15,
    "setup application must arm exactly one timed charge")

local reduced, legalReason, legalHandled = Graph:PrepareLegal(
    summonAction, projectedState, summonFacts, 20)
assert(legalHandled and not legalReason and reduced
    and reduced.cast == 5.5 and reduced.cost == 480
    and reduced.warlockFelDominationConsumption
    and reduced.warlockFelDominationConsumption.epoch
        == projectedState.warlockFelDomination.epoch,
    "an admitted affected summon must receive both exact reductions")
XelAssist.Game.SpellClassification = {
    NormalGcd = function() return true end,
}
dofile("Graph/ActionAdmission.lua")
local admittedCast = XelAssist.Graph.ActionAdmission:Timing(
    summonAction, projectedState, reduced)
assert(admittedCast == 5.5 and summonAction.facts.cast == nil,
    "generic Timing must retain the sealed affected summon cast")
projectedState.actorReadyAt = { player = 20 }
local settledAt, settled, settledReason = Graph:SettleAdmission(
    summonAction, projectedState, summonFacts)
assert(settledAt == 20 and settledReason == nil and settled
    and settled.cast == 5.5 and settled.cost == 480
    and settled.warlockFelDominationConsumption,
    "admission settlement must retain an in-window affected summon")
local candidate = { action = summonAction, tooltip = reduced,
    cast = admittedCast, cost = reduced.cost }
assert(Graph:Consume(projectedState, candidate)
    and not projectedState.warlockFelDomination.active
    and projectedState.warlockFelDomination.consumed
    and projectedState.warlockFelDomination.savedCast == 4.5
    and projectedState.warlockFelDomination.savedMana == 320,
    "only the admitted summon application may consume the charge")
assert(not Graph:Consume(projectedState, candidate),
    "one charge must not be consumable twice")

local expiring = { time = 30, warlockFelDomination = {
    available = true, exact = true, active = false,
    profile = state.warlockFelDomination.profile } }
assert(Graph:Apply(expiring, { classMechanicProjection = setupProjection }))
expiring.warlockFelDomination.remaining = 0.5
local committed = Graph:PrepareLegal(summonAction, expiring, summonFacts, 30)
assert(committed and committed.warlockFelDominationConsumption)
assert(Graph:Advance(expiring, 1) and expiring.warlockFelDomination.expired
    and not expiring.warlockFelDomination.active,
    "the unconsumed setup must expire on the causal graph clock")
assert(Graph:Consume(expiring, { action = summonAction, tooltip = committed,
    cast = committed.cast, cost = committed.cost }),
    "a summon admitted before expiry must retain its snapshotted modifiers")

local tooLate = { time = 30, warlockFelDomination = {
    available = true, exact = true, active = false,
    profile = state.warlockFelDomination.profile } }
assert(Graph:Apply(tooLate, { classMechanicProjection = setupProjection }))
tooLate.warlockFelDomination.remaining = 0.5
local late, lateReason, lateHandled = Graph:PrepareLegal(
    summonAction, tooLate, assert(Graph:PrepareLegal(
        summonAction, tooLate, summonFacts, 30)), 30.5)
assert(lateHandled and not lateReason and late
    and late.cast == 10 and late.cost == 800
    and late.warlockFelDominationExpiredBeforeStart
    and not late.warlockFelDominationConsumption,
    "a summon starting at expiry must retain only its sealed baseline")
tooLate.actorReadyAt = { player = 30.5 }
local lateAt, settledLate, lateBlocker = Graph:SettleAdmission(
    summonAction, tooLate, summonFacts)
assert(lateAt == 30.5 and lateBlocker == nil and settledLate
    and settledLate.cast == 10 and settledLate.cost == 800
    and settledLate.warlockFelDominationExpiredBeforeStart
    and not settledLate.warlockFelDominationConsumption,
    "future admission must recompute once to the expired baseline")

local copied = {}
Graph:Copy(tooLate, copied)
copied.warlockFelDomination.profile.castFlat = 0
assert(tooLate.warlockFelDomination.profile.castFlat == -4500,
    "state copying must not alias the sealed setup profile")

local blocked, blockedReason, blockedHandled = Graph:PrepareLegal(
    malformedAction, tooLate, { warlockFelDominationSummon = malformed }, 30)
assert(blockedHandled and not blocked
    and blockedReason == "affected Warlock summon topology is incomplete",
    "an active charge must fail closed on a recognized malformed consumer")

UnitClass, GetSpellRecField, IsPlayerSpell, GetSpellModifiers,
    GetUnitField, GetTime = saved[1], saved[2], saved[3], saved[4],
        saved[5], saved[6]
C_Spell.GetSpellInfo, C_Spell.GetSpellPowerCost = saved[7], saved[8]
C_UnitAuras.GetPlayerAuraBySpellID = saved[9]

Runtime:Invalidate()
rows[18708].effectBasePoints = triple(-4500, -41)
local invalidFacts, invalidReason, invalidHandled = Runtime:InferKnowledge(18708)
assert(invalidHandled and not invalidFacts
    and invalidReason == "Fel Domination DBC topology is incomplete")
rows[18708].effectBasePoints = triple(-4501, -41)
local cachedFacts, cachedReason, cachedHandled = Runtime:InferKnowledge(18708)
assert(cachedHandled and not cachedFacts and cachedReason == invalidReason,
    "cached invalid setup topology must remain recognized")

print("ok: Warlock Fel Domination is an exact one-use summon setup consequence")
