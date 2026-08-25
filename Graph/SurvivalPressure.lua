-- Converts learned hostile health pressure into bounded expected action output.
-- This is evidence-driven survival probability, not a class rotation rule.
XelAssist.Graph.SurvivalPressure = {}
local S = XelAssist.Graph.SurvivalPressure

local function topologyArea(context)
    local tooltip = context.effectTooltip or context.tooltip or {}
    return tooltip.topology and tooltip.topology.area == true
end

local function aliveAt(time, lower, upper)
    if time <= lower then return 1 end
    if time >= upper then return 0 end
    return 1 - (time - lower) / math.max(0.001, upper - lower)
end

local function areaUntil(time, lower, upper)
    if time <= 0 then return 0 end
    if time <= lower then return time end
    local width = math.max(0.001, upper - lower)
    if time < upper then
        local x = time - lower
        return lower + x - x * x / (2 * width)
    end
    return lower + width / 2
end

local function windowFraction(startAt, duration, lower, upper)
    if duration <= 0 then return aliveAt(startAt, lower, upper) end
    local area = areaUntil(startAt + duration, lower, upper)
        - areaUntil(startAt, lower, upper)
    return math.max(0, math.min(1, area / duration))
end

local function evidence(context)
    if not context.damageKind or not context.descriptor
        or context.descriptor.relation ~= "hostile" then return nil end
    local learned = context.state.targetSurvival
    if type(learned) ~= "table" or learned.available ~= true
        or not context.state.targetHealthExact then return nil end
    local health = tonumber(context.targetHealthAtImpact)
        or tonumber(context.state.targetHealth)
    local rate = tonumber(learned.incomingDps)
    if health == nil or health <= 0 or rate == nil or rate <= 0 then return nil end
    local rootHealth = tonumber(context.state.targetHealth) or health
    local scale = rootHealth > 0 and health / rootHealth or 1
    local lower = math.max(0, (tonumber(learned.lowerTimeToDie) or 0) * scale)
    local upper = math.max(lower,
        (tonumber(learned.upperTimeToDie) or learned.timeToDie or 0) * scale)
    return learned, lower, upper
end

function S:Adjust(context)
    if topologyArea(context) then
        local learned = context.state.targetSurvival
        if type(learned) == "table" and learned.available == true then
            context.survival = { available = false,
                reason = "per-recipient area survival forecast unavailable",
                confidence = "unknown" }
        end
        return
    end
    local learned, lower, upper = evidence(context)
    if not learned then return end
    local stateTime = math.max(0, tonumber(context.state.time) or 0)
    local impactDelay = math.max(0, tonumber(context.impactDelay)
        or (tonumber(context.wait) or 0) + (tonumber(context.cast) or 0))
    local impactAt = stateTime + impactDelay
    local before = math.max(0, tonumber(context.expectedPower) or 0)
    local directFactor = aliveAt(impactAt, lower, upper)
    local periodicFactor, duration = nil, nil
    if context.kind == "dot" then
        duration = math.max(0, tonumber(context.effectTooltip.duration)
            or tonumber(context.tooltip.duration) or 12)
        periodicFactor = windowFraction(impactAt, duration, lower, upper)
        local periodic = math.max(0,
            tonumber(context.dotPeriodicExpectedPower) or before)
        local direct = math.max(0, before - periodic)
        context.dotPeriodicExpectedPower = periodic * periodicFactor
        context.expectedPower = direct * directFactor
            + context.dotPeriodicExpectedPower
    elseif context.facts.channel and context.cast > 0 then
        local startAt = stateTime + math.max(0, tonumber(context.wait) or 0)
        duration = math.max(0, tonumber(context.cast) or 0)
        periodicFactor = windowFraction(startAt, duration, lower, upper)
        context.expectedPower = before * periodicFactor
    else
        context.expectedPower = before * directFactor
    end
    local factor = before > 0 and context.expectedPower / before or 1
    context.survival = { available = true,
        timeToDie = learned.timeToDie, lowerTimeToDie = lower,
        upperTimeToDie = upper, incomingDps = learned.incomingDps,
        observedFor = learned.observedFor, samples = learned.samples,
        confidence = learned.confidence, source = learned.source,
        impactAt = impactAt, duration = duration,
        directFactor = directFactor, periodicFactor = periodicFactor,
        decisionFactor = factor }
end

function S:Explain(context)
    local survival = context.survival
    if not survival or (survival.decisionFactor or 1) >= 0.75 then return end
    if context.kind == "dot" then
        context.reason = "target may die before the effect pays back"
    elseif context.facts.channel then
        context.reason = "target may die before the channel completes"
    elseif (survival.directFactor or 1) < 0.5 then
        context.reason = "target may die before the action lands"
    end
end
