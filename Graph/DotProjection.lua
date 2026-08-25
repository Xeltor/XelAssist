-- Candidate-local direct/periodic decomposition. Resistance scoring owns the
-- expected power; this module presents one stable transition contract.
XelAssist.Graph.DotProjection = {}
local D = XelAssist.Graph.DotProjection

local function weightedSplit(candidate)
    local resistance = candidate.resistance
    if not (resistance and resistance.mode == "hybrid"
        and type(resistance.components) == "table") then
        return 0, candidate.power
    end
    local direct, periodic, unassigned, total = 0, 0, 0, 0
    local i
    for i = 1, table.getn(resistance.components) do
        local component = resistance.components[i]
        local share = tonumber(component.decisionShare) or 0
        total = total + share
        if component.componentPhase == "direct" then direct = direct + share
        elseif component.componentPhase == "periodic" then periodic = periodic + share
        else unassigned = unassigned + share end
    end
    if total <= 0 then return 0, candidate.power end
    periodic = periodic + unassigned
    return candidate.power * direct / total,
        candidate.power * periodic / total
end

function D:Candidate(candidate)
    local direct, periodic, duration, elapsed = 0, 0, nil, 0
    if candidate.action.facts.kind ~= "dot" then
        return direct, periodic, duration, elapsed
    end
    if candidate.dotRawPeriodicPower ~= nil then
        periodic = candidate.dotPeriodicExpectedPower or 0
        direct = math.max(0, candidate.power - periodic)
    else direct, periodic = weightedSplit(candidate) end
    duration = math.max(1, tonumber(candidate.tooltip.duration) or 12)
    elapsed = math.min(duration,
        math.max(0, (candidate.occupancy or 0)
            - math.max(0, candidate.cast or 0)))
    return direct, periodic, duration, elapsed
end

function D:RawPeriodicRate(candidate, duration)
    local power = tonumber(candidate.dotRawPeriodicPower)
    if power == nil or not duration or duration <= 0 then return nil end
    local survival = candidate.survival
    return power * (survival and survival.periodicFactor or 1) / duration
end
