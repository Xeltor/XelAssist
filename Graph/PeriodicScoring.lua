-- Marginal value for damage that overlaps later actions.  Installed-client
-- effect power supplies the total; causal survival evidence bounds how much of
-- that total can actually contribute before the hostile dies.
XelAssist.Graph.PeriodicScoring = {}
local P = XelAssist.Graph.PeriodicScoring

function P:Score(context, targetHealth)
    local state = context.state
    local raw = math.max(0, tonumber(context.power)
        or tonumber(context.expectedPower) or 0)
    local expected = math.max(0, tonumber(context.expectedPower) or 0)
    local effective, fraction = expected, expected > 0 and 1 or 0
    if expected > 0 and state.targetHealthExact and targetHealth > 0 then
        effective = math.min(expected, targetHealth)
        fraction = math.min(1, targetHealth / math.max(1, expected))
    end
    context.effectivePower = effective
    if context.periodicRefreshUnproductive then
        context.value = -math.max(1, tonumber(context.cost) or 0)
        context.reason = "refresh would displace remaining periodic damage"
        return
    end
    local expectedTicks = context.survival
        and tonumber(context.survival.expectedPeriodicTicks)
    if expected > 0 and expectedTicks and expectedTicks < 1 then
        context.value = -math.max(1, tonumber(context.cost) or 0)
        context.reason = "target may die before the first useful tick"
        return
    end
    -- Value only damage the target can causally receive.  A prior fixed
    -- "periodic progress" bonus made even one low-damage late tick dominate
    -- immediate attacks.  The same resource-efficiency scale which rewards
    -- delivered damage now charges the unavailable remainder, representing
    -- rage/mana/energy committed to ticks forecast not to occur.
    local resourceScale = 45 / math.max(1, context.cost)
    local undelivered = math.max(0, raw - expected)
    local rawDirect = math.max(0,
        tonumber(context.dotRawDirectPower)
            or tonumber(context.tooltip and context.tooltip.directDamage) or 0)
    local rawPeriodic = math.max(0,
        tonumber(context.dotRawPeriodicPower)
            or tonumber(context.tooltip and context.tooltip.periodicDamage)
            or raw)
    local expectedPeriodic = math.max(0,
        tonumber(context.dotPeriodicExpectedPower) or expected)
    local completion = rawPeriodic > 0
        and math.min(1, expectedPeriodic / rawPeriodic) or 0
    -- Periodic damage overlaps later player actions; the shallow graph cannot
    -- wait through every tick before comparing that saved action runway.  Pay
    -- only for damage forecast to land, scaled again by effect completion, so
    -- a fully consumable DoT earns its overlap while one late tick does not.
    local overlap = rawDirect <= 0.0001
        and math.min(effective, expectedPeriodic) * 5 * completion or 0
    context.periodicUndeliveredPower = undelivered
    context.periodicOverlapPower = overlap
    context.value = effective * 4 / math.max(1, context.downtime)
        + effective * resourceScale + overlap
        - undelivered * resourceScale
    if fraction < 1 then
        context.value = context.value - (expected - effective) * 3
    end
    context.reason = (expected <= 0.0001
        or undelivered > math.max(0.001, raw * 0.25))
        and "target may die before the effect pays back"
        or "adds efficient lasting damage"
    if state.role == "damage" then context.value = context.value * 1.15
    elseif state.role == "healer" then context.value = context.value * 0.85 end
end
