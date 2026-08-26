-- Marginal damage for refreshing an owned periodic aura. Reapplying a DoT
-- resets its tick phase, so damage the existing aura would still deliver is
-- not new value and an imminent old tick can be displaced entirely.
XelAssist.Graph.PeriodicRefresh = {}
local R = XelAssist.Graph.PeriodicRefresh

local APPLICATION_BLOCK_THRESHOLD = 0.75

local function finite(value, low)
    value = tonumber(value)
    if not value or value ~= value or value < low then return nil end
    return value
end

local function sameAction(aura, action)
    local spellId = aura and tonumber(aura.spellId)
    if not spellId and aura and aura.periodicAction then
        spellId = tonumber(aura.periodicAction.spellId)
    end
    if spellId then return tonumber(action and action.spellId) == spellId end
    -- Some 1.12 aura lanes expose an exact localized name and ownership but
    -- omit the spell ID. activeAura already selected this record by the
    -- action's exact name, so absent rank metadata cannot permit an overwrite.
    return aura and action and aura.name == action.name
end

local function activeAura(context)
    local state, name = context.state, context.action.name
    local aura = state.auras and state.auras[name]
    if not aura then aura = state.targetAuras and state.targetAuras[name] end
    if type(aura) ~= "table" or aura.mine == false
        or (tonumber(aura.applicationProbability) or 1)
            < APPLICATION_BLOCK_THRESHOLD
        or not sameAction(aura, context.action) then return nil end
    return aura
end

local function phaseAtApplication(aura, interval, offset)
    local remaining = finite(aura.remaining, 0)
    if not remaining or remaining <= offset then return nil end
    local nextIn = finite(aura.periodicNextIn, 0.0001)
    if not nextIn then
        local duration = finite(aura.duration, 0.0001)
        if not duration or remaining > duration + 0.0001 then return nil end
        nextIn = XelAssist.Game.SpellTiming:Next(
            interval, math.max(0, duration - remaining))
    end
    while nextIn and nextIn <= offset + 0.0001 do
        nextIn = nextIn + interval
    end
    if not nextIn then return nil end
    return remaining - offset, nextIn - offset
end

local function aliveAt(time, lower, upper)
    if time <= lower then return 1 end
    if time >= upper then return 0 end
    return 1 - (time - lower) / math.max(0.001, upper - lower)
end

local function expectedOldTicks(remaining, firstIn, interval,
    applicationAt, lower, upper)
    local expected, ticks, at = 0, 0, firstIn
    while at <= remaining + 0.0001 and ticks < 80 do
        expected = expected + aliveAt(applicationAt + at, lower, upper)
        ticks, at = ticks + 1, at + interval
    end
    return expected, ticks
end

function R:Adjust(context)
    if not (context and context.kind == "dot") then return false end
    local aura = activeAura(context)
    if not aura then return false end
    if not (context.survival and context.survival.available == true) then
        context.periodicRefreshUnproductive = true
        context.periodicRefresh = { exact = false,
            source = "owned aura present; marginal refresh timing unavailable" }
        return true
    end
    local interval = finite(context.survival.periodicInterval, 0.0001)
    local newExpectedTicks = finite(
        context.survival.expectedPeriodicTicks, 0)
    local totalTicks = finite(context.survival.periodicTicks, 1)
    if not (interval and newExpectedTicks and totalTicks) then
        context.periodicRefreshUnproductive = true
        context.periodicRefresh = { exact = false,
            source = "owned aura present; periodic cadence unavailable" }
        return true
    end
    local offset = math.max(0, tonumber(context.wait) or 0)
        + math.max(0, tonumber(context.cast) or 0)
    local remaining, firstIn = phaseAtApplication(aura, interval, offset)
    if not remaining then
        context.periodicRefreshUnproductive = true
        context.periodicRefresh = { exact = false,
            source = "owned aura present; expiry or tick phase unavailable" }
        return true
    end
    local applicationAt = math.max(0, tonumber(context.state.time) or 0) + offset
    local lower = math.max(0, tonumber(context.survival.lowerTimeToDie) or 0)
    local upper = math.max(lower,
        tonumber(context.survival.upperTimeToDie) or lower)
    local oldExpectedTicks, oldTicks = expectedOldTicks(
        remaining, firstIn, interval, applicationAt, lower, upper)
    local deliveredPeriodic = math.max(0,
        tonumber(context.dotPeriodicExpectedPower)
            or tonumber(context.expectedPower) or 0)
    local perTick = newExpectedTicks > 0
        and deliveredPeriodic / newExpectedTicks or 0
    local displaced = perTick * oldExpectedTicks
    local marginalPeriodic = math.max(0, deliveredPeriodic - displaced)
    context.expectedPower = math.max(0,
        (tonumber(context.expectedPower) or 0)
            - deliveredPeriodic + marginalPeriodic)
    context.dotPeriodicExpectedPower = marginalPeriodic
    context.periodicRefresh = { exact = true, remaining = remaining,
        firstTickIn = firstIn, oldTicks = oldTicks,
        oldExpectedTicks = oldExpectedTicks, displacedPower = displaced,
        marginalPeriodicPower = marginalPeriodic,
        source = "owned aura expiry and installed-client tick cadence" }
    context.periodicRefreshUnproductive = deliveredPeriodic > 0
        and marginalPeriodic <= 0.0001 and true or nil
    if context.power and context.power > 0 then
        context.survival.decisionFactor = math.max(0,
            math.min(1, context.expectedPower / context.power))
    end
    return true
end
