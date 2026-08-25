-- Generic marginal value for DBC-discovered combo spenders. A long-lived
-- target should not repeatedly collect the finisher's fixed base utility and
-- full resource cost at one point; exact lethal damage remains authoritative.
XelAssist.Graph.ComboScoring = {}
local C = XelAssist.Graph.ComboScoring

local MAX_COMBO = 5

function C:Apply(context)
    local facts, tooltip, state = context.facts, context.tooltip, context.state
    local spends = facts.combo or tooltip.comboSpendAll
    local points = math.max(0, math.min(MAX_COMBO,
        spends and XelAssist.Graph.ComboState
            and XelAssist.Graph.ComboState:ConditionalExpected(state)
            or tonumber(state.combo) or 0))
    if spends and context.kind == "damage" and points < MAX_COMBO
        and context.reason ~= "finishes the target" then
        local raw = math.max(0, tonumber(context.power) or 0)
        local combo = math.max(0, tonumber(tooltip.comboBonus) or 0) * points
        local base = math.max(0, raw - combo)
        local delivery = raw > 0
            and math.max(0, (tonumber(context.expectedPower) or 0) / raw)
            or math.max(0, tonumber(context.effectDelivery) or 1)
        local timing = context.onNextSwing and context.impactDelay
            or context.downtime
        local unused = (MAX_COMBO - points) / MAX_COMBO
        local penalty = (250 + base * delivery * 4
            / math.max(0.5, tonumber(timing) or 0)) * unused
        context.value = context.value - penalty
        context.comboEfficiencyPenalty = penalty
    end
    local gain = tonumber(tooltip.comboGain)
    if not gain and (facts.kind == "builder" or facts.comboBuilder) then gain = 1 end
    if gain and gain > 0 and points < MAX_COMBO then
        context.reason = "builds toward an efficient finisher"
    end
end
