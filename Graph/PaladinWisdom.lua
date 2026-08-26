-- Search-pure self Blessing of Wisdom consequence. The cast carries no flat
-- utility: exact periodic mana changes later action reachability. Other
-- recipients and Greater Blessing class fanout remain deliberately unresolved.
XelAssist.Graph.PaladinWisdom = {}
local W = XelAssist.Graph.PaladinWisdom

W.CONSUMER_KEY = "paladinWisdom:manaSpend"
local EPSILON = 0.000001

local function finite(value, low, high)
    value = tonumber(value)
    if value == nil or value ~= value or value == math.huge
        or value == -math.huge or value < low or value > high then return nil end
    return value
end

local function integer(value, low, high)
    value = finite(value, low, high)
    return value and math.floor(value) == value and value or nil
end

local function copy(source)
    local out, key, value = {}, nil, nil
    for key, value in pairs(source or {}) do
        out[key] = type(value) == "table" and copy(value) or value
    end
    return out
end

local function runtime()
    return XelAssist.Game and XelAssist.Game.Player
        and XelAssist.Game.Player.PaladinWisdom
end

local function validGUID(value)
    return value ~= nil and value ~= "" and value ~= "0x000000000"
        and value ~= "0x0000000000000000"
end

local function profile(subject)
    local owner = runtime()
    return owner and owner:Profile(subject) or nil
end

local function rootPlayer(state)
    local root = state and state.paladinAuraState
    local player = root and root.player
    if not (root and root.available == true and player
        and player.available == true and player == root.byKey[root.playerKey]
        and validGUID(root.playerGUID) and player.guid == root.playerGUID
        and player.playerGUID == root.playerGUID
        and player.recipientRelation == "self") then return nil, nil end
    return root, player
end

local function ownBlessing(root, player)
    return player and player.blessingsByCaster
        and player.blessingsByCaster[root.playerGUID] or nil
end

local function sealedComponent(state)
    local component = state and state.paladinWisdom
    local root, player = rootPlayer(state)
    if not (component and root and component.available == true
        and component.exact == true) then return nil end
    if component.activeSpellId ~= nil then
        local found = profile({ paladinWisdomEvidence = component.activeProfile,
            paladinWisdomProfile = component.activeProfile })
        if not (found and found.spellId == component.activeSpellId
            and finite(component.remaining, EPSILON, found.duration)
            and finite(component.nextIn, EPSILON, found.period)
            and component.nextIn <= component.remaining + EPSILON
            and component.ownOtherBlessingSpellId == nil) then return nil end
    elseif component.activeProfile ~= nil or component.remaining ~= nil
        or component.nextIn ~= nil then return nil
    elseif component.ownOtherBlessingSpellId ~= nil then
        if not integer(component.ownOtherBlessingSpellId, 1, 4294967295) then
            return nil
        end
    end
    return component, root, player
end

local function exactComponent(state)
    local component, root, player = sealedComponent(state)
    if not component then return nil end
    local aura = ownBlessing(root, player)
    local expected = component.activeSpellId
        or component.ownOtherBlessingSpellId
    if expected ~= nil then
        if not (aura and aura.exact == true and aura.spellId == expected
            and aura.sourceGUID == root.playerGUID) then return nil end
    elseif aura ~= nil then return nil end
    return component
end

function W:Attach(state)
    if type(state) ~= "table" then return false end
    local owner, root, player = runtime(), rootPlayer(state)
    local observed = owner and root and owner:ObserveRoot(player, root.playerGUID)
    local available = observed and observed.available == true
        and observed.exact == true
    state.paladinWisdom = { available = available or false,
        exact = available or false, activeSpellId = observed and observed.activeSpellId,
        activeProfile = observed and observed.activeProfile
            and copy(observed.activeProfile) or nil,
        remaining = observed and observed.activeRemaining,
        nextIn = observed and observed.activeNextIn,
        ownOtherBlessingSpellId = observed
            and observed.ownOtherBlessingSpellId or nil,
        zeroThreat = available and true or nil,
        source = "projected exact self Wisdom mana",
        reason = observed and observed.reason or "Wisdom root evidence unavailable" }
    return available and exactComponent(state) ~= nil or false
