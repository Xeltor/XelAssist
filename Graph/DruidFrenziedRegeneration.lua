-- Search-pure Frenzied Regeneration lifecycle. The action has no up-front
-- heal: only a fresh one-second tick reachable inside the action window earns
-- direct value, while later ticks consume branch-local rage and heal health.
XelAssist.Graph.DruidFrenziedRegeneration = {}
local F = XelAssist.Graph.DruidFrenziedRegeneration

local EPSILON = 0.0001

local function finite(value, low, high)
    value = tonumber(value)
    if value == nil or value ~= value or value == math.huge
        or value == -math.huge or value < low or value > high then return nil end
    return value
end

local function integer(value, low, high)
    value = finite(value, low, high)
    return value and math.floor(value) == value and value or nil
end

local function copy(source)
    local out, key, value = {}, nil, nil
    for key, value in pairs(source or {}) do
        out[key] = type(value) == "table" and copy(value) or value
    end
    return out
end

local function runtime()
    return XelAssist.Game and XelAssist.Game.Player
        and XelAssist.Game.Player.DruidFrenziedRegeneration
end

local function staticEvidence(subject)
    local owner = runtime()
    return owner and owner.Evidence and owner:Evidence(subject) or nil
end

local function capturedEvidence(subject)
    local owner = runtime()
    if owner and owner.CapturedEvidence then
        return owner:CapturedEvidence(subject)
    end
    return nil, "Frenzied Regeneration runtime evidence unavailable"
end

local function component(state, activeOnly)
    local owner = runtime()
    local found = state and state.druidFrenziedRegeneration
    if not (owner and type(found) == "table" and found.available == true
        and found.exact == true and (found.active == true or found.active == false)) then
        return nil
    end
    if activeOnly and not (found.active == true
        and integer(found.spellId, 1, 4294967295)
        and owner.RANKS[found.spellId]
        and finite(found.remaining, EPSILON, owner.DURATION)
        and finite(found.nextIn, EPSILON, owner.PERIOD)
        and integer(found.ticksRemaining, 1, owner.TICKS)
        and finite(found.lifePerRage, 1, 100)) then return nil end
    if activeOnly and (found.healingThreat ~= owner.HEALING_THREAT
        or found.spellThreatMultiplier ~= owner.SPELL_THREAT_MULTIPLIER) then
        return nil
    end
    return found
end

local function transition(value)
    local owner = runtime()
    if not (owner and type(value) == "table"
        and value.kind == "druidFrenziedRegeneration"
        and value.evidenceExact == true and owner.RANKS[value.spellId]
        and value.lifePerRage == owner.RANKS[value.spellId].lifePerRage
        and value.triggerSpellId == owner.TRIGGER_ID
        and value.duration == owner.DURATION and value.period == owner.PERIOD
        and value.ticks == owner.TICKS
        and value.ragePerTick == owner.RAGE_PER_TICK
        and value.powerType == owner.RAGE
        and value.healingThreat == owner.HEALING_THREAT
        and value.spellThreatMultiplier == owner.SPELL_THREAT_MULTIPLIER
        and value.runtimeVerified == false) then
        return nil
    end
    return value
end

local function projectionOf(candidate)
    local projection = candidate and candidate.classMechanicProjection
    return transition(projection
        and projection.druidFrenziedRegenerationTransition)
        or transition(candidate and candidate.druidFrenziedRegenerationTransition)
        or transition(candidate and candidate.tooltip
            and candidate.tooltip.druidFrenziedRegenerationTransition)
end

function F:Attach(state, knownClass)
    if type(state) ~= "table" then return false end
    local owner = runtime()
    local root = owner and owner:Snapshot(knownClass) or nil
    state.druidFrenziedRegeneration = root and {
        available = root.available == true, exact = root.exact == true,
        active = root.active == true, spellId = root.spellId,
        remaining = root.remaining, phaseKnown = root.phaseKnown,
        epoch = root.epoch, projected = false,
        reason = root.reason, source = root.source,
    } or nil
    return component(state) ~= nil
end

function F:Copy(source, target)
    if not target then return false end
    target.druidFrenziedRegeneration = source
        and source.druidFrenziedRegeneration
        and copy(source.druidFrenziedRegeneration) or nil
    return component(target) ~= nil
        or target.druidFrenziedRegeneration ~= nil
