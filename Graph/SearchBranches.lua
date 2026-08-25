-- Protects strategically distinct beam branches from raw-value pruning.
-- Search ordering stays in Engine; this module only chooses required survivors.
XelAssist.Graph.SearchBranches = {}
local B = XelAssist.Graph.SearchBranches

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

function B:Retain(candidates, width, before)
    local setup, bestSetup, earliest, earliestAt, i = nil, 0, nil, nil, nil
    for i = 1, table.getn(candidates) do
        local value = setupValue(candidates[i])
        if value > bestSetup then setup, bestSetup = candidates[i], value end
        local at = tonumber(candidates[i].actionStart) or math.huge
        if earliestAt == nil or at < earliestAt then
            earliest, earliestAt = candidates[i], at
        end
    end
    while table.getn(candidates) > width do table.remove(candidates) end
    local required = {}
    if setup then required[setup] = true end
    if earliest then required[earliest] = true end
    local branch
    for branch in pairs(required) do
        local found = false
        for i = 1, table.getn(candidates) do
            if candidates[i] == branch then found = true; break end
        end
        if not found then
            local replace = table.getn(candidates)
            while replace > 0 and required[candidates[replace]] do
                replace = replace - 1
            end
            if replace > 0 then candidates[replace] = branch
            elseif table.getn(candidates) < width then
                table.insert(candidates, branch)
            end
        end
    end
    table.sort(candidates, before)
end
