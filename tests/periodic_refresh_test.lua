XelAssist = { Game = {}, Graph = {} }
dofile("Game/SpellTiming.lua")
dofile("Graph/PeriodicRefresh.lua")
dofile("Graph/PeriodicScoring.lua")

local action = { name = "Rend", spellId = 772 }
local function context(remaining, nextIn, expectedTicks, delivered)
    return { action = action, kind = "dot", expectedPower = delivered,
        dotPeriodicExpectedPower = delivered, power = 15, cost = 10,
        downtime = 1.5, wait = 0, cast = 0,
        state = { time = 0, targetHealthExact = true, targetHealth = 30,
            role = "damage", auras = {}, targetAuras = { Rend = {
                spellId = 772, mine = true, duration = 9,
                remaining = remaining, periodicNextIn = nextIn } } },
        survival = { available = true, periodicInterval = 3,
            periodicTicks = 3, expectedPeriodicTicks = expectedTicks,
            lowerTimeToDie = 4, upperTimeToDie = 4,
            decisionFactor = expectedTicks / 3 } }
end

local clipping = context(1.2, 1.2, 1, 5)
assert(XelAssist.Graph.PeriodicRefresh:Adjust(clipping)
    and clipping.periodicRefresh.oldExpectedTicks == 1
    and clipping.periodicRefreshUnproductive
    and clipping.expectedPower == 0,
    "a refresh must not claim the imminent tick it displaces")
XelAssist.Graph.PeriodicScoring:Score(clipping, 30)
assert(clipping.value == -10
    and clipping.reason == "refresh would displace remaining periodic damage",
    "an unproductive periodic refresh must preserve its rage opportunity cost")

local extension = context(1.2, 1.2, 3, 15)
extension.survival.lowerTimeToDie = 12
extension.survival.upperTimeToDie = 12
assert(XelAssist.Graph.PeriodicRefresh:Adjust(extension)
    and extension.periodicRefresh.oldExpectedTicks == 1
    and extension.expectedPower == 10
    and not extension.periodicRefreshUnproductive,
    "a refresh on a durable target must retain only its two marginal ticks")

local projected = context(4, nil, 2, 10)
projected.state.targetAuras.Rend = nil
projected.state.auras.Rend = { spellId = 772, mine = true, duration = 9,
    remaining = 4, periodicNextIn = 1 }
projected.survival.lowerTimeToDie = 8
projected.survival.upperTimeToDie = 8
assert(XelAssist.Graph.PeriodicRefresh:Adjust(projected)
    and projected.periodicRefresh.oldTicks == 2
    and projected.expectedPower == 0,
    "projected branches must subtract all already-owned future ticks")

local incomplete = context(nil, nil, 1, 5)
incomplete.state.targetAuras.Rend.name = "Rend"
assert(XelAssist.Graph.PeriodicRefresh:Adjust(incomplete)
    and incomplete.periodicRefreshUnproductive
    and incomplete.periodicRefresh.exact == false,
    "an observed owned DoT with incomplete timing must fail closed")

local nameOnly = context(nil, nil, 1, 5)
nameOnly.state.targetAuras.Rend.name = "Rend"
nameOnly.state.targetAuras.Rend.spellId = nil
assert(XelAssist.Graph.PeriodicRefresh:Adjust(nameOnly)
    and nameOnly.periodicRefreshUnproductive,
    "an exact owned aura name must not become refresh permission when its ID is absent")

local otherRank = context(1.2, 1.2, 1, 5)
otherRank.state.targetAuras.Rend.spellId = 6546
assert(not XelAssist.Graph.PeriodicRefresh:Adjust(otherRank)
    and otherRank.periodicRefresh == nil,
    "an unidentified or different-rank aura must not fabricate tick power")

print("ok: periodic refreshes value only marginal future ticks")