end

function F:RootBlocker(state)
    local found = state and state.druidFrenziedRegeneration
    if found and found.active == true
        and (found.available ~= true or found.exact ~= true
            or found.phaseKnown ~= true) then
        return found.reason or "active Frenzied Regeneration phase unavailable",
            true
    end
    return nil, found ~= nil
end

function F:Is(action, tooltip)
    local first = type(action) == "table" and action.facts or action
    local second = type(tooltip) == "table" and tooltip.facts or tooltip
    return first and first.druidFrenziedRegeneration == true
        or second and second.druidFrenziedRegeneration == true
        or staticEvidence(action) ~= nil or staticEvidence(tooltip) ~= nil
end

local function exactPlayer(state, descriptor)
    local actor = state and state.actors and state.actors.player
    local guid = actor and actor.guid
    if not (actor and guid ~= nil and descriptor
        and (descriptor.relation == "friendly"
            or descriptor.relation == "self")) then return nil end
    if descriptor.unit == "player" then return guid end
    if descriptor.guid ~= nil and descriptor.guid == guid then return guid end
    return nil
end

local function exactBearState(state)
    local owner = runtime()
    local form = state and state.druidFormState
    local formID = form and integer(form.formID, 0, 32)
    local actor = state and state.actors and state.actors.player
    local resource, maximum = finite(state and state.resource, 0, 1000000000),
        finite(state and state.resourceMax, 1, 1000000000)
    local health, healthMax = finite(state and state.health, 0, 1000000000),
        finite(state and state.healthMax, 1, 1000000000)
    if not (owner and form and form.available == true
        and owner:IsBearForm(formID) and state.resourceType == owner.RAGE
        and state.playerResourceExact == true and resource and maximum
        and resource <= maximum and health and healthMax and health <= healthMax
        and actor and finite(actor.health, 0, healthMax) == health
        and finite(actor.healthMax, 1, 1000000000) == healthMax) then
        return nil
    end
    return { formID = formID, resource = resource, resourceMax = maximum,
        health = health, healthMax = healthMax }
end

function F:Prepare(action, state, descriptor, tooltip)
    if not self:Is(action, tooltip) then return nil, nil, false end
    if not (action and (action.actor or "player") == "player") then
        return nil, "Frenzied Regeneration must be player-owned", true
    end
    local profile, reason = capturedEvidence(tooltip)
    if not profile then
        return nil, reason or "Frenzied Regeneration evidence unavailable", true
    end
    local current = component(state)
    if not current then
        return nil, "Frenzied Regeneration aura state unavailable", true
    end
    if current.active == true then
        return nil, "Frenzied Regeneration already active", true
    end
    if not exactPlayer(state, descriptor) then
        return nil, "Frenzied Regeneration requires the exact player", true
    end
    local root = exactBearState(state)
    if not root then
        return nil, "exact Bear rage and health state unavailable", true
    end
    if root.resource <= 0 then return nil, "no rage to convert", true end
    if root.health >= root.healthMax then
        return nil, "no exact missing player health", true
    end
    local prepared = copy(tooltip)
    prepared.cost, prepared.powerType = 0, profile.powerType
    prepared.cast, prepared.gcd = 0, 1.5
    prepared.classMechanic = "druidFrenziedRegeneration"
    prepared.druidFrenziedRegenerationTransition = {
        kind = "druidFrenziedRegeneration", evidenceExact = true,
        spellId = profile.spellId, triggerSpellId = profile.triggerSpellId,
        lifePerRage = profile.lifePerRage, powerType = profile.powerType,
        duration = profile.duration, period = profile.period,
        ticks = profile.ticks, ragePerTick = profile.ragePerTick,
        healingThreat = profile.healingThreat,
        spellThreatMultiplier = profile.spellThreatMultiplier,
        runtimeVerified = profile.runtimeVerified,
        source = profile.source,
    }
    return prepared, nil, true
end

