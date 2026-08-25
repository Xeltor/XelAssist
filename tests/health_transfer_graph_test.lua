XelAssistGraphScenarioSetupOnly = true
local Fixture = dofile("tests/graph_scenarios.lua")
XelAssistGraphScenarioSetupOnly = nil

GetTime = function() return 100 end
debugprofilestop = function() return 0 end
GetSpellCooldown = function() return 0, 0, 1 end
GetPetActionCooldown = function() return 0, 0, 1 end
GetPetActionsUsable = function() return true end
IsSpellUsable = function() return 1, 0 end

local DATA = { initialHealthCost = 3, periodicHealthCost = 6,
    healPerTick = 12, interval = 1, ticks = 10, duration = 10,
    totalHealing = 120, totalHealthCost = 63, exact = true,
    source = "installed-client Spell.dbc health funnel" }

local function funnelAction()
    local action = Fixture.Action("Health Funnel", 1, "petHeal", 12, 0, {
        pet = true, fixedTarget = "pet", channel = true,
        channelTicks = 10, healthFundedChannel = true,
        movementInterrupts = true, actionInterrupts = true,
        healingThreatActor = "player", testDuration = 10 })
    action.actor, action.executor, action.spellId = "player", "playerSpell", 755
    action.mock.healthTransfer = DATA
    action.mock.healthTransferExact = true
    action.mock.average = 12
    return action
end

local function funnelState(health, petHealth)
    local state = Fixture.State("smart")
    local player = state.friendlies.byKey[state.friendlies.byUnit.player]
    player.health, player.healthMax, player.exact = health, 1000, true
    state.health, state.healthMax = health, 1000
    state.resource, state.resourceMax, state.resourceType = 77, 100, 0
    state.actors.player.guid = "player-guid"
    state.actors.player.health, state.actors.player.healthMax = health, 1000
    state.actors.player.healthExact = true
    state.actors.player.resource, state.actors.player.resourceMax = 77, 100
    local pet = { id = "pet", unit = "pet", actorType = "controlled",
        guid = "pet-guid", health = petHealth, healthMax = 100,
        healthExact = true, resource = 80, resourceMax = 100,
        dead = false, targetExists = false, targetsCurrent = false,
        hasAggro = false, autocasts = {} }
    local friendly = { key = "g:pet-guid", unit = "pet", guid = "pet-guid",
        relation = "pet", source = "controlled", health = petHealth,
        healthMax = 100, exact = true, distance = 0,
        distanceKind = "self", lineOfSight = true, priority = 1,
        targetedByCurrentEnemy = false, auras = {}, absorbs = {} }
    friendly.targetRef = { unit = "pet", guid = "pet-guid",
        relation = "pet", source = "controlled", priority = 1 }
    state.actors.pet, state.pet = pet, true
    state.friendlies.byKey[friendly.key] = friendly
    state.friendlies.byUnit.pet = friendly.key
    table.insert(state.friendlies.order, 1, friendly.key)
    state.friendlies.total = state.friendlies.total + 1
    return state
end

local function score(action, state)
    Fixture:Use(state, { action })
    local targets = XelAssist.Graph.Targets:Targets(action, state)
    return XelAssist.Graph.Scoring:Evaluate(action, state, targets[1])
end

local action = funnelAction()
local state = funnelState(9, 88)
local candidate, blocker = score(action, state)
assert(candidate == nil and blocker == "health",
    "start admission needs health strictly beyond initial cost plus one upkeep")

state = funnelState(10, 88)
candidate, blocker = score(action, state)
assert(candidate and not blocker and candidate.healthTransfer
    and candidate.healthTransfer.plannedTicks == 1,
    "one useful, strictly payable tick must admit the channel")

state = funnelState(10, 88)
state.actorReadyAt.player = 1
state.hostileCasts = { order = { "enemy-guid" }, byCaster = {
    ["enemy-guid"] = { casterGuid = "enemy-guid", generation = 1,
        remaining = 1.5, probability = 1, targetGuid = "player-guid",
        consequence = { kind = "damage", amount = 1,
            targetMode = "target", targetGuid = "player-guid" } },
} }
candidate, blocker = score(action, state)
assert(candidate == nil and blocker == "health",
    "a delayed start made unsafe by incoming damage must fail closed")

state = funnelState(1000, 87)
candidate = score(action, state)
assert(candidate and candidate.cost == 0 and candidate.costKnown
    and candidate.healthTransfer.plannedTicks == 2
    and candidate.cast == 2 and candidate.power == 24
    and candidate.effectivePower == 13,
    "scoring must price only the useful tick horizon and no mana")
