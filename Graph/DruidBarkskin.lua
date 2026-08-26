-- Branch-local Barkskin lifecycle. Value comes only from exact incoming
-- physical casts; its cast and melee opportunity costs alter later graph edges.
XelAssist.Graph.DruidBarkskin = {}
local B = XelAssist.Graph.DruidBarkskin

local function runtime()
    return XelAssist.Game and XelAssist.Game.Player
        and XelAssist.Game.Player.DruidBarkskin
end

local function copy(source)
    local out, key, value = {}, nil, nil
    for key, value in pairs(source or {}) do
        out[key] = type(value) == "table" and copy(value) or value
    end
    return out
end

local function component(state, activeOnly)
    local current = state and state.druidBarkskin
    if not (type(current) == "table"
        and current.available == true and current.exact == true
        and current.duration == 10
        and (current.active == true or current.active == false)
        and current.physicalDamageMultiplier == 0.8
        and current.nonInstantCastTimeAdded == 1
        and current.meleeAttackRateMultiplier == 0.75) then
        return nil
    end
    if activeOnly and not (current.active == true
        and tonumber(current.remaining) and current.remaining > 0) then
        return nil
    end
    return current
end

function B:Attach(state, classToken)
    local owner = runtime()
    local root = owner and owner:Snapshot(classToken)
    if not (state and root) then return false end
    local profile = root.profile
    state.druidBarkskin = {
        available = root.available == true,
        exact = root.exact == true,
        active = root.active == true,
        remaining = root.remaining,
        epoch = root.epoch,
        duration = profile and profile.duration,
        spellId = profile and profile.spellId,
        physicalDamageMultiplier = profile
            and profile.physicalDamageMultiplier,
        nonInstantCastTimeAdded = profile
            and profile.nonInstantCastTimeAdded,
        meleeAttackRateMultiplier = profile
            and profile.meleeAttackRateMultiplier,
        pushbackImmune = profile and profile.pushbackImmune,
        projected = false,
        reason = root.reason,
    }
    return component(state) ~= nil
end

function B:Copy(source, target)
    target.druidBarkskin = source and source.druidBarkskin
        and copy(source.druidBarkskin) or nil
    return component(target) ~= nil
end

local function exactPlayer(state, descriptor)
    local player = state and state.actors and state.actors.player
    return player and descriptor and descriptor.relation == "self"
        and (descriptor.unit == "player" or descriptor.guid ~= nil
            and descriptor.guid == player.guid)
end

function B:Prepare(action, state, descriptor, facts)
    local owner = runtime()
    local evidence = owner and (owner:Evidence(facts)
        or owner:Evidence(action))
    if not evidence then
        return nil, "exact Barkskin evidence unavailable", true
    end
    local current = component(state)
    if not current then
        return nil, "Barkskin aura state unavailable", true
    end
    if current.active then return nil, "Barkskin already active", true end
    if not exactPlayer(state, descriptor) then
        return nil, "Barkskin requires the exact player", true
    end
    local value = {
        kind = "druidBarkskin", exact = true,
        spellId = evidence.spellId, duration = evidence.duration,
        physicalDamageMultiplier = evidence.physicalDamageMultiplier,
        nonInstantCastTimeAdded = evidence.nonInstantCastTimeAdded,
        meleeAttackRateMultiplier = evidence.meleeAttackRateMultiplier,
        pushbackImmune = true,
        epoch = tostring(evidence.spellId) .. ":"
            .. tostring(state.time or 0),
    }
    return { classMechanic = "druidBarkskin",
        druidBarkskinTransition = value }, nil, true
end

local function transition(projection)
    local value = projection and projection.druidBarkskinTransition
    local owner = runtime()
    if not (owner and type(value) == "table" and value.exact == true
        and value.kind == "druidBarkskin"
        and value.spellId == owner.SPELL_ID and value.duration == 10
        and value.physicalDamageMultiplier == 0.8
        and value.nonInstantCastTimeAdded == 1
        and value.meleeAttackRateMultiplier == 0.75
        and value.pushbackImmune == true) then return nil end
    return value
