XelAssist = { Graph = {} }
table.getn = table.getn or function(value)
    local count = 0
    while value[count + 1] ~= nil do count = count + 1 end
    return count
end

local function copy(value, seen)
    if type(value) ~= "table" then return value end
    seen = seen or {}
    if seen[value] then return seen[value] end
    local out, key, entry = {}, nil, nil
    seen[value] = out
    for key, entry in pairs(value) do out[copy(key, seen)] = copy(entry, seen) end
    return out
end

XelAssist.Graph.State = {}
function XelAssist.Graph.State:FriendlyByKey(state, key)
    return state.friendlies and state.friendlies.byKey
        and state.friendlies.byKey[key] or nil
end
function XelAssist.Graph.State:Copy(state) return copy(state) end
function XelAssist.Graph.State:RefreshHostileRecord() end

XelAssist.Graph.RootObservation = {}
function XelAssist.Graph.RootObservation:ActionKey(action)
    return "action:" .. tostring(action.spellId)
end

-- Any accidental client observation by this adapter is a test failure.
GetTime = function() error("live clock read") end
UnitHealth = function() error("live health read") end
UnitExists = function() error("live identity read") end

dofile("Graph/IncomingAbsorbs.lua")
dofile("Graph/IncomingConsequences.lua")
dofile("Graph/HealingTriage.lua")
dofile("Graph/HealingTriageEvidence.lua")
local Evidence = XelAssist.Graph.HealingTriageEvidence

local function damageCast(caster, generation, remaining, target, amount)
    return { casterGuid = caster, targetGuid = target, targetKnown = true,
        spellId = 1000 + generation, active = true, generation = generation,
        remaining = remaining, probability = 1, hostileKey = "h:" .. caster,
        consequence = { kind = "damage", direct = true,
            singleTarget = true, targetMode = "target", targetGuid = target,
            amount = amount, exact = true, estimated = false,
            magnitudeEstimated = false } }
end

local function state()
    local ally = { key = "ally", guid = "ally-guid", unit = "party1",
        health = 500, healthMax = 1000, exact = true, dead = false,
        absorbs = { available = true,
            Shield = { amount = 100, remaining = 10,
                applicationProbability = 1 } } }
    local first = damageCast("caster-a", 1, 1, ally.guid, 400)
    local second = damageCast("caster-b", 2, 2, ally.guid, 300)
    local other = damageCast("caster-c", 3, 1.2, "other-guid", 900)
    other.consequence.exact, other.consequence.estimated = false, true
    other.consequence.magnitudeEstimated = true
    return { time = 0, resource = 300, resourceMax = 1000,
        playerResourceExact = true, friendlies = {
            order = { "ally" }, byKey = { ally = ally }, primaryKey = "ally" },
        actors = {}, hostiles = {
            order = { "h:caster-a", "h:caster-b", "h:caster-c" },
            byKey = {
                ["h:caster-a"] = { guid = "caster-a", health = 1000,
                    healthExact = true },
                ["h:caster-b"] = { guid = "caster-b", health = 1000,
                    healthExact = true },
                ["h:caster-c"] = { guid = "caster-c", health = 1000,
                    healthExact = true },
            } },
        hostileCasts = { order = { "caster-b", "caster-c", "caster-a" },
            byCaster = { ["caster-a"] = first, ["caster-b"] = second,
                ["caster-c"] = other } } }
end

local function context(graphState, low, cast)
    cast = cast or 1.5
    local record = graphState.friendlies.byKey.ally
    local facts = { kind = "heal" }
    local action = { spellId = 2061, actor = "player",
        executor = "playerSpell", facts = facts }
    return { action = action, facts = facts, kind = "heal",
        tooltip = { low = low, high = 400, average = 300,
            cast = cast, gcd = 1.5 },
        state = graphState, descriptor = { key = record.key,
            guid = record.guid, relation = "party", record = record },
        friendly = record, power = 300, expectedPower = 300,
        estimated = false, cost = 100, costKnown = true,
        cast = cast, gcd = 1.5, wait = 0,
        actionStart = graphState.time }
end

local graphState = state()
local plan, reason = Evidence:Score(context(graphState, 200))
assert(plan and reason == nil and plan.incomingEvents == 2
    and plan.landingHealth == 200 and plan.effectiveHealing == 300
    and plan.guaranteedHealing == 200 and plan.projectedHealth == 200
    and plan.guaranteedProjectedHealth == 100 and plan.savesRecipient,
    "the adapter must sort recipient-local casts and use post-absorb damage")
assert(graphState.friendlies.byKey.ally.health == 500
    and graphState.friendlies.byKey.ally.absorbs.Shield.amount == 100,
    "evidence simulation must not mutate the searched graph state")

