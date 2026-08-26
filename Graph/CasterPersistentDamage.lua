-- Graph projection for repeatable impact spells with a persistent damage
-- tail. The action stays a damage spell (so another projectile may be queued)
-- while its later ticks remain causal hostile-local timeline state.
XelAssist.Graph.CasterPersistentDamage = {}
local P = XelAssist.Graph.CasterPersistentDamage

local APPLICATION_BLOCK_THRESHOLD = 0.75

local function clamp(value, low, high)
    return math.max(low, math.min(high, tonumber(value) or low))
end

local function actionFacts(action)
    return action and action.facts or {}
end

function P:Is(action)
    local facts = actionFacts(action)
    return facts.kind == "damage"
        and facts.repeatablePersistentDamage == true
end

local function shapeFrom(tooltip)
    local shape = tooltip and tooltip.persistentDamage
    if type(shape) ~= "table" or shape.exact ~= true then return nil end
    local direct, periodic = tonumber(shape.direct), tonumber(shape.periodic)
    local duration, interval = tonumber(shape.duration), tonumber(shape.interval)
    if not (direct and direct > 0 and periodic and periodic > 0
        and duration and duration > 0 and interval and interval > 0) then
        return nil
    end
    return shape
end

local function usableAura(aura, offset)
    if aura == nil then return nil, "absent" end
    if type(aura) ~= "table" then return nil, "unknown" end
    if aura.mine == false then return nil, "absent" end
    offset = math.max(0, tonumber(offset) or 0)
    if tonumber(aura.remaining) and aura.remaining <= offset then
        return nil, "absent"
    end
    local probability = tonumber(aura.applicationProbability) or 1
    if probability < APPLICATION_BLOCK_THRESHOLD then return nil, "unknown" end
    return aura, "known"
end

function P:ActiveAura(action, state, offset)
    if not (action and state) then return nil, "absent" end
    local projected, status = usableAura(
        state.auras and state.auras[action.name], offset)
    if status ~= "absent" then return projected, status end
    return usableAura(state.targetAuras and state.targetAuras[action.name], offset)
end

-- Unlike a primary DoT, an equal-rank persistent tail does not make the next
-- impact illegal. A different or unidentifiable rank fails closed because
-- replacing its remaining tail could lose unknown damage.
function P:Blocker(action, state, _, tooltip, actionStart)
    if not self:Is(action) then return nil, false end
    if not shapeFrom(tooltip) then
        return "persistent damage evidence unavailable", true
    end
    local offset = math.max(0, (tonumber(actionStart)
        or tonumber(state and state.time) or 0)
        - (tonumber(state and state.time) or 0))
        + math.max(0, tonumber(tooltip and tooltip.cast) or 0)
    local aura, status = self:ActiveAura(action, state, offset)
    if status == "unknown" then return "persistent tail state unknown", true end
    if not aura then return nil, true end
    if action.spellId == nil or aura.spellId == nil
        or tonumber(action.spellId) ~= tonumber(aura.spellId) then
        return "persistent tail rank unknown", true
    end
    return nil, true
end

local function weightedRaw(context, shape)
    local total = shape.direct + shape.periodic
    if total <= 0 then return nil, nil end
    return context.power * shape.direct / total,
        context.power * shape.periodic / total
end

-- Split the already-estimated total into impact and tail delivery. Resistance
-- phase helpers are root-state arithmetic and perform no live observations.
function P:Prepare(context)
    if not self:Is(context and context.action) then return false end
    local shape = shapeFrom(context.tooltip)
    if not shape then return false end
    local rawDirect, rawPeriodic = weightedRaw(context, shape)
    if not rawDirect then return false end
    local direct, periodic = rawDirect, rawPeriodic
    local resistance = context.resistance
    local effects = XelAssist.Graph.Effects
    if resistance and effects then
        direct = rawDirect * effects:PhaseFactor(
            resistance, "direct", false)
        local conditional = effects:OverWindow(context.action,
            context.target, context.tooltip, context.state,
            context.wait + context.cast, shape.duration,
            "periodic", true)
        periodic = conditional and rawPeriodic
            * clamp(context.effectDelivery, 0, 1) * conditional or 0
    end
    context.dotRawDirectPower = rawDirect
    context.dotRawPeriodicPower = rawPeriodic
    context.dotPeriodicExpectedPower = periodic
    context.persistentDirectExpectedPower = direct
    context.expectedPower = direct + periodic
    context.persistentDamagePrepared = true
    if resistance then
        resistance.decisionMultiplier = context.power > 0
            and context.expectedPower / context.power or 0
    end
    return true
end

-- Reuse the shared survival envelope in its periodic mode without changing
-- the action's durable kind. That prevents a later tick from claiming an
-- immediate kill while preserving one graph-wide TTD policy.
function P:AdjustSurvival(context)
    if not self:Is(context and context.action) then return false end
    local survival = XelAssist.Graph.SurvivalPressure
    if survival then
        local kind = context.kind
        context.kind = "dot"
        survival:Adjust(context)
        context.kind = kind
    end
    context.persistentDirectExpectedPower = math.max(0,
        (tonumber(context.expectedPower) or 0)
            - (tonumber(context.dotPeriodicExpectedPower) or 0))
    return true
