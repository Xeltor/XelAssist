XelAssist = { Game = { Pets = {} }, Combat = {}, Graph = {} }
table.getn = table.getn or function(value) return #value end

local a, b, c = {}, {}, {}
local records = {
    [a] = { key = a, guid = a, unit = "target", selected = true,
        engaged = true,
        health = 200, healthExact = true, hasPlayerAggro = false,
        geometry = { player = { distance = 3 } },
        encounter = { inCombat = true }, resistanceFactor = 0.5 },
    [b] = { key = b, guid = b, unit = "pettarget", health = 60,
        engaged = true,
        healthExact = true, hasPlayerAggro = false,
        geometry = { player = { distance = 5 } },
        encounter = { inCombat = true }, resistanceFactor = 1 },
    [c] = { key = c, guid = c, unit = "mouseover", health = 80,
        engaged = false,
        healthExact = true, hasPlayerAggro = false,
        geometry = { player = { distance = 6 } },
        encounter = { inCombat = false }, resistanceFactor = 1 },
}
local state = { targetHealth = 200, targetHealthExact = true,
    targetDamageTaken = {}, role = "damage", groupSize = 1, pet = false,
    hostiles = { order = { a, b, c }, byKey = records,
        selectedKey = a, total = 3, capped = false,
        discoveryComplete = true } }

XelAssist.Graph.State = {
    HostileByKey = function(_, value, key)
        return value.hostiles and value.hostiles.byKey[key]
    end,
    HostileContext = function(_, value, key)
        local record = value.hostiles.byKey[key]
        return { targetResistance = { factor = record.resistanceFactor },
            targetDamageTaken = {}, targetHealth = record.health,
            targetHealthExact = record.healthExact }
    end,
    SyncSelectedHostile = function(_, value)
        value.synced = (value.synced or 0) + 1
    end,
    SelectedHostile = function(_, value)
        local hostiles = value and value.hostiles
        return hostiles and hostiles.byKey[hostiles.selectedKey]
    end,
}
XelAssist.Graph.Effects = {
    StateAtImpact = function(_, value) return value end,
    Decision = function(_, resistance)
        local factor = resistance and resistance.factor or 1
        return factor, factor
    end,
}
XelAssist.Combat.Resistance = {
    Estimate = function(_, _, target, _, localState)
        assert(target == "target")
        return { factor = localState.targetResistance.factor }
    end,
}

dofile("Graph/AreaRecipients.lua")
dofile("Graph/PlayerThreat.lua")
dofile("Graph/HostileEffects.lua")

local topology = { available = true, area = true, effects = {
    { index = 1, relation = "hostile", shape = "area",
        center = "caster", radius = 10, radiusKnown = true },
} }
local action = { name = "Burst", actor = "player",
    facts = { kind = "damage", aoe = true } }
local function scoreContext(value, shape)
    shape = shape or topology
    return { state = value, action = action, effectAction = action,
        facts = action.facts, kind = "damage", targetEffect = true,
        damageKind = true, descriptor = { key = a },
        tooltip = { topology = shape }, effectTooltip = { topology = shape },
        power = 100, expectedPower = 50, effectDelivery = 0.5,
        resistance = { factor = 0.5 }, targetHealthAtImpact = 200,
        downtime = 1.5, wait = 0, cast = 0, value = 0 }
end
local context = scoreContext(state)

assert(XelAssist.Graph.HostileEffects:Score(context),
    "one direct hostile area effect must use recipient-local scoring")
assert(context.recipientEffects.byKey[a].expectedPower == 50
    and context.recipientEffects.byKey[b].expectedPower == 100
    and context.recipientEffects.byKey[b].effectivePower == 60,
    "each proven recipient must use its own resistance and overkill cap")
assert(context.recipientEffects.byKey[c].collateral
    and context.totalExpectedPower == 150
    and context.totalEffectivePower == 110
    and context.collateralExpectedPower == 80,
    "collateral must transition but never inflate credited area throughput")
