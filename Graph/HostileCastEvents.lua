-- Causal hostile-cast completion events and consequence-aware interrupt value.
-- A completion at the same deadline precedes the chosen action (priority 15).
XelAssist.Graph.HostileCastEvents = {}
local E = XelAssist.Graph.HostileCastEvents
local CastState = XelAssist.Graph.HostileCastState
local Incoming = XelAssist.Graph.IncomingConsequences

local EPSILON = 0.0001

local function casterRecord(state, cast)
    local hostiles = state and state.hostiles
    if not (cast and hostiles and hostiles.byKey) then return nil end
    local key = cast.hostileKey
    local record = key ~= nil and hostiles.byKey[key] or nil
    if record and (record.guid or key) == cast.casterGuid then return record end
    local i
    for i = 1, table.getn(hostiles.order or {}) do
        key = hostiles.order[i]
        record = hostiles.byKey[key]
        if record and (record.guid or key) == cast.casterGuid then return record end
    end
    return nil
end

local function casterDead(state, cast)
    local record = casterRecord(state, cast)
    if not record then return false end
    if record.dead == true or record.projectedDefeated == true then return true end
    local health = tonumber(record.health)
    return record.healthExact == true and health ~= nil and health <= 0
end

local function eventKind(state, cast)
    if casterDead(state, cast) then return "hostileCastRetire" end
    if cast.hostileKey ~= nil or cast.consequence then
        return "hostileCastImpact"
    end
    return "hostileCastRetire"
end

function E:Events(state, candidate)
    local events, collection = {}, state and state.hostileCasts
    local window = math.max(0, tonumber(candidate and candidate.downtime) or 0)
    local i, casterGuid, cast, remaining
    for i = 1, table.getn(collection and collection.order or {}) do
        casterGuid = collection.order[i]
        cast = collection.byCaster[casterGuid]
        remaining = cast and math.max(0, tonumber(cast.remaining) or 0)
        if cast and remaining <= window + EPSILON then
            table.insert(events, { owner = "hostileCast",
                kind = eventKind(state, cast), offset = remaining,
                priority = 15, casterGuid = casterGuid,
                generation = cast.generation })
        end
    end
    return events
end

function E:Advance(state, elapsed)
    if CastState then CastState:Advance(state, elapsed) end
end

function E:Apply(state, entry)
    if not (CastState and entry and (entry.kind == "hostileCastImpact"
        or entry.kind == "hostileCastRetire")) then
        return nil
    end
    local cast = CastState:Find(
        state, entry.casterGuid, entry.generation)
    if not cast then return nil end
    local result, reason
    local dead = casterDead(state, cast)
    local resolves = entry.kind == "hostileCastImpact" and not dead
    if resolves and cast.consequence and Incoming then
        result, reason = Incoming:Apply(state, cast)
    elseif dead then reason = "caster defeated before cast completion"
    elseif resolves then
        reason = cast.consequenceReason or "consequence unavailable"
    else reason = "cast retired without a resolvable hostile" end
    CastState:Retire(state, entry.casterGuid, entry.generation)
    if resolves and not result then
        state.lastIncomingUnknown = { casterGuid = entry.casterGuid,
            generation = entry.generation, reason = reason }
    end
    return result, reason
end

local function exactCast(context)
    local descriptor = context and context.descriptor or {}
    local guid = descriptor.guid or context and context.state
        and context.state.targetGUID
    return CastState and CastState:Find(context and context.state, guid), guid
end

local function applicationOffset(context)
    return math.max(0, tonumber(context and context.wait) or 0)
        + math.max(0, tonumber(context and context.cast) or 0)
end

function E:InterruptValue(context)
    local cast = exactCast(context)
    local delivery = math.max(0, math.min(1,
        tonumber(context and context.effectDelivery) or 1))
    if cast then
        if applicationOffset(context) + EPSILON >=
            math.max(0, tonumber(cast.remaining) or 0) then
            return -1200, "cast resolves before the interrupt", true
        end
        local value, reason
        if Incoming then
            value, reason = Incoming:PreventedValue(context.state, cast)
        end
        if value == nil then
            value, reason = 2600,
                cast.consequenceReason or reason or "cast consequence is uncertain"
        end
        return value * delivery, reason, true
    end
    local state = context and context.state
    if state and state.targetCasting then
        local observedRemaining = tonumber(state.targetCastRemaining)
        local remaining = observedRemaining
            and math.max(0, observedRemaining) or nil
        if remaining and remaining > 0
            and applicationOffset(context) + EPSILON >= remaining then
            return -1200, "cast resolves before the interrupt", true
        end
        local probability = state.targetCastProbability
        if probability == nil then probability = 1 end
        return 2600 * probability * delivery,
            "stops an unresolved current cast", true
    end
    return -1000, "no active cast to interrupt", true
end

function E:Interrupt(state, candidate, facts)
    if not (facts and (facts.kind == "interrupt" or facts.interrupt)
        and CastState) then return false end
    local casterGuid = candidate and candidate.targetGUID or state.targetGUID
    local cast = CastState:Find(state, casterGuid)
    if not cast then return false end
    local delivery = math.max(0, math.min(1,
        tonumber(candidate and candidate.effectDelivery) or 1))
    local remaining = math.max(0, tonumber(cast.remaining) or 0)
    if remaining <= EPSILON or delivery <= 0 then return true end
    local probability = (tonumber(cast.probability) or 1) * (1 - delivery)
    if probability <= 0.05 then
        CastState:Retire(state, casterGuid, cast.generation)
    else
        CastState:SetProbability(
            state, casterGuid, cast.generation, probability)
    end
    return true
end

function E:IncomingDamage(state, recipientGuid, within, strictlyAfter)
    if recipientGuid == nil then return 0, false end
    within = math.max(0, tonumber(within) or 0)
    strictlyAfter = tonumber(strictlyAfter)
    local collection = state and state.hostileCasts
    local amount, exact, i, cast = 0, true, nil, nil
    for i = 1, table.getn(collection and collection.order or {}) do
        cast = collection.byCaster[collection.order[i]]
        if cast and (tonumber(cast.remaining) or 0) <= within + EPSILON
            and (strictlyAfter == nil
                or (tonumber(cast.remaining) or 0) > strictlyAfter + EPSILON)
            and not casterDead(state, cast)
            and cast.consequence and cast.consequence.kind == "damage"
            and Incoming:RecipientGuid(cast) == recipientGuid then
            amount = amount + (Incoming:ExpectedAmount(cast) or 0)
            if cast.consequence.estimated then exact = false end
        end
    end
    return amount, exact
end
