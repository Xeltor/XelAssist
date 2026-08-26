-- Productive melee actions can establish the same ambient Attack state as the
-- bare command. This module prices and projects that shared graph edge without
-- inventing a white swing or disturbing a verified round already in progress.
XelAssist.Graph.PlayerEngagement = {}
local E = XelAssist.Graph.PlayerEngagement
local Mechanic = XelAssist.Game.Player.Engagement

local SETUP_VALUE = 800

function E:Score(context)
    local attack = context.state.playerAttack
    if not (Mechanic:Starts(context.action, context.tooltip,
        context.descriptor and context.descriptor.relation)
        and attack and attack.activeKnown == true and attack.active == false
        and not attack.pending) then return end
    context.startsPlayerAttack = true
    context.value = context.value + SETUP_VALUE
    context.reason = "starts sustained attacks with a productive action"
end

local function currentTarget(attack)
    return attack and (attack.targetGuid
        or attack.attackRound and attack.attackRound.targetGuid
        or attack.offhandAttackRound
            and attack.offhandAttackRound.targetGuid) or nil
end

function E:Apply(out, candidate)
    if not Mechanic:HostilePlayerAction(candidate.action,
        candidate.targetRelation) then return false end
    local transition = Mechanic:AttackTransition(candidate.action,
        candidate.tooltip, candidate.targetRelation)
    local attack, targetGuid = out.playerAttack,
        candidate.targetGUID or out.targetGUID
    local activeHere = attack and attack.activeKnown == true
        and attack.active == true and (not currentTarget(attack)
            or not targetGuid or currentTarget(attack) == targetGuid)
    if transition == "stop" and XelAssist.Game.PlayerAttack then
        out.playerAttack = XelAssist.Game.PlayerAttack:ProjectedStopped(
            targetGuid, "graph hostile action stopped Attack")
    elseif transition == "start" and not activeHere
        and XelAssist.Game.PlayerAttack then
        out.playerAttack = XelAssist.Game.PlayerAttack:Projected(
            targetGuid, "graph hostile Attack start")
    end
    if not Mechanic:PreservesStealth(candidate.action, candidate.tooltip) then
        out.playerStealthed, out.playerStealthKnown = false, true
        out.playerStealthSource = "projected hostile action"
    end
    return true
end
