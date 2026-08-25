-- Keeps a bounded search lane for legal resource investments whose value is
-- realized only after a later action spends the gained resource. Unresolved
-- conversions may be explored but can never become a published plan.
XelAssist.Graph.ResourceInvestment = {}
local R = XelAssist.Graph.ResourceInvestment

local function facts(candidate)
    return candidate and candidate.action and candidate.action.facts or {}
end

function R:Is(candidate)
    return facts(candidate).healthConversion == true
end

function R:Expandable(candidate)
    return (tonumber(candidate and candidate.value) or 0) > 0
        or self:Is(candidate)
end

function R:Advance(prior, candidate, out)
    local open = prior.resourceInvestmentOpen == true
    local without = tonumber(prior.resourceWithoutInvestment)
    if self:Is(candidate) then
        if not open then without = tonumber(prior.state.resource) or 0 end
        open = true
    elseif open and (candidate.action.actor or "player") == "player"
        and candidate.costKnown then
        local cost = math.max(0, tonumber(candidate.cost) or 0)
        if cost > (without or 0) then
            open, without = false, nil
        else
            without = math.max(0, (without or 0) - cost)
        end
    end
    out.resourceInvestmentOpen = open and true or nil
    out.resourceWithoutInvestment = open and without or nil
    return out
end

function R:Eligible(path)
    return path and path.resourceInvestmentOpen ~= true
end

function R:Collect(frontier, terminal)
    local out, i = {}, nil
    for i = 1, table.getn(frontier or {}) do
        if self:Eligible(frontier[i]) then table.insert(out, frontier[i]) end
    end
    for i = 1, table.getn(terminal or {}) do
        if self:Eligible(terminal[i]) then table.insert(out, terminal[i]) end
    end
    return out
end

function R:Retain(paths, width, before)
    table.sort(paths, before)
    local investment, i = nil, nil
    for i = 1, table.getn(paths) do
        if paths[i].resourceInvestmentOpen then investment = paths[i]; break end
    end
    while table.getn(paths) > width do table.remove(paths) end
    if investment then
        local found = false
        for i = 1, table.getn(paths) do
            if paths[i] == investment then found = true; break end
        end
        if not found and width > 0 then paths[table.getn(paths)] = investment end
    end
    table.sort(paths, before)
end
