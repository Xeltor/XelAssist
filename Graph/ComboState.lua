-- Probability distribution for combo points after uncertain hostile actions.
-- Root observations are exact; future builders and finishers retain both their
-- landed and failed branches without pretending either outcome is guaranteed.
XelAssist.Graph.ComboState = {}
local C = XelAssist.Graph.ComboState

local MAX_COMBO = 5

local function clampPoints(points)
    return math.max(0, math.min(MAX_COMBO, tonumber(points) or 0))
end

local function clampProbability(probability)
    return math.max(0, math.min(1, tonumber(probability) or 1))
end

function C:Attach(state, points)
    points = clampPoints(points)
    state.comboDistribution = { [points] = 1 }
    state.comboDistributionProjected = false
    state.comboDistributionObserved = points
    state.combo, state.comboAvailability = points, points > 0 and 1 or 0
end

function C:Ensure(state)
    if type(state.comboDistribution) ~= "table"
        or state.comboDistributionProjected ~= true
            and clampPoints(state.combo) ~= state.comboDistributionObserved then
        self:Attach(state, state.combo)
    end
    return state.comboDistribution
end

function C:Summarize(state)
    local distribution = self:Ensure(state)
    local expected, available, points, probability = 0, 0, nil, nil
    for points, probability in pairs(distribution) do
        expected = expected + clampPoints(points) * probability
        if points > 0 then available = available + probability end
    end
    state.combo = expected
    state.comboAvailability = clampProbability(available)
    return expected, state.comboAvailability
end

function C:Expected(state)
    local expected = self:Summarize(state)
    return expected
end

function C:Availability(state)
    local _, available = self:Summarize(state)
    return available
end

function C:ConditionalExpected(state)
    local expected, available = self:Summarize(state)
    if available <= 0 then return 0 end
    return expected / available
end

function C:Apply(state, candidate, facts)
    local tooltip = candidate.tooltip or {}
    local gain = tonumber(tooltip.comboGain)
    if not gain and (facts.kind == "builder" or facts.comboBuilder) then gain = 1 end
    local spends = facts.combo or tooltip.comboSpendAll
    if not (gain and gain > 0 or spends) then return false end
    local land = candidate.resistance
        and candidate.resistance.landChance or 1
    land = clampProbability(land)
    local current, projected = self:Ensure(state), {}
    local points, probability
    for points, probability in pairs(current) do
        local prior = clampPoints(points)
        projected[prior] = (projected[prior] or 0)
            + probability * (1 - land)
        local landed = gain and gain > 0
            and math.min(MAX_COMBO, prior + gain) or 0
        projected[landed] = (projected[landed] or 0)
            + probability * land
    end
    state.comboDistribution = projected
    state.comboDistributionProjected = true
    state.comboDistributionObserved = nil
    self:Summarize(state)
    return true
end
