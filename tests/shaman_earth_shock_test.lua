local function check(value, message)
    if not value then error(message or "check failed") end
end

table.getn = table.getn or function(value) return #value end

local function close(first, second, message)
    if math.abs(first - second) > 0.00001 then
        error((message or "not close") .. ": " .. tostring(first)
            .. " ~= " .. tostring(second))
    end
end

XelAssist = { Game = { Player = {} }, Graph = {} }

local ranks = {
    [8042] = { 9, 4, 4, 30, 16, 3, 0.5, 0.154 },
    [8044] = { 13, 8, 8, 50, 31, 3, 0.7, 0.212 },
    [8045] = { 19, 14, 14, 85, 59, 5, 1, 0.299 },
    [8046] = { 29, 24, 24, 145, 118, 9, 1.4, 0.386 },
    [10412] = { 41, 36, 36, 240, 224, 15, 2, 0.386 },
    [10413] = { 53, 48, 48, 345, 358, 23, 2.6, 0.386 },
    [10414] = { 65, 60, 60, 450, 516, 29, 3.1, 0.386 },
}

local scalarRows, tripleRows = {}, {}
local function installRank(spellId, rank)
    scalarRows[spellId] = {
        school = 3, category = 19, attributes = 327680,
        attributesEx = 512, attributesEx2 = 0, attributesEx3 = 0,
        attributesEx4 = 0, castingTimeIndex = 1, recoveryTime = 0,
        categoryRecoveryTime = 6000, interruptFlags = 0,
        auraInterruptFlags = 0, channelInterruptFlags = 0,
        maxLevel = rank[1], baseLevel = rank[2], spellLevel = rank[3],
        durationIndex = 39, powerType = 0, manaCost = rank[4],
        manaCostPerlevel = 0, manaCostPercentage = 0, rangeIndex = 3,
        speed = 0, startRecoveryCategory = 133, startRecoveryTime = 1500,
        spellFamilyName = 11, spellFamilyFlags = 1048576,
        dmgClass = 1, preventionType = 1,
    }
    tripleRows[spellId] = {
        effect = { 2, 68, 0 }, effectDieSides = { rank[6], 0, 0 },
        effectBaseDice = { 1, 0, 0 }, effectDicePerLevel = { 0, 0, 0 },
        effectRealPointsPerLevel = { rank[7], 0, 0 },
        effectBasePoints = { rank[5], 0, 0 },
        effectBonusCoefficient = { rank[8], 0, 0 },
        effectMechanic = { 0, 26, 0 },
        effectImplicitTargetA = { 6, 6, 0 },
        effectImplicitTargetB = { 0, 0, 0 },
        effectApplyAuraName = { 0, 0, 0 },
        effectAmplitude = { 0, 0, 0 }, effectTriggerSpell = { 0, 0, 0 },
    }
end

for spellId, rank in pairs(ranks) do installRank(spellId, rank) end
scalarRows[90000] = { school = 2, preventionType = 1,
    interruptFlags = 2, channelInterruptFlags = 0 }
scalarRows[90001] = { school = 4, preventionType = 0,
    interruptFlags = 2, channelInterruptFlags = 0 }
scalarRows[90002] = { school = 5, preventionType = 1,
    interruptFlags = 0, channelInterruptFlags = 4 }
tripleRows[777] = { effect = { 6, 0, 0 },
    effectApplyAuraName = { 79, 0, 0 } }

function UnitClass() return "Shaman", "SHAMAN" end
function UnitLevel() return 60 end
function GetSpellRecField(spellId, field, array)
    if array then
        local values = tripleRows[spellId] and tripleRows[spellId][field]
        if not values then return nil end
        return { values[1], values[2], values[3] }
    end
    return scalarRows[spellId] and scalarRows[spellId][field]
end
function GetSpellModifiers(_, operation)
    if operation == 8 then return 2, 10, 1 end
    if operation == 0 then return 3, 20, 1 end
    if operation == 24 then return 4, 25, 1 end
end
function GetSpellPower() return 0, 0, 0, 100, 0, 0, 0 end
function GetSpellDuration() return 2000 end
C_UnitAuras = { GetUnitAuras = function() return {} end }

