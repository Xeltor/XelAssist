-- Session-only ownership for the player's single on-next-swing lane.
-- Nampower's exact slot is authoritative; spell names and arrival order never
-- substitute for a nonzero native attempt identity.
XelAssist.Game.Player.OnSwing = {}
local O = XelAssist.Game.Player.OnSwing
local CAST_TYPE_ON_SWING, PROVISIONAL_HOLD, RECENT_HOLD, MAX_RECENT = 2, 0.35, 8, 8
local ARMED, BUFFERED, ARMED_REPLACED, BUFFER_REPLACED = 0, 1, 2, 3
local BUFFER_POPPED, CONSUMED, FAILED, CANCELLED, BUFFER_CANCELLED = 4, 5, 6, 7, 8
local function now()
    if type(GetTime) ~= "function" then return 0 end
    local ok, value = pcall(GetTime)
    return ok and tonumber(value) or 0
end
local function truth(value) return value == true or tonumber(value) == 1 end
local function presentGuid(value)
    if value == nil or value == 0 or value == "0"
        or value == "0x000000000" or value == "0x0000000000000000" then return nil end
    return value
end
local function attempt(value)
    value = tostring(value or "0")
    return value ~= "" and value ~= "0" and value or nil
end
local function sameGeneration(record, spellId, attemptId)
    local identity = attempt(attemptId)
    return record and identity and attempt(record.attemptId) == identity
        and tonumber(record.spellId) == tonumber(spellId)
end
local function compatible(record, spellId, targetGuid)
    if not record or tonumber(record.spellId) ~= tonumber(spellId) then return false end
    targetGuid = presentGuid(targetGuid)
    return record.targetGuid == nil or targetGuid == nil
        or record.targetGuid == targetGuid
end
local function nativeInfo()
    if type(GetOnSwingInfo) ~= "function" then return nil, false end
    local ok, info = pcall(GetOnSwingInfo)
    if not ok then return nil, false end
    if info == nil then return { armed = false, buffered = false }, true end
    if type(info) ~= "table" then return nil, false end
    local armed = truth(info.armed) or truth(info.pending)
    local buffered = truth(info.buffered)
    return { armed = armed, spellId = armed and tonumber(info.spellId) or nil,
        targetGuid = armed and presentGuid(info.targetGuid) or nil,
        attemptId = armed and tostring(info.attemptId or "0") or "0",
        buffered = buffered,
        bufferedSpellId = buffered and tonumber(info.bufferedSpellId) or nil,
        bufferedTargetGuid = buffered and presentGuid(info.bufferedTargetGuid) or nil,
        bufferedAttemptId = buffered and tostring(info.bufferedAttemptId or "0") or "0" }, true
end
local function fallbackPending()
    if type(GetCurrentCastingInfo) ~= "function" then return nil, false end
    local ok, _, _, _, _, _, pending = pcall(GetCurrentCastingInfo)
    if not ok then return nil, false end
    if pending == true or tonumber(pending) == 1 then return true, true end
    if pending == false or tonumber(pending) == 0 then return false, true end
    return nil, false
end
local function newRecord(owner, phase, spellId, targetGuid, attemptId)
    return { owner = owner, phase = phase, spellId = tonumber(spellId),
        targetGuid = presentGuid(targetGuid), attemptId = attempt(attemptId) or "0",
        observedAt = now(), graceUntil = now() + PROVISIONAL_HOLD }
end
local function copyMetadata(from, into)
    if not (from and into) then return into end
    into.owner, into.action, into.tooltip = from.owner, from.action, from.tooltip
    into.rawPower, into.cost, into.costKnown, into.submissionId, into.submittedAt =
        from.rawPower, from.cost, from.costKnown, from.submissionId, from.submittedAt
    return into
end
local function copyRecord(record)
    if not record then return nil end
    return { owner = record.owner, phase = record.phase,
        spellId = record.spellId, targetGuid = record.targetGuid,
        attemptId = record.attemptId, action = record.action,
        tooltip = record.tooltip, rawPower = record.rawPower, cost = record.cost, costKnown = record.costKnown,
        replayedFromAttemptId = record.replayedFromAttemptId }
