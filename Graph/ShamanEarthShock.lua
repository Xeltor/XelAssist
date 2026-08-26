-- Search-pure Earth Shock damage/interrupt transition. Direct damage remains
-- in the normal resistance pipeline; this leaf replaces its raw mean with the
-- exact root profile and couples a successful binary delivery to interruption
-- plus the server's two-second school lockout.
XelAssist.Graph.ShamanEarthShock = {}
local E = XelAssist.Graph.ShamanEarthShock

local EPSILON = 0.0001

local function finite(value, low, high)
    value = tonumber(value)
    if value == nil or value ~= value or value == math.huge
        or value == -math.huge or value < low or value > high then return nil end
    return value
end

local function clamp(value)
    return math.max(0, math.min(1, tonumber(value) or 0))
end

local function identityField(field)
    if type(field) ~= "string" then return false end
    field = string.lower(field)
    return field == "key" or string.sub(field, -3) == "key"
        or string.sub(field, -4) == "guid"
end

local function copy(source, field)
    local out, key, value = {}, nil, nil
    for key, value in pairs(source or {}) do
        out[key] = type(value) == "table" and not identityField(key)
            and copy(value, key) or value
    end
    return out
end

local function runtime()
    return XelAssist.Game and XelAssist.Game.Player
        and XelAssist.Game.Player.ShamanEarthShock
end

local function profile(action)
    local owner = runtime()
    return owner and owner:Evidence(action) or nil
end

local function validGUID(value)
    return value ~= nil and value ~= "" and value ~= "0x000000000"
        and value ~= "0x0000000000000000"
end

local function targetGUID(state, descriptor)
    local guid = descriptor and (descriptor.guid or descriptor.castGuid)
        or state and state.targetGUID
    return validGUID(guid) and guid or nil
end

local function castFor(state, descriptor)
    local guid = targetGUID(state, descriptor)
    local casts = XelAssist.Graph.HostileCastState
    return casts and casts:Find(state, guid), guid
end

local function applicationDelay(state, actionStart, cast)
    local now = tonumber(state and state.time) or 0
    local start = math.max(now, tonumber(actionStart) or now)
    return start - now + math.max(0, tonumber(cast) or 0)
end

local function transition(action, state, descriptor, actionStart, castTime)
    local found = profile(action)
    if not found then
        return nil, "exact Earth Shock root evidence unavailable"
    end
    if not descriptor or descriptor.relation ~= "hostile" then
        return nil, "Earth Shock requires an exact hostile recipient"
    end
    local cast, guid = castFor(state, descriptor)
    if not guid then return nil, "Earth Shock target identity unavailable" end
    local delay = applicationDelay(state, actionStart, castTime)
    local out = { exact = true, activeCast = false,
        spellId = found.spellId, targetGUID = guid,
        applicationDelay = delay, interruptDuration = found.interruptDuration,
        profile = copy(found), source = found.source }
    if not cast then return out end
    local remaining = finite(cast.remaining, 0, 86400)
    if not remaining then
        return nil, "hostile cast deadline evidence unavailable"
    end
    if delay + EPSILON >= remaining then
        out.castResolvesFirst = true
        out.hostileCastGeneration = cast.generation
        out.hostileSpellId = cast.spellId
        return out
    end
    local owner = runtime()
    local castEvidence = owner and owner:CastEvidence(cast)
    if not castEvidence then
        return nil, "hostile cast interrupt predicate is unavailable"
    end
    out.activeCast = true
    out.hostileCastGeneration = cast.generation
    out.hostileSpellId = cast.spellId
    out.interruptible = castEvidence.interruptible
    out.interruptedSchool = castEvidence.school
    out.interruptedSchoolMask = castEvidence.schoolMask
    out.castEvidence = castEvidence
    return out
end

local function sealed(value)
    local found = value and value.shamanEarthShockTransition or value
    local owner = runtime()
    local action = found and { spellId = found.spellId,
        facts = { shamanEarthShock = true,
            shamanEarthShockEvidence = found.profile } }
    local profileFound = action and owner and owner:Evidence(action)
    if not (found and found.exact == true and profileFound
        and found.targetGUID and found.interruptDuration == owner.INTERRUPT_DURATION
        and finite(found.applicationDelay, 0, 86400)) then return nil end
    if found.activeCast then
        local cast = found.castEvidence
        local verified = type(cast) == "table" and owner:CastEvidence({
            spellId = found.hostileSpellId, channel = cast.channel == true,
            shamanEarthShockInterrupt = cast }) or nil
        if not (verified and cast.spellId == found.hostileSpellId
            and cast.school == found.interruptedSchool
            and cast.schoolMask == found.interruptedSchoolMask
            and found.interruptible == cast.interruptible) then return nil end
    end
    return found, profileFound
end

function E:Is(action)
    return action and action.facts and action.facts.shamanEarthShock == true
end

function E:Blocker(action, state, descriptor, tooltip, actionStart)
    if not self:Is(action) then return nil, false end
    local prepared, reason = transition(action, state, descriptor,
        actionStart, tooltip and tooltip.cast)
    return prepared and nil or reason, true
end

