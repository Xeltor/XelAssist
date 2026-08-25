-- Actor-clock and resource admission for a chosen graph action.
XelAssist.Graph.ActionAdmission = {}
local A = XelAssist.Graph.ActionAdmission

local function castTime(action, state, tooltip)
    local facts = action.facts
    local cast = facts.cast
    if cast == nil then cast = tooltip.cast or (facts.channel and 3 or 0) end
    cast = math.max(0, tonumber(cast) or 0)
    if facts.channel and cast <= 0 then
        cast = math.max(0, tonumber(tooltip.duration) or 3)
    end
    if state.instantNext and cast > 0 then cast = 0 end
    return cast
end

function A:Timing(action, state, tooltip)
    local cast = castTime(action, state, tooltip)
    local swings = XelAssist.Graph.PlayerSwings
    local nextSwing = swings and swings:Is(action, tooltip)
    if nextSwing then cast = 0 end
    local defaultGCD = action.actor == "pet" and 0.1 or 1.5
    local gcd = tonumber(action.facts.gcd)
    if gcd == nil then gcd = tonumber(tooltip.gcd) end
    gcd = math.max(0, gcd == nil and defaultGCD or gcd)
    local normalGcd = action.actor ~= "pet"
        and XelAssist.Game.SpellClassification:NormalGcd(action, tooltip)
    local cycle = math.max(0.05, gcd, cast)
    local occupancy = nextSwing and swings:Occupancy()
        or action.actor == "pet" and cycle or math.max(0.05, cast)
    return cast, nextSwing, gcd, normalGcd and true or false,
        cycle, occupancy
end

function A:Start(action, state, tooltip)
    local facts, kind = action.facts, action.facts.kind
    local cast = castTime(action, state, tooltip)
    if action.actor ~= "pet" and state.moving and cast and cast > 0 then
        return nil, "moving"
    end
    local actor = action.actor or "player"
    local playerSwings = XelAssist.Graph.PlayerSwings
    local channel = XelAssist.Graph.ChannelCommitment
    if channel and channel:IsActive(state, action) then
        return nil, "channel already active"
    end
    local immediate = kind == "command"
        or playerSwings and playerSwings:Is(action, tooltip)
        or facts.autoRepeat and state.playerChanneling
        or channel and channel:CanClip(state, action)
    local resources = XelAssist.Graph.CompanionResources
    if actor == "pet" and kind ~= "command" and resources
        and not resources:ReadyExact(state, action) then
        return nil, "companion readiness unknown"
    end
    local at = immediate and (state.time or 0) or math.max(state.time or 0,
        (state.actorReadyAt and state.actorReadyAt[actor]) or 0)
    if actor == "player" and not immediate
        and XelAssist.Game.SpellClassification:NormalGcd(action, tooltip) then
        at = math.max(at, tonumber(state.playerGcdReadyAt) or 0)
    end
    if actor == "pet" and kind ~= "command" and at > (state.time or 0)
        and (state.time or 0) <= 0 then
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

local function observedCooldown(action, state, actionStart)
    local root = XelAssist.Graph.RootObservation
    if not root then return nil, false end
    local record, status = root:ActionRecord(state, action)
    if status == "absent" then return nil, false end
    if status ~= "known" or type(record.cooldown) ~= "table" then
        return "cooldown evidence unknown", true
    end
    local cooldown = record.cooldown
    if cooldown.applicable and not cooldown.known then
        return cooldown.reason or "cooldown evidence unknown", true
    end
    local rootReady = cooldown.applicable
        and math.max(0, tonumber(cooldown.remaining) or 0) or 0
    local ledger = XelAssist.Graph.CooldownLedger
    local projected = ledger and ledger.ReadyAt
        and tonumber(ledger:ReadyAt(state, action)) or 0
    local readyAt = math.max(rootReady, projected or 0)
    if readyAt <= (tonumber(actionStart) or 0) then return nil, true end
    if projected and projected > rootReady then return "future cooldown", true end
    if action.executor == "item" then return "item cooldown", true end
    return action.actor == "pet" and "pet cooldown" or "cooldown", true
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
    local handled, blocker = false, nil
    blocker, handled = observedCooldown(action, state, actionStart)
    if handled then
        if blocker then return blocker end
    elseif action.executor == "item" then
        local remaining = XelAssist.Game.Inventory:Cooldown(action)
        if remaining and remaining > actionStart then return "item cooldown" end
    else
        local ledger = XelAssist.Graph.CooldownLedger
        if ledger and ledger:IsPrepared(state) then
            blocker, handled = ledger:Blocker(state, action, actionStart)
        end
        if handled then
            if blocker then return blocker end
        elseif action.actor == "pet" then
            local remaining = XelAssist.Game.Actors:PetCooldown(action)
            if remaining and remaining > actionStart then return "pet cooldown" end
        elseif not XelAssist.Game.Capabilities:IsReady(action.name,
            actionStart) then return "cooldown" end
    end
    if state.readyAt[actor .. ":" .. action.name]
        and state.readyAt[actor .. ":" .. action.name] > actionStart then
        return "future cooldown"
    end
    local group = facts.cooldownGroup or tooltip.cooldownGroup
    local ledger = XelAssist.Graph.CooldownLedger
    local groupKey = ledger and ledger:IsPrepared(state)
        and ledger:GroupKey(group) or group and "group:" .. group
    if groupKey and state.readyAt[groupKey]
        and state.readyAt[groupKey] > actionStart then
        return "shared cooldown"
    end
    return nil
end
