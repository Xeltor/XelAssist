-- Session-only ownership of Nampower's single normal player-spell queue slot.
-- On-swing and non-GCD queues are independent and never enter this latch.
local Q = {}
XelAssist.Core.PlayerNormalQueue = Q

local NORMAL_QUEUED = 2
local NORMAL_POPPED = 3
local MIN_HOLD_SECONDS = 5
local MAX_HOLD_SECONDS = 120
local NORMAL_CAST_TYPE = { [0] = true, [3] = true, [4] = true }

local function now()
    return GetTime and tonumber(GetTime()) or 0
end

local function sameSpell(record, spellId)
    return record and tonumber(record.spellId) ~= nil
        and tonumber(record.spellId) == tonumber(spellId)
end

local function usableAttemptId(value)
    if value == nil then return nil end
    value = tostring(value)
    if value == "" or value == "0" then return nil end
    return value
end

local function holdSeconds(wait, cast)
    local duration = math.max(0, tonumber(wait) or 0)
        + math.max(0, tonumber(cast) or 0) + MIN_HOLD_SECONDS
    return math.max(MIN_HOLD_SECONDS,
        math.min(MAX_HOLD_SECONDS, duration))
end

function Q:Reset()
    self.current = nil
    self.eventSerial = 0
end

function Q:NextEvent()
    self.eventSerial = (tonumber(self.eventSerial) or 0) + 1
    return self.eventSerial
end

local function targetMatches(record, targetGuid)
    return record and (record.targetGuid == nil or targetGuid == nil
        or record.targetGuid == targetGuid)
end

local function clearFailureCandidate(record)
    record.failureCandidateId, record.failureCandidateSerial,
        record.failureCandidateRetrySerial = nil, nil, nil
end

function Q:Sweep(resolveFailure)
    local current, at = self.current, now()
    if current and (not current.deadline or current.deadline <= at
        or tonumber(current.armedAt) and current.armedAt > at + 1) then
        self.current = nil
    elseif current and resolveFailure and (current.phase == "failure-pending"
        or current.phase == "client-failed") then
        -- Failure evidence is delivered before Nampower can synchronously emit
        -- a retry/pop. A new /xa submission proves that callback has returned
        -- without more evidence, so the latch may be released.
        self.current = nil
    end
    return self.current
end

function Q:MayOccupy(action, tooltip)
    return XelAssist.Game.SpellClassification:NormalGcd(action, tooltip)
end

function Q:Blocker(action, tooltip)
    if not self:MayOccupy(action, tooltip) then return nil end
    local current = self:Sweep(true)
    if not current then return nil end
    if current.owner == "xelassist" then
        return "normal player spell already queued"
    end
    return "normal player spell queue occupied"
end

function Q:Arm(action, tooltip, spellName, targetGuid, wait, cast)
    local blocker = self:Blocker(action, tooltip)
    if blocker then return nil, blocker end
    local at = now()
    local duration = holdSeconds(wait, cast)
    local record = { owner = "xelassist", phase = "arming",
        spellId = action and action.spellId, spellName = spellName,
        targetGuid = targetGuid, armedAt = at,
        holdDuration = duration, deadline = at + duration }
    self.current = record
    return record, nil
end

-- QueueSpellByName can synchronously emit queue/cast events. Missing events
-- are uncertainty, so a dispatched provisional arm remains latched briefly.
function Q:Finalize(record, dispatched)
    if not dispatched then
        if self.current == record then self.current = nil end
        return false, "dispatch failed"
    end
    if self.current ~= record then
        if record.phase == "client-failed"
            or record.phase == "failure-pending"
            or record.phase == "dropped" then
            return false, "client cast failed"
        end
        return true, nil
    end
    if record.phase == "client-failed" or record.phase == "failure-pending"
        or record.phase == "pre-cast-failure" then
        self.current = nil
        return false, "client cast failed"
    end
    if record.phase == "non-normal" then
        self.current = nil
        return true, nil
    end
    if self.current == record and (record.phase == "arming"
        or record.phase == "pre-dispatch-pop") then
        record.phase = "unknown"
    end
    return true, nil
end

