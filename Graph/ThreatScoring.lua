-- Threat attribution and resource/confidence adjustments. This remains
-- separate from action utility so player, pet, and healing ownership are
-- explicit graph evidence instead of incidental scoring branches.
XelAssist.Graph.ThreatScoring = {}
local T = XelAssist.Graph.ThreatScoring
local PlayerThreat = XelAssist.Graph.PlayerThreat

local function playerThreatRisk(state)
    return state.hasAggro or state.targetPlayerThreatDeltaExact == false
end

local function petThreatFactor(state)
    if not (XelAssist.Game.Pets and XelAssist.Game.Pets.Effects) then return 1 end
    return XelAssist.Game.Pets.Effects:ThreatMultiplier(
        state.actors and state.actors.pet)
end

local function priceResource(context, maximum, effective)
    if context.cost <= 0 or maximum <= 0 then return end
    context.value = context.value - context.cost / maximum * 240
    local kind = context.facts.kind
    if not context.state.tank
        and (kind == "damage" or kind == "builder") then
        -- Direct attacks need the same delivered-damage-per-resource signal
        -- already used for periodic damage. This prevents a cheap weaker hit
        -- from winning solely because of the fixed scarcity reserve.
        context.value = context.value
            + math.max(0, tonumber(effective) or 0)
                / math.max(1, context.cost) * 45
    end
end

function T:Apply(context)
    local state, facts, kind = context.state, context.facts, context.kind
    local groupSize = tonumber(state.groupSize) or 0
    local resourceMax = tonumber(state.resourceMax) or 0
    if context.action.actor == "pet" then
        local pet = state.actors and state.actors.pet
        resourceMax = pet and pet.resourceMax or 0
    end
    if kind == "petThreat" then
        context.threat = 0
        priceResource(context, resourceMax, 0)
        return
    end
    local healing = kind == "heal" or kind == "hot" or kind == "petHeal"
    local baseFlatThreat = facts.baseFlatThreatBySpellId
        and facts.baseFlatThreatBySpellId[tonumber(context.action.spellId)] or nil
    -- A restored resource quantity is not hostile effect magnitude. Pricing
    -- mana as threat made Life Tap appear to generate aggro equal to its gain.
    local threatPower = kind == "resource" and 0
        or (kind == "damage" or kind == "dot" or kind == "builder")
        and (context.fullEffectivePower or context.effectivePower
            or context.expectedPower) or (healing
            and (context.effectivePower or 0) or context.power)
    local threat = threatPower * (facts.threat or (healing and 0.5 or 1))
    local valueThreatPower = context.onNextSwing
        and (context.marginalEffectivePower or context.marginalPower or 0)
        or threatPower
    local valueThreat = valueThreatPower
        * (facts.threat or (healing and 0.5 or 1))
    if facts.baseFlatThreatBySpellId then
        threatPower, valueThreatPower = 0, 0
        threat = math.max(0, tonumber(baseFlatThreat) or 0)
            * math.max(0, math.min(1, tonumber(context.effectDelivery) or 1))
        valueThreat = threat
        context.power, context.expectedPower = 0, 0
        context.effectivePower, context.fullEffectivePower = 0, 0
    elseif facts.deferredFlatThreat then
        threat = threatPower * (tonumber(facts.petThreatMultiplierOnCast) or 1)
        valueThreat = valueThreatPower
            * (tonumber(facts.petThreatMultiplierOnCast) or 1)
    end
    local actor = facts.damageActor or facts.effectActor
        or facts.healingThreatActor or context.action.actor
    local playerThreatExact, playerThreatMultiplier = true, 1
    if actor == "pet" then
        threat = threat * (facts.deferredFlatThreat and 1 or 0.9)
            * petThreatFactor(state)
        valueThreat = valueThreat * (facts.deferredFlatThreat and 1 or 0.9)
            * petThreatFactor(state)
        local petTank = XelAssistCharDB.petThreat == "tank"
            or (XelAssistCharDB.petThreat ~= "avoid" and groupSize == 0)
        if petTank then context.value = context.value + valueThreat * 0.4
        elseif groupSize > 0 then
            context.value = context.value - valueThreat * 0.25
        end
    else
        if PlayerThreat then
            threat, playerThreatExact, playerThreatMultiplier =
                PlayerThreat:Scale(state, actor, threat)
            valueThreat = valueThreat * playerThreatMultiplier
        end
        context.playerThreatExact = playerThreatExact
        context.playerThreatMultiplier = playerThreatMultiplier
        if playerThreatExact == false then context.estimated = true end
    end
    if actor ~= "pet" and state.tank and valueThreat > valueThreatPower then
        context.value = context.value
            + (valueThreat - valueThreatPower) * 0.5
        context.reason = "builds threat"
    elseif actor ~= "pet" and (groupSize > 0 or state.pet)
        and not state.tank then
        -- Unknown future Auto Shot threat reserves additional threat without
        -- pretending the live victim observation already says player aggro.
        local risk = playerThreatRisk(state)
        context.value = context.value - valueThreat * (risk and 3 or 0.25)
        if risk then context.reason = state.hasAggro
            and "limits additional threat" or "limits threat while aggro is uncertain"
        elseif valueThreat > valueThreatPower * 1.2 then
            context.reason = "lower threat for the group"
        end
    end
    context.threat = threat
    priceResource(context, resourceMax, valueThreatPower)
    if facts.inferred or facts.runtimeUnverified then context.estimated = true end
    if context.estimated then context.value = context.value * 0.88 end
end
