-- State-context gates that are independent of recipient, range, resource and
-- cooldown evidence. Keeping these together prevents target legality from
-- becoming the owner of stealth, channel and summon policy as well.
XelAssist.Graph.ActionContextPolicy = {}
local P = XelAssist.Graph.ActionContextPolicy

function P:Blocker(action, state, tooltip)
    local facts, kind = action.facts, action.facts.kind
    if facts.unmodeledUnsafe then
        local evocation = XelAssist.Graph.MageEvocation
        if not (facts.mageEvocation == true and evocation
            and evocation:CanUse(state, facts)) then
            return type(facts.unmodeledUnsafe) == "string"
                and facts.unmodeledUnsafe or "unsafe consequence is not modeled"
        end
    end
    if facts.requiresExactTooltipCost
        and not (tooltip and tooltip.tooltipCostExact == true) then
        return "dynamic action cost unavailable"
    end
    local forms = XelAssist.Graph.FormRequirements
    local formBlocker = forms and forms:Blocker(state, tooltip)
    if formBlocker then return formBlocker end
    local equipment = XelAssist.Graph.EquipmentRequirements
    local equipmentBlocker = equipment and equipment:Blocker(state, tooltip)
    if equipmentBlocker then return equipmentBlocker end
    local threatDrop = XelAssist.Graph.ThreatDrop
    local feign = XelAssist.Graph.HunterFeignDeath
    local feignBlocker, feignHandled = feign
        and feign:Blocker(action, state, nil, tooltip)
    if feignHandled then return feignBlocker end
    local threatDropBlocker = threatDrop
        and threatDrop:Blocker(action, state, tooltip)
    if threatDropBlocker then return threatDropBlocker end
    local aspects = XelAssist.Graph.HunterAspects
    local aspectBlocker = aspects and aspects:Blocker(action)
    if aspectBlocker then return aspectBlocker end
    if facts.autoRepeat and state.playerCasting
        and not state.playerChanneling then return "casting" end
    if facts.wandRepeat and state.moving then return "moving" end
    if facts.outOfCombat and state.inCombat then return "combat state" end
    if facts.combatOnly and not state.inCombat then return "combat state" end
    if kind == "resource" and state.playerResourceMinimumExact
        and state.playerResourceExact ~= true then
        return "resource ceiling unknown"
    end
    if facts.stealthPreparation and state.playerStealthKnown == true
        and state.playerStealthed == true then return "already stealthed" end
    if facts.stealthPreparation and XelAssist.Graph.StealthSetup then
        local blocker = XelAssist.Graph.StealthSetup:Blocker(state)
        if blocker then return blocker end
    end
    if kind == "summon" and not facts.petLifecycle then
        if state.pet then return "companion already active" end
        if state.inCombat then return "unsafe summon" end
    end
    return nil
end
