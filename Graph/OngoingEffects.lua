-- Passage-of-time projections that happen while a candidate occupies the
-- player: friendly periodic healing, pet autocasts, hostile periodic effects,
-- and expiration of observed or projected target state.
XelAssist.Graph.OngoingEffects = {}
local O = XelAssist.Graph.OngoingEffects
local State = XelAssist.Graph.State
local Effects = XelAssist.Graph.Effects

local function advanceFriendlies(state, elapsed)
    if not state.friendlies or elapsed <= 0 then return end
    local i, name, aura
    for i = 1, table.getn(state.friendlies.order or {}) do
        local record = State:FriendlyByKey(
            state, state.friendlies.order[i])
        if record then
            for name, aura in pairs(record.auras or {}) do
                if type(aura) == "table" then
                    local active = aura.remaining
                        and math.min(elapsed, aura.remaining) or elapsed
                    if aura.periodicHealRate and active > 0 then
                        record.health = math.min(record.healthMax,
                            record.health + aura.periodicHealRate * active)
                    end
                    if aura.remaining then
                        aura.remaining = math.max(0, aura.remaining - elapsed)
                        if aura.remaining <= 0 then record.auras[name] = nil end
                    end
                end
            end
            for name, aura in pairs(record.absorbs or {}) do
                if type(aura) == "table" and aura.remaining then
                    aura.remaining = math.max(0, aura.remaining - elapsed)
                    if aura.remaining <= 0 then record.absorbs[name] = nil end
                end
            end
        end
    end
end

local function advancePlayerCast(state, elapsed)
    if not state.playerCasting then return end
    local remaining = tonumber(state.castRemaining)
    if not remaining then return end
    state.castRemaining = math.max(0, remaining - elapsed)
    if state.castRemaining <= 0 then
        state.playerCasting, state.playerChanneling = false, false
        state.playerCastName = nil
    end
end

local function projectedEventState(source, context, offset)
    local state = Effects:StateAtImpact(source, offset)
    if offset >= context.applicationOffset
        and context:ChangesHostileTarget() then
        state = State:Copy(state)
        context:ProjectCurrentApplication(state,
            offset - context.applicationOffset)
    end
    return state
end

local function ambientSupported(ambient)
    if ambient.kind == "damage" or ambient.kind == "taunt"
        or ambient.kind == "petThreat" then return true end
    local duration = ambient.tooltip and tonumber(ambient.tooltip.duration)
        or ambient.facts and tonumber(ambient.facts.duration)
    return ambient.kind == "dot" and duration and duration > 0
        and (tonumber(ambient.power) or 0) > 0
end

local function ambientPetEvents(out, candidate)
    local events = {}
    local pet = out.actors and out.actors.pet
    if not (pet and pet.autocasts and pet.targetExists
        and pet.targetsCurrent) then return events end
    local i
    for i = 1, table.getn(pet.autocasts) do
        local ambient = pet.autocasts[i]
        if ambientSupported(ambient) then
            local ready = math.max(0, tonumber(ambient.readyIn) or 0)
            local cooldown = math.max(0.1,
                tonumber(ambient.cooldown) or 1.5)
            ambient.readyIn = math.max(0, ready - candidate.downtime)
            while ready <= candidate.downtime do
                table.insert(events, { owner = "ongoing", kind = "petAutocast",
                    offset = ready, priority = 50, autocastIndex = i,
                    windowEnd = candidate.downtime })
                ready = ready + cooldown
            end
        end
    end
    return events
end

local function markTargetDeath(out)
    if not (out.targetHealthExact and out.targetHealth <= 0) then return end
    out.hostile = false
    if out.autoShot then out.autoShot.active = false end
end