assert(context.reason == "risks pulling an additional enemy"
    and context.areaSelectedIncluded,
    "pull risk must stay visible in the candidate reason")

local candidate = { action = action, targetKey = a,
    areaDirectResolved = context.areaDirectResolved,
    recipientEffects = context.recipientEffects }
assert(XelAssist.Graph.HostileEffects:Apply(state, candidate)
    and records[a].health == 200 and records[b].health == 0
    and records[b].projectedDefeated
    and records[c].health == 0 and records[c].projectedCollateralHit
    and records[b].dead and records[c].dead
    and records[b].projectedThreat.player == 60
    and records[c].projectedThreat.player == 80
    and records[b].threat.playerDelta == 60
    and records[c].threat.playerDelta == 80 and state.synced == 1,
    "secondary and collateral effects must be local while cost remains external")

records[b].health, records[b].dead, records[b].projectedDefeated = 60, false, false
records[b].projectedThreat, records[b].threat = nil, nil
records[c].health, records[c].dead, records[c].projectedDefeated = 80, false, false
records[c].projectedThreat, records[c].projectedCollateralHit = nil, nil
local boundedState = { targetHealth = 200, targetHealthExact = true,
    targetDamageTaken = {}, role = "damage", groupSize = 1, pet = false,
    hostiles = { order = { a, b, c }, byKey = records,
        selectedKey = a, total = 3, capped = false,
        discoveryComplete = false, additionalUnknown = true } }
local boundedContext = scoreContext(boundedState)
assert(XelAssist.Graph.HostileEffects:Score(boundedContext)
    and boundedContext.totalExpectedPower == 50
    and boundedContext.recipientEffects.byKey[b].creditWithheld
    and boundedContext.recipientEffects.byKey[b].expectedPower == 100,
    "incomplete discovery must withhold known secondary benefit, not its physics")
local boundedCandidate = { action = action, targetKey = a,
    areaDirectResolved = true,
    recipientEffects = boundedContext.recipientEffects }
assert(XelAssist.Graph.HostileEffects:Apply(boundedState, boundedCandidate)
    and records[b].health == 0 and records[b].projectedThreat.player == 60,
    "a known in-range secondary must still take physical damage and threat")

records[b].health, records[b].dead, records[b].projectedDefeated = 60, false, false
records[b].projectedThreat, records[b].threat = nil, nil
local reducedContext = scoreContext(boundedState)
assert(XelAssist.Graph.HostileEffects:Score(reducedContext))
records[b].health = 10
assert(XelAssist.Graph.HostileEffects:Apply(boundedState, {
        action = action, targetKey = a, areaDirectResolved = true,
        recipientEffects = reducedContext.recipientEffects })
    and records[b].health == 0
    and records[b].projectedThreat.player == 10
    and records[b].threat.playerDelta == 10,
    "earlier ambient damage must cap secondary area threat to damage still dealt")

local primaryRecord = { key = a, guid = a, selected = true,
    health = 10, healthExact = true }
local primaryState = { targetHealth = 10, targetHealthExact = true,
    actors = {}, hostiles = { order = { a }, byKey = { [a] = primaryRecord },
        selectedKey = a } }
local primaryCandidate = { action = action, targetKey = a, targetGUID = a,
    targetRelation = "hostile", power = 50, threat = 50 }
local primaryContext = { action = action, facts = action.facts }
local applied, dealt = XelAssist.Graph.HostileEffects:ApplySelectedDamage(
    primaryState, primaryCandidate.power)
primaryContext.appliedHostileDamage = dealt
XelAssist.Graph.HostileEffects:ApplyPrimaryThreat(
    primaryState, primaryCandidate, primaryContext)
assert(applied and primaryRecord.health == 0 and dealt == 10
    and primaryRecord.projectedThreat.player == 10
    and primaryRecord.threat.playerDelta == 10,
    "earlier ambient damage must cap selected direct threat to damage still dealt")