local out = XelAssist.Graph.Transitions:Advance(state, candidate)
assert(out.health == 985 and out.actors.player.health == 985
    and out.actors.pet.health == 100
    and out.friendlies.byKey["g:pet-guid"].health == 100
    and out.resource == 77 and out.actors.player.resource == 77
    and candidate.healthTransferAppliedTicks == 2
    and candidate.healthTransferHealthSpent == 15
    and out.playerChanneling and out.castRemaining == 8
    and out.channelCommitment and out.channelCommitment.healthTransferData == DATA,
    "start plus two paid ticks must causally move player health to pet health")

state = funnelState(1000, 87)
state.playerCasting, state.playerChanneling = true, true
state.playerCastName, state.playerCastSpellId = "Old Channel", 999
state.castRemaining, state.actorReadyAt.player = 5, 5
candidate = score(action, state)
assert(candidate and candidate.clipsChannel,
    "starting Health Funnel must be able to clip a prior player channel")
out = XelAssist.Graph.Transitions:Advance(state, candidate)
assert(out.playerChanneling and out.playerCastSpellId == 755
    and out.castRemaining == 8,
    "the old-channel clip marker must not clear the replacement Health Funnel")

state = funnelState(16, 76)
state.hostileCasts = { order = { "enemy-guid" }, byCaster = {
    ["enemy-guid"] = { casterGuid = "enemy-guid", generation = 1,
        remaining = 2, probability = 1, targetGuid = "player-guid",
        consequence = { kind = "damage", amount = 1,
            targetMode = "target", targetGuid = "player-guid" } },
} }
candidate = score(action, state)
assert(candidate and candidate.healthTransfer.plannedTicks == 1,
    "scoring must not include a tick made unsafe by same-time incoming damage")

-- Force a stale two-tick candidate to prove the transition remains safe when
-- combat changes after scoring: priority-15 damage resolves before upkeep 16.
candidate.healthTransfer.plannedTicks = 2
candidate.healthTransfer.plannedDuration = 2
candidate.healthTransfer.rawHealing = 24
candidate.healthTransfer.effectiveHealing = 24
candidate.cast, candidate.occupancy = 2, 2
candidate.downtime, candidate.advanceDowntime = 2, 2
candidate.power, candidate.rawPower, candidate.effectivePower = 24, 24, 24
out = XelAssist.Graph.Transitions:Advance(state, candidate)
assert(out.health == 6 and out.actors.pet.health == 88
    and candidate.healthTransferAppliedTicks == 1
    and candidate.healthTransferInterrupted
    and not out.playerChanneling and out.castRemaining == 0
    and out.resource == 77,
    "an incoming event must stop unaffordable upkeep before that tick heals")

state = funnelState(100, 64)
state.friendlies.byKey["g:pet-guid"] = nil
state.friendlies.byUnit.pet = nil
table.remove(state.friendlies.order, 1)
state.friendlies.total = state.friendlies.total - 1
state.playerCasting, state.playerChanneling = true, true
state.playerCastName, state.playerCastSpellId = "Health Funnel", 755
state.playerCastTargetGUID, state.castRemaining = nil, 2.4
state.actorReadyAt.player = 2.4
XelAssist.Graph.ChannelCommitment:Prepare(state, { action })
candidate = XelAssist.Graph.ChannelCommitment:Candidate(state)
assert(candidate and candidate.healthTransfer
    and candidate.healthTransfer.continuation
    and candidate.healthTransfer.plannedTicks == 3
    and math.abs(candidate.healthTransfer.nextTickIn - 0.4) < 0.0001
    and math.abs(candidate.cast - 2.4) < 0.0001
    and candidate.target == "pet" and candidate.targetGUID == "pet-guid",
    "a capped live implicit-pet channel must retain its exact actor and cadence")
out = XelAssist.Graph.Transitions:Advance(state, candidate)
assert(out.health == 82 and out.actors.pet.health == 100
    and out.resource == 77 and not out.playerChanneling
    and out.castRemaining == 0 and out.channelCommitment == nil
    and math.abs(out.actorReadyAt.player - out.time) < 0.0001,
    "continuation must pay only upkeep, heal tickwise, and release the actor")

state = funnelState(100, 70)
state.playerCasting, state.playerChanneling = true, true
state.playerCastName, state.playerCastSpellId = "Health Funnel", 755
state.playerCastTargetGUID, state.castRemaining = "pet-guid", 8
state.actorReadyAt.player = 8
local movement = XelAssist.Graph.MovementSetup:Candidate(
    state, { range = 1 })
assert(movement, "movement fixture must produce a graph instruction")
out = XelAssist.Graph.Transitions:Advance(state, movement)
assert(not out.playerChanneling and out.castRemaining == 0
    and out.actorReadyAt.player <= out.time,
    "causal movement must interrupt the active Health Funnel channel")

print("ok: causal graph-native Health Funnel start and continuation")