local function applyAmbientDot(out, source, context, entry, ambient, pet)
    local tooltip, facts = ambient.tooltip or {}, ambient.facts or {}
    local duration = tonumber(tooltip.duration) or tonumber(facts.duration)
    if not duration or duration <= 0 then return false end
    local power = math.max(0, tonumber(ambient.power) or 0)
    if XelAssist.Game.Pets and XelAssist.Game.Pets.Effects then
        power = power * XelAssist.Game.Pets.Effects:DamageMultiplier(pet)
    end
    local eventState = projectedEventState(source, context, entry.offset)
    local delivery, conditional = 1, 1
    if XelAssist.Combat.Resistance then
        local estimate = XelAssist.Combat.Resistance:Estimate(
            ambient, "target", tooltip, eventState)
        local ignored
        ignored, delivery = Effects:Decision(estimate, eventState, true)
        conditional = Effects:OverWindow(ambient, "target", tooltip,
            eventState, 0, duration, "periodic", true) or 1
    end
    local prior = out.auras and out.auras[ambient.name]
    local stacks = type(prior) == "table" and (prior.expectedStacks
        or prior.stacks or 0) or 0
    local maximum = tonumber(facts.stackable)
    local expectedStacks = maximum
        and math.min(maximum, stacks + delivery) or nil
    local scale = expectedStacks or 1
    out.auras = out.auras or {}
    out.auras[ambient.name] = { remaining = duration, duration = duration,
        mine = true, target = "target", sourceActor = "pet",
        periodicRate = power * scale * (maximum and 1 or delivery)
            * conditional / duration,
        periodicRawRate = not maximum and power / duration or nil,
        periodicAction = ambient,
        periodicTooltip = { school = tooltip.school },
        periodicInterval = tooltip.periodicInterval,
        periodicNextIn = XelAssist.Game.SpellTiming:Next(
            tooltip.periodicInterval, 0),
        applicationProbability = delivery,
        stacks = maximum and math.min(maximum, (prior and prior.stacks or 0) + 1)
            or nil,
        expectedStacks = expectedStacks }
    if XelAssist.Game.Pets and XelAssist.Game.Pets.Effects then
        XelAssist.Game.Pets.Effects:ConsumeMelee(
            out, ambient, out.targetGUID, delivery)
    end
    return true
end

local function applyAmbientPet(out, source, context, entry)
    local pet = out.actors and out.actors.pet
    local ambient = pet and pet.autocasts
        and pet.autocasts[entry.autocastIndex]
    if not (ambient and pet.targetExists and pet.targetsCurrent) then return end
    if out.targetHealthExact and out.targetHealth <= 0 then return end
    if pet.resource < (ambient.cost or 0) then return end
    pet.resource = pet.resource - (ambient.cost or 0)
    ambient.readyIn = math.max(0.1, (ambient.cooldown or 1.5)
        - math.max(0, entry.windowEnd - entry.offset))
    if ambient.kind == "dot" then
        applyAmbientDot(out, source, context, entry, ambient, pet)
    elseif ambient.kind == "damage" then
        local power, delivery = ambient.power or 0, 1
        if XelAssist.Game.Pets and XelAssist.Game.Pets.Effects then
            power = power * XelAssist.Game.Pets.Effects:DamageMultiplier(pet)
        end
        if XelAssist.Combat.Resistance then
            local eventState = projectedEventState(
                source, context, entry.offset)
            local estimate = XelAssist.Combat.Resistance:Estimate(
                ambient, "target", ambient.tooltip or {}, eventState)
            local decision
            decision, delivery = Effects:Decision(estimate, eventState, true)
            power = power * decision
        end
        if out.targetHealthExact then
            out.targetHealth = math.max(0, out.targetHealth - power)
        end
        if XelAssist.Game.Pets and XelAssist.Game.Pets.Effects then
            XelAssist.Game.Pets.Effects:ConsumeMelee(
                out, ambient, out.targetGUID, delivery)
        end
        markTargetDeath(out)
    elseif XelAssist.Graph.CompanionThreat
        and XelAssist.Graph.CompanionThreat:Apply(
            out, ambient, nil, 1) then
        -- Relative threat changed; victim booleans remain live facts.
    elseif ambient.kind == "taunt" then
        local petTank = XelAssistCharDB.petThreat == "tank"
            or (XelAssistCharDB.petThreat ~= "avoid" and out.groupSize == 0)
        if petTank then out.hasAggro, pet.hasAggro = false, true end
    end
end