local stanceRecord = { key = a, guid = a, selected = true,
    health = 100, healthExact = true, threat = { playerDeltaExact = true } }
local stanceState = { targetHealth = 100, targetHealthExact = true,
    actors = {}, playerThreat = { actor = "player", playerOnly = true,
        exact = true, multiplier = 0.8, minimum = 0.8, maximum = 0.8 },
    hostiles = { order = { a }, byKey = { [a] = stanceRecord },
        selectedKey = a } }
local stanceCandidate = { action = action, targetKey = a, targetGUID = a,
    targetRelation = "hostile", power = 50, threat = 40,
    playerThreatExact = true, playerThreatMultiplier = 0.8 }
local stanceContext = { action = action, facts = action.facts,
    appliedHostileDamage = 50 }
XelAssist.Graph.HostileEffects:ApplyPrimaryThreat(
    stanceState, stanceCandidate, stanceContext)
assert(stanceRecord.projectedThreat.player == 40
    and stanceRecord.threat.playerDelta == 40
    and stanceRecord.threat.playerDeltaExact,
    "transition damage must use the same exact player threat component as scoring")

records[b].health, records[b].dead, records[b].projectedDefeated = 60, false, false
records[b].projectedThreat, records[b].threat = nil, nil
local staleContext = scoreContext(boundedState)
assert(XelAssist.Graph.HostileEffects:Score(staleContext))
records[b].health, records[b].dead, records[b].projectedDefeated = 0, true, true
assert(XelAssist.Graph.HostileEffects:Apply(boundedState, {
        action = action, targetKey = a, areaDirectResolved = true,
        recipientEffects = staleContext.recipientEffects })
    and records[b].projectedThreat == nil,
    "an off-target that dies before impact must gain no projected damage threat")

local mixed = { available = true, area = true, effects = {
    topology.effects[1],
    { index = 2, relation = "hostile", shape = "single", center = "target" },
} }
local mixedContext = scoreContext(state, mixed)
assert(XelAssist.Graph.HostileEffects:Score(mixedContext)
    and mixedContext.areaRecipientsUnknown
    and mixedContext.areaDirectResolved
    and mixedContext.expectedPower == 0
    and table.getn(mixedContext.recipientEffects.order) == 0
    and mixedContext.value < 0,
    "mixed per-effect power must suppress the single-target fallback")

local unresolved = {
    { available = true, area = true, effects = {
        { index = 1, relation = "hostile", shape = "cone",
            center = "caster", radius = 10, radiusKnown = true } } },
    { available = true, area = true, effects = {
        { index = 1, relation = "hostile", shape = "ground",
            center = "dynamicObject", radius = 10, radiusKnown = true } } },
}
local i
for i = 1, table.getn(unresolved) do
    local unknownContext = scoreContext(state, unresolved[i])
    assert(XelAssist.Graph.HostileEffects:Score(unknownContext)
        and unknownContext.expectedPower == 0 and unknownContext.value < 0,
        "unresolved area geometry must never fall back to selected damage")
end

local outsideRecords = { [a] = { key = a, guid = a, unit = "target",
    selected = true, engaged = true, dead = false, health = 200,
    healthExact = true, geometry = { player = { distance = 20 } } } }
local outsideState = { targetHealth = 200, targetHealthExact = true,
    targetDamageTaken = {}, role = "damage", groupSize = 0,
    hostiles = { order = { a }, byKey = outsideRecords, selectedKey = a,
        total = 1, capped = false, discoveryComplete = true } }
local outsideContext = scoreContext(outsideState)
assert(XelAssist.Graph.HostileEffects:Score(outsideContext)
    and not outsideContext.areaSelectedIncluded
    and outsideContext.expectedPower == 0 and outsideContext.value < 0
    and outsideContext.reason == "no proven engaged area recipient",
    "a proven zero-hit caster area must not remain recommendable")

print("ok: recipient-local area value, resistance, collateral and transition")