end
function O:Remember(record, phase)
    if not record then return nil end
    if self.armed == record then self.armed = nil end
    if self.buffered == record then self.buffered = nil end
    if self.submission == record then self.submission = nil end
    record.phase, record.terminalAt = phase or record.phase, now()
    self.recent = self.recent or {}
    table.insert(self.recent, record)
    while table.getn(self.recent) > MAX_RECENT do table.remove(self.recent, 1) end
    return record
end
function O:Recent(spellId, attemptId, unresolvedOnly)
    local at, index = now(), table.getn(self.recent or {})
    while index >= 1 do
        local record = self.recent[index]
        if at - (tonumber(record.terminalAt) or at) > RECENT_HOLD then
            table.remove(self.recent, index)
        elseif (not attemptId or sameGeneration(record, spellId, attemptId))
            and (attemptId or tonumber(record.spellId) == tonumber(spellId))
            and (not unresolvedOnly or not record.deliveryReturned) then
            return record
        end
        index = index - 1
    end
    return nil
end
function O:Reset(reason)
    self.submission, self.armed, self.buffered, self.replaySource = nil, nil, nil, nil
    self.recent, self.lastResetReason = {}, reason or "session reset"
end
function O:Is(action, tooltip)
    local facts = action and action.facts or {}
    return facts.onNextSwing or facts.onSwing or tooltip
        and (tooltip.onNextSwing or tooltip.onSwing) and true or false
end
function O:Bind(slot, spellId, targetGuid, attemptId)
    local record = self[slot]
    if sameGeneration(record, spellId, attemptId) then
        record.targetGuid = presentGuid(targetGuid) or record.targetGuid
        return record
    end
    if record then self:Remember(record, slot .. " replaced without matching event") end
    record = newRecord("external", slot, spellId, targetGuid, attemptId)
    self[slot] = record
    return record
end
function O:ReconcileExact(info)
    if info.armed and self.buffered and self.buffered.owner == "xelassist"
        and compatible(self.buffered, info.spellId, info.targetGuid)
        and not sameGeneration(self.buffered, info.spellId, info.attemptId) then
        self.replaySource = self.buffered
    end
    if info.armed then
        self:Bind("armed", info.spellId, info.targetGuid, info.attemptId)
    elseif self.armed then self:Remember(self.armed, "native armed slot absent") end
    if info.buffered then
        self:Bind("buffered", info.bufferedSpellId, info.bufferedTargetGuid,
            info.bufferedAttemptId)
    elseif self.buffered then self:Remember(self.buffered, "native buffer absent") end
    if self.submission and not info.armed and not info.buffered
        and (tonumber(self.submission.graceUntil) or 0) <= now() then
        self:Remember(self.submission, "submission produced no native generation")
    end
end
function O:ReconcileFallback(live, known)
    local at = now()
    if live == true and not self.armed then
        self.armed = newRecord("external", "armed-identity-unknown", nil, nil, nil)
    elseif live == false and self.armed and not self.buffered
        and (tonumber(self.armed.graceUntil) or 0) <= at then
        self:Remember(self.armed, "fallback pending flag cleared")
    end
    if self.buffered and self.buffered.phase == "buffer-pop-pending"
        and live == false and (tonumber(self.buffered.graceUntil) or 0) <= at then
        self:Remember(self.buffered, "fallback buffer pop settled")
    end
    if self.submission and live == false and not self.buffered
        and (tonumber(self.submission.graceUntil) or 0) <= at then
        self:Remember(self.submission, "fallback submission absent")
    end
end
function O:Reconcile()
    local info, exact = nativeInfo()
    if exact then self:ReconcileExact(info) return info, true end
    local live, known = fallbackPending()
    self:ReconcileFallback(live, known)
    return { armed = live == true, buffered = self.buffered ~= nil }, false, known