local lowRoll = Evidence:Score(context(state(), 50))
assert(lowRoll and lowRoll.effectiveHealing == 300
    and lowRoll.efficiency == 3 and lowRoll.healingThreat == 150
    and lowRoll.guaranteedHealing == 50 and not lowRoll.savesRecipient
    and lowRoll.deathSaveUnproven,
    "tooltip average may not prove survival when its exact minimum cannot")
local unknownMinimum = Evidence:Score(context(state(), nil))
assert(unknownMinimum and unknownMinimum.guaranteedHealingKnown == false
    and not unknownMinimum.savesRecipient
    and unknownMinimum.deathSaveUnproven,
    "an unknown minimum must withhold only death-save credit")
local fixedContext = context(state(), nil)
fixedContext.powerEvidence = { exact = true, complete = true }
local fixed = Evidence:Score(fixedContext)
assert(fixed and fixed.guaranteedHealing == 300 and fixed.savesRecipient,
    "an exact fixed amount may prove the same survival as an exact minimum")
local expiringState = state()
expiringState.friendlies.byKey.ally.absorbs.Shield.remaining = 0.5
local expiring = Evidence:Score(context(expiringState, 200))
assert(expiring and expiring.landingHealth == 100
    and expiring.guaranteedProjectedHealth == 0
    and not expiring.savesRecipient,
    "an absorb that expires before impact must not reduce incoming damage")
local farUnknownState = state()
local far = farUnknownState.hostileCasts.byCaster["caster-a"]
far.remaining, far.targetGuid, far.targetKnown, far.consequence = 10, nil, false, nil
local farPlan = Evidence:Score(context(farUnknownState, 200))
assert(farPlan,
    "unresolved casts beyond the scored stability window must not block healing")

local immediateState = state()
immediateState.hostileCasts.order = { "caster-a" }
immediateState.hostileCasts.byCaster = {
    ["caster-a"] = damageCast("caster-a", 1, 0, "ally-guid", 600) }
immediateState.hostiles.order = { "h:caster-a" }
immediateState.friendlies.byKey.ally.health = 400
local immediate, immediateReason = Evidence:Score(
    context(immediateState, 300, 0))
assert(immediate == nil and immediateReason == "recipient dies before heal lands",
    "a pending zero-offset cast must resolve before an instant heal")

local function rejected(mutator, expected)
    local candidateState = state()
    local candidateContext = context(candidateState, 200)
    mutator(candidateState, candidateContext)
    local result, blocker = Evidence:Score(candidateContext)
    assert(result == nil and blocker == expected,
        expected .. ": got " .. tostring(blocker))
end

rejected(function(candidateState)
    candidateState.hostileCasts.byCaster["caster-a"].probability = 0.5
end, "incoming damage evidence unavailable")
rejected(function(candidateState)
    local facts = candidateState.hostileCasts.byCaster["caster-a"].consequence
    facts.exact, facts.estimated = false, true
end, "incoming damage evidence unavailable")
rejected(function(candidateState)
    candidateState.friendlies.byKey.ally.absorbs.available = false
end, "incoming damage projection unavailable")
rejected(function(candidateState)
    candidateState.friendlies.byKey.ally.absorbs.Shield.remaining = nil
end, "incoming absorb timing unavailable")
rejected(function(candidateState)
    candidateState.friendlies.byKey.ally.absorbs.Shield.applicationProbability = 0.5
end, "incoming damage projection unavailable")
rejected(function(candidateState)
    local cast = candidateState.hostileCasts.byCaster["caster-a"]
    cast.targetGuid, cast.targetKnown, cast.consequence = nil, false, nil
end, "incoming cast recipient evidence unavailable")
rejected(function(candidateState)
    candidateState.hostileCasts.byCaster["caster-b"].generation = 1
end, "incoming cast snapshot invalid")
rejected(function(candidateState)
    candidateState.hostileCasts.order[2] = nil
end, "incoming cast snapshot unavailable")
rejected(function(candidateState)
    candidateState.hostileCasts = nil
end, "incoming cast snapshot unavailable")
rejected(function(candidateState, candidateContext)
    candidateContext.tooltip.gcd = nil
end, "healing timing evidence unavailable")
rejected(function(candidateState, candidateContext)
    candidateContext.estimated = true
end, "heal evidence unavailable")
rejected(function(candidateState, candidateContext)
    candidateContext.costKnown = false
end, "heal evidence unavailable")
rejected(function(candidateState)
    candidateState.playerResourceExact = false
end, "healing resource evidence unavailable")
rejected(function(candidateState)
    candidateState.friendlies.byKey.ally.exact = false
end, "healing recipient evidence unavailable")
rejected(function(candidateState, candidateContext)
    candidateContext.descriptor.guid = "replacement-guid"
end, "healing recipient evidence unavailable")
rejected(function(candidateState, candidateContext)
    candidateContext.tooltip.low = 400
end, "heal range evidence invalid")

print("ok: healing triage evidence derives exact frozen hostile-cast events")
