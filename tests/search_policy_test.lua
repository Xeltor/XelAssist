XelAssist = { Graph = {} }
XelAssistCharDB = {}

local now = 100
function GetTime() return now end

dofile("Graph/SearchPolicy.lua")
local Policy = XelAssist.Graph.SearchPolicy

assert(Policy:Depth() == 24,
    "the automatic graph must use the full strategic decision horizon")
XelAssistCharDB.graphDepth = 99
assert(Policy:Depth() == 24,
    "a compatibility override must not exceed the safe decision horizon")
XelAssistCharDB.graphDepth = 6
assert(Policy:Depth() == 6,
    "standalone scenarios must retain their bounded depth override")
XelAssistCharDB.graphDepth = nil

local states, milliseconds = Policy:Limits({ time = 10, inCombat = true,
    playerGcdReadyAt = 10, actorReadyAt = { player = 10 } })
assert(states == 256 and milliseconds == 8,
    "a ready action must use the low-latency search lane")

states, milliseconds = Policy:Limits({ time = 10, inCombat = true,
    playerGcdReadyAt = 10.6, actorReadyAt = { player = 10 } })
assert(states == 512 and milliseconds == 12,
    "a short GCD window must fund a medium graph search")

states, milliseconds = Policy:Limits({ time = 10, inCombat = true,
    playerGcdReadyAt = 11.1, actorReadyAt = { player = 10 } })
assert(states == 768 and milliseconds == 18,
    "a long GCD window must fund the deep graph search")

states, milliseconds = Policy:Limits({ time = 10, inCombat = false,
    playerGcdReadyAt = 10, actorReadyAt = { player = 10 } })
assert(states == 768 and milliseconds == 18,
    "out-of-combat setup must use the deep graph search")

assert(Policy:WithinHorizon({ time = 54.99 }, 10)
    and not Policy:WithinHorizon({ time = 55 }, 10),
    "the modeled-time horizon must be exactly 45 seconds")
assert(Policy:Weight(10, { actionStart = 10, cast = 0 }) == 1,
    "an immediate action must retain full weight")
assert(math.abs(Policy:Weight(10, { actionStart = 14.5, cast = 0 }) - 0.5)
        < 0.0001,
    "an action one discount interval away must retain half weight")

local counter = { count = 255, maxStates = 256, maxMs = 8 }
assert(not Policy:BudgetReached(now, counter),
    "the state budget must allow its final state")
counter.count = 256
assert(Policy:BudgetReached(now, counter),
    "the state budget must stop at its exact bound")

print("search policy tests passed")