end
function O:Snapshot()
    local info, exact, liveKnown = self:Reconcile()
    local active = self.armed or self.submission or self.buffered
    local out = copyRecord(active) or {}
    out.supported = exact or type(GetCurrentCastingInfo) == "function"
    out.exact, out.liveKnown = exact, exact or liveKnown
    out.pending = info.armed or self.submission ~= nil
    out.buffered = info.buffered or self.buffered ~= nil
    out.occupied = out.pending or out.buffered
    out.bufferedSpellId = self.buffered and self.buffered.spellId
        or info.bufferedSpellId
    out.bufferedTargetGuid = self.buffered and self.buffered.targetGuid
        or info.bufferedTargetGuid
    out.bufferedAttemptId = self.buffered and self.buffered.attemptId
        or info.bufferedAttemptId
    out.bufferedOwner = self.buffered and self.buffered.owner
    out.source = exact and "Nampower exact on-swing state"
        or "Nampower 4.7 pending flag plus session evidence"
    return out
end
function O:Blocker(action, tooltip)
    if not self:Is(action, tooltip) then return nil end
    local state = self:Snapshot()
    if state.occupied then
        return state.owner == "xelassist" and "next-swing action already armed"
            or "next-swing action lane occupied"
    end
    if not state.supported then return "next-swing state unavailable" end
    return nil
end
function O:Owned(spellId)
    self:Reconcile()
    local record = self.armed or self.submission
    if record and record.owner == "xelassist"
        and tonumber(record.spellId) == tonumber(spellId) then return record end
    return nil
end
function O:Arm(action, tooltip, targetGuid, rawPower, cost, costKnown)
    if not self:Is(action, tooltip) then return nil, "not an on-next-swing action" end
    local blocker = self:Blocker(action, tooltip)
    if blocker then return nil, blocker end
    local spellId = tonumber(action and action.spellId)
    if not spellId then return nil, "next-swing spell identity unavailable" end
    self.submissionSerial = (tonumber(self.submissionSerial) or 0) + 1
    local record = newRecord("xelassist", "submitting", spellId, targetGuid, nil)
    record.action, record.tooltip, record.rawPower, record.cost, record.costKnown =
        action, tooltip, rawPower, tonumber(cost), costKnown ~= false
    record.submissionId, record.submittedAt = self.submissionSerial, now()
    self.submission = record
    return record, nil
end
function O:Submitted(action, tooltip, targetGuid, rawPower, cost, costKnown)
    if self.submission and compatible(self.submission,
        action and action.spellId, targetGuid) then
        self.submission.action, self.submission.tooltip = action, tooltip
        self.submission.rawPower, self.submission.cost, self.submission.costKnown = rawPower, tonumber(cost), costKnown ~= false
        return self.submission, nil
    end
    return self:Arm(action, tooltip, targetGuid, rawPower, cost, costKnown)
end
function O:OwnGeneration(record, slot, phase, spellId, targetGuid, attemptId)
    local current = self[slot]
    if not current or not sameGeneration(current, spellId, attemptId) then return nil end
    if record == self.submission then
        record.spellId, record.targetGuid = tonumber(spellId),
            presentGuid(targetGuid) or record.targetGuid
        record.attemptId, record.phase = attempt(attemptId) or "0", phase
        self.submission, self[slot] = nil, record
        current = record
    elseif record then
        copyMetadata(record, current)
        current.owner = "xelassist"
    end
    current.phase = phase
    current.targetGuid = presentGuid(targetGuid) or current.targetGuid
    return current
