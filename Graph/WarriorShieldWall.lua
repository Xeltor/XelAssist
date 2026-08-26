-- Search-pure Shield Wall timeline and all-school incoming-damage consequence.
-- The action earns no flat defensive utility: only exact hostile casts that
-- will hit the player inside the sealed aura window contribute value.
XelAssist.Graph.WarriorShieldWall = {}
local W = XelAssist.Graph.WarriorShieldWall

local EPSILON = 0.0001

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
        and XelAssist.Game.Player.WarriorShieldWall
end

local function incoming()
    return XelAssist.Graph and XelAssist.Graph.IncomingConsequences
end

local function staticEvidence(subject)
    local owner = runtime()
    return owner and owner.Evidence and owner:Evidence(subject) or nil
end

local function capturedEvidence(subject)
    local owner = runtime()
    if owner and owner.CapturedEvidence then
        return owner:CapturedEvidence(subject)
    end
    return nil, "Shield Wall runtime evidence unavailable"
end

local function component(state, activeOnly)
    local owner, found = runtime(), state and state.warriorShieldWall
    if not (owner and type(found) == "table"
        and found.available == true and found.exact == true
        and found.spellId == owner.SPELL_ID
        and found.schoolMask == owner.ALL_SCHOOLS
        and found.damageTakenMultiplier == 0.25
        and found.duration and found.duration > 0 and found.duration <= 60
        and (found.active == true or found.active == false)) then return nil end
    if activeOnly and not (found.active == true
        and finite(found.remaining, EPSILON, found.duration)) then return nil end
    return found
end

local function transition(value)
    local owner = runtime()
    if not (owner and type(value) == "table"
        and value.kind == "warriorShieldWall"
        and value.evidenceExact == true and value.spellId == owner.SPELL_ID
        and value.schoolMask == owner.ALL_SCHOOLS
        and value.damageTakenMultiplier == 0.25
        and value.damageTakenPercent == -75
        and finite(value.duration, 0.001, 60)
        and type(value.epoch) == "string" and value.epoch ~= "") then
        return nil
    end
    return value
end

local function projectionOf(candidate)
    local value = candidate and candidate.classMechanicProjection or candidate
    return value and transition(value.warriorShieldWallTransition)
        or candidate and candidate.tooltip
            and transition(candidate.tooltip.warriorShieldWallTransition)
        or nil
end

function W:Attach(state, knownClass)
    if type(state) ~= "table" then return false end
    state.warriorShieldWall = nil
    local owner = runtime()
    local root = owner and owner:Snapshot(knownClass) or nil
    if not root then return false end
    local profile = root.profile
    state.warriorShieldWall = {
        available = root.available == true, exact = root.exact == true,
        active = root.active == true, remaining = root.remaining,
        duration = profile and profile.duration,
        spellId = profile and profile.spellId,
        schoolMask = profile and profile.schoolMask,
        damageTakenPercent = profile and profile.damageTakenPercent,
        damageTakenMultiplier = profile and profile.damageTakenMultiplier,
        serverProfileExact = profile and profile.serverProfileExact,
        runtimeVerified = profile and profile.runtimeVerified,
        epoch = root.epoch and tostring(root.epoch) or nil,
        projected = false, reason = root.reason, source = root.source,
    }
    return component(state) ~= nil
end

function W:Copy(source, target)
    if not target then return false end
    target.warriorShieldWall = source and source.warriorShieldWall
        and copy(source.warriorShieldWall) or nil
    return component(target) ~= nil
end

function W:Is(action, tooltip)
    return staticEvidence(action) ~= nil or staticEvidence(tooltip) ~= nil
end

local function exactPlayer(state, descriptor)
    local player = state and state.actors and state.actors.player
    local guid = player and player.guid
    if not (player and guid ~= nil and descriptor
        and descriptor.relation == "self") then return nil end
    if descriptor.unit == "player" then return guid end
    if descriptor.guid ~= nil and descriptor.guid == guid then return guid end
    return nil
end

function W:Prepare(action, state, descriptor, tooltip)
    if not self:Is(action, tooltip) then return nil, nil, false end
    if not (action and (action.actor or "player") == "player") then
        return nil, "Shield Wall must be player-owned", true
    end
    local profile, reason = capturedEvidence(tooltip)
    if not profile then
        return nil, reason or "Shield Wall root evidence unavailable", true
    end
    local current = component(state)
    if not current then return nil, "Shield Wall aura state unavailable", true end
    if not exactPlayer(state, descriptor) then
        return nil, "Shield Wall requires the exact player recipient", true
    end
    if current.active == true then return nil, "Shield Wall already active", true end
    local prepared = copy(tooltip)
    prepared.cost, prepared.powerType = 0, profile.powerType
    prepared.classMechanic = "warriorShieldWall"
    prepared.warriorShieldWallTransition = {
        kind = "warriorShieldWall", evidenceExact = true,
        spellId = profile.spellId, duration = profile.duration,
        schoolMask = profile.schoolMask,
        damageTakenPercent = profile.damageTakenPercent,
        damageTakenMultiplier = profile.damageTakenMultiplier,
        serverProfileExact = profile.serverProfileExact,
        runtimeVerified = profile.runtimeVerified,
        epoch = tostring(profile.spellId) .. ":"
            .. tostring(finite(state and state.time, 0, 1000000000) or 0),
        source = profile.source,
    }
    return prepared, nil, true
