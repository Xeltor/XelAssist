-- Search-pure, one-charge Druid Clearcasting consequence. Eligibility and
-- effective costs are sealed by the root evidence owner; branches only apply
-- and consume that contract, without choosing which action should spend it.
XelAssist.Graph.DruidClearcasting = {}
local C = XelAssist.Graph.DruidClearcasting

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
    local evidence = state and state.druidClearcasting
    at = finite(at)
    return evidence and evidence.available == true and evidence.exact == true
        and evidence.learned == true and evidence.active == true
        and integer(evidence.remainingCharges, 1, 1) == 1 and at
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
    target.druidClearcasting = source.druidClearcasting
        and copy(source.druidClearcasting) or nil
    return target.druidClearcasting ~= nil
end

function C:PrepareLegal(action, state, tooltip)
    local contract = tooltip and tooltip.druidClearcastingCost
    if not contract then return tooltip, nil, false end
    local evidence = state and state.druidClearcasting
    local formID = state and state.druidFormState
        and state.druidFormState.formID
    if not action or contract.claimed ~= true or contract.exact ~= true
        or contract.spellId ~= action.spellId or not evidence
        or contract.epoch ~= evidence.epoch or contract.formID ~= formID then
        return nil, contract.reason
            or "Druid Clearcasting cost contract unavailable", true
    end
    local baseline, activeCost = finite(contract.baselineCost),
        finite(contract.activeCost)
    if not baseline or baseline < 0 or not activeCost or activeCost < 0
        or activeCost > baseline then
        return nil, "Druid Clearcasting cost contract unavailable", true
    end
    local out = copy(tooltip)
    out.cost = baseline
    local active = activeAt(state, earliestPlayerStart(state))
    if contract.eligible ~= true or not active then return out, nil, true end
    local profile = active.profile
    if not (profile and profile.valid == true and profile.exact == true
        and profile.spellId == 16870 and profile.charges == 1) then
        return nil, "Druid Clearcasting aura contract unavailable", true
    end
    out.cost = activeCost
    out.druidClearcastingConsumption = { exact = true,
        spellId = action.spellId, auraSpellId = profile.spellId,
        epoch = active.epoch, formID = contract.formID,
        powerType = contract.powerType, baselineCost = baseline,
        activeCost = activeCost, source = contract.source }
    return out, nil, true
end

function C:Consume(state, candidate)
    local marker = candidate and candidate.tooltip
        and candidate.tooltip.druidClearcastingConsumption
    local action = candidate and candidate.action
    local evidence = activeAt(state, candidate and candidate.actionStart)
    local formID = state and state.druidFormState
        and state.druidFormState.formID
    if not (marker and marker.exact == true and action and evidence
        and marker.spellId == action.spellId and marker.epoch == evidence.epoch
        and marker.formID == formID and evidence.profile
        and marker.auraSpellId == evidence.profile.spellId
        and finite(marker.activeCost) == tonumber(candidate.cost)) then
        return false
    end
    evidence.remainingCharges, evidence.active = 0, false
    evidence.expiresAt, evidence.remaining = nil, nil
    evidence.consumed = true
    evidence.source = "projected exact Druid Clearcasting consumption"
    return true
end
