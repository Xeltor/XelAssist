-- Bounded, session-only evidence for Nampower and SuperWoW hostile casts.
-- GUIDs remain opaque identities; no name, unit token or SavedVariables state
-- is retained. Ownership must be decided explicitly by the event caller.
XelAssist.Game.HostileCasts = {}
local C = XelAssist.Game.HostileCasts

C.MAX_CASTS = 16

local function now(value)
    value = tonumber(value)
    if value then return value end
    return GetTime and GetTime() or 0
end

local function exactGuid(value)
    if value == nil then return nil end
    if type(value) == "string" then
        if value == "" or string.find(value, "^0+$")
            or string.find(value, "^0[xX]0+$") then return nil end
    end
    return value
end

local function copy(record, at)
    if not record then return nil end
    local out, key, value = {}, nil, nil
    for key, value in pairs(record) do out[key] = value end
    out.remaining = math.max(0, record.deadline - at)
    return out
end

local function state(owner)
    if not owner.byCaster then owner.byCaster = {} end
    owner.generation = tonumber(owner.generation) or 0
    return owner.byCaster
end

local function remove(owner, casterGuid)
    local casts = state(owner)
    local record = casts[casterGuid]
    casts[casterGuid] = nil
    return record
end

local function count(casts)
    local total, _ = 0, nil
    for _ in pairs(casts) do total = total + 1 end
    return total
end

local function evictOldest(owner)
    local casts = state(owner)
    if count(casts) < owner.MAX_CASTS then return end
    local oldestGuid, oldestGeneration, guid, record = nil, nil, nil, nil
    for guid, record in pairs(casts) do
        if oldestGeneration == nil or record.generation < oldestGeneration then
            oldestGuid, oldestGeneration = guid, record.generation
        end
    end
    if oldestGuid ~= nil then casts[oldestGuid] = nil end
end

local function terminalMatches(record, targetGuid, spellId)
    if not record or record.spellId ~= spellId then return false end
    return not (record.targetGuid ~= nil and targetGuid ~= nil
        and record.targetGuid ~= targetGuid)
end

local function ownership(owner, casterGuid, owned)
    casterGuid = exactGuid(casterGuid)
    if casterGuid == nil then return nil, "caster identity unavailable" end
    if owned == true then
        remove(owner, casterGuid)
        return nil, "owned cast excluded"
    elseif owned ~= false then
        return nil, "caster ownership unavailable"
    end
    return casterGuid
end

local function begin(owner, casterGuid, targetGuid, status, spellId,
    durationMs, owned, observedAt, details)
    observedAt = now(observedAt)
    owner:Expire(observedAt)
    local reason
    casterGuid, reason = ownership(owner, casterGuid, owned)
    if casterGuid == nil then return nil, reason end
    targetGuid = exactGuid(targetGuid)
    spellId, durationMs = tonumber(spellId), tonumber(durationMs)
    if not spellId or spellId <= 0 then return nil, "spell identity unavailable" end
    if not durationMs or durationMs <= 0 then
        return nil, "cast duration unavailable"
    end
    local casts = state(owner)
    local previous = casts[casterGuid]
    if not previous then evictOldest(owner) end
    owner.generation = owner.generation + 1
    local record = {
        casterGuid = casterGuid,
        targetGuid = targetGuid,
        targetKnown = targetGuid ~= nil,
        spellId = spellId,
        status = status,
        channel = status == "CHANNEL",
        active = true,
        generation = owner.generation,
        startedAt = observedAt,
        durationMs = durationMs,
        deadline = observedAt + durationMs / 1000,
        source = details and details.source or "SuperWoW UNIT_CASTEVENT",
        targetlessTerminalAmbiguous = previous ~= nil
            and previous.spellId == spellId or false,
    }
    local key, value = nil, nil
    for key, value in pairs(details or {}) do
        if key ~= "source" then record[key] = value end
    end
    state(owner)[casterGuid] = record
    return copy(record, observedAt), "cast observed"
end

local function finish(owner, casterGuid, targetGuid, spellId, status,
    owned, observedAt)
    observedAt = now(observedAt)
    local reason
    casterGuid, reason = ownership(owner, casterGuid, owned)
    if casterGuid == nil then return nil, reason end
    targetGuid, spellId = exactGuid(targetGuid), tonumber(spellId)
    if not spellId or spellId <= 0 then return nil, "spell identity unavailable" end
    local active = state(owner)[casterGuid]
    -- Capture the exact terminal match before ordinary deadline cleanup: a GO
    -- normally arrives at the deadline and is still authoritative completion.
    owner:Expire(observedAt)
    if not terminalMatches(active, targetGuid, spellId) then
        return nil, "no matching active cast"
    end
    if active.targetGuid == nil and targetGuid ~= nil then
        active.targetGuid, active.targetKnown = targetGuid, true
        active.targetEnriched = true
    end
    if status == "CAST" and active.channel
        and active.deadline > observedAt then
        active.castObserved = true
        return copy(active, observedAt), "channel remains active"
    end
    remove(owner, casterGuid)
    local ended = copy(active, observedAt)
    ended.active = false
    ended.terminalStatus = status
    return ended, status == "CAST" and "cast completed" or "cast failed"
