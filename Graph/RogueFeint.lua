-- Target-local Feint consequence over sealed build-5875 evidence.  The graph
-- values only the expected flat threat removed from the selected hostile; it
-- never treats Feint as a global aggro wipe or claims that the victim changed.
XelAssist.Graph.RogueFeint = {}
local F = XelAssist.Graph.RogueFeint

local function clamp(value)
    value = tonumber(value)
    if not value then return nil end
    return math.max(0, math.min(1, value))
end

local function runtime()
    return XelAssist.Game and XelAssist.Game.Player
        and XelAssist.Game.Player.RogueFeint
end

local function evidence(action, tooltip)
    local owner = runtime()
    if not owner then return nil end
    return owner:Evidence(tooltip) or owner:Evidence(action)
end

local function selectedRecord(state)
    local hostiles = state and state.hostiles
    if not (hostiles and hostiles.byKey) then return nil, nil end
    local key = hostiles.selectedKey
    local record = key ~= nil and hostiles.byKey[key] or nil
    if record then return record, key end
    local i
    for i = 1, table.getn(hostiles.order or {}) do
        key = hostiles.order[i]
        record = hostiles.byKey[key]
        if record and record.selected == true then return record, key end
    end
    return nil, nil
end

local function exactTarget(state, descriptor)
    local record, key = selectedRecord(state)
    if not (record and record.dead ~= true and record.selected ~= false
        and record.threat and record.guid ~= nil) then
        return nil, "selected hostile threat state unavailable"
    end
    if descriptor then
        if descriptor.unit ~= "target" or descriptor.relation ~= "hostile"
            or descriptor.source ~= "selected" then
            return nil, "Feint requires the selected hostile"
        end
        if descriptor.key ~= nil and descriptor.key ~= key
            or descriptor.guid ~= nil and descriptor.guid ~= record.guid then
            return nil, "Feint target identity changed"
        end
    end
    if state.targetGUID ~= nil and state.targetGUID ~= record.guid then
        return nil, "Feint target identity changed"
    end
    return record, nil, key
end

local function ownership(record)
    local threat = record and record.threat
    if not threat then return nil, false end
    if threat.projectedPlayerReferenceKnown == true
        and threat.projectedPlayerReference == false then return false, true end
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

function F:Is(action, tooltip)
    return evidence(action, tooltip) ~= nil
end

function F:Evidence(action, tooltip)
    return evidence(action, tooltip)
end

function F:Blocker(action, state, descriptor, tooltip)
    local found = evidence(action, tooltip)
    if not found then return nil, false end
    if (action.actor or "player") ~= "player" then
        return "Feint is player-owned", true
    end
    if state.inCombat ~= true then
        return state.inCombat == false and "no combat threat to reduce"
            or "combat state unavailable", true
    end
    local record, reason = exactTarget(state, descriptor)
    if not record then return reason, true end
    local _, known = ownership(record)
    if not known then return "selected hostile threat ownership unavailable", true end
    return nil, true
end

local function delivery(context)
    if type(context and context.resistance) ~= "table" then
        return nil, "Feint melee delivery evidence unavailable"
    end
    local probability = clamp(context.effectDelivery)
    if probability == nil then
        return nil, "Feint melee delivery probability unavailable"
    end
    return probability, nil
end

function F:Score(context)
    local action, state = context and context.action, context and context.state
    local found = evidence(action, context and context.tooltip)
    if not found then return false end
    local blocker = self:Blocker(action, state, context.descriptor,
        context.tooltip)
    if blocker then
        context.value, context.reason = -100000, blocker
        return true
    end
    local probability, reason = delivery(context)
    if probability == nil or probability <= 0 then
        context.value, context.reason = -100000,
            reason or "Feint cannot affect this target"
        return true
    end
    local record = exactTarget(state, context.descriptor)
    local hasAggro = ownership(record)
    local reduction = found.amount * probability
    context.power, context.expectedPower, context.effectivePower = 0, 0, 0
    context.threat, context.rogueFeintExpectedThreatReduction = 0, reduction
    context.rogueFeintDelivery = probability
    if state.tank == true then
        context.value, context.reason = -reduction,
            "preserves selected-target tank threat"
    elseif hasAggro == true then
        context.value, context.reason = reduction,
            "lowers threat on the selected attacker"
    else
        context.value, context.reason = 0,
            "selected target is not attacking the player"
    end
    if probability < 0.999 or context.resistance.unknown == true
        or found.resourceRefundAmountExact == false then
        context.estimated = true
    end
    return true
end

local function candidateDescriptor(candidate)
    return candidate and { unit = "target", relation = candidate.targetRelation,
        source = candidate.targetSource, key = candidate.targetKey,
        guid = candidate.targetGUID } or nil
end

function F:Apply(state, candidate)
    local action = candidate and candidate.action
    local found = evidence(action, candidate and candidate.tooltip)
    if not found then return false end
    local descriptor = candidateDescriptor(candidate)
    local blocker = self:Blocker(action, state, descriptor,
        candidate and candidate.tooltip)
    if blocker then return false end
    local probability = clamp(candidate.effectDelivery)
    if probability == nil or probability <= 0 then return false end
    local record, _, key = exactTarget(state, descriptor)
    if not record then return false end
    local hadAggro, ownershipKnown = ownership(record)
    if not ownershipKnown then return false end
    local reduction = found.amount * probability
    local threat = record.threat
    threat.playerDelta = (tonumber(threat.playerDelta) or 0) - reduction
    threat.playerDeltaExact = false
    threat.projectedPlayerThreatReduction =
        (tonumber(threat.projectedPlayerThreatReduction) or 0) + reduction
    threat.projectedPlayerThreatReductionExact = false
    threat.projectedPlayerThreatReductionProbability = probability
    threat.projectedThreatDropModel = found.model
    threat.projectedThreatDropSourceSpellId = found.spellId
    record.projectedThreat = record.projectedThreat or {}
    record.projectedThreat.playerReduction =
        (tonumber(record.projectedThreat.playerReduction) or 0) + reduction
    record.projectedFeint = { expectedReduction = reduction,
        rawReduction = found.amount, applicationProbability = probability,
        sourceSpellId = found.spellId, exactMagnitude = true,
        resourceRefundAmountExact = found.resourceRefundAmountExact }
    -- Lowering player threat cannot make a non-player victim switch to the
    -- player.  If the player currently owns the victim, however, exact totals
    -- for every competing actor are absent, so the post-Feint owner is unknown.
    if hadAggro == true then
        threat.projectedPlayerOwnershipUnknown = true
        threat.projectedPlayerHasAggro = nil
    end
    local graphState = XelAssist.Graph.State
    if graphState and graphState.RefreshHostileRecord then
        graphState:RefreshHostileRecord(state, key)
    elseif hadAggro == true then
        state.hasAggro = nil
        state.targetPlayerThreatDeltaExact = false
    end
    return true
end
