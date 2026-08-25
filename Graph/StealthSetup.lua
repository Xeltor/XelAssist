-- Projects a self-stealth action and exposes the narrow spatial setup it can
-- unlock. Movement remains player-controlled and conditional: the graph never
-- claims that distance, rear position, target facing, or detection is solved.
XelAssist.Graph.StealthSetup = {}
local S = XelAssist.Graph.StealthSetup

local function aggressive(state)
    local reaction = tonumber(state and state.targetReaction)
    return reaction ~= nil and reaction <= 3
end

local function playerAction(action)
    return action and (action.actor or "player") == "player"
        and not (action.facts and action.facts.stealthPreparation)
end

local function outOfMeleeRange(state, tooltip)
    local distance = tonumber(state and (state.targetDistance or state.distance))
    local maximum = tonumber(tooltip and tooltip.maxRange)
    return distance ~= nil and maximum ~= nil and distance > maximum
end

-- Stealth is a setup edge, so its value must come from another discovered
-- action. A true stealth prerequisite always qualifies. Against an aggressive
-- target, Stealth may also enable an undetected approach for a rear melee
-- opener that is currently out of range. A neutral target does not need that
-- protection, so ordinary Backstab alone never makes Stealth useful there.
function S:Prepare(state, actions)
    state.stealthOpportunityCount = 0
    state.stealthOpportunityName = nil
    state.stealthOpportunityReason = nil
    if not state or state.hostile ~= true or state.targetGUID == nil then return end

    local i, action, facts, tooltip, reason
    for i = 1, table.getn(actions or {}) do
        action = actions[i]
        facts = action and action.facts or {}
        if playerAction(action) and not facts.self then
            tooltip = XelAssist.Game.Actors:Facts(action) or {}
            reason = nil
            if tooltip.requiresStealth == true or facts.requiresStealth == true then
                reason = "unlocks " .. tostring(action.name)
            elseif aggressive(state) and facts.melee == true
                and facts.behind == true and outOfMeleeRange(state, tooltip) then
                reason = "enables an undetected approach for "
                    .. tostring(action.name)
            end
            if reason then
                state.stealthOpportunityCount = state.stealthOpportunityCount + 1
                if not state.stealthOpportunityName then
                    state.stealthOpportunityName = action.name
                    state.stealthOpportunityReason = reason
                end
            end
        end
    end
end

function S:Blocker(state)
    if not state or state.hostile ~= true or state.targetGUID == nil then
        return "no stealth setup target"
    end
    if state.targetHealthExact and (tonumber(state.targetHealth) or 0) <= 0 then
        return "target defeated"
    end
    if (tonumber(state.stealthOpportunityCount) or 0) <= 0 then
        return "no stealth-enabled action"
    end
    return nil
end

function S:Score(context)
    local multiplier = math.max(0, math.min(1,
        tonumber(context.facts.movementSpeedMultiplier) or 1))
    local movementCost = (1 - multiplier) * 500
    context.value = 500 - movementCost
    context.reason = context.state.stealthOpportunityReason
        or (multiplier < 1 and "prepares an opener with slower movement"
            or "prepares a stealth opener")
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
