-- Actor-clock and resource admission for a chosen graph action.
XelAssist.Graph.ActionAdmission = {}
local A = XelAssist.Graph.ActionAdmission

function A:Start(action, state, tooltip)
    local facts, kind = action.facts, action.facts.kind
    local cast = facts.cast
    if cast == nil then cast = tooltip.cast end
    if facts.channel and (not cast or cast <= 0) then
        cast = tooltip.duration or 3
    end
    if state.instantNext and cast and cast > 0 then cast = 0 end
    if action.actor ~= "pet" and (state.time or 0) <= 0
        and state.moving and cast and cast > 0 then
        return nil, "moving"
    end
    local actor = action.actor or "player"
    local playerSwings = XelAssist.Graph.PlayerSwings
    local immediate = kind == "command"
        or playerSwings and playerSwings:Is(action, tooltip)
        or facts.autoRepeat and state.playerChanneling
    local resources = XelAssist.Graph.CompanionResources
    if actor == "pet" and kind ~= "command" and resources
        and not resources:ReadyExact(state, action) then
        return nil, "companion readiness unknown"
    end
    local at = immediate and (state.time or 0) or math.max(state.time or 0,
        (state.actorReadyAt and state.actorReadyAt[actor]) or 0)
    if actor == "pet" and kind ~= "command" and at > (state.time or 0) then
        return nil, "companion casting"
    end
    local playerResources = XelAssist.Game.Player
        and XelAssist.Game.Player.Resources
    if actor == "player" and playerResources then
        local available = (tonumber(state.resource) or 0)
            - (tonumber(state.playerResourceReserved) or 0)
        if (state.time or 0) <= 0
            and available < (tonumber(tooltip.cost) or 0) then
            return nil, "resource"
        end
        local ready = playerResources:Earliest(state, tooltip.cost, at)
        if ready then at = math.max(at, ready)
        elseif (tonumber(state.resource) or 0)
            - (tonumber(state.playerResourceReserved) or 0)
            < (tonumber(tooltip.cost) or 0) then return nil, "resource" end
    end
    return at, nil
end

function A:Readiness(action, state, tooltip, actionStart)
    local facts, actor = action.facts, action.actor or "player"
    local resource = state.resource
    if action.actor == "pet" and state.actors and state.actors.pet then
        resource = state.actors.pet.resource
    elseif action.actor ~= "pet" and resource ~= nil then
        local playerResources = XelAssist.Game.Player
            and XelAssist.Game.Player.Resources
        resource = playerResources and playerResources:ResourceAt(
            state, actionStart) or resource - math.max(0,
                tonumber(state.playerResourceReserved) or 0)
    end
    local resources = XelAssist.Graph.CompanionResources
    if resources and not resources:ChosenExact(
        state, action, tooltip.cost) then return "pet resource unknown" end
    if resource == nil then
        return action.actor == "pet" and "pet resource unknown" or "resource unknown"
    end
    if resource < (tooltip.cost or 0) then
        return action.actor == "pet" and "pet resource" or "resource"
    end
    if action.executor == "item" then
        local remaining = XelAssist.Game.Inventory:Cooldown(action)
        if remaining and remaining > actionStart then return "item cooldown" end
    elseif action.actor == "pet" then
        local remaining = XelAssist.Game.Actors:PetCooldown(action)
        if remaining and remaining > actionStart then return "pet cooldown" end
    elseif not XelAssist.Game.Capabilities:IsReady(action.name, actionStart) then
        return "cooldown"
    end
    if state.readyAt[actor .. ":" .. action.name]
        and state.readyAt[actor .. ":" .. action.name] > actionStart then
        return "future cooldown"
    end
    local group = facts.cooldownGroup or tooltip.cooldownGroup
    if group and state.readyAt["group:" .. group]
        and state.readyAt["group:" .. group] > actionStart then
        return "shared cooldown"
    end
    return nil
end
