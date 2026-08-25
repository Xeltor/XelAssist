-- Generic combo-point transition facts discovered from Spell.dbc, with the
-- semantic knowledge table retained only as a compatibility fallback.
XelAssist.Graph.ComboEffects = {}
local C = XelAssist.Graph.ComboEffects

function C:Apply(out, candidate, facts)
    if XelAssist.Graph.ComboState
        and XelAssist.Graph.ComboState:Apply(out, candidate, facts) then
        return
    end
    local tooltip = candidate.tooltip or {}
    local gain = tonumber(tooltip.comboGain)
    if not gain and (facts.kind == "builder" or facts.comboBuilder) then gain = 1 end
    if gain and gain > 0 then
        out.combo = math.min(5, (out.combo or 0) + gain)
    elseif facts.combo or tooltip.comboSpendAll then out.combo = 0 end
end
