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

local stateCopies, lastStateCopy = 0, nil
XelAssist.Graph.State = {
    Copy = function(_, state)
        stateCopies, lastStateCopy = stateCopies + 1, copy(state)
        return lastStateCopy
    end,
    RefreshHostileRecord = function() end,
}
dofile("Graph/HostileCastState.lua")
dofile("Graph/IncomingConsequences.lua")
dofile("Graph/HostileCastEvents.lua")
dofile("Graph/IncomingScoring.lua")

local HostileEvents = XelAssist.Graph.HostileCastEvents
XelAssist.Graph.ActionEffects = {
    Context = function(_, _, candidate)
        return { applicationOffset = (candidate.wait or 0)
            + (candidate.cast or 0) }
    end,
    Consume = function() return true end,
    Apply = function(_, out, _, candidate)
        local facts = candidate.action.facts
        if facts.killCaster then
            local hostile = out.hostiles.byKey["enemy-key"]
            hostile.health, hostile.dead, hostile.projectedDefeated = 0, true, true
            out.targetHealth, out.hostile = 0, false
        else HostileEvents:Interrupt(out, candidate, facts) end
        out.actionApplied = true
    end,
}
XelAssist.Graph.AutoShotEffects = {
    CreateTimeline = function() return nil end,
    FinishTimeline = function() end,
}
XelAssist.Graph.OngoingEffects = {
    Prepare = function() return {} end,
    PersistentAuraSnapshot = function() return {} end,
    AdvanceState = function(_, out, elapsed)
        out.time = out.time + elapsed
    end,
    AdvanceEventAuras = function() end,
    AuraSnapshot = function() return {} end,
    TrackEventAuras = function() end,
    ApplyEvent = function() end,
}
XelAssist.Graph.EventAuras = { AgeBranches = function() end }
XelAssist.Game.Pets.Effects = { Advance = function() end }
dofile("Graph/AmbientTargetHealth.lua")
dofile("Graph/Timeline.lua")

local Timeline = XelAssist.Graph.Timeline

local function state(remaining)
    local player = { key = "player-key", guid = "player-guid",
        health = 100, healthMax = 100, exact = true,
        absorbs = {}, auras = {} }
    local enemy = { key = "enemy-key", guid = "enemy-guid",
        health = 100, healthMax = 100, healthExact = true,
        dead = false, projectedDefeated = false }
    return { time = 0, hostile = true, targetGUID = "enemy-guid",
        targetHealth = 100, targetHealthExact = true,
        health = 100, healthMax = 100, absorbs = {},
        actors = { player = { guid = "player-guid",
            health = 100, healthMax = 100 } },
        friendlies = { order = { "player-key" }, primaryKey = "player-key",
            byKey = { ["player-key"] = player } },
        hostiles = { order = { "enemy-key" }, selectedKey = "enemy-key",
            byKey = { ["enemy-key"] = enemy } },
        hostileCasts = { order = { "enemy-guid" }, byCaster = {
            ["enemy-guid"] = { casterGuid = "enemy-guid",
                targetGuid = "player-guid", hostileKey = "enemy-key", generation = 7,
                remaining = remaining, probability = 1,
                consequence = { kind = "damage", targetMode = "target",
                    targetGuid = "player-guid", amount = 40 } } } } }
end

local function candidate(offset)
    return { action = { name = "Kick", actor = "player",
            facts = { kind = "interrupt", interrupt = true } },
        targetRelation = "hostile", targetGUID = "enemy-guid",
        wait = offset, cast = 0, occupancy = 0,
        downtime = 2, effectDelivery = 1, tooltip = {} }
end

local early = state(2)
local earlyCandidate = candidate(0)
Timeline:Run(early, copy(early), earlyCandidate,
    XelAssist.Graph.ActionEffects:Context(early, earlyCandidate))
assert(early.health == 100 and early.actionApplied
    and not early.hostileCasts.byCaster["enemy-guid"],
    "an earlier interrupt must cancel the exact future consequence")

local deadline = state(2)
local deadlineCandidate = candidate(2)
Timeline:Run(deadline, copy(deadline), deadlineCandidate,
    XelAssist.Graph.ActionEffects:Context(deadline, deadlineCandidate))
assert(deadline.health == 60 and deadline.actionApplied
    and not deadline.hostileCasts.byCaster["enemy-guid"],
    "a hostile impact must resolve before an interrupt at the exact deadline")

local stale = state(0)
stale.hostileCasts = { order = { "unmatched-guid" }, byCaster = {
    ["unmatched-guid"] = { casterGuid = "unmatched-guid", generation = 8,
        remaining = 0, probability = 1,
        consequenceReason = "caster is not retained" } } }
local observeCandidate = candidate(0)
observeCandidate.action = { name = "Observe", actor = "player", facts = {} }
Timeline:Run(stale, copy(stale), observeCandidate,
    XelAssist.Graph.ActionEffects:Context(stale, observeCandidate))
assert(not stale.hostileCasts.byCaster["unmatched-guid"]
    and table.getn(stale.hostileCasts.order) == 0,
    "every completed cast must receive a retirement event instead of a zero row")

local zeroProbeState = state(0)
local copiesBeforeZeroProbe = stateCopies
local zeroProbe = Timeline:BeforeScoredAction(
    zeroProbeState, candidate(0))
assert(stateCopies > copiesBeforeZeroProbe and zeroProbe.targetHealth == 100
    and lastStateCopy.health == 60
    and not lastStateCopy.hostileCasts.byCaster["enemy-guid"],
    "a zero-time hostile cast must retain the full pre-action consequence path")

local defeated = state(2)
local killCandidate = candidate(0)
killCandidate.action = { name = "Lethal Strike", actor = "player",
    facts = { kind = "damage", killCaster = true } }
Timeline:Run(defeated, copy(defeated), killCandidate,
    XelAssist.Graph.ActionEffects:Context(defeated, killCandidate))
assert(defeated.health == 100
    and not defeated.hostileCasts.byCaster["enemy-guid"]
    and defeated.lastIncomingConsequence == nil,
    "a cast must retire without resolving after its caster is provably defeated")

local shieldState = state(30)
shieldState.hostileCasts = { order = {}, byCaster = {} }
local function incomingCast(guid, remaining, amount)
    table.insert(shieldState.hostileCasts.order, guid)
    shieldState.hostileCasts.byCaster[guid] = { casterGuid = guid,
        targetGuid = "player-guid", generation = remaining,
        remaining = remaining, probability = 1,
        consequence = { kind = "damage", targetMode = "target",
            targetGuid = "player-guid", amount = amount } }
end
incomingCast("before-shield", 1, 10)
incomingCast("at-shield", 2, 20)
incomingCast("inside-shield", 3, 30)
incomingCast("at-bounded-end", 17, 40)
incomingCast("after-bounded-end", 17.1, 50)
local shieldContext = { state = shieldState, target = "player",
    wait = 1, cast = 1, downtime = 1, power = 1000,
    tooltip = { duration = 30 } }
local shieldValue = XelAssist.Graph.IncomingScoring:AbsorbValue(shieldContext)
assert(shieldContext.incomingDuringAbsorb == 70 and shieldValue == 4250
    and HostileEvents:IncomingDamage(
        shieldState, "player-guid", 17, 2) == 70,
    "absorb value must count only impacts strictly after application through its bounded duration")

print("ok: hostile cast impact and interrupt timeline ordering")