end

local function playerGuid(state)
    return state and state.actors and state.actors.player
        and state.actors.player.guid or nil
end

local function exactPhysicalPreview(incoming, state, cast, guid,
    application, expiration)
    local remaining = cast and tonumber(cast.remaining)
    if not (remaining and remaining > application
        and remaining < expiration
        and incoming:RecipientGuid(cast) == guid
        and cast.consequence and cast.consequence.kind == "damage"
        and cast.consequence.school == 0
        and cast.consequence.estimated ~= true) then return nil end
    local preview = incoming:Preview(state, cast)
    if not (preview and preview.recipient
        and preview.recipient.kind == "player") then return nil end
    return preview
end

local function preventedDamage(state, value, application)
    local ledger = state and state.hostileCasts
    local incoming = XelAssist.Graph.IncomingConsequences
    local guid = playerGuid(state)
    if not (ledger and ledger.order and ledger.byCaster
        and incoming and guid) then return 0, 0 end
    local total, count, index = 0, 0, nil
    local expiration = application + value.duration
    for index = 1, math.min(table.getn(ledger.order), 16) do
        local cast = ledger.byCaster[ledger.order[index]]
        local preview = exactPhysicalPreview(incoming, state, cast, guid,
            application, expiration)
        if preview then
            total = total + preview.amount
                * (1 - value.physicalDamageMultiplier)
            count = count + 1
        end
    end
    return total, count
end

function B:Score(context, projection)
    local value = transition(projection)
    if not value then return false, "Barkskin transition unavailable" end
    local application = (context.wait or 0) + (context.cast or 0)
    local prevented, count = preventedDamage(
        context.state, value, application)
    local white, whiteCount = 0, 0
    local whiteModel = XelAssist.Graph.HostileWhiteMitigation
    if whiteModel then white, whiteCount = whiteModel:Prevented(context.state,
        "player", application, value.duration,
        value.physicalDamageMultiplier) end
    prevented, count = prevented + white, count + whiteCount
    context.power, context.expectedPower, context.effectivePower = 0, 0, 0
    context.kind, context.value = "classMechanic", prevented
    context.reason = count > 0 and "prevents exact physical damage"
        or "no exact physical damage inside Barkskin"
    context.druidBarkskinWhiteRounds = whiteCount
    context.estimated = whiteCount > 0
    return true
end

function B:Apply(state, candidate)
    local value = transition(candidate and candidate.classMechanicProjection)
    local current = component(state)
    if not (value and current and not current.active) then return false end
    current.active, current.remaining, current.projected = true, value.duration, true
    current.epoch = value.epoch
    return true
end

function B:Advance(state, elapsed)
    local current = component(state, true)
    elapsed = tonumber(elapsed)
    if not (current and elapsed and elapsed > 0) then return false end
    current.remaining = math.max(0, current.remaining - elapsed)
    if current.remaining <= 0 then
        current.active, current.remaining, current.epoch = false, nil, nil
        current.projected = true
    end
    return true
end

function B:AdjustIncoming(state, recipient, amount, school)
    local current = component(state, true)
    if not current or not recipient or recipient.kind ~= "player" then
        return amount, nil, false
    end
    if school ~= 0 then return amount, nil, true end
    amount = tonumber(amount)
    if not amount then return nil, "incoming damage unavailable", true end
    return amount * current.physicalDamageMultiplier, nil, true
end

function B:CastTime(state, base)
    local current = component(state, true)
    base = tonumber(base)
    if not (current and base and base > 0) then return base, false end
    return base + current.nonInstantCastTimeAdded, true
end

function B:MeleeInterval(state, base)
    local current = component(state, true)
    base = tonumber(base)
    if not (current and base and base > 0) then return base, false end
    return base / current.meleeAttackRateMultiplier, true
end
