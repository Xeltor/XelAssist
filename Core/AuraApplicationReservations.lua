-- Exact aura-application lifecycle reservations. This module extends the
-- reservation API after Core/Reservations.lua has established its identity
-- keys, pending records, and spell lifecycle correlation.
local XA = XelAssist
local APPLICATION_VISIBILITY_GRACE = 0.75
local MAX_APPLICATION_RESERVATION = 60

local function exactApplicationRecord(owner, name, guid, casterGuid, spellId,
    auraBar)
    if not name or guid == nil or casterGuid == nil then return nil, nil end
    if type(owner.pendingAuras) ~= "table" then owner.pendingAuras = {} end
    local key = owner:PendingAuraKey(name, guid, casterGuid, true)
    if not key then return nil, nil end
    local record = owner.pendingAuras[key]
    if not record then
        record = { name = name, target = guid, casterGuid = casterGuid,
            spellId = spellId, auraBar = auraBar, submittedAt = GetTime() }
        owner.pendingAuras[key] = record
    end
    record.spellId = record.spellId or spellId
    record.auraBar = record.auraBar or auraBar
    return record, key
end

local function detachCurrent(owner, record, key)
    local current = owner.currentPendingAuras
        and owner.currentPendingAuras[record.casterGuid]
    if current and current.key == key then
        owner.currentPendingAuras[record.casterGuid] = nil
    end
end

-- Nampower's exact aura event can precede the corresponding UnitBuff/UnitDebuff
-- visibility update. Keep a short execution guard after proven application so
-- repeated physical inputs cannot submit the same effect in that gap. Detach
-- it from the caster's current in-flight slot: later identityless cast failures
-- belong to newer work and must not poison an already landed application.
function XA:ConfirmAuraPending(name, guid, casterGuid, spellId, auraBar)
    local record, key = exactApplicationRecord(
        self, name, guid, casterGuid, spellId, auraBar)
    if not record then return false end
    local at = GetTime()
    record.state, record.confirmedAt, record.failureAt =
        "application-confirmed", at, nil
    record.untilAt = at + APPLICATION_VISIBILITY_GRACE
    detachCurrent(self, record, key)
    local lifecycle = self:Lifecycle(record.spellId, record.casterGuid,
        record.target, false)
    if lifecycle then
        lifecycle.state, lifecycle.confirmedAt, lifecycle.failureAt,
            lifecycle.lastAt = "application-confirmed", at, nil, at
    end
    return true
end

function XA:HoldAuraPendingUncertain(name, guid, casterGuid, spellId, auraBar,
    state)
    local record, key = exactApplicationRecord(
        self, name, guid, casterGuid, spellId, auraBar)
    if not record then return nil end
    local at = GetTime()
    record.state, record.confirmedAt, record.failureAt =
        state or "application-uncertain", nil, nil
    record.untilAt = at + APPLICATION_VISIBILITY_GRACE
    detachCurrent(self, record, key)
    local lifecycle = self:Lifecycle(record.spellId, record.casterGuid,
        record.target, false)
    if lifecycle then
        lifecycle.state, lifecycle.confirmedAt, lifecycle.failureAt,
            lifecycle.lastAt = record.state, nil, nil, at
    end
    return record
end

-- SPELL_DELAYED_SELF is exact evidence that the active player cast was pushed
-- back. Its payload has no spell id, so extend only a unique reservation still
-- in the server-started phase. This can sit behind a newer queued aura without
-- attributing delay to an older landed aura or an ambiguous stale cast.
function XA:DelayCurrentPendingAura(casterGuid, delayMs)
    local record, candidate = nil, nil
    for _, candidate in pairs(self.pendingAuras or {}) do
        if candidate.casterGuid == casterGuid
            and candidate.state == "started" then
            if record then return false end
            record = candidate
        end
    end
    if not record then return false end
    local delay = math.max(0, tonumber(delayMs) or 0) / 1000
    if delay <= 0 then return false end
    local hardUntil = (tonumber(record.submittedAt) or GetTime())
        + MAX_APPLICATION_RESERVATION
    record.untilAt = math.min(hardUntil,
        (tonumber(record.untilAt) or GetTime()) + delay)
    record.delayedAt = GetTime()
    record.delaySeconds = (tonumber(record.delaySeconds) or 0) + delay
    local lifecycle = self:Lifecycle(record.spellId, record.casterGuid,
        record.target, false)
    if lifecycle then
        lifecycle.delayedAt, lifecycle.delaySeconds, lifecycle.lastAt =
            GetTime(), (tonumber(lifecycle.delaySeconds) or 0) + delay, GetTime()
    end
    return true
end
