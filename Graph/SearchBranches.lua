-- Protects strategically distinct beam branches from raw-value pruning.
-- Search ordering stays in Engine; this module only chooses required survivors.
XelAssist.Graph.SearchBranches = {}
local B = XelAssist.Graph.SearchBranches
local STRATEGIC_SETUP_LANES = 2

local function setupValue(candidate)
    local tooltip = candidate.tooltip or {}
    local remaining = (tonumber(tooltip.duration) or 0)
        - math.max(0, (candidate.occupancy or 0) - (candidate.cast or 0))
    if candidate.targetRelation ~= "hostile" or remaining <= 0
        or (candidate.effectDelivery or 1) <= 0 then return 0 end
    local value, _, amount = math.max(0,
        tonumber(tooltip.targetArmorReduction) or 0), nil, nil
    for _, amount in pairs(tooltip.targetResistanceReduction or {}) do
        value = value + math.max(0, tonumber(amount) or 0)
    end
    for _, amount in pairs(tooltip.targetDamageTaken or {}) do
        value = value + math.max(0, tonumber(amount) or 0) * 100
    end
    return value * remaining * (candidate.effectDelivery or 1)
end

local function strategicBefore(a, b, before)
    local aCost = a.costKnown and tonumber(a.cost) or math.huge
    local bCost = b.costKnown and tonumber(b.cost) or math.huge
    if aCost ~= bCost then return aCost < bCost end
    local aTime, bTime = tonumber(a.occupancy) or math.huge,
        tonumber(b.occupancy) or math.huge
    if aTime ~= bTime then return aTime < bTime end
    if a.strategicSetupKey ~= b.strategicSetupKey then
        return a.strategicSetupKey < b.strategicSetupKey
    end
    return before(a, b)
end

function B:Retain(candidates, width, before)
    local setup, bestSetup, movement, charge, wandStart, sustained, melee,
        exchange, earliest, earliestAt, strategic, ordinary, i = nil, 0, nil,
            nil, nil, nil, nil, nil, nil, nil, {}, {}, nil
    for i = 1, table.getn(candidates) do
        local candidate = candidates[i]
        local isStrategic = candidate.strategicSetup == true
            and type(candidate.strategicSetupKey) == "string"
            and candidate.strategicSetupKey ~= ""
        if isStrategic then
            local prior = strategic[candidate.strategicSetupKey]
            if not prior or strategicBefore(candidate, prior, before) then
                strategic[candidate.strategicSetupKey] = candidate
            end
        else
            table.insert(ordinary, candidate)
            local facts = candidate.action and candidate.action.facts
            if facts and facts.movementSetup then movement = candidate end
            if facts and facts.chargeMovement then charge = candidate end
            if facts and facts.wandContinuation then sustained = candidate end
            if facts and facts.wandRepeat then wandStart = candidate end
            if facts and facts.playerAttackContinuation then melee = candidate end
            if facts and facts.healthConversion then exchange = candidate end
            local value = setupValue(candidate)
            if value > bestSetup then setup, bestSetup = candidate, value end
            local at = tonumber(candidate.actionStart) or math.huge
            if earliestAt == nil or at < earliestAt then
                earliest, earliestAt = candidate, at
            end
        end
    end
    width = math.max(0, math.floor(tonumber(width) or 0))
    local setupCandidates, key = {}, nil
    for key in pairs(strategic) do
        table.insert(setupCandidates, strategic[key])
    end
    table.sort(setupCandidates, function(a, b)
        return strategicBefore(a, b, before)
    end)
    local setupLimit = math.min(STRATEGIC_SETUP_LANES,
        table.getn(ordinary) > 0 and math.max(0, width - 1) or width,
        table.getn(setupCandidates))
    local ordinaryWidth = width - setupLimit
    while table.getn(candidates) > 0 do table.remove(candidates) end
    for i = 1, table.getn(ordinary) do table.insert(candidates, ordinary[i]) end
    table.sort(candidates, before)
    while table.getn(candidates) > ordinaryWidth do table.remove(candidates) end
    local required, requiredSet = {}, {}
    local function requireBranch(value)
        if value and not requiredSet[value] then
            requiredSet[value] = true; table.insert(required, value)
        end
    end
    requireBranch(setup); requireBranch(movement); requireBranch(charge)
    requireBranch(wandStart); requireBranch(sustained); requireBranch(melee)
    requireBranch(exchange); requireBranch(earliest)
    local branch
    for i = 1, table.getn(required) do
        branch = required[i]
        local found = false
        local j
        for j = 1, table.getn(candidates) do
            if candidates[j] == branch then found = true; break end
        end
        if not found then
            local replace = table.getn(candidates)
            while replace > 0 and requiredSet[candidates[replace]] do
                replace = replace - 1
            end
            if replace > 0 then candidates[replace] = branch
            elseif table.getn(candidates) < ordinaryWidth then
                table.insert(candidates, branch)
            end
        end
    end
    for i = 1, setupLimit do
        table.insert(candidates, setupCandidates[i])
    end
    table.sort(candidates, before)
end