end

local function exactTargetHealth(context, targetHealth)
    local exact = context.state and context.state.targetHealthExact == true
    local health = tonumber(targetHealth)
    return health, exact and health and health > 0
end

-- A fresh tail earns its full expected value. Recasting over our same-rank
-- tail earns only the provable impact as a conservative marginal lower bound;
-- the transition still refreshes and simulates the real future ticks.
function P:Score(context, targetHealth)
    if not self:Is(context and context.action) then return false end
    local shape = shapeFrom(context.tooltip)
    if not shape or not context.persistentDamagePrepared then
        context.value, context.reason = -100000,
            "persistent damage evidence unavailable"
        return true
    end
    local aura, status = self:ActiveAura(context.action, context.state,
        math.max(0, tonumber(context.wait) or 0)
            + math.max(0, tonumber(context.cast) or 0))
    if status == "unknown" then
        context.value, context.reason = -100000, "persistent tail state unknown"
        return true
    end
    local direct = math.max(0,
        tonumber(context.persistentDirectExpectedPower) or 0)
    local total = math.max(0, tonumber(context.expectedPower) or 0)
    local marginal = aura and direct or total
    local health, exact = exactTargetHealth(context, targetHealth)
    local effective = exact and math.min(marginal, health) or marginal
    context.persistentMarginalPower = marginal
    context.effectivePower = effective
    if marginal <= 0 then
        context.value, context.reason = -1000, "no delivered persistent damage"
        return true
    end
    if aura then
        context.value = 250 + effective * 4
            / math.max(0.5, tonumber(context.downtime) or 0)
        context.reason = "recasts for its direct impact"
    else
        local progress = context.survival
            and tonumber(context.survival.decisionFactor) or 1
        progress = clamp(progress, 0, 1)
        context.value = 250 * progress
            + effective * 4 / math.max(1, tonumber(context.downtime) or 0)
        if exact and marginal > health then
            context.value = context.value - (marginal - health) * 3
        end
        context.reason = "adds impact and lasting damage"
    end
    if exact and direct >= health then
        context.value = context.value + 700
        context.reason = "finishes with the direct impact"
    end
    if context.state.role == "damage" then
        context.value = context.value * 1.15
    elseif context.state.role == "healer" then
        context.value = context.value * 0.85
    end
    return true
end

local function rawPeriodicRate(candidate, duration)
    local raw = tonumber(candidate.dotRawPeriodicPower)
    if raw == nil or duration <= 0 then return nil end
    local factor = candidate.survival
        and tonumber(candidate.survival.periodicFactor) or 1
    return raw * clamp(factor, 0, 1) / duration
end

-- Apply only the impact at this edge, then install a hostile-local aura clock.
-- EventAuras owns later health/threat changes and probabilistic replacement.
function P:Apply(out, candidate, context)
    if not self:Is(candidate and candidate.action) then return false end
    local shape = shapeFrom(candidate.tooltip)
    if not shape then return false end
    local periodic = math.max(0,
        tonumber(candidate.dotPeriodicExpectedPower) or 0)
    local direct = math.max(0, (tonumber(candidate.power) or 0) - periodic)
    local elapsed = math.min(shape.duration, math.max(0,
        (tonumber(candidate.occupancy) or 0)
            - math.max(0, tonumber(candidate.cast) or 0)))
    local timing = XelAssist.Game.SpellTiming
    local immediate = timing and timing:AppliedPower(periodic,
        shape.duration, elapsed, shape.interval) or 0
    local hostile = XelAssist.Graph.HostileEffects
    local _, dealt = hostile:ApplySelectedDamage(out, direct + immediate)
    context.appliedHostileDamage = dealt

    local remaining = math.max(0, shape.duration - elapsed)
    if remaining <= 0 then return true end
    out.auras = out.auras or {}
    local prior = out.auras[candidate.action.name]
    local eventAuras = XelAssist.Graph.EventAuras
    local delivery = clamp(candidate.effectDelivery, 0, 1)
    local branches = eventAuras and eventAuras:ReplaceStateAura(
        out, candidate.action.name, delivery, prior) or nil
    out.auras[candidate.action.name] = {
        remaining = remaining, duration = shape.duration, mine = true,
        target = candidate.target, spellId = candidate.action.spellId,
        applicationProbability = delivery,
        periodicRate = periodic / shape.duration,
        periodicRawRate = rawPeriodicRate(candidate, shape.duration),
        periodicAction = candidate.action,
        periodicTooltip = { school = candidate.tooltip.school },
        periodicInterval = shape.interval,
        periodicNextIn = timing and timing:Next(shape.interval, elapsed) or nil,
        periodicThreatActor = actionFacts(candidate.action).damageActor
            or actionFacts(candidate.action).effectActor
            or candidate.action.actor or "player",
        periodicThreatMultiplier = actionFacts(candidate.action).threat or 1,
        periodicBranches = branches,
        repeatablePersistentDamage = true,
    }
    return true
end
