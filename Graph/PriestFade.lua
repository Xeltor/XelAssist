-- Exact graph-causal Fade consequence over sealed root evidence.  Application
-- snapshots only currently proven player hostile references.  Later hostile
-- references receive no offset; expiration mirrors VMaNGOS by resetting the
-- temporary modifier on every then-current tracked player reference.
XelAssist.Graph.PriestFade = {}
local F = XelAssist.Graph.PriestFade

F.MAX_TRACKED_HOSTILES = 20

local function finite(value, low, high)
    value = tonumber(value)
    if value == nil or value ~= value or value == math.huge
        or value == -math.huge or value < low or value > high then return nil end
    return value
end

local function runtime()
    return XelAssist.Game and XelAssist.Game.Player
        and XelAssist.Game.Player.PriestFade
end

local function staticEvidence(action, tooltip)
    local owner = runtime()
    if not owner then return nil end
    return owner:Evidence(tooltip) or owner:Evidence(action)
end

local function contract(action, tooltip)
    local owner = runtime()
    if not owner then return nil end
    return owner:CapturedEvidence(tooltip) or owner:CapturedEvidence(action)
end

local function descriptorValid(descriptor)
    if not descriptor then return true end
    return descriptor.unit == "player" and descriptor.relation == "self"
        and (descriptor.source == nil or descriptor.source == "self")
end

local function playerReference(record)
    local threat = record and record.threat
    if not threat then return nil, false end
    if threat.projectedPlayerReferenceKnown == true then
        return threat.projectedPlayerReference and true or false, true
    end
    if threat.playerReferenceKnown == true then
        return threat.playerReference and true or false, true
    end
    if threat.projectedPlayerHasAggro == true
        or threat.playerHasAggro == true or record.hasPlayerAggro == true
        or (tonumber(threat.playerDelta) or 0) > 0 then return true, true end
    return nil, false
end

local function ownership(record)
    local threat = record and record.threat
    if not threat then return nil, false end
    if threat.projectedPlayerOwnershipUnknown == true
        or threat.projectedOwnershipUnknown == true then return nil, false end
    if threat.projectedPlayerHasAggro ~= nil then
        return threat.projectedPlayerHasAggro and true or false, true
    end
    if threat.playerHasAggro ~= nil then
        return threat.playerHasAggro and true or false, true
    end
    if record.hasPlayerAggro ~= nil then
        return record.hasPlayerAggro and true or false, true
    end
    return nil, false
end

local function recipientSnapshot(state)
    local hostiles = state and state.hostiles
    if not (hostiles and type(hostiles.order) == "table"
        and type(hostiles.byKey) == "table") then
        return nil, "hostile reference snapshot unavailable"
    end
    local count = table.getn(hostiles.order)
    if count > F.MAX_TRACKED_HOSTILES then
        return nil, "hostile reference snapshot exceeds the graph bound"
    end
    local out, seen, index, key, record = {}, {}, nil, nil, nil
    for index = 1, count do
        key, record = hostiles.order[index], nil
        if key == nil or seen[key] then
            return nil, "hostile reference identities are incoherent"
        end
        seen[key], record = true, hostiles.byKey[key]
        if not (type(record) == "table" and record.guid ~= nil) then
            return nil, "hostile reference identity unavailable"
        end
        if record.dead ~= true then
            local exists, known = playerReference(record)
            if known and exists then
                table.insert(out, { key = key, guid = record.guid,
                    hasTemporaryModifier = record.threat
                        and record.threat.playerThreatOffset ~= nil })
            end
        end
    end
    return { recipients = out, observedCount = count,
        observedCoverageComplete = hostiles.capped == false,
        discoveryComplete = hostiles.discoveryComplete == true }
end

local function active(state)
    local aura = state and state.priestFade
    local remaining = aura and finite(aura.remaining, 0, 600)
    return remaining and remaining > 0 and aura or nil
end

function F:Is(action, tooltip)
    return staticEvidence(action, tooltip) ~= nil
end