-- Integration calls this after ordinary legality/timing has built the context,
-- but before resistance projection. It never reads DBC, Unit*, or spell APIs.
function E:Prepare(context)
    if not self:Is(context and context.action) then return false, nil, false end
    local prepared, reason = transition(context.action, context.state,
        context.descriptor, context.actionStart, context.cast)
    if not prepared then return false, reason, true end
    local found = prepared.profile
    context.power = found.rawNoncriticalMean
    context.expectedPower = context.power
    context.effectivePower = context.power
    context.powerEvidence = { exact = true, complete = true,
        kind = "sealedEarthShockRawMean", spellId = found.spellId,
        source = found.source }
    context.estimated = false
    context.shamanEarthShockTransition = prepared
    return true, nil, true
end

-- Called after binary resistance delivery is known. Damage itself already owns
-- ordinary utility; this adds only a consequence that the hostile cast ledger
-- can price from its exact recipient and amount.
function E:Score(context)
    if not self:Is(context and context.action) then return false, nil, false end
    local prepared = sealed(context.shamanEarthShockTransition)
    if not prepared then
        return false, "Earth Shock transition evidence unavailable", true
    end
    if not (prepared.activeCast and prepared.interruptible) then
        return true, prepared.castResolvesFirst
            and "cast resolves before Earth Shock lands"
            or "deals Nature damage without an interrupt consequence", true
    end
    local casts = XelAssist.Graph.HostileCastState
    local cast = casts and casts:Find(context.state, prepared.targetGUID,
        prepared.hostileCastGeneration)
    local incoming = XelAssist.Graph.IncomingConsequences
    local value, reason = incoming and cast
        and incoming:PreventedValue(context.state, cast) or nil
    if value ~= nil then
        value = value * clamp(context.effectDelivery)
        context.value = context.value + value
        if value > 0 then context.reason = reason end
        context.shamanEarthShockInterruptValue = value
    end
    return true, reason or "interrupt consequence is not numerically known", true
end

function E:Transition(subject)
    local found = subject and (subject.shamanEarthShockTransition
        or subject.classMechanicProjection
            and subject.classMechanicProjection.shamanEarthShockTransition)
    found = sealed(found)
    return found and copy(found) or nil
end

local function hostileRecord(state, cast)
    local hostiles = state and state.hostiles
    local key = cast and cast.hostileKey
    local record = key ~= nil and hostiles and hostiles.byKey
        and hostiles.byKey[key] or nil
    if record and (record.guid or key) == cast.casterGuid then return record end
    local index
    for index = 1, table.getn(hostiles and hostiles.order or {}) do
        key = hostiles.order[index]
        record = hostiles.byKey[key]
        if record and (record.guid or key) == cast.casterGuid then return record end
    end
    return nil
end

local function addLockout(record, prepared, delivery)
    if not (record and delivery > 0) then return end
    record.shamanEarthShockSchoolLockouts =
        record.shamanEarthShockSchoolLockouts or {}
    local key = tostring(prepared.hostileCastGeneration) .. ":"
        .. tostring(prepared.interruptedSchool)
    record.shamanEarthShockSchoolLockouts[key] = {
        exact = true, school = prepared.interruptedSchool,
        schoolMask = prepared.interruptedSchoolMask,
        remaining = prepared.interruptDuration,
        applicationProbability = delivery,
        sourceSpellId = prepared.spellId,
        interruptedSpellId = prepared.hostileSpellId,
        source = "successful binary Earth Shock interrupt" }
end

-- Integration invokes this before the generic interrupt finalizer and skips
-- that finalizer whenever handled=true, preserving the exact predicate.
function E:Apply(state, candidate)
    if not self:Is(candidate and candidate.action) then return false, false end
    local prepared = self:Transition(candidate)
    if not prepared then return false, true end
    if candidate.targetGUID ~= prepared.targetGUID then return false, true end
    if not (prepared.activeCast and prepared.interruptible) then return true, true end
    local casts = XelAssist.Graph.HostileCastState
    local cast = casts and casts:Find(state, prepared.targetGUID,
        prepared.hostileCastGeneration)
    if not cast or cast.spellId ~= prepared.hostileSpellId then return true, true end
    local delivery = clamp(candidate.effectDelivery)
    local record = hostileRecord(state, cast)
    addLockout(record, prepared, delivery)
    local events = XelAssist.Graph.HostileCastEvents
    if events then events:Interrupt(state, candidate, { interrupt = true }) end
    return true, true
end

function E:Advance(state, elapsed)
    elapsed = math.max(0, tonumber(elapsed) or 0)
    if elapsed <= 0 then return end
    local hostiles = state and state.hostiles
    local index, key, record, lockKey, lock
    for index = 1, table.getn(hostiles and hostiles.order or {}) do
        key, record = hostiles.order[index], hostiles.byKey[hostiles.order[index]]
        for lockKey, lock in pairs(record
            and record.shamanEarthShockSchoolLockouts or {}) do
            lock.remaining = math.max(0, (tonumber(lock.remaining) or 0) - elapsed)
            if lock.remaining <= EPSILON then
                record.shamanEarthShockSchoolLockouts[lockKey] = nil
            end
        end
    end
end