end

function W:Copy(source, target)
    if not (source and target and source.paladinWisdom) then return false end
    target.paladinWisdom = copy(source.paladinWisdom)
    return exactComponent(target) ~= nil
end

local function exactSelf(state, projection)
    local root, player = rootPlayer(state)
    local friendlies = state and state.friendlies
    local record = root and friendlies and friendlies.byKey
        and friendlies.byKey[root.playerKey]
    if not (root and projection and projection.kind == "blessing"
        and projection.recipientKey == root.playerKey
        and projection.recipientGUID == root.playerGUID
        and projection.casterGUID == root.playerGUID
        and record and record.unit == "player" and record.relation == "self"
        and record.guid == root.playerGUID and player.guid == root.playerGUID) then
        return nil, nil
    end
    return root, player
end

local function claimed(facts)
    return facts and (facts.paladinWisdom == true
        or facts.requiresExactPaladinWisdomProfile == true
        or facts.paladinWisdomEvidence ~= nil)
end

local function transition(mode, projection, component, found)
    return { exact = true, kind = "paladinWisdomTransition", mode = mode,
        sourceSpellId = projection.actionSpellId,
        replacedWisdomSpellId = component.activeSpellId,
        amount = found and found.amount or nil,
        period = found and found.period or nil,
        duration = found and found.duration or nil,
        powerType = found and found.powerType or nil,
        zeroThreat = found and found.zeroThreat or true,
        profile = found and copy(found) or nil,
        source = "exact own blessing replacement and periodic mana profile" }
end

function W:Prepare(state, projection, facts)
    local isWisdom = claimed(facts)
    if not isWisdom and not (projection and projection.kind == "blessing") then
        return nil, nil, false
    end
    local root = exactSelf(state, projection)
    if not root then
        return nil, isWisdom and "Wisdom requires exact self recipient" or nil,
            isWisdom and true or false
    end
    local component = exactComponent(state)
    if not component then
        return nil, state and state.paladinWisdom
            and state.paladinWisdom.reason
            or "exact Wisdom component unavailable", isWisdom
    end
    local found = profile(facts)
    if isWisdom then
        local owner = runtime()
        if not (found and facts.paladinEffectRepresented == true
            and owner and found.powerType == owner.MANA
            and found.zeroThreat == true) then
            return nil, "captured Wisdom consequence unavailable", true
        end
        if component.ownOtherBlessingSpellId ~= nil then
            return nil, "displaced own blessing consequence is unresolved", true
        end
        projection.paladinWisdomTransition = transition(
            "apply", projection, component, found)
        return projection, nil, true
    end
    if component.activeSpellId == nil then return nil, nil, false end
    if projection.replacedSpellId ~= component.activeSpellId then
        return nil, "active Wisdom replacement is incoherent", true
    end
    projection.paladinWisdomTransition = transition(
        "remove", projection, component, nil)
    return projection, nil, true
end

local function exactTransition(value)
    if not (type(value) == "table" and value.exact == true
        and value.kind == "paladinWisdomTransition"
        and (value.mode == "apply" or value.mode == "remove")
        and integer(value.sourceSpellId, 1, 4294967295)
        and value.zeroThreat == true) then return nil end
    if value.mode == "apply" then
        local found = profile({ paladinWisdomEvidence = value.profile,
            paladinWisdomProfile = value.profile })
        if not (found and found.spellId == value.sourceSpellId
            and value.amount == found.amount and value.period == found.period
            and value.duration == found.duration
            and value.powerType == found.powerType) then return nil end
    elseif value.amount ~= nil or value.period ~= nil or value.duration ~= nil
        or value.powerType ~= nil or value.profile ~= nil
        or not integer(value.replacedWisdomSpellId, 1, 4294967295) then
        return nil
    end
    return value
end

