-- The player Attack button starts a client-owned melee state; the press itself
-- is neither a swing nor damage.  Nampower exposes the exact live toggle state.
-- A short submission latch closes the frame/event delay where a second input
-- could otherwise toggle Attack back off.
XelAssist.Game.PlayerAttack = {}
local A = XelAssist.Game.PlayerAttack

local SUBMISSION_GUARD = 0.75
local MAX_SUBMISSION_GUARD = 15

local function now()
    if type(GetTime) ~= "function" then return nil end
    local ok, value = pcall(GetTime)
    if ok and type(value) == "number" then return value end
    return nil
end

local function liveState()
    if type(GetCurrentCastingInfo) ~= "function" then
        return nil, false, "Nampower auto-attack state unavailable"
    end
    local ok, _, _, _, _, _, _, autoAttack = pcall(GetCurrentCastingInfo)
    if not ok then return nil, false, "Nampower auto-attack query failed" end
    if autoAttack == true or tonumber(autoAttack) == 1 then
        return true, true, "Nampower current casting info"
    end
    if autoAttack == false or tonumber(autoAttack) == 0 then
        return false, true, "Nampower current casting info"
    end
    return nil, false, "Nampower auto-attack state unknown"
end

function A:Reset()
    self.pendingUntil, self.pendingTargetGuid = nil, nil
    self.pendingSubmittedAt, self.pendingSource = nil, nil
end

function A:Snapshot()
    local active, activeKnown, source = liveState()
    local at = now()
    if self.pendingUntil and at and (self.pendingUntil <= at
        or self.pendingSubmittedAt and at < self.pendingSubmittedAt) then
        self:Reset()
    end
    local pending = at and self.pendingUntil and self.pendingUntil > at
        and true or false
    if active == true then
        self:Reset()
        pending = false
    end
    local snapshot = { supported = type(GetCurrentCastingInfo) == "function"
            and type(AttackTarget) == "function",
        active = active, activeKnown = activeKnown,
        pending = pending, pendingTargetGuid = pending and self.pendingTargetGuid or nil,
        clockKnown = at ~= nil,
        source = pending and self.pendingSource or source }
    if XelAssist.Game.Player and XelAssist.Game.Player.OnSwing then
        snapshot.onSwing = XelAssist.Game.Player.OnSwing:Snapshot()
    end
    if XelAssist.Game.Player and XelAssist.Game.Player.AttackRounds then
        XelAssist.Game.Player.AttackRounds:Attach(snapshot)
    end
    return snapshot
end

function A:CanStart(snapshot)
    local state = snapshot or self:Snapshot()
    if state.pending then return false, "player Attack start pending" end
    if state.activeKnown ~= true or state.active == nil then
        return false, "player Attack state uncertain"
    end
    if state.active ~= false then return false, "player Attack already active" end
    if not state.clockKnown then return false, "combat clock unavailable" end
    if type(AttackTarget) ~= "function" then
        return false, "player Attack command unavailable"
    end
    return true, nil
end

function A:Projected(targetGuid, source)
    local snapshot = { supported = true, active = true, activeKnown = true,
        pending = false, clockKnown = true, source = source or "graph start",
        targetGuid = targetGuid }
    if XelAssist.Game.Player and XelAssist.Game.Player.OnSwing then
        snapshot.onSwing = XelAssist.Game.Player.OnSwing:Snapshot()
    end
    if XelAssist.Game.Player and XelAssist.Game.Player.AttackRounds then
        snapshot.attackRound = { supported = true, phaseKnown = false,
            verified = false, projectable = false,
            targetGuid = targetGuid,
            reason = "Attack submitted; awaiting resolved player swing" }
    end
    return snapshot
end

function A:ProjectedStopped(targetGuid, source)
    return { supported = true, active = false, activeKnown = true,
        pending = false, clockKnown = true,
        source = source or "graph stop", targetGuid = targetGuid,
        onSwing = { occupied = false, pending = false, exact = true,
            source = "graph Attack stop" },
        attackRound = { supported = true, phaseKnown = false,
            verified = false, projectable = false, targetGuid = targetGuid,
            reason = "Attack stopped; awaiting a new resolved player swing" } }
end

function A:Stopped()
    self:Reset()
end

function A:Submitted(targetGuid, duration, source)
    local submittedAt = now()
    if not submittedAt then return false, "combat clock unavailable" end
    duration = math.max(SUBMISSION_GUARD,
        math.min(MAX_SUBMISSION_GUARD, tonumber(duration) or SUBMISSION_GUARD))
    self.pendingSubmittedAt = submittedAt
    self.pendingUntil = submittedAt + duration
    self.pendingTargetGuid = targetGuid
    self.pendingSource = source or "submitted Attack command"
    return true, nil
end

function A:Start(targetGuid)
    local allowed, reason = self:CanStart(self:Snapshot())
    if not allowed then return false, reason end
    local submittedAt = now()
    if not submittedAt then return false, "combat clock unavailable" end
    local ok = pcall(AttackTarget)
    if not ok then return false, "player Attack command failed" end
    self.pendingSubmittedAt = submittedAt
    self.pendingUntil = submittedAt + SUBMISSION_GUARD
    self.pendingTargetGuid = targetGuid
    self.pendingSource = "submitted Attack command"
    return true, nil
end

A:Reset()
