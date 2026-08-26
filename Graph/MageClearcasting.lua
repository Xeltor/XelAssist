-- Search-pure, branch-local Clearcasting consequence. The root evidence owner
-- seals exact eligibility and baseline cost; descendants only apply/consume
-- that one-use contract, with no live APIs and no action-order preference.
XelAssist.Graph.MageClearcasting = {}
local C = XelAssist.Graph.MageClearcasting

local function finite(value)
    value = tonumber(value)
    if value == nil or value ~= value
        or value == math.huge or value == -math.huge then return nil end
    return value
end

local function copy(source)
    local out, key, value = {}, nil, nil
    for key, value in pairs(source or {}) do out[key] = value end
    return out
end

local function activeAt(state, at)
    local evidence = state and state.mageClearcasting
    at = finite(at)
    return evidence and evidence.available == true and evidence.exact == true
        and evidence.active == true and at
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
    target.mageClearcasting = source.mageClearcasting
        and copy(source.mageClearcasting) or nil
    if target.mageClearcasting and source.mageClearcasting.profile then
        target.mageClearcasting.profile = copy(source.mageClearcasting.profile)
    end
    return target.mageClearcasting ~= nil
end

function C:PrepareLegal(action, state, tooltip)
    local contract = tooltip and tooltip.mageClearcastingCost
    if not contract then return tooltip, nil, false end
    local evidence = state and state.mageClearcasting
    if not action or contract.claimed ~= true or contract.exact ~= true
        or contract.spellId ~= action.spellId
        or not evidence or contract.epoch ~= evidence.epoch then
        return nil, contract.reason
            or "Clearcasting cost contract unavailable", true
    end
    local cost = finite(contract.baselineCost)
    if not cost or cost <= 0 then
        return nil, "Clearcasting baseline cost unavailable", true
    end
    local out = copy(tooltip)
    out.cost = cost
    if contract.eligible ~= true
        or not activeAt(state, earliestPlayerStart(state)) then
        return out, nil, true
    end
    out.cost = 0
    out.mageClearcastingConsumption = { exact = true,
        spellId = action.spellId, epoch = evidence.epoch,
        baselineCost = cost, source = contract.source }
    return out, nil, true
end

function C:Consume(state, candidate)
    local marker = candidate and candidate.tooltip
        and candidate.tooltip.mageClearcastingConsumption
    local action = candidate and candidate.action
    local evidence = activeAt(state, candidate and candidate.actionStart)
    if not (marker and marker.exact == true and action and evidence
        and marker.spellId == action.spellId
        and marker.epoch == evidence.epoch
        and finite(marker.baselineCost) and marker.baselineCost > 0
        and tonumber(candidate.cost) == 0) then return false end
    evidence.active, evidence.expiresAt, evidence.remaining = false, nil, nil
    evidence.consumed = true
    evidence.source = "projected exact Clearcasting consumption"
    return true
end
