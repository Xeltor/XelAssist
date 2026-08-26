XelAssistGraphScenarioSetupOnly = true
local Fixture = dofile("tests/graph_scenarios.lua")
XelAssistGraphScenarioSetupOnly = nil

local function hostile(guid)
    return { key = "enemy", unit = "target", guid = guid,
        selected = true, dead = false, health = 1000, healthMax = 1000,
        healthExact = true, targetAuras = {}, projectedAuras = {},
        threat = { available = true, playerHasAggro = false,
            petHasAggro = false, playerDelta = 0,
            playerDeltaExact = true, petDelta = 0 } }
end

local function state()
    local value = Fixture.State("smart")
    local ally = value.friendlies.byKey[value.friendlies.byUnit.party1]
    ally.health, ally.healthMax = 100, 1000
    ally.exact, ally.healthExact = true, true
    ally.absorbs = { available = true }
    value.healHealth, value.healMax = ally.health, ally.healthMax
    value.resource, value.resourceMax = 300, 1000
    value.playerResourceExact = true
    value.inCombat = true
    value.hostiles = { order = { "enemy" }, selectedKey = "enemy",
        capped = false, byKey = { enemy = hostile(value.targetGUID) } }
    value.hostileCasts = { order = { value.targetGUID }, byCaster = {
        [value.targetGUID] = { casterGuid = value.targetGUID,
            hostileKey = "enemy", targetGuid = ally.guid,
            targetKnown = true, active = true, generation = 1,
            remaining = 2, probability = 1,
            consequence = { kind = "damage", direct = true,
                singleTarget = true, targetMode = "target",
                targetGuid = ally.guid, amount = 200, exact = true,
                estimated = false, magnitudeEstimated = false } },
    } }
    XelAssist.Graph.State:SyncSelectedHostile(value)
    return value, ally.key
end

local function heal()
    local action = Fixture.Action("Localized direct heal", 1,
        "heal", 300, 100, { cast = 1.5 })
    action.mock.low, action.mock.high = 250, 350
    action.mock.gcd = 1.5
    return action
end

local function score(value, action, allyKey)
    Fixture:Use(value, { action })
    local descriptors = XelAssist.Graph.Targets:Targets(action, value)
    local descriptor, i
    for i = 1, table.getn(descriptors) do
        if descriptors[i].key == allyKey then descriptor = descriptors[i] end
    end
    assert(descriptor, "the retained ally must remain a legal heal edge")
    return XelAssist.Graph.Scoring:Evaluate(action, value, descriptor)
end

local graphState, allyKey = state()
local action = heal()
local candidate, blocker = score(graphState, action, allyKey)
assert(candidate and blocker == nil and candidate.healingTriage
    and candidate.healingTriage.frozen
    and candidate.healingTriage.savesRecipient
    and candidate.effectivePower == 300
    and candidate.reason == "prevents proven recipient death",
    "exact incoming evidence must enhance ordinary direct-heal scoring")

local uncertain, uncertainKey = state()
uncertain.hostileCasts.byCaster[uncertain.targetGUID]
    .consequence.estimated = true
local fallback = score(uncertain, action, uncertainKey)
assert(fallback and fallback.healingTriage == nil
    and fallback.reason ~= "prevents proven recipient death",
    "unproven triage must retain the generic healing edge without claiming a save")

local replaced = XelAssist.Graph.State:Copy(graphState)
local replacement = replaced.friendlies.byKey[allyKey]
replacement.guid, replacement.health = "replacement-guid", 100
local projected = XelAssist.Graph.Transitions:Advance(replaced, candidate)
assert(projected.friendlies.byKey[allyKey].health == 100,
    "a frozen heal plan must not apply to a replacement friendly identity")

print("ok: exact healing triage enhances scoring and revalidates at landing")
