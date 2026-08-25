-- A non-executable spatial instruction that keeps out-of-range combat branches
-- visible. It never changes measured distance: future actions remain explicitly
-- conditional on the player actually reaching their required range band.
XelAssist.Graph.MovementSetup = {}
local M = XelAssist.Graph.MovementSetup

local ACTION = { name = "Move into range", rank = 0, actor = "player",
    executor = "instruction", facts = { kind = "movement",
        movementSetup = true, gcd = 0 } }

function M:Candidate(state, blockers)
    if not state or state.hostile ~= true or state.targetGUID == nil
        or state.movementSetupTargetGUID == state.targetGUID
        or not blockers or (blockers.range or 0) <= 0 then return nil end
    return { action = ACTION, value = 1,
        reason = "closes distance for the next action",
        target = "target", targetKey = state.targetGUID,
        targetGUID = state.targetGUID, targetRelation = "hostile",
        targetSource = "selected", targetRef = state.targetRef,
        targetPriority = 1, cost = 0, costKnown = true,
        cast = 0, wait = 0, occupancy = 0.05, downtime = 0.05,
        valueDowntime = 0.05, gcd = 0, normalGcd = false,
        tooltip = { cost = 0, cast = 0, gcd = 0,
            source = "spatial instruction" }, power = 0, rawPower = 0,
        effectivePower = 0, effectDelivery = 1,
        estimated = false, spatialInstruction = true }
end

function M:Apply(state, candidate)
    if not (candidate and candidate.action
        and candidate.action.facts.movementSetup) then return false end
    state.movementSetupTargetGUID = candidate.targetGUID or state.targetGUID
    return true
end

function M:CanApproach(action, state, descriptor)
    return (tonumber(state and state.time) or 0) > 0
        and action and (action.actor or "player") == "player"
        and not (action.facts and action.facts.movementSetup)
        and descriptor and descriptor.relation == "hostile"
        and descriptor.guid ~= nil
        and state.movementSetupTargetGUID == descriptor.guid
end
