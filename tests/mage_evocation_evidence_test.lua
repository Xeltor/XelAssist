XelAssist = { Game = { Player = {} }, Graph = {} }
table.getn = table.getn or function(value)
    local count = 0
    while value[count + 1] ~= nil do count = count + 1 end
    return count
end

dofile("Game/Player/MageEvocationEvidence.lua")
local Runtime = XelAssist.Game.Player.MageEvocationEvidence

Runtime:Invalidate("test start")
assert(Runtime:AuraChanged(true, 100, 1000, 0),
    "exact Evocation aura start must open a learner")
assert(Runtime:Observe(200, 1000, 2))
assert(Runtime:Observe(310, 1000, 4))
assert(Runtime:Observe(410, 1000, 6))
assert(Runtime:Observe(520, 1000, 8))
assert(Runtime:AuraChanged(false, 520, 1000, 8),
    "one complete uncapped channel must seal its envelope")
local learned = Runtime:Snapshot()
assert(learned and learned.exact and learned.minimumGain == 100
    and learned.maximumInterval == 2 and learned.minimumTicks == 3
    and learned.resourceGain == 300,
    "future value must use minimum gain and phase-independent tick count")

assert(not Runtime:AuraChanged(false, 520, 1000, 9)
    and Runtime:Snapshot() == nil,
    "a later unrelated aura change must retire the learned regime")
Runtime:AuraChanged(true, 100, 1000, 20)
Runtime:Observe(200, 1000, 22)
Runtime:Contaminate("external energize")
Runtime:Observe(300, 1000, 24)
Runtime:Observe(400, 1000, 26)
Runtime:Observe(500, 1000, 28)
assert(not Runtime:AuraChanged(false, 500, 1000, 28)
    and Runtime:Snapshot() == nil,
    "an attributed external gain must reject the whole channel")

dofile("Graph/MageEvocation.lua")
local Graph = XelAssist.Graph.MageEvocation
local action = { facts = { mageEvocation = true,
    unmodeledUnsafe = "Evocation dynamic mana/timing consequences are not modeled",
    mageEvocationEvidence = { valid = true, exact = true, spellId = 12051 } } }
local state = { resource = 100, resourceMax = 1000,
    mageEvocationEvidence = learned, actors = { player = { resource = 100 } },
    playerResourceClock = { phaseKnown = true, nextIn = 1 } }
local projection, reason, handled = Graph:Prepare(action, state,
    { duration = 8, cooldown = 480 })
assert(projection and not reason and handled
    and projection.mageEvocationTransition.resourceGain == 300,
    "root-sealed learner must admit the matching Evocation action")
dofile("Graph/ActionContextPolicy.lua")
assert(XelAssist.Graph.ActionContextPolicy:Blocker(action, state, {}) == nil,
    "learned evidence must release only Evocation's generic unsafe guard")
local noEvidence = state.mageEvocationEvidence
state.mageEvocationEvidence = nil
assert(XelAssist.Graph.ActionContextPolicy:Blocker(action, state, {})
    == action.facts.unmodeledUnsafe,
    "unlearned Evocation must retain its original hard blocker")
state.mageEvocationEvidence = noEvidence
dofile("Graph/ClassActionMechanics.lua")
local routed, routedReason, routedHandled =
    XelAssist.Graph.ClassActionMechanics:Prepare(action, state, nil,
        { duration = 8, cooldown = 480 }, 0)
assert(routed and not routedReason and routedHandled
    and routed.mageEvocationTransition.resourceGain == 300,
    "production class-mechanic dispatch must route learned Evocation")
local context = { state = state, downtime = 8 }
assert(Graph:Score(context, projection) and context.value > 0
    and context.effectivePower == 300,
    "learned Evocation must receive missing-mana value")
local candidate = { classMechanicProjection = projection }
assert(Graph:Apply(state, candidate) and state.resource == 400
    and state.actors.player.resource == 400
    and state.playerResourceClock.phaseKnown == false,
    "Evocation must apply one bounded gain and retire the old mana phase")

state.resource = 1000
local full, fullReason = Graph:Prepare(action, state, {})
assert(full == nil and fullReason == "mana already full",
    "Evocation must never be recommended at full mana")
state.resource, state.mageEvocationEvidence = 100, nil
local missing, missingReason, missingHandled = Graph:Prepare(action, state, {})
assert(missing == nil and missingHandled
    and missingReason == "completed Evocation evidence unavailable",
    "an unlearned character must continue to fail closed")

print("ok: completed Evocation channels teach bounded character mana value")