function Q:QueueEvent(queueCode, spellId)
    queueCode = tonumber(queueCode)
    local serial, at, current = self:NextEvent(), now(), self:Sweep(false)
    if queueCode == NORMAL_QUEUED then
        if current and (current.phase == "arming" or current.phase == "queued"
            or current.phase == "attempted" or current.phase == "popped"
            or current.phase == "failure-pending" or current.phase == "unknown"
            or current.phase == "pre-dispatch-pop"
            or current.phase == "pre-cast-failure")
            and (current.spellId == nil or sameSpell(current, spellId)) then
            current.spellId = tonumber(spellId) or current.spellId
            current.phase, current.queuedAt = "queued", at
            current.attemptId, current.attemptSerial = nil, nil
            current.retrySerial = current.failedSerial
                and serial > current.failedSerial and serial or current.retrySerial
            if current.failureCandidateSerial
                and serial > current.failureCandidateSerial then
                current.failureCandidateRetrySerial = serial
            end
            current.deadline = math.max(current.deadline or 0,
                at + (tonumber(current.holdDuration) or MIN_HOLD_SECONDS))
            return current
        end
        self.current = { owner = "external", phase = "queued",
            spellId = tonumber(spellId), armedAt = at, queuedAt = at,
            deadline = at + MAX_HOLD_SECONDS }
        return self.current
    end
    if queueCode == NORMAL_POPPED then
        if sameSpell(current, spellId) then
            if current.phase == "client-failed" then
                self.current = nil
            elseif current.phase == "attempted" then
                current.phase, current.poppedAt = "popped", at
                current.deadline = math.max(current.deadline or 0,
                    at + MIN_HOLD_SECONDS)
            elseif current.phase == "queued" and current.ignoreNextPop then
                -- A confirmed local retry was queued inside the failed old
                -- generation. This pop retires the old attempt, not the retry.
                current.ignoreNextPop, current.priorPoppedAt = nil, at
                current.deadline = math.max(current.deadline or 0,
                    at + (tonumber(current.holdDuration) or MIN_HOLD_SECONDS))
                return current, "prior-generation-pop"
            elseif current.phase == "queued" or current.phase == "unknown" then
                -- A real queued attempt emits SPELL_CAST_EVENT before code 3.
                -- Without it, Nampower cancelled, expired, or dropped the slot.
                current.phase = "dropped"
                self.current = nil
            elseif current.phase == "arming" then
                -- This can be an older same-spell slot popped inside the new
                -- QueueSpellByName call. Let a later synchronous event win.
                current.phase, current.preDispatchPopAt = "pre-dispatch-pop", at
            else return false end
            return current
        end
    end
    if (queueCode == 0 or queueCode == 1 or queueCode == 4 or queueCode == 5)
        and current and current.owner == "xelassist"
        and (current.phase == "arming" or current.phase == "pre-dispatch-pop")
        and (current.spellId == nil or sameSpell(current, spellId)) then
        current.phase = "non-normal"
        return current
    end
    return false
end

-- SPELL_CAST_EVENT is client-attempt evidence, not server acceptance. Keeping
-- this state closes the latency window in which repeated taps could replace a
-- cast that has left Nampower's queue but has not yet reached the server.
function Q:CastEvent(result, spellId, castType, targetGuid, attemptId)
    local serial, current = self:NextEvent(), self:Sweep(false)
    if not current or (current.phase ~= "arming" and current.phase ~= "queued"
        and current.phase ~= "unknown"
        and current.phase ~= "pre-dispatch-pop"
        and current.phase ~= "pre-cast-failure") then
        return false
    end
    if current.spellId ~= nil and not sameSpell(current, spellId) then return false end
    if not targetMatches(current, targetGuid) then return false end
    if not NORMAL_CAST_TYPE[tonumber(castType)] then
        if current.owner == "xelassist"
            and (current.phase == "arming" or current.phase == "unknown"
                or current.phase == "pre-dispatch-pop") then
            current.phase = "non-normal"
            return current
        end
        return false
    end
    local suppliedAttempt = usableAttemptId(attemptId)
    current.spellId = tonumber(spellId) or current.spellId
    current.targetGuid = current.targetGuid or targetGuid
    if tonumber(result) ~= 1 and current.failureCandidateId
        and suppliedAttempt == current.failureCandidateId then
        local retried = current.failureCandidateRetrySerial
            and current.failureCandidateSerial
            and current.failureCandidateRetrySerial
                > current.failureCandidateSerial
        clearFailureCandidate(current)
        if retried then
            current.phase, current.attemptId, current.attemptSerial =
                "queued", nil, nil
            current.ignoreNextPop = true
            return current, "retry-preserved"
        end
    else
        -- Any matching-target cast event is the current generation. An older
        -- exact failure candidate that names another attempt cannot claim it.
        clearFailureCandidate(current)
    end
    if tonumber(result) ~= 1 and current.failedAttemptId
        and suppliedAttempt == current.failedAttemptId
        and current.retrySerial and current.failedSerial
        and current.retrySerial > current.failedSerial then
        -- Nampower emits a local failure inside the cast trampoline. Its
        -- synchronous retry code 2 therefore precedes this outer result 0.
        -- The failed generation ended, but the retry still owns the slot.
        current.phase, current.attemptId, current.attemptSerial =
            "queued", nil, nil
        current.failedAttemptId, current.failedSerial,
            current.retrySerial = nil, nil, nil
        return current, "retry-preserved"
    end
    current.attemptId = suppliedAttempt
    current.attemptSerial, current.attemptedAt = serial, now()
    if tonumber(result) == 1 then
        current.phase = "attempted"
        current.deadline = math.max(current.deadline or 0,
            current.attemptedAt + MIN_HOLD_SECONDS)
    else current.phase = "client-failed" end
    return current