end
function O:CastEvent(success, spellId, castType, targetGuid, attemptId)
    if tonumber(castType) ~= CAST_TYPE_ON_SWING then return nil end
    spellId, targetGuid = tonumber(spellId), presentGuid(targetGuid)
    local info, exact = self:Reconcile()
    local slot = info.armed and sameGeneration(self.armed, spellId, attemptId)
        and "armed" or info.buffered and sameGeneration(self.buffered,
            spellId, attemptId) and "buffered" or nil
    local candidate = compatible(self.submission, spellId, targetGuid) and self.submission or nil
    if not candidate and slot == "armed" and self.buffered
        and self.buffered.owner == "xelassist"
        and compatible(self.buffered, spellId, targetGuid) then
        candidate = self.buffered
    end
    if not candidate and slot == "armed" and self.replaySource
        and self.replaySource.owner == "xelassist"
        and compatible(self.replaySource, spellId, targetGuid) then
        candidate = self.replaySource
    end
    if exact and slot then
        local replay = candidate and candidate ~= self.submission
        local owned = self:OwnGeneration(candidate, slot,
            tonumber(success) == 1 and "attempted" or "client-failure-pending",
            spellId, targetGuid, attemptId)
        if replay and owned then
            owned.replayedFromAttemptId = candidate.attemptId
            if candidate == self.replaySource then self.replaySource = nil end
        end
        return owned
    end
    if not exact and candidate then
        local replay = candidate == self.buffered
        if tonumber(success) ~= 1 then
            candidate.attemptId = attempt(attemptId) or candidate.attemptId
            candidate.phase = "client-failure-pending"
            return candidate
        end
        local record
        if candidate == self.submission then
            record = candidate
            record.spellId, record.targetGuid = spellId, targetGuid or record.targetGuid
            record.attemptId, record.phase = attempt(attemptId) or "0", "attempted"
            self.submission = nil
        else
            record = newRecord("xelassist", "attempted", spellId, targetGuid, attemptId)
            copyMetadata(candidate, record)
        end
        if replay then
            record.replayedFromAttemptId = candidate.attemptId
            self:Remember(candidate, "buffer replay attempted")
        else self.submission = nil end
        self.armed = record
        return record
    end
    if self.submission and compatible(self.submission, spellId, targetGuid) then
        self.submission.attemptId = attempt(attemptId) or "0"
        self.submission.phase = "client-failure-pending"
        return self.submission
    end
    return nil
end
function O:Finalize(record, dispatched)
    if not record then return false, "next-swing ownership unavailable" end
    record.finalized = true
    local info, exact = self:Reconcile()
    local active = self.submission == record or self.armed == record
        or self.buffered == record
    if not dispatched then
        if self.armed == record or self.buffered == record then return true, nil end
        if active then self:Remember(record, "dispatch failed") end
        return false, "dispatch failed"
    end
    if not exact and active and record.phase == "client-failure-pending"
        and not info.armed and not info.buffered then
        self:Remember(record, "client cast failed")
        return false, "client cast failed"
    end
    if active and (not exact or self.armed == record or self.buffered == record) then
        return true, nil
    end
    local retired = self:Recent(record.spellId, record.attemptId)
    if retired and (retired.phase == "consumed" or retired.phase == "resolved") then
        return true, nil
    end
    if active then self:Remember(record, "native generation uncorrelated") end
    return false, "native next-swing generation was not correlated"
end
local function terminalSlot(code)
    return (code == BUFFER_REPLACED or code == BUFFER_POPPED
        or code == BUFFER_CANCELLED) and "buffered" or "armed"
end
function O:StateEvent(code, spellId, targetGuid, attemptId)
    code, spellId = tonumber(code), tonumber(spellId)
    if code == ARMED then
        self:Bind("armed", spellId, targetGuid, attemptId)
        self:Reconcile()
        return self.armed
    elseif code == BUFFERED then
        self:Bind("buffered", spellId, targetGuid, attemptId)
        self:Reconcile()
        return self.buffered
    end
    if code ~= ARMED_REPLACED and code ~= BUFFER_REPLACED
        and code ~= BUFFER_POPPED and code ~= CONSUMED and code ~= FAILED
        and code ~= CANCELLED and code ~= BUFFER_CANCELLED then return nil end
    if not attempt(attemptId) then
        self:Reconcile()
        return nil
    end
    local slot, record = terminalSlot(code), nil
    record = self[slot]
    if not sameGeneration(record, spellId, attemptId) and code == FAILED then
        slot = slot == "armed" and "buffered" or "armed"
        record = self[slot]
    end
    if not sameGeneration(record, spellId, attemptId) then
        local recent = self:Recent(spellId, attemptId)
        if code == BUFFER_POPPED and recent then
            recent.phase = "buffer-popped"
            if recent.owner == "xelassist" then self.replaySource = recent end
        elseif code == BUFFER_CANCELLED and recent then
            recent.phase = "buffer-cancelled"
            if sameGeneration(self.replaySource, spellId, attemptId) then self.replaySource = nil end
            if self.armed and attempt(self.armed.replayedFromAttemptId) == attempt(attemptId) then
                local armed = self.armed
                armed.owner, armed.action, armed.tooltip, armed.rawPower, armed.cost, armed.costKnown = "external", nil, nil, nil, nil, nil
                armed.submissionId, armed.submittedAt, armed.replayedFromAttemptId = nil, nil, nil
            end
        end
        self:Reconcile()
        return recent
    end
    local phases = { [ARMED_REPLACED] = "armed-replaced", [BUFFER_REPLACED] = "buffer-replaced",
        [BUFFER_POPPED] = "buffer-popped", [CONSUMED] = "consumed", [FAILED] = "failed",
        [CANCELLED] = "cancelled", [BUFFER_CANCELLED] = "buffer-cancelled" }
    if code == CONSUMED and self.buffered and self.buffered.owner == "xelassist" then
        self.replaySource = self.buffered
    elseif code == BUFFER_POPPED and record.owner == "xelassist" then self.replaySource = record end
    self:Remember(record, phases[code])
    self:Reconcile()
    if code == BUFFER_CANCELLED then self.replaySource = nil end
    return record
