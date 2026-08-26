-- Branch-local Enrage lifecycle. Rage timing is exact. The installed armor
-- loss is charged as a conservative counterfactual bound against learned
-- post-mitigation hostile white damage; it is never silently treated as free.
XelAssist.Graph.DruidEnrage = {}
local E = XelAssist.Graph.DruidEnrage

local function runtime()
    return XelAssist.Game and XelAssist.Game.Player
        and XelAssist.Game.Player.DruidEnrage
end
local function copy(source)
    local out, key, value = {}, nil, nil
    for key, value in pairs(source or {}) do
        out[key] = type(value) == "table" and copy(value) or value
    end
    return out
end
local function component(state, activeOnly)
    local value = state and state.druidEnrage
    if not (type(value) == "table" and value.available == true
        and value.exact == true and value.spellId == 5229
        and value.duration == 10 and value.interval == 1
        and value.ragePerTick == 2 and value.ticks == 10
        and value.armorRetained == 0.25
        and value.incomingDamageUpperMultiplier == 4
        and (value.active == true or value.active == false)) then return nil end
    if activeOnly and not (value.active == true
        and tonumber(value.remaining) and value.remaining > 0) then return nil end
    return value
end

function E:Attach(state, classToken)
    local owner = runtime()
    local root = owner and owner:Snapshot()
    if not (state and classToken == "DRUID" and root
        and root.available == true and root.exact == true
        and root.profile) then return false end
    local found = root.profile
    state.druidEnrage = { available = true, exact = true,
        active = root.active == true, remaining = root.remaining,
        spellId = found.spellId, duration = found.duration,
        interval = found.interval, ragePerTick = found.ragePerTick,
        ticks = found.ticks, armorRetained = found.armorRetained,
        incomingDamageUpperMultiplier = found.armorCounterfactualBound,
        source = found.source }
    if root.active and tonumber(root.remaining) and root.remaining > 0 then
        local ticks = math.min(found.ticks,
            math.floor(root.remaining / found.interval))
        state.playerResourceClock = { kind = "druidEnrage",
            verified = true, active = true, exact = false,
            lowerBound = true, phaseKnown = false,
            resourceType = owner.RAGE, amount = found.ragePerTick,
            interval = found.interval, nextIn = found.interval,
            remaining = root.remaining, ticksRemaining = ticks,
            spellId = found.spellId, source = found.source }
    end
    return component(state) ~= nil
end

function E:Copy(source, target)
    target.druidEnrage = source and source.druidEnrage
        and copy(source.druidEnrage) or nil
    return component(target) ~= nil
end

local function evidence(subject)
    local owner = runtime()
    return owner and owner.Evidence and owner:Evidence(subject) or nil
end
local function exactPlayer(state, descriptor)
    local player = state and state.actors and state.actors.player
    return descriptor and descriptor.relation == "self"
        and (descriptor.unit == "player" or player and descriptor.guid
            and descriptor.guid == player.guid)
end

function E:Prepare(action, state, descriptor, facts)
    local found = evidence(facts) or evidence(action)
    if not found then return nil, "exact Enrage evidence unavailable", true end
    local current = component(state)
    if not current then return nil, "Enrage aura state unavailable", true end
    if current.active then return nil, "Enrage already active", true end
    if not exactPlayer(state, descriptor) then
        return nil, "Enrage requires the exact player", true
    end
    local form = state and state.druidFormState
    if not (form and form.available == true
        and (form.formID == 5 or form.formID == 8)) then
        return nil, "Enrage requires Bear or Dire Bear Form", true
    end
    local resource, maximum = tonumber(state.resource),
        tonumber(state.resourceMax)
    if not (state.playerResourceExact == true
        and state.resourceType == found.powerType and resource and maximum
        and resource >= 0 and maximum >= resource) then
        return nil, "exact Bear rage state unavailable", true
    end
    return { classMechanic = "druidEnrage",
        druidEnrageTransition = { kind = "druidEnrage", exact = true,
            spellId = found.spellId, duration = found.duration,
            interval = found.interval, ragePerTick = found.ragePerTick,
            ticks = found.ticks, totalRage = found.totalRage,
            armorRetained = found.armorRetained,
            incomingDamageUpperMultiplier =
                found.armorCounterfactualBound,
            source = found.source } }, nil, true
end

local function transition(projection)
    local value = projection and projection.druidEnrageTransition
    if not (type(value) == "table" and value.kind == "druidEnrage"
        and value.exact == true and value.spellId == 5229
        and value.duration == 10 and value.interval == 1
        and value.ragePerTick == 2 and value.ticks == 10
        and value.totalRage == 20 and value.armorRetained == 0.25
        and value.incomingDamageUpperMultiplier == 4) then return nil end
    return value
end

local function boundedIncoming(state, value, application)
    local lanes = state and state.hostileSwings and state.hostileSwings.lanes
        or {}
    local total, count, i = 0, 0, 1
    while lanes[i] do
        local lane = lanes[i]
        if lane.victimKind == "player" then
            local interval = tonumber(lane.interval)
            local offset = tonumber(lane.nextSwingIn)
            local amount = tonumber(lane.expectedDamage)
            local events = 0
            while interval and interval > 0.1 and offset and amount
                and offset <= application + value.duration and events < 8 do
                if offset > application then
                    total = total + amount
                        * (value.incomingDamageUpperMultiplier - 1)
                    count = count + 1
                end
                offset, events = offset + interval, events + 1
            end
        end
        i = i + 1
    end
    return total, count
end

function E:Score(context, projection)
    local value = transition(projection)
    if not value then return false, "Enrage transition unavailable" end
    local application = (tonumber(context.wait) or 0)
        + (tonumber(context.cast) or 0)
    local penalty, rounds = boundedIncoming(context.state, value, application)
    local current, maximum = tonumber(context.state.resource) or 0,
        tonumber(context.state.resourceMax) or 0
    local effective = math.min(value.totalRage, math.max(0, maximum - current))
    context.kind, context.power = "classMechanic", value.totalRage
    context.expectedPower, context.effectivePower = value.totalRage, effective
    context.resourceGain, context.value = value.totalRage, -penalty
    context.estimated = rounds > 0
    context.reason = rounds > 0
        and "gains rage with bounded Enrage armor exposure"
        or "gains 2 rage each second"
    return true
end

function E:Apply(state, candidate)
    local value = transition(candidate and candidate.classMechanicProjection)
    local current = component(state)
    if not (value and current and not current.active
        and state.playerResourceExact == true) then return false end
    current.active, current.remaining = true, value.duration
    state.playerResourceClock = { kind = "druidEnrage", verified = true,
        active = true, exact = true, lowerBound = true, phaseKnown = true,
        resourceType = 1, amount = value.ragePerTick,
        interval = value.interval, nextIn = value.interval,
        remaining = value.duration, ticksRemaining = value.ticks,
        spellId = value.spellId, source = value.source }
    state.inCombat = true
    return true
end

function E:Advance(state, elapsed)
    local current = component(state, true)
    elapsed = tonumber(elapsed)
    if not (current and elapsed and elapsed > 0) then return false end
    current.remaining = math.max(0, current.remaining - elapsed)
    if current.remaining <= 0 then
        current.active, current.remaining = false, nil
    end
    return true
end

function E:AdjustProjectedSwing(state, entry, amount)
    local current = component(state, true)
    amount = tonumber(amount)
    if not (current and entry and entry.victimKind == "player" and amount) then
        return amount, false
    end
    return amount * current.incomingDamageUpperMultiplier, true
end