local function periodicSegment(aura, state, span)
    if span <= 0 then return 0 end
    if not (aura.periodicRawRate and aura.periodicAction
        and XelAssist.Combat.Resistance) then
        return math.max(0, aura.periodicRate or 0) * span
    end
    local conditional = Effects:OverWindow(aura.periodicAction, "target",
        aura.periodicTooltip or {}, state, 0, span, "periodic", true)
    if not conditional then
        return math.max(0, aura.periodicRate or 0) * span
    end
    return math.max(0, aura.periodicRawRate) * span
        * (tonumber(aura.applicationProbability) or 1) * conditional
end

local function periodicDamage(source, context, aura, elapsed, baseState)
    local fallback = math.max(0, aura.periodicRate or 0) * elapsed
    if not (aura.periodicRawRate and aura.periodicAction
        and XelAssist.Combat.Resistance and elapsed > 0) then
        return fallback
    end
    if context:ChangesHostileTarget()
        and context.applicationOffset < elapsed then
        local before = math.max(0, context.applicationOffset)
        local afterState = State:Copy(
            Effects:StateAtImpact(source, context.applicationOffset))
        context:ProjectCurrentApplication(afterState, 0)
        context:AddProjectedModifierAura(afterState)
        return periodicSegment(aura, baseState, before)
            + periodicSegment(aura, afterState, elapsed - before)
    end
    return periodicSegment(aura, baseState, elapsed)
end

local function addPeriodicEvent(events, kind, name, aura, offset,
    priority, left, right, span)
    table.insert(events, { owner = "ongoing", kind = kind, auraName = name,
        aura = aura, offset = offset, priority = priority,
        left = left, right = right, tickSpan = span })
end

local function periodicEvents(source, candidate, context)
    local events, name, aura = {}, nil, nil
    for name, aura in pairs(source.auras or {}) do
        if type(aura) == "table" and aura.remaining
            and aura.periodicRate and aura.target == "target" then
            local active = math.min(aura.remaining, candidate.downtime)
            local interval = tonumber(aura.periodicInterval)
            local nextTick = tonumber(aura.periodicNextIn)
            if interval and interval > 0 and nextTick then
                nextTick = math.max(0, nextTick)
                while nextTick <= active do
                    local priority = nextTick < context.applicationOffset
                        and 10 or 60
                    addPeriodicEvent(events, "periodicTick", name, aura,
                        nextTick, priority, nil, nil, interval)
                    nextTick = nextTick + interval
                end
            elseif active > 0 then
                local cut = context.applicationOffset
                if cut > 0 and cut < active then
                    addPeriodicEvent(events, "periodicSegment", name, aura,
                        cut, 10, 0, cut)
                    addPeriodicEvent(events, "periodicSegment", name, aura,
                        active, 60, cut, active)
                else
                    local priority = active <= cut and 10 or 60
                    addPeriodicEvent(events, "periodicSegment", name, aura,
                        active, priority, 0, active)
                end
            end
        end
    end
    return events
end

local function advanceAuraDurations(out, candidate)
    local name, aura
    for name, aura in pairs(out.auras) do
        if type(aura) == "table" and aura.remaining then
            local elapsed = math.min(aura.remaining, candidate.downtime)
            local interval = tonumber(aura.periodicInterval)
            local nextTick = tonumber(aura.periodicNextIn)
            if interval and interval > 0 and nextTick then
                while nextTick <= elapsed do
                    nextTick = nextTick + interval
                end
                aura.periodicNextIn = math.max(0, nextTick - elapsed)
            end
            aura.remaining = math.max(0, aura.remaining - elapsed)
            if aura.remaining <= 0 then
                if aura.targetModifier then
                    Effects:RemoveTargetModifier(out, name)
                end
                out.auras[name] = nil
            end
        end
    end
    Effects:AdvanceModifierFallbacks(out, candidate.downtime)
end

local function periodicEventDamage(source, context, entry)
    if entry.kind == "periodicTick" then
        local eventState = projectedEventState(source, context, entry.offset)
        return periodicSegment(entry.aura, eventState, entry.tickSpan)
    end
    local baseState = State:Copy(source)
    local right = periodicDamage(
        source, context, entry.aura, entry.right, baseState)
    local left = periodicDamage(
        source, context, entry.aura, entry.left, baseState)
    return math.max(0, right - left)
end