end

function C:Expire(at)
    at = now(at)
    local casts, expired, guid, record = state(self), 0, nil, nil
    for guid, record in pairs(casts) do
        if record.deadline <= at then
            casts[guid] = nil
            expired = expired + 1
        end
    end
    return expired
end

function C:Reset()
    self.byCaster = {}
    self.generation = 0
end

-- The caller must pass owned=true for the player or a controlled actor and
-- owned=false for a proven non-owned caster. Unknown ownership is discarded.
function C:Observe(casterGuid, targetGuid, status, spellId, durationMs,
    owned, observedAt)
    if status ~= "START" and status ~= "CHANNEL"
        and status ~= "CAST" and status ~= "FAIL" then
        return nil, "unsupported cast status"
    end
    if status == "CAST" or status == "FAIL" then
        return finish(self, casterGuid, targetGuid, spellId, status,
            owned, observedAt)
    end
    return begin(self, casterGuid, targetGuid, status, spellId, durationMs,
        owned, observedAt)
end

function C:ObserveUnitCast(casterGuid, targetGuid, status, spellId,
    durationMs, owned, observedAt)
    if status == "START" or status == "CHANNEL" then
        observedAt = now(observedAt)
        self:Expire(observedAt)
        local exactCaster, reason = ownership(self, casterGuid, owned)
        if exactCaster == nil then return nil, reason end
        local exactTarget = exactGuid(targetGuid)
        local numericSpell = tonumber(spellId)
        local active = state(self)[exactCaster]
        if active and active.source == "Nampower START_OTHER" then
            if active.spellId ~= numericSpell then
                return copy(active, observedAt),
                    "different-spell fallback cast ignored"
            end
            local compatible = not (active.targetGuid ~= nil and exactTarget ~= nil
                and active.targetGuid ~= exactTarget)
            if not compatible then
                return copy(active, observedAt),
                    "conflicting fallback cast ignored"
            end
            if active.targetGuid == nil and exactTarget ~= nil then
                active.targetGuid, active.targetKnown = exactTarget, true
                active.targetEnriched = true
            end
            active.unitCastCorroborated = true
            active.unitCastStatus = status
            return copy(active, observedAt), "cast corroborated"
        end
    end
    return self:Observe(casterGuid, targetGuid, status, spellId, durationMs,
        owned, observedAt)
end

-- Nampower START_OTHER exposes separate cast and channel occupancy. Spell type
-- 1 is the authoritative channel discriminator; a non-zero channel duration
-- alone is retained as evidence but never changes a normal spell into one.
function C:ObserveStartOther(casterGuid, targetGuid, spellId, castTimeMs,
    channelDurationMs, spellType, owned, observedAt)
    castTimeMs = tonumber(castTimeMs) or 0
    channelDurationMs = tonumber(channelDurationMs) or 0
    spellType = tonumber(spellType)
    local channel = spellType == 1
    local durationMs = castTimeMs
    if channel then durationMs = durationMs + channelDurationMs end
    return begin(self, casterGuid, targetGuid,
        channel and "CHANNEL" or "START", spellId,
        durationMs, owned, observedAt, {
            castTimeMs = castTimeMs,
            channelDurationMs = channelDurationMs,
            spellType = spellType,
            source = "Nampower START_OTHER",
        })
end

function C:ObserveGoOther(casterGuid, targetGuid, spellId, owned, observedAt)
    local active = owned == false and self:Active(casterGuid, observedAt) or nil
    if active and active.spellId == tonumber(spellId)
        and active.targetlessTerminalAmbiguous
        and exactGuid(targetGuid) == nil then
        return active, "ambiguous targetless terminal"
    end
    return finish(self, casterGuid, targetGuid, spellId, "CAST",
        owned, observedAt)
end

-- FAILED_OTHER carries no target. One active generation per exact caster lets
-- caster+spell clear that generation without manufacturing a recipient.
function C:ObserveFailedOther(casterGuid, spellId, owned, observedAt)
    local active = owned == false and self:Active(casterGuid, observedAt) or nil
    if active and active.spellId == tonumber(spellId)
        and active.targetlessTerminalAmbiguous then
        return active, "ambiguous targetless terminal"
    end
    return finish(self, casterGuid, nil, spellId, "FAIL", owned, observedAt)
end

function C:Active(casterGuid, at)
    at = now(at)
    self:Expire(at)
    return copy(state(self)[exactGuid(casterGuid)], at)
end

function C:Snapshot(at)
    at = now(at)
    self:Expire(at)
    local out, _, record = {}, nil, nil
    for _, record in pairs(state(self)) do
        table.insert(out, copy(record, at))
    end
    table.sort(out, function(first, second)
        return first.generation < second.generation
    end)
    return out
end

-- Generation matching lets a future interrupt/cancellation path remove only
-- the cast that it actually observed, never a replacement cast by that GUID.
function C:Cancel(casterGuid, generation)
    casterGuid = exactGuid(casterGuid)
    local record = casterGuid ~= nil and state(self)[casterGuid] or nil
    if not record or record.generation ~= tonumber(generation) then return false end
    remove(self, casterGuid)
    return true
end
