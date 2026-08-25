-- Thin native-event bridge for the player's one on-next-swing owner. It keeps
-- exact queue identity, resistance submission, and main-hand phase anchoring
-- out of the general runtime dispatcher.
XelAssist.Game.Player.OnSwingEvents = {}
local E = XelAssist.Game.Player.OnSwingEvents
local OnSwing = XelAssist.Game.Player.OnSwing
local Rounds = XelAssist.Game.Player.AttackRounds

local CONSUMED = 5
local CONSUMED_GRACE = 0.75

local function now()
    if type(GetTime) ~= "function" then return 0 end
    local ok, value = pcall(GetTime)
    return ok and tonumber(value) or 0
end

local function playerGuid()
    if type(UnitExists) ~= "function" then return nil end
    local ok, exists, guid = pcall(UnitExists, "player")
    return ok and exists and guid or nil
end

local function sameSpell(record, spellId)
    return record and tonumber(record.spellId) == tonumber(spellId)
end

local function actualGuid(value)
    if value == nil or value == 0 or value == "0"
        or value == "0x000000000" or value == "0x0000000000000000" then return nil end
    return value
end

local function impactRecord(owner, casterGuid, spellId)
    if casterGuid ~= playerGuid() then return nil end
    local record = owner.lastConsumed
    if sameSpell(record, spellId)
        and now() - (tonumber(record.consumedAt) or 0) <= CONSUMED_GRACE then
        return record
    end
    return OnSwing:Owned(spellId)
end

local function submitImpact(record, targetGuid)
    if not (record and record.action and record.tooltip
        and targetGuid ~= nil) or record.impactSubmitted then return false end
    if XelAssist.Combat.Observations
        and XelAssist.Combat.Observations.SubmittedGuid then
        XelAssist.Combat.Observations:SubmittedGuid(
            record.action, targetGuid, record.tooltip)
        record.impactSubmitted = true
        return true
    end
    return false
end

local function anchorRound(record, targetGuid)
    if not (Rounds and record and targetGuid ~= nil) then return false end
    return Rounds:ObserveOnSwingGo(playerGuid(), targetGuid, {
        action = record.action, tooltip = record.tooltip,
        onNextSwing = true, actor = "player", hand = "main",
        attemptId = record.attemptId, exact = record.exact ~= false,
        exactAttempt = record.exact ~= false, phase = record.phase,
        outcome = "owned on-swing consumed",
    }, now())
end

function E:Reset(reason)
    self.lastConsumed = nil
    OnSwing:Reset(reason)
end

function E:State(code, spellId, targetGuid, attemptId)
    local record = OnSwing:StateEvent(code, spellId, targetGuid, attemptId)
    if tonumber(code) ~= CONSUMED or not record then return record end
    record.consumedAt = now()
    self.lastConsumed = record
    return record
end

function E:Miss(casterGuid, targetGuid, spellId)
    local record = impactRecord(self, casterGuid, spellId)
    targetGuid = actualGuid(targetGuid)
    if not record or not targetGuid then return nil end
    submitImpact(record, targetGuid)
    anchorRound(record, targetGuid)
    return record
end

function E:Damage(targetGuid, casterGuid, spellId)
    local record = impactRecord(self, casterGuid, spellId)
    targetGuid = actualGuid(targetGuid)
    if not record or not targetGuid then return nil end
    submitImpact(record, targetGuid)
    anchorRound(record, targetGuid)
    return record
end

function E:Go(spellId, casterGuid, targetGuid)
    local record = OnSwing:Resolved(
        spellId, casterGuid, playerGuid(), targetGuid)
    local cached = self.lastConsumed
    if not record and sameSpell(cached, spellId)
        and now() - (tonumber(cached.consumedAt) or 0) <= CONSUMED_GRACE then
        record = cached
    end
    if not record then return nil end
    targetGuid = actualGuid(targetGuid)
    if targetGuid then
        submitImpact(record, targetGuid)
        anchorRound(record, targetGuid)
    end
    self.lastConsumed = nil
    return record
end

function E:Handle(eventName, a1, a2, a3, a4, a5, a6)
    if eventName == "SPELL_ON_SWING_STATE" then
        return self:State(a1, a2, a3, a4)
    elseif eventName == "SPELL_QUEUE_EVENT" then
        return OnSwing:QueueEvent(a1, a2)
    elseif eventName == "SPELL_CAST_EVENT" then
        return OnSwing:CastEvent(a1, a2, a3, a4, a6)
    elseif eventName == "SPELL_CAST_RESULT_SELF" then
        return OnSwing:ServerResult(a1, a2, a3, a5)
    elseif eventName == "SPELL_FAILED_SELF" then
        return OnSwing:Failed(a1, a4)
    elseif eventName == "SPELL_MISS_SELF" then
        return self:Miss(a1, a2, a3)
    elseif eventName == "SPELL_DAMAGE_EVENT_SELF" then
        return self:Damage(a1, a2, a3)
    elseif eventName == "SPELL_GO_SELF" then
        return self:Go(a2, a3, a4)
    end
    return nil
end