function F:Blocker(action, state, descriptor, tooltip)
    local recognized = staticEvidence(action, tooltip)
    if not recognized then return nil, false end
    local found = contract(action, tooltip)
    if not found then return "Fade root evidence unavailable", true end
    if (action.actor or "player") ~= "player" then
        return "Fade is player-owned", true
    end
    if not descriptorValid(descriptor) then
        return "Fade requires the player recipient", true
    end
    if state.inCombat ~= true then
        return state.inCombat == false and "no combat threat to reduce"
            or "combat state unavailable", true
    end
    if active(state) then return "Fade is already active", true end
    local snapshot, reason = recipientSnapshot(state)
    if not snapshot then return reason, true end
    if table.getn(snapshot.recipients) == 0 then
        return "no exact current player hostile reference", true
    end
    return nil, true
end

local function delivery(context)
    local probability = finite(context and context.effectDelivery, 0, 1)
    if probability == nil then return nil, "Fade aura delivery unavailable" end
    if probability < 0.999 then
        return nil, "Fade self-aura delivery is not exact"
    end
    return probability
end

function F:Score(context)
    local action, state = context and context.action, context and context.state
    if not staticEvidence(action, context and context.tooltip) then return false end
    local blocker = self:Blocker(action, state, context.descriptor,
        context.tooltip)
    if blocker then
        context.value, context.reason = -100000, blocker
        return true
    end
    local probability, reason = delivery(context)
    if not probability then
        context.value, context.reason = -100000, reason
        return true
    end
    local found = contract(action, context.tooltip)
    local snapshot = recipientSnapshot(state)
    local certainAggro, applicable, index = 0, 0, nil
    for index = 1, table.getn(snapshot.recipients) do
        local recipient = snapshot.recipients[index]
        local record = state.hostiles.byKey[recipient.key]
        if not recipient.hasTemporaryModifier then
            applicable = applicable + 1
            local hasAggro, known = ownership(record)
            if known and hasAggro then certainAggro = certainAggro + 1 end
        end
    end
    local consequence = found.amount * certainAggro
    context.power, context.expectedPower, context.effectivePower = 0, 0, 0
    context.threat, context.priestFadeThreatReduction = 0, consequence
    context.priestFadeRecipients, context.priestFadeApplicable =
        table.getn(snapshot.recipients), applicable
    context.priestFadeDuration = found.duration
    if state.tank == true then
        context.value = -found.amount * applicable
        context.reason = "preserves current tank threat"
    elseif certainAggro > 0 then
        context.value, context.reason = consequence,
            "temporarily lowers threat on current attackers"
    else
        context.value, context.reason = 0,
            "no current attacker has exact unwanted player aggro"
    end
    context.estimated = found.runtimeVerified ~= true
        or snapshot.observedCoverageComplete ~= true
        or snapshot.discoveryComplete ~= true
    return true
end

local function candidateDescriptor(candidate)
    if not candidate then return nil end
    if not (candidate.target or candidate.targetRelation
        or candidate.targetSource) then return nil end
    return { unit = candidate.target, relation = candidate.targetRelation,
        source = candidate.targetSource }
end

local function epoch(state, found)
    local at = finite(state and state.time, 0, 1000000000) or 0
    return tostring(found.spellId) .. ":" .. tostring(at)
end

local function markApplied(record, found, token)
    local threat = record.threat
    if threat.playerThreatOffset ~= nil then return false end
    threat.playerThreatOffset = { amount = -found.amount,
        remaining = found.duration, exact = true, sourceSpellId = found.spellId,
        model = found.model, priestFade = true, epoch = token }
    threat.projectedPlayerOwnershipUnknown = true
    threat.projectedPlayerHasAggro = nil
    threat.projectedThreatDropModel = found.model
    threat.projectedThreatDropSourceSpellId = found.spellId
    threat.playerDeltaExact = false
    return true
end

