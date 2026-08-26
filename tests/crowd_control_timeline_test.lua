table.getn = table.getn or function(value) return #value end

XelAssist = { Game = { Pets = {} }, Graph = {} }

local function copy(value, seen)
    if type(value) ~= "table" then return value end
    seen = seen or {}
    if seen[value] then return seen[value] end
    local out, key, entry = {}, nil, nil
    seen[value] = out
    for key, entry in pairs(value) do out[key] = copy(entry, seen) end
    return out
end

XelAssist.Graph.State = {
    Copy = function(_, state) return copy(state) end,
    HostileByKey = function(_, state, key)
        return state.hostiles and state.hostiles.byKey[key]
    end,
    ActiveHostile = function(_, state)
        return state.hostiles and state.hostiles.byKey[state.targetContextKey]
    end,
    RefreshHostileRecord = function() end,
}
dofile("Graph/CrowdControl.lua")
dofile("Graph/CrowdControlTimeline.lua")

local advanceDamage = 0
XelAssist.Graph.ActionEffects = {
    Context = function(_, _, candidate)
        return { applicationOffset = (candidate.wait or 0)
            + (candidate.cast or 0) }
    end,
    Consume = function() return true end,
    Apply = function(_, out, _, candidate)
        local record = out.hostiles.byKey["enemy"]
        local damage = tonumber(candidate.testDamage) or 0
        record.health = math.max(0, record.health - damage)
        out.targetHealth = record.health
    end,
}
XelAssist.Graph.AutoShotEffects = {
    CreateTimeline = function() return nil end,
    FinishTimeline = function() end,
}
XelAssist.Graph.OngoingEffects = {
    Prepare = function(_, _, _, candidate) return candidate.testEvents or {} end,
    PersistentAuraSnapshot = function() return {} end,
    AdvanceState = function(_, out, elapsed) out.time = out.time + elapsed end,
    AdvanceEventAuras = function(_, out, _, elapsed)
        if elapsed <= 0 or advanceDamage <= 0 then return end
        local record = out.hostiles.byKey["enemy"]
        record.health = math.max(0, record.health - advanceDamage)
        out.targetHealth = record.health
    end,
    AuraSnapshot = function() return {} end,
    TrackEventAuras = function() end,
    ApplyEvent = function() end,
}
XelAssist.Game.Pets.Effects = { Advance = function() end }
dofile("Graph/Timeline.lua")

local Timeline = XelAssist.Graph.Timeline
local function state(directOnly)
    local aura = { remaining = 20, duration = 20, crowdControl = true,
        applicationProbability = 1, damageBreakSpecified = true,
        breaksOnAnyDamage = not directOnly,
        breaksOnDirectDamage = directOnly and true or false }
    local record = { key = "enemy", guid = "enemy-guid", health = 100,
        healthExact = true, projectedAuras = { Control = aura } }
    return { time = 0, hostile = true, targetContextKey = "enemy",
        targetGUID = "enemy-guid", targetHealth = 100,
        targetHealthExact = true, auras = record.projectedAuras,
        actors = { player = { health = 100, healthExact = true } },
        hostiles = { selectedKey = "enemy", order = { "enemy" },
            byKey = { enemy = record } } }, aura
end

local function candidate(delivery, damage, wait)
    return { action = { name = "Damage", actor = "player",
            facts = { kind = "damage" } }, targetRelation = "hostile",
        targetKey = "enemy", targetGUID = "enemy-guid", target = "target",
        wait = wait or 0, cast = 0, occupancy = 0,
        downtime = wait or 0, effectDelivery = delivery,
        testDamage = damage, tooltip = {} }
end

local exact = state(true)
local exactCandidate = candidate(1, 10)
Timeline:Run(exact, copy(exact), exactCandidate,
    XelAssist.Graph.ActionEffects:Context(exact, exactCandidate))
assert(not exact.hostiles.byKey.enemy.projectedAuras.Control,
    "a proven direct chosen hit should clear direct-break control")

local expected = state(false)
local expectedCandidate = candidate(0.5, 10)
Timeline:Run(expected, copy(expected), expectedCandidate,
    XelAssist.Graph.ActionEffects:Context(expected, expectedCandidate))
local expectedAura = expected.hostiles.byKey.enemy.projectedAuras.Control
assert(expectedAura and expectedAura.controlBreakOutcomeUnknown,
    "expected damage must not invent a guaranteed control break")

local advanced, advancedAura = state(true)
advanceDamage = 5
local advanceCandidate = candidate(1, 0, 1)
advanceCandidate.testEvents = { { owner = "ongoing", kind = "noop",
    offset = 1, priority = 10 } }
Timeline:Run(advanced, copy(advanced), advanceCandidate,
    XelAssist.Graph.ActionEffects:Context(advanced, advanceCandidate))
advanceDamage = 0
assert(advanced.hostiles.byKey.enemy.projectedAuras.Control == advancedAura
    and not advancedAura.controlBreakOutcomeUnknown,
    "periodic advance damage must not be reclassified by the following event")

print("ok: timeline resolves crowd-control breaks without expected-hit invention")