end

local function attemptMatches(record, attemptId)
    local supplied = usableAttemptId(attemptId)
    if record.attemptId ~= nil then return supplied == record.attemptId end
    return supplied == nil
end

function Q:ServerAccepted(spellId, targetGuid, attemptId)
    self:NextEvent()
    local current = self:Sweep(false)
    if not current or (current.phase ~= "attempted"
        and current.phase ~= "popped")
        or not sameSpell(current, spellId)
        or not targetMatches(current, targetGuid)
        or not attemptMatches(current, attemptId) then return false end
    current.phase = "server-accepted"
    self.current = nil
    return true
end

function Q:ServerFailure(spellId, targetGuid, attemptId)
    local serial, current = self:NextEvent(), self:Sweep(false)
    local suppliedAttempt = usableAttemptId(attemptId)
    if not current or not sameSpell(current, spellId)
        or not targetMatches(current, targetGuid) then return false end
    if (current.phase == "arming" or current.phase == "pre-dispatch-pop")
        and suppliedAttempt then
        current.phase, current.failedSerial = "pre-cast-failure", serial
        current.failedAttemptId, current.failedAt = suppliedAttempt, now()
        return current
    end
    if current.phase == "queued" and suppliedAttempt then
        -- Targetless failure evidence can belong to a prior same-spell cast.
        -- Defer attribution until its later CAST0 supplies the same attempt ID
        -- and a target matching this owned queue generation.
        current.failureCandidateId = suppliedAttempt
        current.failureCandidateSerial = serial
        current.failureCandidateRetrySerial = nil
        return false, "deferred"
    end
    if current.phase == "failure-pending"
        and attemptMatches(current, attemptId) then
        -- SPELL_CAST_RESULT_SELF precedes the matching legacy failure event.
        -- Return the already-attributed generation so reservation routing can
        -- treat that second event as exact rather than ambiguous.
        return current
    end
    if (current.phase ~= "attempted" and current.phase ~= "popped")
        or not attemptMatches(current, attemptId) then return false end
    current.phase, current.failedSerial = "failure-pending", serial
    current.failedAt = now()
    current.deadline = math.max(current.deadline or 0,
        current.failedAt + MIN_HOLD_SECONDS)
    return current
end

function Q:ServerResult(success, spellId, targetGuid, resultCode, attemptId)
    local serial, current = self:NextEvent(), self:Sweep(false)
    attemptId = usableAttemptId(attemptId)
    if not current or not attemptId or current.attemptId ~= attemptId
        or (current.phase ~= "attempted" and current.phase ~= "popped")
        or not sameSpell(current, spellId)
        or not targetMatches(current, targetGuid) then return false end
    if tonumber(success) == 1 then
        current.phase = "server-accepted"
        self.current = nil
        return true
    end
    current.phase, current.failedSerial = "failure-pending", serial
    current.failedAt, current.failureResult = now(), tonumber(resultCode)
    current.deadline = math.max(current.deadline or 0,
        current.failedAt + MIN_HOLD_SECONDS)
    return current
end

function Q:Current()
    return self:Sweep()
end
