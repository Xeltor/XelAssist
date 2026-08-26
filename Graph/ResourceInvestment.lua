-- Keeps bounded search lanes for legal investments whose value is realized by
-- a later edge. Resource conversions close when their gain becomes necessary;
-- form and stance setup closes only on an exact destination-dependent edge.
-- An unresolved lane may be explored but can never become a published plan.
XelAssist.Graph.ResourceInvestment = {}
local R = XelAssist.Graph.ResourceInvestment
local STRATEGIC_SETUP_LANES = 2

local function facts(candidate)
    return candidate and candidate.action and candidate.action.facts or {}
end

local function formID(value)
    if type(value) ~= "number" or value < 0 or value > 32
        or math.floor(value) ~= value then return nil end
    return value
end

local function flagSet(value, flag)
    if type(value) ~= "number" or value < 0
        or value > 4294967295 or math.floor(value) ~= value
        or not flag or flag <= 0 then return false end
    return math.floor(value / flag)
        - math.floor(value / (flag * 2)) * 2 == 1
end

local function maskFor(value)
    value = formID(value)
    if not value or value == 0 then return 0 end
    return 2 ^ (value - 1)
end

function R:Is(candidate)
    local found = facts(candidate)
    return found.healthConversion == true or found.petManaConversion == true
end

function R:IsStrategic(candidate)
    if not (candidate and candidate.strategicSetup == true
        and type(candidate.strategicSetupKey) == "string"
        and candidate.strategicSetupKey ~= ""
        and type(candidate.strategicSetupConsumerKey) == "string"
        and candidate.strategicSetupConsumerKey ~= "") then return false end
    local source = candidate.strategicSetupSourceForm
    local target = candidate.strategicSetupTargetForm
    return source == nil and target == nil or formID(source) ~= nil
        and formID(target) ~= nil
end

function R:Expandable(candidate, prior)
    if candidate and candidate.strategicSetup == true then
        return self:IsStrategic(candidate)
            and not (prior and prior.strategicSetupOpen == true)
    end
    if (tonumber(candidate and candidate.value) or 0) > 0
        or self:Is(candidate) then return true end
    return false
end
local function dependencyMatches(path, key, allowed, excluded)
    if not (path and path.strategicSetupOpen == true) then return false end
    local expected = path.strategicSetupConsumerKey
    if type(expected) == "string" and expected ~= ""
        and key == expected then return true end
    local source, target = formID(path.strategicSetupSourceForm),
        formID(path.strategicSetupTargetForm)
    if source == nil or target == nil then return false end
    local sourceMask, targetMask = maskFor(source), maskFor(target)
    if type(allowed) == "number" and allowed > 0
        and targetMask > 0 and flagSet(allowed, targetMask)
        and (sourceMask == 0 or not flagSet(allowed, sourceMask)) then
        return true
    end
    return type(excluded) == "number" and excluded > 0
        and sourceMask > 0 and flagSet(excluded, sourceMask)
        and (targetMask == 0 or not flagSet(excluded, targetMask))
end

local function consumesSetup(path, candidate)
    if not (candidate and candidate.strategicSetup ~= true
        and (tonumber(candidate.value) or 0) > 0) then return false end
    return dependencyMatches(path, candidate.setupConsumerKey,
        candidate.setupAllowedForms, candidate.setupExcludedForms)
end

-- SearchSession uses only sealed action facts to avoid rescanning the complete
-- catalog for each reserved setup lane. Unknown or malformed masks fail closed.
function R:PotentialConsumer(path, _, sealedFacts)
    if not (path and path.strategicSetupOpen == true
        and type(sealedFacts) == "table") then return false end
    local key = sealedFacts.setupConsumerKey
    local priest = XelAssist.Graph.PriestInnerFocus
    if key == nil and priest then key = priest:ConsumerKey(sealedFacts) end
    local presence = XelAssist.Graph.MagePresenceOfMind
    if key == nil and presence then
        key = presence:ConsumerKey(sealedFacts)
    end
    local powerInfusion = XelAssist.Graph.PriestPowerInfusion
    if key == nil and powerInfusion then
        key = powerInfusion:ConsumerKey(sealedFacts)
    end
    local manaSpring = XelAssist.Graph.ShamanManaSpring
    if key == nil and manaSpring then
        key = manaSpring:ConsumerKey(sealedFacts)
    end
    if type(key) ~= "string" or key == ""
        or string.len(key) > 128 then key = nil end
    return dependencyMatches(path, key,
        sealedFacts.stances, sealedFacts.stancesNot)
end