dofile("Game/Player/ShamanEarthShock.lua")
local Runtime = XelAssist.Game.Player.ShamanEarthShock

local facts, reason, handled = Runtime:InferKnowledge(8046)
check(handled and facts and facts.shamanEarthShock, reason)
check(facts.kind == "damage" and facts.interrupt and facts.binary,
    "Earth Shock inference lost binary damage/interrupt identity")
check(facts.threat == 2 and facts.threatProfileExact == true
    and facts.runtimeUnverified == true,
    "Earth Shock must retain its exact build-5875 two-times threat")
local unrelated, _, unrelatedHandled = Runtime:InferKnowledge(8043)
check(unrelated == nil and unrelatedHandled == false,
    "trainer learn wrapper must not be claimed")

local savedCategory = scalarRows[8046].category
scalarRows[8046].category = 0
Runtime:Invalidate()
local invalid, invalidReason, invalidHandled = Runtime:InferKnowledge(8046)
check(not invalid and invalidHandled and invalidReason,
    "recognized malformed Earth Shock must fail closed")
scalarRows[8046].category = savedCategory
Runtime:Invalidate()
facts = assert((Runtime:InferKnowledge(8046)))

local savedCoefficient = tripleRows[8046].effectBonusCoefficient[1]
tripleRows[8046].effectBonusCoefficient[1] = 0.5
Runtime:Invalidate()
local badCoefficient, coefficientReason, coefficientHandled =
    Runtime:InferKnowledge(8046)
check(not badCoefficient and coefficientHandled and coefficientReason,
    "unsealed Earth Shock coefficient must fail closed")
tripleRows[8046].effectBonusCoefficient[1] = savedCoefficient
Runtime:Invalidate()
facts = assert((Runtime:InferKnowledge(8046)))

local rankSevenFacts = assert((Runtime:InferKnowledge(10414)))
local rankSevenAction = { spellId = 10414,
    facts = Runtime:CaptureFacts({ spellId = 10414 }, rankSevenFacts,
        { actors = { player = { level = 60 } } }) }
close(Runtime:Evidence(rankSevenAction).rawNoncriticalMean, 771.06,
    "rank-seven installed base points")

local action = { spellId = 8046, actor = "player", executor = "playerSpell",
    facts = facts }
action.facts = Runtime:CaptureFacts(action, facts,
    { actors = { player = { level = 60 } } })
local power = Runtime:Evidence(action)
check(power and power.complete, "root power profile missing")
close(power.rawNoncriticalMean, 241.74, "exact server modifier order")
local sealedCoefficient = action.facts.shamanEarthShockEvidence.coefficient
action.facts.shamanEarthShockEvidence.coefficient = 0.5
check(Runtime:Evidence(action) == nil,
    "mutated sealed coefficient must fail closed")
action.facts.shamanEarthShockEvidence.coefficient = sealedCoefficient
local auraAPI = C_UnitAuras.GetUnitAuras
C_UnitAuras.GetUnitAuras = function()
    return { { spellId = 777 } }
end
local blockedPower = Runtime:CaptureFacts(action, facts,
    { actors = { player = { level = 60 } } })
check(Runtime:Evidence(blockedPower) == nil,
    "unmodeled whole-hit damage aura must fail closed")
C_UnitAuras.GetUnitAuras = auraAPI

local normalCast = Runtime:CaptureCast({ casterGuid = "enemy",
    spellId = 90000, channel = false, generation = 7, remaining = 1.2,
    hostileKey = "enemy" })
local blockedCast = Runtime:CaptureCast({ casterGuid = "enemy",
    spellId = 90001, channel = false, generation = 8, remaining = 1.2,
    hostileKey = "enemy" })
local channelCast = Runtime:CaptureCast({ casterGuid = "enemy",
    spellId = 90002, channel = true, generation = 9, remaining = 1.2,
    hostileKey = "enemy" })
check(Runtime:CastEvidence(normalCast).interruptible == true,
    "normal damage-pushback cast should be interruptible")
