table.getn = table.getn or function(value)
    local count = 0
    while value[count + 1] ~= nil do count = count + 1 end
    return count
end

XelAssist = { Game = { Pets = {} }, Graph = {} }
local petGuid = {}
dofile("Game/Pets/Resources.lua")
dofile("Graph/CompanionResources.lua")
dofile("Graph/ActionConsumption.lua")

XelAssist.Graph.State = { Copy = function(_, state) return state end }
XelAssist.Graph.ActionEffects = {
    Context = function(_, _, candidate)
        return { applicationOffset = (candidate.wait or 0)
            + (candidate.cast or 0) }
    end,
    Consume = function(_, out, candidate, context)
        return XelAssist.Graph.ActionConsumption:Consume(
            out, candidate, context)
    end,
    Apply = function(_, out) out.applied = (out.applied or 0) + 1 end,
}
XelAssist.Graph.AutoShotEffects = {
    CreateTimeline = function() return nil end,
    FinishTimeline = function() end,
}
XelAssist.Graph.CompanionEvents = {
    Apply = function(_, out, _, _, _, entry)
        if entry.kind ~= "petAutocastTimelineCap" then return false end
        out.actors.pet.resourceExact = false
        out.actors.pet.actionReadyExact = false
        return true
    end,
}
XelAssist.Graph.OngoingEffects = {
    Prepare = function(_, out, _, candidate)
        out.time = out.time + candidate.downtime
        return candidate.testEvents or {}
    end,
    Events = function(_, _, _, candidate) return candidate.testEvents or {} end,
    AuraSnapshot = function() return {} end,
    TrackEventAuras = function() end,
    AdvanceEventAuras = function() end,
    ApplyEvent = function(_, out, _, _, _, entry)
        if entry.kind == "testTargetDeath" then
            out.targetHealth, out.hostile = 0, false
        end
    end,
}
XelAssist.Game.Pets.Effects = {
    Advance = function(_, state, elapsed)
        XelAssist.Game.Pets.Resources:AdvanceActor(
            state.actors.pet, elapsed)
    end,
}
dofile("Graph/Timeline.lua")
local Timeline = XelAssist.Graph.Timeline

local function state(focus)
    return { time = 0, hostile = true, targetHealth = 100,
        targetHealthExact = true, resource = 100, resourceMax = 100,
        actorReadyAt = { player = 0, pet = 0 }, actors = { pet = {
            guid = petGuid, ownerClass = "HUNTER", resourceType = 2,
            resource = focus, resourceMax = 100, resourceExact = true,
            resourceRegen = { verified = true, resourceType = 2,
                amount = 20, interval = 4, nextIn = 1, phaseKnown = true,
                sourceGuid = petGuid, externalEnergizeExcluded = true },
        } } }
end

local function petCandidate(cost, known)
    return { action = { name = "Chosen Focus Cast", actor = "pet",
            executor = "petAbility", facts = { kind = "damage" } },
        targetRelation = "hostile", wait = 0, cast = 2,
        occupancy = 2, downtime = 2, cost = cost,
        costKnown = known, tooltip = known and { cost = cost } or {} }
end

local function run(value, candidate)
    local context = { applicationOffset = 2 }
    return Timeline:Run(value, value, candidate, context)
end

local causal = run(state(100), petCandidate(50, true))
assert(causal.applied == 1 and causal.actors.pet.resource == 70
    and causal.actors.pet.resourceRegen.nextIn == 3,
    "chosen pet focus must pay at cast start before later ticks advance")

local interrupted = state(100)
local interruptedCandidate = petCandidate(50, true)
interruptedCandidate.testEvents = { { owner = "ongoing",
    kind = "testTargetDeath", offset = 1, priority = 10 } }
run(interrupted, interruptedCandidate)
assert(interrupted.actors.pet.resource == 70 and not interrupted.applied
    and interrupted.chosenActionPrevented,
    "target death during a paid pet cast must suppress only its effect")

local deadAtStart = state(100)
deadAtStart.hostile, deadAtStart.targetHealth = false, 0
run(deadAtStart, petCandidate(50, true))
assert(deadAtStart.actors.pet.resource == 100 and not deadAtStart.applied,
    "a pet cast invalid before start must spend nothing")

local insufficient = run(state(40), petCandidate(50, true))
assert(insufficient.actors.pet.resource == 60 and not insufficient.applied,
    "an unaffordable cast start must not pay later at completion")

local unknown = run(state(10), petCandidate(0, false))
assert(unknown.actors.pet.resource == 30 and not unknown.applied,
    "an unknown chosen pet cost must not execute as a known free action")
local zero = run(state(10), petCandidate(0, true))
assert(zero.actors.pet.resource == 30 and zero.applied == 1,
    "an explicitly known zero-cost pet action must remain executable")

local movingPet = state(100)
movingPet.moving = true
run(movingPet, petCandidate(50, true))
assert(movingPet.applied == 1 and movingPet.actors.pet.resource == 70,
    "player movement must not interrupt the independently casting pet")

local player = state(100)
player.resource = 40
local playerCandidate = { action = { name = "Too Expensive", actor = "player",
        facts = { kind = "damage" } }, targetRelation = "hostile",
    wait = 0, cast = 0, occupancy = 1.5, downtime = 1.5,
    cost = 50, tooltip = { cost = 50 } }
local playerContext = { applicationOffset = 0 }
Timeline:Run(player, player, playerCandidate, playerContext)
assert(player.resource == 40 and not player.applied,
    "atomic action consumption must never clamp an unaffordable payment to zero")

print("ok: causal chosen companion payment, interruption and atomic failure")
