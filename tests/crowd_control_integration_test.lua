XelAssistGraphScenarioSetupOnly = true
local Fixture = dofile("tests/graph_scenarios.lua")
XelAssistGraphScenarioSetupOnly = nil

XelAssistCharDB.toggles.petControl = true
XelAssistCharDB.graphDepth = 1

local function hostile(state)
    return { key = "enemy", unit = "target", guid = state.targetGUID,
        selected = true, dead = false, health = 1000, healthMax = 1000,
        healthExact = true, encounter = { creatureTypeId = 7 },
        targetAuras = {}, projectedAuras = {},
        threat = { available = true, playerHasAggro = false,
            petHasAggro = false, playerDelta = 0,
            playerDeltaExact = true, petDelta = 0 } }
end

local function state()
    local value = Fixture.State("smart")
    local ally = value.friendlies.byKey[value.friendlies.byUnit.party1]
    value.inCombat, value.targetCasting = true, true
    value.hostiles = { order = { "enemy" }, selectedKey = "enemy",
        capped = false, byKey = { enemy = hostile(value) } }
    value.hostileCasts = { order = { value.targetGUID }, byCaster = {
        [value.targetGUID] = { casterGuid = value.targetGUID,
            hostileKey = "enemy", targetGuid = ally.guid,
            targetKnown = true, active = true, generation = 1,
            remaining = 2.5, probability = 1,
            consequence = { kind = "damage", direct = true,
                singleTarget = true, targetMode = "target",
                targetGuid = ally.guid, amount = 200, exact = true,
                estimated = false, magnitudeEstimated = false } },
    } }
    XelAssist.Graph.State:SyncSelectedHostile(value)
    return value
end

local evidence = { valid = true, controlType = "polymorph",
    targetCreatureMask = 0, breaksOnAnyDamage = true,
    breaksOnDirectDamage = false, damageBreakSpecified = true,
    source = "sealed integration fixture" }

local function control(extra)
    extra = extra or {}
    local action = Fixture.Action("Localized exact control", 1,
        "crowdControl", 0, 80, { cast = 1.5,
            testDuration = extra.duration == false and nil or 20,
            channel = extra.channel })
    action.facts.crowdControlEvidence = evidence
    action.mock.crowdControlEvidence = evidence
    if extra.duration == false then action.mock.duration = nil end
    return action
end

local function evaluate(value, action)
    Fixture:Use(value, { action })
    local descriptor = XelAssist.Graph.Targets:Targets(action, value)[1]
    return XelAssist.Graph.Scoring:Evaluate(action, value, descriptor)
end

local modeled = state()
local action = control()
local candidate, blocker = evaluate(modeled, action)
assert(candidate and blocker == nil and candidate.value > 0
    and candidate.reason == "prevents incoming damage",
    "exact control should derive value from the represented hostile consequence")
local projected = XelAssist.Graph.Transitions:Advance(modeled, candidate)
assert(not projected.hostileCasts.byCaster[modeled.targetGUID]
    and projected.hostiles.byKey.enemy.projectedAuras[action.name],
    "the control transition must suppress the exact cast and install its aura")

Fixture:Use(modeled, { action })
local plan = XelAssist.Graph:Evaluate("smart", true)
assert(plan and plan.action and plan.action.name == action.name,
    "represented exact control must survive through plan publication")

local missingDuration = control({ duration = false })
candidate, blocker = evaluate(state(), missingDuration)
assert(not candidate and blocker == "crowd-control duration unknown",
    "duration-unknown control must not become a candidate")

local maintained = control({ channel = true })
candidate, blocker = evaluate(state(), maintained)
assert(not candidate and blocker == "channeled control projection unavailable",
    "maintained control must not become a plan without channel lifecycle support")
local tooltipMaintained = control()
tooltipMaintained.mock.channel = true
candidate, blocker = evaluate(state(), tooltipMaintained)
assert(not candidate and blocker == "channeled control projection unavailable",
    "sealed tooltip channel evidence must also fail closed defensively")

local legacyTyped = Fixture.Action("Legacy typed channel control", 1,
    "crowdControl", 0, 80, { cast = 0, testDuration = 20,
        channel = true })
candidate, blocker = evaluate(state(), legacyTyped)
assert(not candidate
    and blocker == "exact crowd-control lifecycle unavailable",
    "typed pet control without exact lifecycle evidence must not bypass the graph")

local unrelated = state()
unrelated.hostileCasts = { order = {}, byCaster = {} }
XelAssist.Graph.State:SyncSelectedHostile(unrelated)
candidate, blocker = evaluate(unrelated, control())
assert(not candidate and blocker == "control consequence unavailable",
    "control without a modeled downstream consequence must fail closed")

local tooLate = state()
tooLate.hostileCasts.byCaster[tooLate.targetGUID].remaining = 1
XelAssist.Graph.State:SyncSelectedHostile(tooLate)
candidate, blocker = evaluate(tooLate, control())
assert(not candidate and blocker == "control arrives after modeled consequence",
    "control landing after the cast must not claim prevented value")

print("ok: exact crowd control crosses legality, scoring, transition and plan")
