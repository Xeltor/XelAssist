XelAssist = { Graph = {} }
dofile("Graph/PeriodicScoring.lua")
local P = XelAssist.Graph.PeriodicScoring

local function score(expected, cost, factor, health, expectedTicks, raw)
    local context = { power = raw or expected, expectedPower = expected,
        cost = cost, downtime = 1.5,
        state = { targetHealthExact = true, targetHealth = health,
            role = "damage" },
        survival = { decisionFactor = factor,
            expectedPeriodicTicks = expectedTicks } }
    P:Score(context, health)
    return context
end

local expired = score(0, 10, 0, 8)
assert(expired.value == 0 and expired.effectivePower == 0
    and expired.reason == "target may die before the effect pays back",
    "a periodic action with no deliverable tick must have no setup value")

local partial = score(5, 10, 1 / 3, 30)
local full = score(15, 10, 1, 100)
assert(partial.value > 0 and partial.value < full.value,
    "periodic value must scale with causal delivered damage")
assert(full.value > 0 and full.reason == "adds efficient lasting damage",
    "a fully consumable periodic effect must retain throughput and resource value")

local noUsefulTick = score(1, 10, 0.08, 8, 0.24)
assert(noUsefulTick.value < 0
    and noUsefulTick.reason == "target may die before the first useful tick",
    "a fractional chance of one late tick must not justify paying for a DoT")

local usefulTick = score(4, 10, 0.4, 30, 1.2)
assert(usefulTick.value > 0,
    "one causally expected tick must remain eligible for graph comparison")

local lateRend = score(5, 10, 1 / 3, 30, 1, 15)
assert(lateRend.value < 0 and lateRend.periodicUndeliveredPower == 10
    and math.abs(lateRend.periodicOverlapPower - 25 / 3) < 0.0001
    and lateRend.reason == "target may die before the effect pays back",
    "one late Rend tick must not inherit value from ten undeliverable damage")

local twoTickRend = score(10, 10, 2 / 3, 75, 2, 15)
assert(twoTickRend.value > lateRend.value and twoTickRend.value < full.value,
    "Rend value must rise monotonically with causally deliverable ticks")

print("ok: periodic scoring values delivered ticks and charges unavailable damage")
