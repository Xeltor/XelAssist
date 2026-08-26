XelAssist = { Game = {}, Graph = {} }
table.getn = table.getn or function(value)
    local count = 0
    while value[count + 1] ~= nil do count = count + 1 end
    return count
end

dofile("Game/TargetSurvival.lua")
local L = XelAssist.Game.TargetSurvival
local guid = {}
local evidence = L:Observe(guid, 1000, 1000, true, 0)
assert(not evidence.available and evidence.reason == "health trend still learning",
    "the first exact sample must not invent a survival forecast")
evidence = L:Observe(guid, 900, 1000, true, 0.5)
assert(not evidence.available and evidence.samples == 2,
    "a sub-second health burst must remain unproven")
evidence = L:Observe(guid, 800, 1000, true, 1)
assert(evidence.available and evidence.incomingDps == 200
    and evidence.timeToDie == 4 and evidence.confidence == "limited samples"
    and evidence.lowerTimeToDie == 2 and evidence.upperTimeToDie == 7,
    "a sustained exact loss must expose a bounded limited-sample forecast")
L:Observe(guid, 700, 1000, true, 1.5)
L:Observe(guid, 600, 1000, true, 2)
L:Observe(guid, 500, 1000, true, 2.5)
evidence = L:Observe(guid, 400, 1000, true, 3)
assert(evidence.available and evidence.incomingDps == 200
    and evidence.timeToDie == 2 and evidence.confidence == "observed"
    and evidence.lowerTimeToDie == 1.5 and evidence.upperTimeToDie == 2.7,
    "a longer material trend must narrow its evidence bounds")

evidence = L:Observe(guid, 900, 1000, true, 3.5)
assert(not evidence.available and evidence.reason == "large heal reset health trend"
    and evidence.samples == 1,
    "a large heal must reset rather than inflate old damage pressure")
evidence = L:Observe(guid, 850, 1200, true, 4)
assert(not evidence.available and evidence.reason == "maximum health changed",
    "a maximum-health regime change must reset the trend")
evidence = L:Observe(guid, 840, 1200, false, 4.5)
assert(not evidence.available and L.histories[guid] == nil,
    "inexact hostile health must remove stale exact evidence")

local gapGuid = {}
L:Observe(gapGuid, 1000, 1000, true, 0)
evidence = L:Observe(gapGuid, 700, 1000, true, 2)
assert(not evidence.available
    and evidence.reason == "observation gap reset health trend",
    "an unobserved interval must not be converted into continuous pressure")

L:Reset()
local oldLimit = L.MAX_TARGETS
L.MAX_TARGETS = 3
local first, second, third, fourth = {}, {}, {}, {}
L:Observe(first, 100, 100, true, 1)
L:Observe(second, 100, 100, true, 2)
L:Observe(third, 100, 100, true, 3)
L:Observe(fourth, 100, 100, true, 4)
assert(L.historyCount == 3 and L.histories[first] == nil
    and L.histories[second] and L.histories[third] and L.histories[fourth],
    "session health histories must stay bounded and evict least-recent evidence")
L.MAX_TARGETS = oldLimit
L:Reset()

dofile("Graph/SurvivalPressure.lua")
local P = XelAssist.Graph.SurvivalPressure
local survival = { available = true, incomingDps = 200, timeToDie = 2,
    lowerTimeToDie = 1.5, upperTimeToDie = 2.7,
    observedFor = 3, samples = 7, confidence = "observed",
    source = "exact hostile health trend" }
local function context(kind, cast, duration)
    return { kind = kind, damageKind = kind ~= "debuff",
        facts = { kind = kind, channel = kind == "channel" },
        state = { time = 0, targetHealth = 400,
            targetHealthExact = true, targetSurvival = survival },
        descriptor = { relation = "hostile" }, targetHealthAtImpact = 400,
        wait = 0, cast = cast or 0, downtime = 1.5, expectedPower = 500,
        dotPeriodicExpectedPower = kind == "dot" and 500 or nil,
        tooltip = { duration = duration }, effectTooltip = { duration = duration } }
end

