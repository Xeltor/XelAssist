-- Projects a self-stealth action and exposes the narrow spatial setup it can
-- unlock. Movement remains player-controlled and conditional: the graph never
-- claims that distance, rear position, target facing, or detection is solved.
XelAssist.Graph.StealthSetup = {}
local S = XelAssist.Graph.StealthSetup

local function aggressive(state)
    local reaction = tonumber(state and state.targetReaction)
    return reaction ~= nil and reaction <= 3
end

function S:Blocker(state)
    if not state or state.hostile ~= true or state.targetGUID == nil then
        return "no stealth setup target"
    end
    if state.targetHealthExact and (tonumber(state.targetHealth) or 0) <= 0 then
        return "target defeated"
    end
    return nil
end

function S:Score(context)
    local multiplier = math.max(0, math.min(1,
        tonumber(context.facts.movementSpeedMultiplier) or 1))
    local movementCost = (1 - multiplier) * 500
    context.value = 500 - movementCost
    context.reason = multiplier < 1
        and "prepares an opener with slower movement"
        or "prepares a stealth opener"
end

function S:Apply(out, candidate)
    local tooltip = candidate.tooltip or {}
    local facts = candidate.action and candidate.action.facts or {}
    if tooltip.appliesStealth or facts.stealthPreparation then
        out.playerStealthed, out.playerStealthKnown = true, true
        out.playerStealthSource = "projected stealth action"
        if not out.inCombat and out.targetGUID and aggressive(out) then
            out.stealthApproachTargetGUID = out.targetGUID
            out.stealthApproachReaction = out.targetReaction
        else
            out.stealthApproachTargetGUID = nil
            out.stealthApproachReaction = nil
        end
        return
    end
    if candidate.targetRelation == "hostile" then
        out.stealthApproachTargetGUID = nil
        out.stealthApproachReaction = nil
    end
end

function S:CanApproach(action, state, descriptor)
    local facts = action and action.facts or {}
    return (tonumber(state and state.time) or 0) > 0
        and state.inCombat == false and state.playerStealthed == true
        and facts.melee == true and (action.actor or "player") == "player"
        and descriptor and descriptor.relation == "hostile"
        and descriptor.guid ~= nil
        and state.stealthApproachTargetGUID == descriptor.guid
        and aggressive(state)
end