check(Runtime:CastEvidence(blockedCast).interruptible == false,
    "non-silence-prevention cast should not be interruptible")
check(Runtime:CastEvidence(channelCast).interruptible == true,
    "action-cancel channel should be interruptible")
local forgedCast = Runtime:CaptureCast({ casterGuid = "enemy",
    spellId = 90001, channel = false, generation = 10, remaining = 1.2,
    hostileKey = "enemy" })
forgedCast.shamanEarthShockInterrupt.interruptible = true
check(Runtime:CastEvidence(forgedCast) == nil,
    "forged interrupt predicate must fail closed")
local opaqueGUID = {}
local opaqueCast = Runtime:CaptureCast({ casterGuid = opaqueGUID,
    spellId = 90000, channel = false, generation = 11, remaining = 1.2,
    hostileKey = opaqueGUID })
check(opaqueCast.casterGuid == opaqueGUID and opaqueCast.hostileKey == opaqueGUID,
    "opaque hostile identity must survive root evidence copying")

local saved = { GetSpellRecField, GetSpellModifiers, GetSpellPower,
    GetSpellDuration, C_UnitAuras.GetUnitAuras, UnitLevel, UnitClass }
GetSpellRecField = function() error("DBC read during graph search") end
GetSpellModifiers = function() error("modifier read during graph search") end
GetSpellPower = function() error("power read during graph search") end
GetSpellDuration = function() error("duration read during graph search") end
C_UnitAuras.GetUnitAuras = function() error("aura read during graph search") end
UnitLevel = function() error("level read during graph search") end
UnitClass = function() error("class read during graph search") end

local currentCast = normalCast
XelAssist.Graph.HostileCastState = {
    Find = function(_, state, guid, generation)
        local cast = state.hostileCasts and state.hostileCasts.byCaster[guid]
        if cast and generation ~= nil and cast.generation ~= generation then
            return nil
        end
        return cast
    end,
}
XelAssist.Graph.IncomingConsequences = {
    PreventedValue = function() return 100, "prevents incoming damage" end,
}
local interruptCalls = 0
XelAssist.Graph.HostileCastEvents = {
    Interrupt = function(_, state, candidate)
        interruptCalls = interruptCalls + 1
        local cast = state.hostileCasts.byCaster[candidate.targetGUID]
        cast.probability = (cast.probability or 1)
            * (1 - candidate.effectDelivery)
        return true
    end,
}

dofile("Graph/ShamanEarthShock.lua")
local Graph = XelAssist.Graph.ShamanEarthShock
local hostile = { key = "enemy", guid = "enemy", relation = "hostile" }
local state = { time = 5, targetGUID = "enemy",
    hostiles = { order = { "enemy" }, byKey = { enemy = hostile } },
    hostileCasts = { order = { "enemy" }, byCaster = { enemy = currentCast } } }
local descriptor = { key = "enemy", guid = "enemy", relation = "hostile",
    record = hostile }

local blocker, claimed = Graph:Blocker(action, state, descriptor, { cast = 0 }, 5)
check(claimed and blocker == nil, blocker)
local context = { action = action, state = state, descriptor = descriptor,
    tooltip = { cast = 0 }, actionStart = 5, cast = 0, value = 10,
    effectDelivery = 0.8 }
local prepared, prepareReason, prepareHandled = Graph:Prepare(context)
check(prepared and prepareHandled, prepareReason)
close(context.power, 241.74, "sealed graph raw power")
local scored, scoreReason, scoreHandled = Graph:Score(context)
check(scored and scoreHandled, scoreReason)
close(context.value, 90, "binary interrupt consequence value")

local candidate = { action = action, targetGUID = "enemy",
    effectDelivery = 0.8,
    shamanEarthShockTransition = Graph:Transition(context) }
local applied, applyHandled = Graph:Apply(state, candidate)
check(applied and applyHandled and interruptCalls == 1,
    "exact Earth Shock interrupt was not applied")
close(currentCast.probability, 0.2, "resist branch keeps hostile cast")
local lock
for _, value in pairs(hostile.shamanEarthShockSchoolLockouts or {}) do
    lock = value