function W:Score(context, projection)
    local found = exactTransition(projection and projection.paladinWisdomTransition)
    local component = exactComponent(context and context.state)
    if not found then return false, nil end
    if not component or found.replacedWisdomSpellId ~= component.activeSpellId then
        return false, "exact Wisdom projection unavailable"
    end
    if found.mode == "remove" then return false, nil end
    context.power, context.expectedPower, context.effectivePower = 0, 0, 0
    context.value, context.estimated = 0, false
    context.kind, context.reason = "classMechanic", "starts exact periodic player mana"
    return true
end

function W:Apply(state, projection)
    projection = projection and projection.classMechanicProjection or projection
    local found = exactTransition(projection and projection.paladinWisdomTransition)
    local component, root, player = sealedComponent(state)
    local aura = root and ownBlessing(root, player)
    if not (found and component and aura and aura.exact == true
        and aura.spellId == found.sourceSpellId
        and aura.sourceGUID == root.playerGUID
        and projection.action and tonumber(projection.action.spellId)
            == found.sourceSpellId
        and projection.recipientKey == root.playerKey
        and projection.recipientGUID == root.playerGUID
        and projection.casterGUID == root.playerGUID
        and projection.replacedSpellId == (component.activeSpellId
            or component.ownOtherBlessingSpellId)
        and found.replacedWisdomSpellId == component.activeSpellId) then
        return false
    end
    component.projected, component.expired = true, nil
    if found.mode == "apply" then
        component.activeSpellId = found.sourceSpellId
        component.activeProfile = copy(found.profile)
        component.remaining, component.nextIn = found.duration, found.period
        component.ownOtherBlessingSpellId = nil
    else
        component.activeSpellId, component.activeProfile = nil, nil
        component.remaining, component.nextIn = nil, nil
        component.ownOtherBlessingSpellId = found.sourceSpellId
    end
    return exactComponent(state) ~= nil
end

local function active(state)
    local component = exactComponent(state)
    local found = component and component.activeProfile
        and profile({ paladinWisdomEvidence = component.activeProfile,
            paladinWisdomProfile = component.activeProfile }) or nil
    return found and component or nil, found
end

local function syncPlayer(state)
    local player = state.actors and state.actors.player
    if player then player.resource = state.resource end
    local friendlies = state.friendlies
    if friendlies and type(friendlies.player) == "table" then
        friendlies.player.resource = state.resource
    end
    local key = friendlies and friendlies.byUnit and friendlies.byUnit.player
    local record = key ~= nil and friendlies.byKey and friendlies.byKey[key]
    if record then record.resource = state.resource end
end

local function tickCount(nextIn, period, elapsed, remaining)
    local window = remaining and math.min(elapsed, remaining) or elapsed
    if window + EPSILON < nextIn then return 0 end
    return 1 + math.floor((window - nextIn + EPSILON) / period)
end

local function expire(state, component)
    local root, player = rootPlayer(state)
    local aura = root and ownBlessing(root, player)
    if aura and aura.spellId == component.activeSpellId
        and aura.sourceGUID == root.playerGUID then
        player.blessingsByCaster[root.playerGUID] = nil
    end
    component.activeSpellId, component.activeProfile = nil, nil
    component.remaining, component.nextIn = nil, nil
    component.ownOtherBlessingSpellId, component.expired = nil, true
end

function W:Advance(state, elapsed)
    local component, found = active(state)
    elapsed = finite(elapsed, 0, 1000000)
    if not component or not elapsed or elapsed <= 0 then return 0 end
    local remaining, nextIn = component.remaining, component.nextIn
    local window, ticks = math.min(elapsed, remaining),
        tickCount(nextIn, found.period, elapsed, remaining)
    if window + EPSILON < nextIn then component.nextIn = nextIn - window
    elseif elapsed < remaining then
        local afterFirst = window - nextIn
        local residual = afterFirst - (ticks - 1) * found.period
        component.nextIn = found.period - residual
    end
    component.remaining = math.max(0, remaining - elapsed)
    local prior = tonumber(state.resource) or 0
    if state.playerResourceExact == true and tonumber(state.resourceType) == found.powerType
        and not state.dead and finite(state.resource, 0, 1000000000)
        and finite(state.resourceMax, state.resource, 1000000000) then
        state.resource = math.min(state.resourceMax,
            state.resource + ticks * found.amount)
        syncPlayer(state)
        if state.resource >= state.resourceMax and state.playerResourceClock then
            state.playerResourceClock.phaseKnown = false
            state.playerResourceClock.nextIn = nil
            state.playerResourceClock.phaseSource =
                "projected Wisdom cap erased base mana tick phase"
        end
    end
    if component.remaining <= 0 then expire(state, component) end
    return (tonumber(state.resource) or prior) - prior