local dot = context("dot", 0, 12)
P:Adjust(dot); P:Explain(dot)
assert(dot.survival and dot.survival.periodicFactor > 0.17
    and dot.survival.periodicFactor < 0.18
    and dot.expectedPower < 90
    and dot.reason == "target may die before the effect pays back",
    "a long periodic effect must retain only output inside the learned survival window")
local tickingDot = context("dot", 0, 9)
tickingDot.tooltip.periodicInterval = 3
tickingDot.effectTooltip.periodicInterval = 3
P:Adjust(tickingDot); P:Explain(tickingDot)
assert(tickingDot.survival.tickDiscrete == true
    and tickingDot.survival.periodicInterval == 3
    and tickingDot.survival.periodicFactor == 0
    and tickingDot.expectedPower == 0,
    "a target dying before the first exact tick must not receive continuous periodic credit")
local oneTickDot = context("dot", 0, 9)
oneTickDot.state.targetSurvival = { available = true, incomingDps = 100,
    timeToDie = 4, lowerTimeToDie = 3, upperTimeToDie = 5,
    observedFor = 3, samples = 7, confidence = "observed",
    source = "exact hostile health trend" }
oneTickDot.tooltip.periodicInterval = 3
oneTickDot.effectTooltip.periodicInterval = 3
P:Adjust(oneTickDot)
assert(oneTickDot.survival.periodicFactor > 0.33
    and oneTickDot.survival.periodicFactor < 0.34
    and oneTickDot.expectedPower > 166 and oneTickDot.expectedPower < 167,
    "exact cadence must value only the ticks whose recipients can survive")
local instant = context("damage", 0)
P:Adjust(instant)
assert(instant.expectedPower == 500 and instant.survival.directFactor == 1,
    "immediate damage must stay fully valuable while the target is alive")
local slow = context("damage", 3)
P:Adjust(slow); P:Explain(slow)
assert(slow.expectedPower == 0
    and slow.reason == "target may die before the action lands",
    "an action landing beyond the upper survival bound must lose expected output")
local channel = context("channel", 3, 3)
P:Adjust(channel); P:Explain(channel)
assert(channel.expectedPower > 349 and channel.expectedPower < 351
    and channel.reason == "target may die before the channel completes",
    "channel output must be integrated over its interruptible survival window")
local future = context("damage", 0)
future.state.time = 2
P:Adjust(future)
assert(future.survival.directFactor > 0.58
    and future.survival.directFactor < 0.59,
    "future graph time must consume the same root survival window")
local debuff = context("debuff", 0, 120)
P:Adjust(debuff); P:Explain(debuff)
assert(debuff.survival and debuff.survival.utilityFactor > 0.07
    and debuff.survival.utilityFactor < 0.071
    and debuff.survival.expectedUtilitySeconds > 2.09
    and debuff.survival.expectedUtilitySeconds < 2.11
    and debuff.survival.utilityPaybackSeconds == 1.5
    and debuff.reason == "target may die before the utility pays back",
    "a hostile utility debuff must retain only observed lifetime after its action payback window")
local expiredDebuff = context("debuff", 0, 120)
expiredDebuff.state.time = 3
P:Adjust(expiredDebuff)
assert(expiredDebuff.survival.utilityFactor == 0,
    "a debuff must have no utility after the target's bounded lifetime")
local durableDebuff = context("debuff", 0, 120)
durableDebuff.state.targetSurvival = { available = true, incomingDps = 20,
    timeToDie = 20, lowerTimeToDie = 15, upperTimeToDie = 25,
    observedFor = 3, samples = 7, confidence = "observed",
    source = "exact hostile health trend" }
P:Adjust(durableDebuff)
assert(durableDebuff.survival.utilityFactor == 1,
    "a target proven to outlive the bounded utility window must retain full debuff value")
local area = context("damage", 3)
area.tooltip.topology = { area = true }
area.effectTooltip.topology = area.tooltip.topology
P:Adjust(area)
assert(area.survival and not area.survival.available
    and area.survival.reason == "per-recipient area survival forecast unavailable"
    and area.expectedPower == 500,
    "one target's learned survival must not be applied to every area recipient and the gap must stay explicit")

print("ok: bounded target survival learning and graph pressure")
