XelAssist = { Game = { Pets = { Effects = {
    ThreatMultiplier = function() return 1 end,
} } }, Graph = { PlayerThreat = {
    Scale = function(_, _, _, amount) return amount, true, 1 end,
} } }
XelAssistCharDB = { petThreat = "auto" }
dofile("Graph/ManaOpportunity.lua")
dofile("Graph/ThreatScoring.lua")

local function score(resource, resourceType, exact)
    local state = { resource = resource, resourceMax = 100,
        resourceType = resourceType, playerResourceExact = exact,
        manaOpportunityWandAvailable = true,
        playerResourceReserved = 0, tank = false, groupSize = 0,
        pet = false, hasAggro = false,
        targetPlayerThreatDeltaExact = true, actors = {} }
    local context = { state = state,
        action = { name = "Test spell", actor = "player" },
        facts = { kind = "damage" }, kind = "damage",
        power = 100, expectedPower = 100, effectivePower = 100,
        fullEffectivePower = 100, cost = 25, value = 100,
        effectDelivery = 1, estimated = false }
    XelAssist.Graph.ThreatScoring:Apply(context)
    return context
end

local full = score(100, 0, true)
local scarce = score(50, 0, true)
assert(full.resourceOpportunityBasis == 100
    and not full.manaScarcityPriced
    and scarce.resourceOpportunityBasis == 50
    and scarce.manaScarcityPriced
    and full.value - scarce.value > 60,
    "spending half of remaining mana must cost more than a quarter of a full pool")

local energy = score(50, 3, true)
local uncertain = score(50, 0, false)
assert(energy.resourceOpportunityBasis == 100
    and not energy.manaScarcityPriced
    and uncertain.resourceOpportunityBasis == 100
    and not uncertain.manaScarcityPriced,
    "energy and inexact mana must retain the established maximum-pool reserve")

local noWand = score(50, 0, true)
noWand.state.manaOpportunityWandAvailable = nil
local fraction, basis, scarce = XelAssist.Graph.ManaOpportunity:CostFraction(
    noWand.state, 25, 100)
assert(fraction == 0.25 and basis == 100 and not scarce,
    "mana scarcity must not strand a caster without a proven zero-cost alternative")

local beforeTick = score(25, 0, true)
local afterTick = score(50, 0, true)
assert(afterTick.value > beforeTick.value,
    "exactly recovered mana must lower the next spell's opportunity cost")
print("ok: branch-local mana scarcity preserves wand and regeneration opportunity")
