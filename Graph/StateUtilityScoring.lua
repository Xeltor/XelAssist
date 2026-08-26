-- Generic state-changing utility. Exact class consequences score before this
-- fallback; this module never defines a class action order.
XelAssist.Graph.StateUtilityScoring = {}
local U = XelAssist.Graph.StateUtilityScoring
local State = XelAssist.Graph.State

function U:Score(context)
    local state, facts, kind = context.state, context.facts, context.kind
    if kind == "defensive" then
        local hp = state.healthMax > 0 and state.health / state.healthMax or 1
        context.value = (1 - hp) * 1800 + (state.hasAggro and 500 or 0)
        context.reason = "reduces immediate danger"
    elseif kind == "resource" then
        if XelAssist.Graph.WarriorRage
            and XelAssist.Graph.WarriorRage:Score(context) then return end
        if XelAssist.Graph.ResourceExchange
            and XelAssist.Graph.ResourceExchange:Score(context) then return end
        local missing = math.max(0, state.resourceMax - state.resource)
        if facts.consumable then
            local effective = math.min(context.power, missing)
            context.value = effective * 4 / math.max(0.5, context.downtime)
                - 1200 / math.max(1, context.action.count or 1)
            if context.power > missing * 1.35 then
                context.value = context.value - (context.power - missing) * 2
            end
            if missing <= 0 then context.value = -1000 end
            context.reason = context.power > missing * 1.35
                and "avoids wasting a resource consumable"
                or "restores needed combat resources"
        else
            context.value = state.resourceMax > 0
                and (1 - state.resource / state.resourceMax) * 1200 or 0
            context.reason = "recovers combat resources"
        end
    elseif kind == "buff" then
        if facts.stealthPreparation and XelAssist.Graph.StealthSetup then
            XelAssist.Graph.StealthSetup:Score(context)
        else
            context.value = 500 + (context.tooltip.duration or 0) * 4
            context.reason = "adds missing utility"
        end
    elseif kind == "debuff" then
        local tooltip = context.tooltip
        local survivalFactor = context.survival
            and context.survival.utilityFactor or 1
        if tooltip.targetArmorReduction
            or tooltip.targetResistanceReduction or tooltip.targetDamageTaken then
            context.value, context.reason = 120 * survivalFactor,
                "opens a stronger damage path"
        else
            context.value = (200
                + math.min(10, tooltip.duration or 0) * 4) * survivalFactor
            context.reason = "adds missing utility"
        end
    elseif kind == "modifier" then
        local urgent = State:PrimaryFriendly(state)
        local missing = State:Missing(urgent)
        local maximum = urgent and (tonumber(urgent.healthMax) or 0) or 0
        context.value = facts.nextInstant
            and (state.moving or missing > maximum * 0.45) and 1500 or 250
        context.reason = facts.nextInstant and "makes the next cast instant"
            or "improves the next action"
    end
end
