-- Projected hostile white rounds use learned post-mitigation damage only for
-- survival timing. Counterfactual block/armor/absorb value remains unknown.
XelAssist.Graph.HostileSwings = {}
local S = XelAssist.Graph.HostileSwings
local Incoming = XelAssist.Graph.IncomingConsequences

S.MAX_EVENTS = 8

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
            offset, count = offset + interval, count + 1
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