function F:Apply(state, candidate)
    local action, tooltip = candidate and candidate.action,
        candidate and candidate.tooltip
    if not staticEvidence(action, tooltip) then return false end
    local blocker = self:Blocker(action, state,
        candidateDescriptor(candidate), tooltip)
    if blocker or not delivery(candidate) then return false end
    local found, snapshot = contract(action, tooltip), recipientSnapshot(state)
    if not (found and snapshot) then return false end
    local token, recipients, index = epoch(state, found), {}, nil
    for index = 1, table.getn(snapshot.recipients) do
        local descriptor = snapshot.recipients[index]
        local record = state.hostiles.byKey[descriptor.key]
        if record and record.guid == descriptor.guid
            and markApplied(record, found, token) then
            table.insert(recipients, { key = descriptor.key,
                guid = descriptor.guid })
        end
    end
    state.priestFade = { active = true, exact = true, epoch = token,
        spellId = found.spellId, amount = found.amount,
        remaining = found.duration, duration = found.duration,
        recipients = recipients,
        observedCoverageComplete = snapshot.observedCoverageComplete,
        discoveryComplete = snapshot.discoveryComplete }
    local affectedKeys = {}
    for index = 1, table.getn(recipients) do
        affectedKeys[index] = recipients[index].key
    end
    state.playerThreatDrop = { model = found.model,
        sourceSpellId = found.spellId, affectedKeys = affectedKeys,
        hostileSetComplete = snapshot.observedCoverageComplete,
        outcomeKnown = false }
    local refresh = XelAssist.Graph.State
        and XelAssist.Graph.State.RefreshHostileRecord
    for index = 1, table.getn(recipients) do
        if refresh then XelAssist.Graph.State:RefreshHostileRecord(
            state, recipients[index].key) end
    end
    if XelAssist.Graph.State and XelAssist.Graph.State.SyncActiveHostile then
        XelAssist.Graph.State:SyncActiveHostile(state)
    else
        state.hasAggro, state.targetPlayerThreatDeltaExact = nil, false
    end
    return true
end

local function ageOwnedOffsets(state, aura, elapsed)
    local hostiles, index = state.hostiles, nil
    for index = 1, table.getn(aura.recipients or {}) do
        local recipient = aura.recipients[index]
        local record = hostiles and hostiles.byKey
            and hostiles.byKey[recipient.key] or nil
        local threat = record and record.guid == recipient.guid
            and record.threat or nil
        local offset = threat and threat.playerThreatOffset or nil
        if offset and offset.priestFade == true
            and offset.epoch == aura.epoch then
            offset.remaining = math.max(0,
                (tonumber(offset.remaining) or 0) - elapsed)
        end
    end
end

local function resetCurrentTemporaryOffsets(state, aura)
    local hostiles, index, record = state.hostiles, nil, nil
    for index = 1, table.getn(hostiles and hostiles.order or {}) do
        record = hostiles.byKey and hostiles.byKey[hostiles.order[index]]
        local threat = record and record.threat
        local offset = threat and threat.playerThreatOffset
        if offset and offset.model == aura.model then
            threat.playerThreatOffset = nil
            threat.projectedTemporaryThreatResetByFade = true
            threat.projectedPlayerOwnershipUnknown = true
            threat.projectedPlayerHasAggro = nil
            threat.playerDeltaExact = false
        end
    end
end

function F:Advance(state, elapsed)
    local aura = active(state)
    elapsed = finite(elapsed, 0, 600)
    if not aura or not elapsed or elapsed <= 0 then return false end
    ageOwnedOffsets(state, aura, elapsed)
    aura.remaining = math.max(0, aura.remaining - elapsed)
    if aura.remaining > 0 then return true end
    aura.model = runtime() and runtime().MODEL or "temporary-flat"
    resetCurrentTemporaryOffsets(state, aura)
    state.priestFade = nil
    return true
end

function F:Copy(source, target)
    if not target then return end
    local aura = source and source.priestFade
    if not aura then target.priestFade = nil; return end
    local out, key, value = {}, nil, nil
    for key, value in pairs(aura) do
        if key ~= "recipients" then out[key] = value end
    end
    out.recipients = {}
    local index
    for index = 1, table.getn(aura.recipients or {}) do
        local recipient = aura.recipients[index]
        out.recipients[index] = { key = recipient.key, guid = recipient.guid }
    end
    target.priestFade = out
end