end

local function baseClock(state)
    local clock = state and state.playerResourceClock
    local amount = clock and finite(clock.amount, EPSILON, 1000000000)
    local period = clock and finite(clock.interval, EPSILON, 1000000)
    local nextIn = clock and period
        and finite(clock.nextIn, 0, period) or nil
    if not (clock and clock.verified == true and clock.phaseKnown == true
        and clock.externalEnergizeExcluded == true
        and tonumber(clock.resourceType) == 0 and amount and period
        and nextIn) then return nil end
    return { amount = amount, period = period, nextIn = nextIn }
end

local function availableAt(state, offset, component, found)
    local current = finite(state.resource, 0, 1000000000)
    local maximum = finite(state.resourceMax, current or 0, 1000000000)
    local reserved = finite(state.playerResourceReserved or 0, 0, maximum or 0)
    if not current or not maximum or not reserved then return nil end
    local gain = 0
    local base = baseClock(state)
    if base then
        gain = gain + tickCount(base.nextIn, base.period, offset) * base.amount
    end
    if not state.dead then
        gain = gain + tickCount(component.nextIn, found.period,
            offset, component.remaining) * found.amount
    end
    return math.max(0, math.min(maximum, current + gain) - reserved)
end

function W:ResourceAt(state, at)
    local component, found = active(state)
    if not component or state.playerResourceExact ~= true
        or tonumber(state.resourceType) ~= found.powerType then return nil, false end
    local offset = math.max(0, (tonumber(at) or 0) - (tonumber(state.time) or 0))
    return availableAt(state, offset, component, found), true
end

function W:Earliest(state, cost, readyAt)
    local component, found = active(state)
    if not component or state.playerResourceExact ~= true
        or tonumber(state.resourceType) ~= found.powerType then return nil, false end
    cost = finite(cost, 0, 1000000000)
    local now = tonumber(state.time) or 0
    readyAt = math.max(now, tonumber(readyAt) or now)
    if not cost then return nil, true end
    local low = readyAt - now
    if (availableAt(state, low, component, found) or -1) >= cost then
        return readyAt, true
    end
    local base = baseClock(state)
    local high = component.remaining
    if base then
        local current = availableAt(state, 0, component, found) or 0
        local ticks = math.ceil(math.max(0, cost - current) / base.amount)
        high = math.max(high, base.nextIn
            + math.max(0, ticks - 1) * base.period)
    end
    high = math.max(low, high)
    if (availableAt(state, high, component, found) or -1) < cost then
        return nil, true
    end
    local index
    for index = 1, 48 do
        local middle = (low + high) / 2
        if (availableAt(state, middle, component, found) or -1) >= cost then
            high = middle
        else low = middle end
    end
    return now + high, true
end

function W:ConsumerKey(facts)
    local cost = facts and finite(facts.cost, EPSILON, 1000000000)
    return facts and facts.paladinWisdom ~= true
        and tonumber(facts.powerType) == 0 and cost and self.CONSUMER_KEY or nil
end

function W:StrategicSetup(tooltip)
    local found = profile(tooltip)
    if not (found and tooltip.paladinWisdom == true
        and tooltip.paladinEffectRepresented == true) then return nil end
    return { key = "paladinWisdom:" .. tostring(found.spellId),
        consumerKey = self.CONSUMER_KEY }
end
