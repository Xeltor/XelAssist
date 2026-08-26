-- State-context gates that are independent of recipient, range, resource and
-- cooldown evidence. Keeping these together prevents target legality from
-- becoming the owner of stealth, channel and summon policy as well.
XelAssist.Graph.ActionContextPolicy = {}
local P = XelAssist.Graph.ActionContextPolicy

function P:Blocker(action, state)
    local facts, kind = action.facts, action.facts.kind
    local aspects = XelAssist.Graph.HunterAspects
    local aspectBlocker = aspects and aspects:Blocker(action)
    if aspectBlocker then return aspectBlocker end
    if facts.autoRepeat and state.playerCasting
        and not state.playerChanneling then return "casting" end
    if facts.wandRepeat and state.moving then return "moving" end
    if facts.outOfCombat and state.inCombat then return "combat state" end
    if facts.combatOnly and not state.inCombat then return "combat state" end
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