local function applyPeriodic(out, source, candidate, context, entry)
    if not out.targetHealthExact or out.targetHealth <= 0 then return end
    local action = candidate.action
    if entry.offset >= context.applicationOffset
        and action and action.name == entry.auraName
        and action.facts and action.facts.kind == "dot" then return end
    out.targetHealth = math.max(0, out.targetHealth
        - periodicEventDamage(source, context, entry))
    markTargetDeath(out)
end

local function advanceObservedTargetAuras(state, elapsed)
    local name, aura
    for name, aura in pairs(state.targetAuras or {}) do
        if type(aura) == "table" and aura.remaining then
            aura.remaining = math.max(0, aura.remaining - elapsed)
            if aura.remaining <= 0 then state.targetAuras[name] = nil end
        end
    end
end

function O:Events(out, source, candidate, context)
    local events = ambientPetEvents(out, candidate)
    local periodic = periodicEvents(source, candidate, context)
    local i
    for i = 1, table.getn(periodic) do table.insert(events, periodic[i]) end
    return events
end

function O:Prepare(out, source, candidate, context)
    local events = self:Events(out, source, candidate, context)
    out.time = out.time + candidate.downtime
    advancePlayerCast(out, candidate.downtime)
    advanceFriendlies(out, candidate.downtime)
    advanceAuraDurations(out, candidate)
    advanceObservedTargetAuras(out, candidate.downtime)
    return events
end

function O:ApplyEvent(out, source, candidate, context, entry)
    if entry.kind == "petAutocast" then
        applyAmbientPet(out, source, context, entry)
    elseif entry.kind == "periodicTick"
        or entry.kind == "periodicSegment" then
        applyPeriodic(out, source, candidate, context, entry)
    end
end

-- Root auras present at Prepare time have already been aged across the full
-- candidate window. Keep a separate clock only for auras created or replaced
-- by later ambient events, so those records can advance causally without
-- aging the pre-existing records twice.
function O:AuraSnapshot(state)
    local snapshot, name, aura = {}, nil, nil
    for name, aura in pairs(state.auras or {}) do snapshot[name] = aura end
    return snapshot
end

function O:TrackEventAuras(state, before, tracked)
    local name, aura
    for name, aura in pairs(state.auras or {}) do
        if before[name] ~= aura then tracked[name] = aura end
    end
    for name, aura in pairs(tracked) do
        if not state.auras or state.auras[name] ~= aura then
            tracked[name] = nil
        end
    end
end

function O:AdvanceEventAuras(state, tracked, elapsed)
    if not elapsed or elapsed <= 0 then return end
    local name, aura
    for name, aura in pairs(tracked or {}) do
        if not state.auras or state.auras[name] ~= aura then
            tracked[name] = nil
        elseif type(aura) == "table" and aura.remaining then
            local active = math.min(aura.remaining, elapsed)
            local interval = tonumber(aura.periodicInterval)
            local nextTick = tonumber(aura.periodicNextIn)
            local damageSpan = active
            if interval and interval > 0 and nextTick then
                local ticks = 0
                while nextTick <= active do
                    nextTick, ticks = nextTick + interval, ticks + 1
                end
                aura.periodicNextIn = math.max(0, nextTick - active)
                damageSpan = ticks * interval
            end
            if damageSpan > 0 and aura.periodicRate
                and state.targetHealthExact and state.targetHealth > 0 then
                state.targetHealth = math.max(0, state.targetHealth
                    - periodicSegment(aura, state, damageSpan))
                markTargetDeath(state)
            end
            aura.remaining = math.max(0, aura.remaining - elapsed)
            if aura.remaining <= 0 then
                if aura.targetModifier then
                    Effects:RemoveTargetModifier(state, name)
                end
                state.auras[name], tracked[name] = nil, nil
            end
        end
    end
end

function O:Advance(out, source, candidate, context)
    local events = self:Prepare(out, source, candidate, context)
    table.sort(events, function(left, right)
        if left.offset ~= right.offset then return left.offset < right.offset end
        return left.priority < right.priority
    end)
    local i
    for i = 1, table.getn(events) do
        self:ApplyEvent(out, source, candidate, context, events[i])
    end
end
