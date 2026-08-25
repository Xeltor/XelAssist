-- Threat attribution and resource/confidence adjustments. This remains
-- separate from action utility so player, pet, and healing ownership are
-- explicit graph evidence instead of incidental scoring branches.
XelAssist.Graph.ThreatScoring = {}
local T = XelAssist.Graph.ThreatScoring

local function petThreatFactor(state)
    if not (XelAssist.Game.Pets and XelAssist.Game.Pets.Effects) then return 1 end
    return XelAssist.Game.Pets.Effects:ThreatMultiplier(
        state.actors and state.actors.pet)
end

function T:Apply(context)
    local state, facts, kind = context.state, context.facts, context.kind
    local resourceMax = state.resourceMax
    if context.action.actor == "pet" then
        local pet = state.actors and state.actors.pet
        resourceMax = pet and pet.resourceMax or 0
    end
    if kind == "petThreat" then
        context.threat = 0
        if context.cost > 0 and resourceMax > 0 then
            context.value = context.value - context.cost / resourceMax * 240
        end
        return
    end
    local healing = kind == "heal" or kind == "hot" or kind == "petHeal"
    local threatPower = (kind == "damage" or kind == "dot" or kind == "builder")
        and (context.effectivePower or context.expectedPower) or (healing
            and (context.effectivePower or 0) or context.power)
    local threat = threatPower * (facts.threat or (healing and 0.5 or 1))
    if facts.deferredFlatThreat then
        threat = threatPower * (tonumber(facts.petThreatMultiplierOnCast) or 1)
    end
    local actor = facts.damageActor or facts.effectActor
        or facts.healingThreatActor or context.action.actor
    if actor == "pet" then
        threat = threat * (facts.deferredFlatThreat and 1 or 0.9)
            * petThreatFactor(state)
        local petTank = XelAssistCharDB.petThreat == "tank"
            or (XelAssistCharDB.petThreat ~= "avoid" and state.groupSize == 0)
        if petTank then context.value = context.value + threat * 0.4
        elseif state.groupSize > 0 then
            context.value = context.value - threat * 0.25
        end
    elseif state.tank and threat > threatPower then
        context.value = context.value + (threat - threatPower) * 0.5
        context.reason = "builds threat"
    elseif (state.groupSize > 0 or state.pet) and not state.tank then
        context.value = context.value - threat * (state.hasAggro and 3 or 0.25)
        if state.hasAggro then context.reason = "limits additional threat"
        elseif threat > threatPower * 1.2 then context.reason = "lower threat for the group" end
    end
    context.threat = threat
    if context.cost > 0 and resourceMax > 0 then
        context.value = context.value - context.cost / resourceMax * 240
    end
    if facts.inferred or facts.runtimeUnverified then context.estimated = true end
    if context.estimated then context.value = context.value * 0.88 end
end