function R:ConsumerActions(path, state, actions, observation)
    local out, i = {}, nil
    if not (observation and type(observation.Facts) == "function") then
        return out
    end
    for i = 1, table.getn(actions or {}) do
        local action = actions[i]
        local sealed, status = observation:Facts(state, action)
        if status == "known" and type(sealed) == "table"
            and self:PotentialConsumer(path, action, sealed) then
            table.insert(out, action)
        end
    end
    return out
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
    local setupKey = prior.strategicSetupOpen == true and prior.strategicSetupKey
        or nil
    local setupSource = setupKey and prior.strategicSetupSourceForm or nil
    local setupTarget = setupKey and prior.strategicSetupTargetForm or nil
    local setupConsumer = setupKey and prior.strategicSetupConsumerKey or nil
    if self:IsStrategic(candidate) then
        setupKey, setupSource, setupTarget, setupConsumer =
            candidate.strategicSetupKey, candidate.strategicSetupSourceForm,
            candidate.strategicSetupTargetForm,
            candidate.strategicSetupConsumerKey
    elseif setupKey and consumesSetup(prior, candidate) then
        setupKey, setupSource, setupTarget, setupConsumer = nil, nil, nil, nil
    end
    out.strategicSetupOpen = setupKey and true or nil
    out.strategicSetupKey = setupKey
    out.strategicSetupSourceForm = setupSource
    out.strategicSetupTargetForm = setupTarget
    out.strategicSetupConsumerKey = setupConsumer
    return out
end

function R:Eligible(path)
    return path and path.resourceInvestmentOpen ~= true
        and path.strategicSetupOpen ~= true
end

function R:Collect(frontier, terminal)
    local out, seen, i = {}, {}, nil
    for i = 1, table.getn(frontier or {}) do
        if self:Eligible(frontier[i]) and not seen[frontier[i]] then
            seen[frontier[i]] = true; table.insert(out, frontier[i])
        end
    end
    for i = 1, table.getn(terminal or {}) do
        if self:Eligible(terminal[i]) and not seen[terminal[i]] then
            seen[terminal[i]] = true; table.insert(out, terminal[i])
        end
    end
    return out
end

local function contains(paths, wanted)
    local i
    for i = 1, table.getn(paths) do
        if paths[i] == wanted then return true end
    end
    return false
end

local function setupPathBefore(a, b, before)
    local aStep = a.steps and a.steps[table.getn(a.steps)] or nil
    local bStep = b.steps and b.steps[table.getn(b.steps)] or nil
    local aCost = aStep and aStep.costKnown and tonumber(aStep.cost) or math.huge
    local bCost = bStep and bStep.costKnown and tonumber(bStep.cost) or math.huge
    if aCost ~= bCost then return aCost < bCost end
    local aTime = aStep and tonumber(aStep.occupancy) or math.huge
    local bTime = bStep and tonumber(bStep.occupancy) or math.huge
    if aTime ~= bTime then return aTime < bTime end
    if a.strategicSetupKey ~= b.strategicSetupKey then
        return a.strategicSetupKey < b.strategicSetupKey
    end
    return before(a, b)
end

function R:Schedule(paths, before)
    table.sort(paths, function(a, b)
        local aOpen, bOpen = a.strategicSetupOpen == true,
            b.strategicSetupOpen == true
        if aOpen ~= bOpen then return aOpen end
        if aOpen then return setupPathBefore(a, b, before) end
        return before(a, b)
    end)
end

function R:Retain(paths, width, before)
    table.sort(paths, before)
    local ordinary, setups, investment, i = {}, {}, nil, nil
    for i = 1, table.getn(paths) do
        local path, key = paths[i], paths[i].strategicSetupKey
        if path.strategicSetupOpen == true and type(key) == "string"
            and key ~= "" then
            if not setups[key] or before(path, setups[key]) then
                setups[key] = path
            end
        elseif path.strategicSetupOpen ~= true then
            table.insert(ordinary, path)
            if not investment and path.resourceInvestmentOpen then
                investment = path
            end
        end
    end
    width = math.max(0, math.floor(tonumber(width) or 0))
    local setupPaths, key = {}, nil
    for key in pairs(setups) do table.insert(setupPaths, setups[key]) end
    table.sort(setupPaths, function(a, b)
        return setupPathBefore(a, b, before)
    end)
    local setupLimit = math.min(STRATEGIC_SETUP_LANES,
        table.getn(ordinary) > 0 and math.max(0, width - 1) or width,
        table.getn(setupPaths))
    local ordinaryWidth = width - setupLimit
    while table.getn(ordinary) > ordinaryWidth do table.remove(ordinary) end
    if investment then
        if not contains(ordinary, investment) and ordinaryWidth > 0 then
            ordinary[table.getn(ordinary)] = investment
        end
    end
    while table.getn(paths) > 0 do table.remove(paths) end
    for i = 1, table.getn(ordinary) do table.insert(paths, ordinary[i]) end
    for i = 1, setupLimit do table.insert(paths, setupPaths[i]) end
    self:Schedule(paths, before)
end
