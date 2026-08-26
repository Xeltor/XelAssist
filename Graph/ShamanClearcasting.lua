-- Search-pure Shaman Clearcasting consequence. Exact engine costs and charges
-- are sealed at the root; branches merely apply and consume that contract.
XelAssist.Graph.ShamanClearcasting = {}
local C = XelAssist.Graph.ShamanClearcasting

local function finite(value)
    value = tonumber(value)
    if value == nil or value ~= value
        or value == math.huge or value == -math.huge then return nil end
    return value
end

local function integer(value, low, high)
    value = finite(value)
    if not value or value < low or value > high
        or math.floor(value) ~= value then return nil end
    return value
end

local function copy(source)
    local out, key, value = {}, nil, nil
    for key, value in pairs(source or {}) do
        out[key] = type(value) == "table" and copy(value) or value
    end
    return out
end

local function activeAt(state, at)
    local evidence = state and state.shamanClearcasting
    at = finite(at)
    return evidence and evidence.available == true and evidence.exact == true
        and evidence.active == true and at and integer(
            evidence.remainingCharges, 1, 16)
        and finite(evidence.expiresAt) and at < evidence.expiresAt
        and evidence or nil
end

local function earliestPlayerStart(state)
    local at = finite(state and state.time) or 0
    at = math.max(at, finite(state and state.playerGcdReadyAt) or 0)
    at = math.max(at, finite(state and state.actorReadyAt
        and state.actorReadyAt.player) or 0)
    return at
end

function C:Copy(source, target)
    if not (source and target) then return false end
    target.shamanClearcasting = source.shamanClearcasting
        and copy(source.shamanClearcasting) or nil
    return target.shamanClearcasting ~= nil
end

function C:PrepareLegal(action, state, tooltip)
    local contract = tooltip and tooltip.shamanClearcastingCost
    if not contract then return tooltip, nil, false end
    local evidence = state and state.shamanClearcasting
    if not action or contract.claimed ~= true or contract.exact ~= true
        or contract.spellId ~= action.spellId or not evidence
        or contract.epoch ~= evidence.epoch then
        return nil, contract.reason
            or "Shaman Clearcasting cost contract unavailable", true
    end
    local baseline, activeCost = finite(contract.baselineCost),
        finite(contract.activeCost)
    if not baseline or baseline <= 0 or not activeCost or activeCost < 0
        or activeCost > baseline then
        return nil, "Shaman Clearcasting cost contract unavailable", true
    end
    local out = copy(tooltip)
    out.cost = baseline
    local active = activeAt(state, earliestPlayerStart(state))
    if contract.eligible ~= true or not active then return out, nil, true end
    local profile = active.profile
    if not (profile and profile.valid == true and profile.exact == true
        and profile.spellId == contract.auraSpellId) then
        return nil, "Shaman Clearcasting aura contract unavailable", true
    end
    out.cost = activeCost
    out.shamanClearcastingConsumption = { exact = true,
        spellId = action.spellId, auraSpellId = profile.spellId,
        epoch = active.epoch, baselineCost = baseline,
        activeCost = activeCost, source = contract.source }
    return out, nil, true
end

function C:Consume(state, candidate)
    local marker = candidate and candidate.tooltip
        and candidate.tooltip.shamanClearcastingConsumption
    local action = candidate and candidate.action
    local evidence = activeAt(state, candidate and candidate.actionStart)
    if not (marker and marker.exact == true and action and evidence
        and marker.spellId == action.spellId and marker.epoch == evidence.epoch
        and evidence.profile and marker.auraSpellId == evidence.profile.spellId
        and finite(marker.activeCost) == tonumber(candidate.cost)) then return false end
    evidence.remainingCharges = evidence.remainingCharges - 1
    evidence.consumedCharges = (tonumber(evidence.consumedCharges) or 0) + 1
    if evidence.remainingCharges <= 0 then
        evidence.active, evidence.expiresAt, evidence.remaining = false, nil, nil
    end
    evidence.source = "projected exact Shaman Clearcasting consumption"
    return true
end
