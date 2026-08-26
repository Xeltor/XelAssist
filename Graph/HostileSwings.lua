-- Projected hostile white rounds use learned post-mitigation damage only for
-- survival timing. Counterfactual block/armor/absorb value remains unknown.
XelAssist.Graph.HostileSwings = {}
local S = XelAssist.Graph.HostileSwings
local Incoming = XelAssist.Graph.IncomingConsequences

S.MAX_EVENTS = 8

local function attacker(state, lane)
    local hostiles = state and state.hostiles
    local record = hostiles and hostiles.byKey
        and hostiles.byKey[lane.attackerKey] or nil
    if record and record.guid == lane.attackerGuid then return record end
    return nil
end

local function intervalAfter(state, lane, resetAt, base)
    local record = attacker(state, lane)
    local effects = record and record.meleeAttackTimeEffects
    local slow = effects and effects.thunderClap
    if not (slow and slow.exact == true and slow.multiplier == 1.1
        and (slow.observedMultiplier == 1 or slow.observedMultiplier == 1.1)
        and slow.phaseAdjustment == "future-reset-only") then return base end
    slow.baseIntervals = slow.baseIntervals or {}
    local hand = lane.hand or "main"
    local normalized = tonumber(slow.baseIntervals[hand])
    if not normalized then
        normalized = base / slow.observedMultiplier
        slow.baseIntervals[hand] = normalized
    end
    local expiresAt = tonumber(slow.expiresAt)
    if not expiresAt or resetAt >= expiresAt then
        effects.thunderClap = nil
        lane.interval = normalized
        return normalized
    end
    return normalized * slow.multiplier
end

function S:Events(state, candidate)
    local events, lanes = {}, state and state.hostileSwings
        and state.hostileSwings.lanes or {}
    local window = math.max(0, tonumber(candidate and candidate.downtime) or 0)
    local i
    for i = 1, table.getn(lanes) do
        local lane = lanes[i]
        local interval = math.max(0.1, tonumber(lane.interval) or 0)
        local offset = math.max(0.05, tonumber(lane.nextSwingIn) or interval)
        local count = 0
        while interval > 0.1 and offset <= window and count < self.MAX_EVENTS do
            table.insert(events, { owner = "hostileSwing", kind = "hostileWhiteSwing",
                priority = 15, offset = offset,
                attackerGuid = lane.attackerGuid, attackerKey = lane.attackerKey,
                victimGuid = lane.victimGuid, victimKind = lane.victimKind,
                generation = lane.generation, amount = lane.expectedDamage,
                estimated = true, postMitigation = true })
            count = count + 1
            local resetAt = (tonumber(state.time) or 0) + offset
            local nextInterval = intervalAfter(state, lane, resetAt, interval)
            offset = offset + nextInterval
            interval = nextInterval
        end
        lane.nextSwingIn = math.max(0.05, offset - window)
        if count == self.MAX_EVENTS and offset <= window then
            state.incomingProjectionPartial = true
            lane.phaseKnown = false
        end
    end
    return events
end

function S:Apply(state, entry)
    if not (entry and entry.kind == "hostileWhiteSwing" and Incoming
        and Incoming.ApplyResolvedDamage) then return false end
    local result = Incoming:ApplyResolvedDamage(state, entry.victimGuid,
        entry.amount, true, "projected hostile white swing")
    if not result then state.incomingProjectionPartial = true; return false end
    state.lastHostileSwing = { attackerGuid = entry.attackerGuid,
        victimGuid = entry.victimGuid, generation = entry.generation,
        effective = result.effective, estimated = true }
    return true
end