local function firstTick(context, found)
    local root = exactBearState(context and context.state)
    local wait = finite(context and context.wait, 0, 600)
    local cast = finite(context and context.cast, 0, 600)
    local cycle = finite(context and context.downtime, 0, 600)
    if not root or wait == nil or cast == nil or cycle == nil then
        return nil, "Frenzied Regeneration tick window unavailable"
    end
    local at = wait + cast + found.period
    if cast + found.period > cycle + EPSILON then
        return nil, "first Frenzied Regeneration tick is beyond the player cycle"
    end
    -- A resource wait can contain unrepresented incoming/swing rage. A fresh,
    -- immediate application is the only exact first-tick resource baseline.
    if wait > EPSILON or cast > EPSILON then
        return nil, "rage before the first tick is unresolved"
    end
    local spent = math.min(found.ragePerTick, root.resource)
    local raw = spent * found.lifePerRage
    local missing = root.healthMax - root.health
    local effective = math.min(raw, missing)
    if spent <= 0 or effective <= 0 then
        return nil, "no exact first-tick healing"
    end
    return { at = at, rageSpent = spent, rawHealing = raw,
        effectiveHealing = effective, overheal = raw - effective,
        resourceMax = root.resourceMax }
end

function F:Score(context, projection)
    local found = projection and transition(
        projection.druidFrenziedRegenerationTransition)
    if not found then
        return false, "Frenzied Regeneration transition unavailable"
    end
    local tick, reason = firstTick(context, found)
    if not tick then return false, reason end
    local effective, spent = tick.effectiveHealing, tick.rageSpent
    context.power, context.expectedPower, context.effectivePower =
        tick.rawHealing, tick.rawHealing, effective
    context.value = effective * 5 / math.max(0.5, tick.at)
        + effective / math.max(1, spent) * 80
        - spent / math.max(1, tick.resourceMax) * 240
        - tick.overheal * 2
    context.druidFrenziedRegenerationFirstTick = tick
    context.druidFrenziedRegenerationClassScore = true
    context.classMechanicOwnsKindScore = true
    context.estimated = found.runtimeVerified ~= true
    context.reason = "converts exact rage into first-tick self-healing"
    return true
end

function F:Apply(state, candidate)
    local found, current = projectionOf(candidate), component(state)
    if not (found and current and current.active == false
        and exactBearState(state)) then return false end
    current.available, current.exact, current.active = true, true, true
    current.spellId, current.triggerSpellId = found.spellId, found.triggerSpellId
    current.lifePerRage, current.ragePerTick =
        found.lifePerRage, found.ragePerTick
    current.healingThreat = found.healingThreat
    current.spellThreatMultiplier = found.spellThreatMultiplier
    current.duration, current.remaining = found.duration, found.duration
    current.period, current.nextIn = found.period, found.period
    current.ticksRemaining, current.phaseKnown = found.ticks, true
    current.projected, current.reason = true, nil
    current.epoch = tostring(found.spellId) .. ":projected:"
        .. tostring(finite(state.time, 0, 1000000000) or 0)
    current.source = "projected fresh Frenzied Regeneration application"
    return component(state, true) ~= nil
end

local function syncPlayer(state, health, resource)
    state.health, state.resource = health, resource
    local actor = state.actors and state.actors.player
    if actor then actor.health, actor.resource = health, resource end
    local friendlies = state.friendlies
    local key = friendlies and friendlies.byUnit
        and friendlies.byUnit.player or nil
    local record = key ~= nil and friendlies.byKey
        and friendlies.byKey[key] or nil
    if record then
        record.health = health
        if friendlies.primaryKey == key then
            state.healHealth, state.healMax = health, record.healthMax
        end
    end
end

local function invalidateHealingThreat(state, current, effective)
    if effective <= 0 or state.inCombat == false then return end
    local base = effective * current.healingThreat
        * current.spellThreatMultiplier
    local maximum, exact, multiplier = base, false, 1
    local owner = XelAssist.Graph and XelAssist.Graph.PlayerThreat
    if owner and owner.Scale then
        maximum, exact, multiplier = owner:Scale(state, "player", base, 0)
    end
    current.healingThreatRawTotal =
        (current.healingThreatRawTotal or 0) + base
    current.healingThreatMinimum = 0
    current.healingThreatMaximum =
        (current.healingThreatMaximum or 0) + maximum
    current.healingThreatMultiplier = multiplier
    current.healingThreatMultiplierExact = exact
    current.threatFanoutExact = false
    current.threatReason = "hostile-reference fanout is hidden"
    local hostiles, index, record = state.hostiles, nil, nil
    for index = 1, table.getn(hostiles and hostiles.order or {}) do
        record = hostiles.byKey and hostiles.byKey[hostiles.order[index]]
        if record and record.dead ~= true then
            record.threat = record.threat or {}
            record.threat.playerDeltaExact = false
            record.threat.containsUnresolvedFrenziedRegenerationThreat = true
        end
    end
    state.targetPlayerThreatDeltaExact = false
