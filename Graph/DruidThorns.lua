-- Branch-local Thorns. Its only value is bounded Nature retaliation against a
-- phase-known hostile white-attack lane which is actually striking the player.
XelAssist.Graph.DruidThorns = {}
local T = XelAssist.Graph.DruidThorns

local RETALIATION_ACTION = { name = "Thorns retaliation", actor = "player",
    facts = { kind = "damage", spell = true, school = 3,
        deliveryModel = "none" } }
local RETALIATION_TOOLTIP = { kind = "damage", school = 3,
    deliveryModel = "none" }

local function finite(value, low, high)
    value = tonumber(value)
    return value and value == value and value ~= math.huge
        and value ~= -math.huge and value >= low and value <= high
        and value or nil
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
        and XelAssist.Game.Player.DruidThorns
end

local function validProfile(found)
    local owner, rank = runtime(), nil
    rank = owner and found and owner.RANKS[found.spellId]
    return type(found) == "table" and rank
        and found.valid == true and found.exact == true
        and found.portfolio == "druidThorns" and found.rank == rank.rank
        and found.damage == rank.damage * (found.improved and 2 or 1)
        and found.duration == (found.improved and 1200 or 600)
        and finite(found.cost, 0, 100000) and found.powerType == 0
        and found.school == 3 and found.auraType == owner.THORNS_AURA
end

local function component(state)
    local current = state and state.druidThorns
    if not (type(current) == "table" and current.available == true
        and current.exact == true and validProfile(current.profile)) then return nil end
    if current.active then
        if not (validProfile(current.activeProfile)
            and finite(current.remaining, 0.0001, 1200)) then return nil end
    end
    return current
end

function T:Attach(state, token)
    local owner = runtime()
    local root = owner and owner:Snapshot(token)
    if not (state and root) then return false end
    state.druidThorns = { available = root.available == true,
        exact = root.exact == true, active = root.active == true,
        remaining = root.remaining, profile = copy(root.profile),
        activeProfile = copy(root.activeProfile), reason = root.reason }
    return component(state) ~= nil
end

function T:Copy(source, target)
    target.druidThorns = source and source.druidThorns
        and copy(source.druidThorns) or nil
    return component(target) ~= nil
end

local function exactPlayer(state, descriptor)
    local player = state and state.actors and state.actors.player
    return player and descriptor and descriptor.relation == "self"
        and (descriptor.unit == "player" or descriptor.guid ~= nil
            and descriptor.guid == player.guid)
end

function T:Prepare(action, state, descriptor, facts)
    local owner = runtime()
    local found = owner and (owner:Evidence(facts) or owner:Evidence(action))
    if not found then return nil, "exact Thorns evidence unavailable", true end
    local current = component(state)
    if not current then return nil, "Thorns aura state unavailable", true end
    if current.active then return nil, "Thorns already active", true end
    if not exactPlayer(state, descriptor) then
        return nil, "Thorns requires the exact player", true
    end
    return { classMechanic = "druidThorns",
        druidThornsTransition = { kind = "druidThorns", exact = true,
            profile = copy(found) } }, nil, true
end

local function transition(projection)
    local value = projection and projection.druidThornsTransition
    return value and value.kind == "druidThorns" and value.exact == true
        and validProfile(value.profile) and value or nil
end

local function selectedLane(state)
    local swings, hostiles = state and state.hostileSwings,
        state and state.hostiles
    local selected = hostiles and hostiles.selectedKey
    local player = state and state.actors and state.actors.player
    local i, match
    for i = 1, table.getn(swings and swings.lanes or {}) do
        local lane = swings.lanes[i]
        if lane.phaseKnown == true and lane.attackerKey == selected
            and lane.victimKind == "player" and player
            and lane.victimGuid == player.guid
            and finite(lane.interval, 0.1, 20)
            and finite(lane.nextSwingIn, 0, 20)
            and finite(lane.retaliationProbability, 0, 1) then
            if match then return nil end
            match = lane
        end
    end
    return match
end

local function aliveProbability(at, lower, upper)
    if at <= lower then return 1 end
    if at >= upper then return 0 end
    return 1 - (at - lower) / math.max(0.001, upper - lower)
