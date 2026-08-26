-- Every player ranged-attack spell consumes the same carried ammunition as
-- Auto Shot. A chosen special shot must update both inventory and Auto Shot's
-- causal counter before another launch or graph edge can spend the last round.
XelAssistGraphScenarioSetupOnly = true
local Fixture = dofile("tests/graph_scenarios.lua")
XelAssistGraphScenarioSetupOnly = nil
dofile("Game/Inventory.lua")

local state = Fixture.State("smart")
state.resource, state.resourceMax, state.resourceType = 100, 100, 0
state.inventory = {
    ammo = { known = true, count = 2 },
    mainHand = { broken = false }, offHand = { broken = false },
    ranged = { broken = false }, itemCounts = {}, reagentCounts = {},
}
state.autoShot = {
    supported = true, active = false, knownInactive = true,
    ammoKnown = true, ammoCount = 2, inFlight = {}, unknownInFlight = {},
}

local shot = Fixture.Action("Arcane Shot", 1, "damage", 80, 20, {
    ranged = true, weaponRanged = true, ammunition = true,
    testMinRange = 8, testMaxRange = 35,
})
Fixture:Use(state, { shot })
local descriptor = XelAssist.Graph.Targets:Targets(shot, state)[1]
local candidate, blocker = XelAssist.Graph.Scoring:Evaluate(
    shot, state, descriptor)
assert(candidate, "a carried round must legalize the first special shot: "
    .. tostring(blocker))

local projected = XelAssist.Graph.Transitions:Advance(state, candidate)
assert(projected.inventory.ammo.count == 1,
    "a chosen Hunter ranged attack must consume exactly one inventory ammunition")
assert(projected.autoShot.ammoCount == 1,
    "a chosen Hunter ranged attack must share its ammunition state with Auto Shot")

local nextDescriptor = XelAssist.Graph.Targets:Targets(shot, projected)[1]
local nextCandidate, nextBlocker = XelAssist.Graph.Scoring:Evaluate(
    shot, projected, nextDescriptor)
assert(nextCandidate, "the second and final carried round must remain usable: "
    .. tostring(nextBlocker))
local exhausted = XelAssist.Graph.Transitions:Advance(projected, nextCandidate)
assert(exhausted.inventory.ammo.count == 0
    and exhausted.autoShot.ammoCount == 0,
    "the final special shot must atomically exhaust both ammunition counters")

local blockedDescriptor = XelAssist.Graph.Targets:Targets(shot, exhausted)[1]
local blockedCandidate, blockedReason = XelAssist.Graph.Scoring:Evaluate(
    shot, exhausted, blockedDescriptor)
assert(blockedCandidate == nil and blockedReason == "ammunition",
    "zero carried rounds must block every later special ranged attack")

local function activeAutoState(rounds)
    local value = Fixture.State("smart")
    value.resource, value.resourceMax, value.resourceType = 100, 100, 0
    value.playerGcdReadyAt, value.actorReadyAt.player = 1, 1
    value.targetDistance, value.targetLineOfSight = 20, true
    value.inventory = {
        ammo = { known = true, count = rounds },
        mainHand = { broken = false }, offHand = { broken = false },
        ranged = { broken = false }, itemCounts = {}, reagentCounts = {},
    }
    value.autoShot = { supported = true, active = true,
        activeSource = "action bar repeat", confidence = "live", spellId = 75,
        rangeChecked = true, rangeVerdict = true,
        rangeIdentityVerified = true, rangeTargetGuid = value.targetGUID,
        rangeSpellId = 75, projectileDistance = 20,
        projectileDistanceKind = "center", projectileSpeed = 40,
        targetGuid = value.targetGUID, currentTargetGuid = value.targetGUID,
        nextLaunchIn = 0.1, rangedSpeed = 2, projectable = true,
        ammoKnown = true, ammoCount = rounds, shotDamage = 50,
        inFlight = {}, unknownInFlight = {} }
    return value
end

local aimed = Fixture.Action("Aimed Shot", 1, "damage", 200, 20, {
    ranged = true, weaponRanged = true, ammunition = true, cast = 1,
    testMinRange = 8, testMaxRange = 35,
})
local twoRounds = activeAutoState(2)
Fixture:Use(twoRounds, { aimed })
local aimedDescriptor = XelAssist.Graph.Targets:Targets(aimed, twoRounds)[1]
local aimedCandidate, aimedBlocker = XelAssist.Graph.Scoring:Evaluate(
    aimed, twoRounds, aimedDescriptor)
assert(aimedCandidate,
    "one round after the earlier Auto Shot must still fund Aimed Shot: "
        .. tostring(aimedBlocker))

local lastRound = activeAutoState(1)
Fixture:Use(lastRound, { aimed })
aimedDescriptor = XelAssist.Graph.Targets:Targets(aimed, lastRound)[1]
local phantom, phantomReason = XelAssist.Graph.Scoring:Evaluate(
    aimed, lastRound, aimedDescriptor)
assert(phantom == nil and phantomReason == "ammunition before application",
    "an earlier ambient launch must block a special shot that would have no round")

local prevented = XelAssist.Graph.Transitions:Advance(lastRound, aimedCandidate)
assert(prevented.chosenActionPrevented
    and prevented.inventory.ammo.count == 0
    and prevented.autoShot.ammoCount == 0
    and prevented.resource == 100 and prevented.targetHealth == 950,
    "the transition guard must spend only the ambient round, never phantom chosen damage")

print("ok: Hunter special shots share causal ammunition with Auto Shot")