end

local function applicationOffset(context)
    return math.max(0, finite(context and context.wait, 0, 600) or 0)
        + math.max(0, finite(context and context.cast, 0, 600) or 0)
end

local function playerGuid(state)
    return state and state.actors and state.actors.player
        and state.actors.player.guid or nil
end

local function preventedByKnownCasts(state, profile, application)
    local ledger, model, guid = state and state.hostileCasts,
        incoming(), playerGuid(state)
    if not (ledger and type(ledger.order) == "table"
        and type(ledger.byCaster) == "table" and model and guid) then
        return 0, 0, 0
    end
    local prevented, exactCount, unresolved = 0, 0, 0
    local index, cast, remaining, recipient, preview
    for index = 1, math.min(table.getn(ledger.order), 16) do
        cast = ledger.byCaster[ledger.order[index]]
        remaining = cast and finite(cast.remaining, 0, 600) or nil
        if remaining and remaining > application + EPSILON
            and remaining < application + profile.duration - EPSILON then
            recipient = model.RecipientGuid and model:RecipientGuid(cast) or nil
            if recipient == guid then
                if cast.consequence and cast.consequence.kind == "damage"
                    and cast.consequence.estimated ~= true and model.Preview then
                    preview = model:Preview(state, cast)
                    if preview and preview.recipient
                        and preview.recipient.kind == "player"
                        and finite(preview.amount, 0, 1000000000) then
                        prevented = prevented + preview.amount
                            * (1 - profile.damageTakenMultiplier)
                        exactCount = exactCount + 1
                    else unresolved = unresolved + 1 end
                else unresolved = unresolved + 1 end
            end
        end
    end
    return prevented, exactCount, unresolved
end

function W:Score(context, projection)
    local found = projection and transition(
        projection.warriorShieldWallTransition)
    if not found then return false, "Shield Wall transition unavailable" end
    if not component(context and context.state) then
        return false, "Shield Wall aura state unavailable"
    end
    local prevented, count, unresolved = preventedByKnownCasts(
        context.state, found, applicationOffset(context))
    local white, whiteCount = 0, 0
    local whiteModel = XelAssist.Graph.HostileWhiteMitigation
    if whiteModel then white, whiteCount = whiteModel:Prevented(context.state,
        "player", applicationOffset(context), found.duration,
        found.damageTakenMultiplier) end
    prevented, count = prevented + white, count + whiteCount
    context.power, context.expectedPower, context.effectivePower = 0, 0, 0
    context.value = prevented
    context.reason = count > 0 and "prevents exact incoming damage"
        or "no exact incoming damage inside Shield Wall"
    context.warriorShieldWallPreventedDamage = prevented
    context.warriorShieldWallIncomingCount = count
    context.warriorShieldWallWhiteRounds = whiteCount
    context.warriorShieldWallUnresolvedIncoming = unresolved
    context.estimated = found.runtimeVerified ~= true or unresolved > 0
        or whiteCount > 0
    return true
end

local function activate(state, found)
    local current = component(state)
    if not current or not found then return false end
    if current.active == true then return current.epoch == found.epoch end
    current.active, current.projected = true, true
    current.remaining, current.duration = found.duration, found.duration
    current.damageTakenPercent = found.damageTakenPercent
    current.damageTakenMultiplier = found.damageTakenMultiplier
    current.schoolMask, current.epoch = found.schoolMask, found.epoch
    current.serverProfileExact = found.serverProfileExact
    current.runtimeVerified = found.runtimeVerified
    current.source = "projected exact Shield Wall application"
    return component(state, true) ~= nil
end

function W:Apply(state, candidate)
    return activate(state, projectionOf(candidate))
end

function W:Advance(state, elapsed)
    local current = component(state, true)
    elapsed = finite(elapsed, 0, 600)
    if not current or not elapsed or elapsed <= 0 then return false end
    current.remaining = math.max(0, current.remaining - elapsed)
    if current.remaining <= EPSILON then
        current.active, current.remaining, current.epoch = false, nil, nil
        current.projected = true
    end
    return true
end

local function schoolCovered(mask, school)
    if school == nil then return mask == 127 end
    school = integer(school, 0, 6)
    if school == nil then return nil end
    local flag = 2 ^ school
    return math.floor(mask / flag) - math.floor(mask / (flag * 2)) * 2 == 1
end

function W:IncomingMultiplier(state, recipient, school)
    local current = component(state, true)
    if not current or not (recipient and recipient.kind == "player") then
        return nil, false
    end
    local covered = schoolCovered(current.schoolMask, school)
    if covered == nil then
        return nil, true, "incoming damage school is outside the DBC mask"
    end
    if not covered then return 1, true end
    return current.damageTakenMultiplier, true
end

function W:AdjustIncoming(state, recipient, amount, school)
    amount = finite(amount, 0, 1000000000)
    if amount == nil then
        return nil, "incoming damage amount unavailable", true
    end
    local multiplier, handled, reason = self:IncomingMultiplier(
        state, recipient, school)
    if not handled then return amount, nil, false end
    if not multiplier then return nil, reason, true end
    return amount * multiplier, nil, true
end