end

local function expectedTriggers(state, profile, application)
    local lane, survival = selectedLane(state), state and state.targetSurvival
    if not (lane and type(survival) == "table" and survival.available == true
        and state.targetHealthExact == true) then return nil end
    local lower = finite(survival.lowerTimeToDie, 0, 3600)
    local upper = finite(survival.upperTimeToDie
        or survival.timeToDie, 0, 3600)
    if not lower or not upper or upper < lower then return nil end
    local at = lane.nextSwingIn
    while at < application do at = at + lane.interval end
    local finish, expected, count = application + profile.duration, 0, 0
    while at <= finish and at <= upper and count < 80 do
        expected = expected + aliveProbability(at, lower, upper)
            * lane.retaliationProbability
        at, count = at + lane.interval, count + 1
    end
    return expected, count
end

local function delivery(state)
    local resistance = XelAssist.Combat and XelAssist.Combat.Resistance
    local effects = XelAssist.Graph and XelAssist.Graph.Effects
    if not (resistance and effects) then return nil end
    local estimate = resistance:Estimate(
        RETALIATION_ACTION, "target", RETALIATION_TOOLTIP, state)
    return finite(effects:Decision(estimate, state, true), 0, 1)
end

function T:Score(context, projection)
    local value = transition(projection)
    if not value then return false, "Thorns transition unavailable" end
    local application = math.max(0, tonumber(context.wait) or 0)
        + math.max(0, tonumber(context.cast) or 0)
    local triggers, rounds = expectedTriggers(
        context.state, value.profile, application)
    local multiplier = triggers and delivery(context.state) or nil
    local damage = triggers and multiplier
        and math.min(context.state.targetHealth,
            value.profile.damage * triggers * multiplier) or 0
    context.power, context.expectedPower, context.effectivePower = 0, damage, damage
    context.value = damage > 0 and damage * 4
        / math.max(0.5, tonumber(context.downtime) or 0) or 0
    context.kind, context.estimated = "classMechanic", true
    context.reason = damage > 0
        and "retaliates against bounded incoming white attacks"
        or rounds and "target cannot consume useful Thorns triggers"
            or "Thorns awaits exact attacker survival evidence"
    return true
end

function T:Apply(state, candidate)
    local value = transition(candidate and candidate.classMechanicProjection)
    local current = component(state)
    if not (value and current and not current.active) then return false end
    current.active, current.remaining = true, value.profile.duration
    current.activeProfile = copy(value.profile)
    return true
end

function T:Advance(state, elapsed)
    local current = component(state)
    elapsed = tonumber(elapsed)
    if not (current and current.active and elapsed and elapsed > 0) then return false end
    current.remaining = math.max(0, current.remaining - elapsed)
    if current.remaining <= 0 then
        current.active, current.remaining, current.activeProfile = false, nil, nil
    end
    return true
end

function T:Retaliation(state, entry)
    local current, lane = component(state), entry
    if not (current and current.active and lane
        and lane.kind == "hostileWhiteSwing" and lane.victimKind == "player"
        and finite(lane.retaliationProbability, 0, 1)
        and lane.retaliationProbability > 0) then return nil end
    local player = state.actors and state.actors.player
    if not (player and lane.victimGuid == player.guid
        and finite(player.health or state.health, 0.0001, 100000000)) then return nil end
    local profile, multiplier = current.activeProfile, delivery(state)
    if not multiplier then return nil end
    return profile.damage * lane.retaliationProbability * multiplier
end

function T:ApplyRetaliation(state, entry)
    local amount = self:Retaliation(state, entry)
    local incoming = XelAssist.Graph.IncomingConsequences
    if not (amount and incoming and incoming.ApplyResolvedDamage) then return false end
    local result = incoming:ApplyResolvedDamage(state, entry.attackerGuid,
        amount, true, "projected Thorns retaliation")
    if not result then state.incomingProjectionPartial = true; return false end
    state.lastDruidThorns = { attackerGuid = entry.attackerGuid,
        effective = result.effective, estimated = true }
    return true
end