end
check(lock and lock.school == 2 and lock.remaining == 2,
    "interrupted school lockout missing")
local otherHostile = { key = "other", guid = "other", relation = "hostile" }
state.hostiles.byKey.other = otherHostile
table.insert(state.hostiles.order, "other")
check(otherHostile.shamanEarthShockSchoolLockouts == nil,
    "school lockout leaked onto a different hostile")
close(lock.applicationProbability, 0.8,
    "damage and interrupt must share one delivery probability")
Graph:Advance(state, 0.5)
close(lock.remaining, 1.5, "school lockout did not age")
Graph:Advance(state, 1.6)
check(next(hostile.shamanEarthShockSchoolLockouts) == nil,
    "expired school lockout retained")
check(otherHostile.shamanEarthShockSchoolLockouts == nil,
    "lockout expiry mutated a different hostile")

state.hostileCasts.byCaster.enemy = blockedCast
local noInterrupt = { action = action, state = state, descriptor = descriptor,
    tooltip = { cast = 0 }, actionStart = 5, cast = 0, value = 10,
    effectDelivery = 1 }
check(Graph:Prepare(noInterrupt))
check(Graph:Score(noInterrupt))
check(noInterrupt.value == 10, "noninterruptible cast gained proxy utility")
local noCandidate = { action = action, targetGUID = "enemy", effectDelivery = 1,
    shamanEarthShockTransition = Graph:Transition(noInterrupt) }
check(Graph:Apply(state, noCandidate))
check(interruptCalls == 1, "noninterruptible cast was interrupted")

local wrongTarget = { action = action, targetGUID = "other-enemy",
    effectDelivery = 1,
    shamanEarthShockTransition = Graph:Transition(noInterrupt) }
local mismatchApplied, mismatchHandled = Graph:Apply(state, wrongTarget)
check(not mismatchApplied and mismatchHandled,
    "candidate/transition target mismatch must fail closed")

state.hostileCasts.byCaster.enemy = { casterGuid = "enemy", spellId = 90000,
    channel = false, generation = 10, remaining = 1, hostileKey = "enemy" }
local missing, missingClaimed = Graph:Blocker(
    action, state, descriptor, { cast = 0 }, 5)
check(missingClaimed and string.find(missing, "predicate"),
    "unsealed active cast did not fail closed")

state.hostileCasts.byCaster.enemy = normalCast
normalCast.remaining = 1
local late = { action = action, state = state, descriptor = descriptor,
    tooltip = { cast = 0 }, actionStart = 6.2, cast = 0, value = 10,
    effectDelivery = 1 }
check(Graph:Prepare(late))
check(late.shamanEarthShockTransition.castResolvesFirst,
    "absolute graph time was not converted to delay")
check(Graph:Score(late) and late.value == 10,
    "late damage action received interrupt proxy value")

local opaqueHostile = { key = opaqueGUID, guid = opaqueGUID,
    relation = "hostile" }
local opaqueState = { time = 5, targetGUID = opaqueGUID,
    hostiles = { order = { opaqueGUID },
        byKey = { [opaqueGUID] = opaqueHostile } },
    hostileCasts = { order = { opaqueGUID },
        byCaster = { [opaqueGUID] = opaqueCast } } }
local opaqueContext = { action = action, state = opaqueState,
    descriptor = { key = opaqueGUID, guid = opaqueGUID,
        relation = "hostile", record = opaqueHostile },
    tooltip = { cast = 0 }, actionStart = 5, cast = 0, value = 0,
    effectDelivery = 1 }
check(Graph:Prepare(opaqueContext),
    "opaque hostile identity did not prepare")
check(Graph:Transition(opaqueContext).targetGUID == opaqueGUID,
    "opaque hostile identity was cloned inside graph evidence")

GetSpellRecField, GetSpellModifiers, GetSpellPower, GetSpellDuration,
    C_UnitAuras.GetUnitAuras, UnitLevel, UnitClass = saved[1], saved[2],
    saved[3], saved[4], saved[5], saved[6], saved[7]

print("shaman earth shock tests passed")