end
function O:QueueEvent(code, spellId)
    code, spellId = tonumber(code), tonumber(spellId)
    local _, exact = nativeInfo()
    if exact then
        self:Reconcile()
        return code == 0 and self.buffered or code == 1
            and self:Recent(spellId, nil) or nil
    end
    if code == 0 then
        if self.buffered and self.buffered.spellId == spellId then return self.buffered end
        local record = compatible(self.submission, spellId, nil) and self.submission
            or newRecord("external", "buffered", spellId, nil, nil)
        if record == self.submission then self.submission = nil end
        record.phase, record.graceUntil = "buffered", now() + PROVISIONAL_HOLD
        self.buffered = record
        return record
    elseif code == 1 and self.buffered and self.buffered.spellId == spellId then
        self.buffered.phase = "buffer-pop-pending"
        self.buffered.graceUntil = now() + PROVISIONAL_HOLD
        return self.buffered
    end
    return nil
end
function O:ServerResult(success, spellId, targetGuid, resultOrAttempt, attemptId)
    attemptId = attemptId or resultOrAttempt
    local record = sameGeneration(self.armed, spellId, attemptId) and self.armed
        or sameGeneration(self.buffered, spellId, attemptId) and self.buffered or nil
    if not record then return self:Recent(spellId, attemptId) end
    if tonumber(success) == 1 then
        record.phase = "server-armed"
        record.targetGuid = presentGuid(targetGuid) or record.targetGuid
    else record.phase = "server-failure-pending" end
    self:Reconcile()
    return record
end
function O:Failed(spellId, resultOrAttempt, failedByServer, attemptId)
    if attemptId == nil and failedByServer == nil then attemptId = resultOrAttempt end
    if not attempt(attemptId) then
        self:Reconcile()
        return nil
    end
    local record = sameGeneration(self.armed, spellId, attemptId) and self.armed
        or sameGeneration(self.buffered, spellId, attemptId) and self.buffered or nil
    if record then record.phase = "failure-pending" end
    self:Reconcile()
    return record or self:Recent(spellId, attemptId)
end
function O:Resolved(spellId, casterGuid, playerGuid, targetGuid)
    if casterGuid ~= playerGuid then return nil end
    local record = self:Recent(spellId, nil, true)
    if record and record.phase == "consumed" then
        record.deliveryReturned = true
        record.resolvedTargetGuid = presentGuid(targetGuid) or record.resolvedTargetGuid
        return record
    end
    local _, exact = nativeInfo()
    if exact or not self.armed or tonumber(self.armed.spellId) ~= tonumber(spellId) then
        return nil
    end
    record = self:Remember(self.armed, "resolved")
    record.deliveryReturned = true
    record.resolvedTargetGuid = presentGuid(targetGuid)
    return record
end
O:Reset("session start")
