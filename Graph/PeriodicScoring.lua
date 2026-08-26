-- Marginal value for damage that overlaps later actions.  Installed-client
-- effect power supplies the total; causal survival evidence bounds how much of
-- that total can actually contribute before the hostile dies.
XelAssist.Graph.PeriodicScoring = {}
local P = XelAssist.Graph.PeriodicScoring

function P:Score(context, targetHealth)
    local state = context.state
    local expected = math.max(0, tonumber(context.expectedPower) or 0)
    local effective, fraction = expected, expected > 0 and 1 or 0
    if expected > 0 and state.targetHealthExact and targetHealth > 0 then
        effective = math.min(expected, targetHealth)
        fraction = math.min(1, targetHealth / math.max(1, expected))
    end
    context.effectivePower = effective
    local progressFactor = context.survival
        and tonumber(context.survival.decisionFactor) or 1
    progressFactor = math.max(0, math.min(1, progressFactor)) * fraction
    local expectedTicks = context.survival
        and tonumber(context.survival.expectedPeriodicTicks)
    if expected > 0 and expectedTicks and expectedTicks < 1 then
        context.value = -math.max(1, tonumber(context.cost) or 0)
        context.reason = "target may die before the first useful tick"
        return
    end
    context.value = 250 * progressFactor
        + effective * 4 / math.max(1, context.downtime)
        + effective / math.max(1, context.cost) * 45
    if fraction < 1 then
        context.value = context.value - (expected - effective) * 3
    end
    context.reason = fraction < 0.75
        and "target may die before the effect pays back"
        or "adds efficient lasting damage"
    if state.role == "damage" then context.value = context.value * 1.15
    elseif state.role == "healer" then context.value = context.value * 0.85 end
end
