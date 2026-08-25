XelAssist = { Game = {}, Graph = {}, Combat = {} }
dofile("Combat/Knowledge.lua")
dofile("Game/ResourceExchange.lua")

local G = XelAssist.Game.ResourceExchange
local inferred = G:Infer("converts 20 health into 20 mana")
assert(inferred and inferred.kind == "resource" and inferred.self
    and inferred.healthConversion and inferred.transientResource
    and inferred.resourceType == "mana",
    "an exact conversion tooltip must become a transient resource action")
assert(G:Infer("restores some mana") == nil,
    "ambiguous resource text must remain outside the exchange model")

local action = { name = "Life Tap", facts =
    XelAssist.Combat.Knowledge["Life Tap"] }
local tooltip = {}
assert(G:Apply(action, tooltip, " converts 20 health into 20 mana ")
    and tooltip.healthCost == 20 and tooltip.resourceGain == 20
    and tooltip.resourceType == "mana",
    "the graph must receive the exact health cost and mana gain")

XelAssist.Graph.State = {
    FriendlyByUnit = function(_, state, unit)
        return unit == "player" and state.player or nil
    end,
}
dofile("Graph/ResourceExchange.lua")
local R = XelAssist.Graph.ResourceExchange
local state = { health = 100, healthMax = 100,
    resource = 20, resourceMax = 100, hasAggro = false }
assert(R:Blocker(action, state, tooltip) == nil)
state.health = 20
assert(R:Blocker(action, state, tooltip)
        == "health conversion would be lethal",
    "a graph path must never project a lethal Life Tap")
state.health, state.resource = 100, 100
assert(R:Blocker(action, state, tooltip) == "resource already full",
    "full mana must reject a wasteful health conversion")

state.resource = 20
local context = { action = action, state = state, tooltip = tooltip,
    downtime = 1.5 }
assert(R:Score(context) and context.power == 20
    and context.effectivePower == 20 and context.value > 0,
    "safe missing mana must give Life Tap a graph-derived utility")

local out = { health = 100, healthMax = 100,
    resource = 90, resourceMax = 100,
    player = { health = 100 },
    actors = { player = { health = 100, resource = 90 } } }
assert(R:Apply(out, { action = action, tooltip = tooltip })
    and out.health == 80 and out.resource == 100
    and out.player.health == 80 and out.actors.player.health == 80
    and out.actors.player.resource == 100,
    "the transition must atomically lose health, cap mana, and sync player views")
print("ok: exact graph-native health-to-resource exchange")
