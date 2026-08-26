table.getn = table.getn or function(value) return #value end

local inferCalls, invalidations = 0, 0
XelAssist = { Game = { Player = {} }, Graph = {} }
XelAssist.Game.Player.ShamanEarthShock = {
    InferKnowledge = function(_, spellId)
        inferCalls = inferCalls + 1
        if spellId == 8042 then
            return { kind = "damage", shamanEarthShock = true }, nil, true
        end
        return nil, nil, false
    end,
    Invalidate = function() invalidations = invalidations + 1 end,
}
XelAssist.Game.Player.ShamanActions = {
    InferKnowledge = function() error("totem fallback claimed Earth Shock") end,
    Invalidate = function() end,
}
dofile("Game/ActionInference.lua")
local facts, reason, handled = XelAssist.Game.ActionInference:ClassKnowledge(8042)
assert(handled and reason == nil and facts.shamanEarthShock
    and inferCalls == 1, "class dispatcher lost exact Earth Shock identity")
XelAssist.Game.ActionInference:InvalidateClass()
assert(invalidations == 1, "class invalidation missed Earth Shock evidence")

local captured = 0
XelAssist = { Game = { Player = {}, HostileCasts = {} }, Graph = {} }
XelAssist.Game.Player.ShamanEarthShock = {
    CaptureCast = function(_, cast)
        captured = captured + 1
        local out, key, value = {}, nil, nil
        for key, value in pairs(cast) do out[key] = value end
        out.shamanEarthShockInterrupt = { exact = true,
            flags = { normal = cast.interruptFlags or 0 } }
        return out
    end,
}
XelAssist.Game.HostileCasts.Snapshot = function()
    return { { casterGuid = "enemy", spellId = 90000,
        generation = 7, remaining = 2, channel = false } }
end
XelAssist.Graph.State = {
    RefreshHostileRecord = function() end,
    SyncActiveHostile = function() end,
}
dofile("Graph/HostileCastState.lua")
local state = { classMechanicClass = "SHAMAN",
    hostiles = { order = { "enemy" }, byKey = {
        enemy = { key = "enemy", guid = "enemy" },
    } } }
XelAssist.Graph.HostileCastState:Attach(state, 0)
local cast = XelAssist.Graph.HostileCastState:Find(state, "enemy")
assert(captured == 1 and cast.shamanEarthShockInterrupt.exact,
    "root hostile cast did not seal Earth Shock interrupt evidence")
local copied = XelAssist.Graph.HostileCastState:Copy(state.hostileCasts)
copied.byCaster.enemy.shamanEarthShockInterrupt.flags.normal = 2
assert(cast.shamanEarthShockInterrupt.flags.normal == 0,
    "branch cast copy aliased nested Earth Shock evidence")

local transition = { exact = true, targetGUID = "enemy" }
XelAssist.Graph.PriestInnerFocus = nil
XelAssist.Graph.MagePresenceOfMind = nil
XelAssist.Graph.PriestPowerInfusion = nil
XelAssist.Graph.ShamanManaSpring = nil
XelAssist.Graph.PaladinWisdom = nil
XelAssist.Graph.MageColdSnap = nil
XelAssist.Graph.WarlockFelDomination = nil
XelAssist.Graph.RoguePreparation = nil
XelAssist.Graph.HunterRapidFire = nil
dofile("Graph/Candidate.lua")
local candidate = XelAssist.Graph.Candidate:Build({
    action = { name = "Earth Shock", facts = {} }, facts = {},
    descriptor = { guid = "enemy", relation = "hostile" }, tooltip = {},
    shamanEarthShockTransition = transition,
})
assert(candidate.shamanEarthShockTransition == transition,
    "candidate transport dropped Earth Shock transition")

local earthApplications = 0
XelAssist.Graph.ShamanEarthShock = {
    Apply = function()
        earthApplications = earthApplications + 1
        return true, true
    end,
}
XelAssist.Graph.HostileCastEvents = {
    Interrupt = function() error("generic interrupt duplicated Earth Shock") end,
}
XelAssist.Graph.HostileCastState = { Find = function() return nil end }
XelAssist.Graph.State.ActiveHostile = function(_, current)
    return current.hostiles.byKey.enemy
end
XelAssist.Graph.State.SyncActiveHostile = function(_, current) return current end
XelAssist.Graph.AreaRecipients = {}
XelAssist.Graph.Effects = {}
XelAssist.Graph.PlayerThreat = {}
XelAssist.Graph.PrimaryThreatEffects = {}
XelAssist.Graph.WarriorThreatPackets = {}
dofile("Graph/HostileEffects.lua")
local projected = { targetGUID = "enemy", targetCasting = true,
    hostiles = { byKey = { enemy = { key = "enemy", guid = "enemy",
        health = 100, healthExact = true } } } }
XelAssist.Graph.HostileEffects:FinalizeSelected(projected,
    { action = { facts = { shamanEarthShock = true } } },
    { kind = "damage", interrupt = true })
assert(earthApplications == 1,
    "hostile finalizer did not delegate exact Earth Shock once")

print("shaman earth shock production wiring passed")
