-- Privacy-safe presentation of target survival evidence attached to a plan.
XelAssist.UI.SurvivalTooltip = {}
local T = XelAssist.UI.SurvivalTooltip

function T:Add(plan)
    local survival = plan and plan.survival
    if not survival then return end
    if survival.available ~= true then
        GameTooltip:AddLine("Survival pressure: "
            .. tostring(survival.reason or "unavailable"), 1, 0.72, 0.28)
        return
    end
    local factor = math.max(0, math.min(1,
        tonumber(survival.decisionFactor) or 1))
    GameTooltip:AddLine(string.format("Target survival ~%.1fs · %.0f damage/s",
        tonumber(survival.timeToDie) or 0,
        tonumber(survival.incomingDps) or 0),
        factor < 0.75 and 1 or 0.72,
        factor < 0.75 and 0.72 or 0.75,
        factor < 0.75 and 0.28 or 0.82)
    GameTooltip:AddLine(string.format("Learned %.1fs · %s · action output %d%%",
        tonumber(survival.observedFor) or 0,
        tostring(survival.confidence or "partial data"),
        math.floor(factor * 100 + 0.5)), 0.55, 0.58, 0.64)
end