end

local function tick(state, current)
    local owner = runtime()
    local form = state.druidFormState
    local formID = form and integer(form.formID, 0, 32)
    local bear = owner and form and form.available == true
        and owner:IsBearForm(formID)
    local rage = bear and state.playerResourceExact == true
        and state.resourceType == owner.RAGE
        and finite(state.resource, 0, 1000000000) or not bear and 0 or nil
    local health, maximum = finite(state.health, 0, 1000000000),
        finite(state.healthMax, 1, 1000000000)
    if rage == nil or not health or not maximum or health > maximum then
        current.available, current.exact = false, false
        current.reason = "projected Frenzied Regeneration tick state unavailable"
        return false
    end
    local spent = math.min(current.ragePerTick, rage)
    local raw = spent * current.lifePerRage
    local effective = math.min(raw, maximum - health)
    if bear then rage = rage - spent else rage = state.resource end
    health = health + effective
    syncPlayer(state, health, rage)
    current.totalRageSpent = (current.totalRageSpent or 0) + spent
    current.totalRawHealing = (current.totalRawHealing or 0) + raw
    current.totalEffectiveHealing =
        (current.totalEffectiveHealing or 0) + effective
    current.lastTick = { rageSpent = spent, rawHealing = raw,
        effectiveHealing = effective }
    invalidateHealingThreat(state, current, effective)
    return true
end

function F:Advance(state, elapsed)
    local current = component(state, true)
    elapsed = finite(elapsed, 0, 600)
    if not current or not elapsed or elapsed <= 0 then return false end
    local window = math.min(elapsed, current.remaining)
    local ticks, raw, effective, spent = 0, 0, 0, 0
    while current.ticksRemaining > 0
        and window + EPSILON >= current.nextIn do
        window = math.max(0, window - current.nextIn)
        if not tick(state, current) then return false end
        ticks, raw = ticks + 1, raw + current.lastTick.rawHealing
        effective = effective + current.lastTick.effectiveHealing
        spent = spent + current.lastTick.rageSpent
        current.ticksRemaining = current.ticksRemaining - 1
        current.nextIn = current.period
    end
    current.remaining = math.max(0, current.remaining - elapsed)
    if current.remaining <= EPSILON or current.ticksRemaining <= 0 then
        current.active, current.remaining, current.nextIn = false, nil, nil
        current.phaseKnown, current.expired = nil, true
    else
        current.nextIn = current.nextIn - window
    end
    current.lastAdvance = { ticks = ticks, rawHealing = raw,
        effectiveHealing = effective, rageSpent = spent, elapsed = elapsed }
    return true
end

-- Leaving Bear sets the server's hidden rage pool to zero. Entering a rage
-- form has an unresolved destination amount, so an active aura must not cross
-- that form edge until destination-rage evidence exists.
function F:FormBlocker(state, transitionValue)
    local current, owner = component(state, true), runtime()
    if not current or not transitionValue then return nil, false end
    local source = integer(transitionValue.sourceForm, 0, 32)
    local target = integer(transitionValue.targetForm, 0, 32)
    if source == nil or target == nil then
        return "Frenzied Regeneration form transition unavailable", true
    end
    if source ~= target and owner:IsBearForm(target) then
        return "active Frenzied Regeneration destination rage unavailable", true
    end
    return nil, true
end

function F:AfterForm(state, transitionValue)
    local current, owner = component(state, true), runtime()
    local source = transitionValue and integer(transitionValue.sourceForm, 0, 32)
    local target = transitionValue and integer(transitionValue.targetForm, 0, 32)
    if not (current and owner and source ~= nil and target ~= nil
        and source ~= target) then return false end
    if owner:IsBearForm(target) then
        current.available, current.exact = false, false
        current.reason = "active Frenzied Regeneration destination rage unavailable"
        return false
    end
    current.leftRageForm, current.hiddenRage = true, 0
    current.source = "projected form exit zeroed hidden rage"
    return true
end
