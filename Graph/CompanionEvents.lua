-- Passive companion combat events. Scheduling captures the pet's exact target;
-- resolution mutates that hostile record rather than whichever target happens
-- to occupy the selected compatibility mirror later in the graph path.
XelAssist.Graph.CompanionEvents = {}
local C = XelAssist.Graph.CompanionEvents
local State = XelAssist.Graph.State
local Effects = XelAssist.Graph.Effects
local Threat = XelAssist.Graph.CompanionEventThreat
local Scheduler = XelAssist.Graph.CompanionScheduler
local CastEvents = XelAssist.Graph.CompanionCastEvents
local CastRuntime = XelAssist.Graph.CompanionCastRuntime
local Targets = XelAssist.Graph.CompanionTargets
local Swings = XelAssist.Graph.CompanionSwings

function C:Events(out, candidate)
    local pet = out.actors and out.actors.pet
    if not pet then return {} end
    local targetGuid, targetKey, targetLocal = Targets:Capture(out, pet)
    local record
    if targetLocal then _, record = Targets:ForGuid(out, targetGuid) end
    local identity
    if targetGuid then identity = {
        guid = targetGuid, key = targetKey, localTarget = targetLocal } end
    local events = Scheduler:Events(pet, record, candidate, identity)
    local swingEvents = Swings:Events(pet, record, candidate, identity)
    local i
    for i = 1, table.getn(swingEvents) do table.insert(events, swingEvents[i]) end
    Swings:ResolveTies(events, pet, candidate)
    for i = 1, table.getn(events) do
        events[i].windowStart = tonumber(out.time) or 0
    end
    if pet.actionReadyIn and pet.actionReadyIn > 0 then
        out.actorReadyAt = out.actorReadyAt or {}
        out.actorReadyAt.pet = math.max(tonumber(out.actorReadyAt.pet) or 0,
            (tonumber(out.time) or 0) + (tonumber(candidate.downtime) or 0)
                + pet.actionReadyIn)
    end
    return events
end
function C:SyncChosenCooldown(out, candidate, context)
    local action = candidate and candidate.action
    local pet = out and out.actors and out.actors.pet
    if not (action and pet and action.actor == "pet"
        and action.executor == "petAbility") then return end
    local i, ambient
    for i = 1, table.getn(pet.autocasts or {}) do
        ambient = pet.autocasts[i]
        if Scheduler:MatchesAction(action, ambient) then
            local cooldown = math.max(0.1, tonumber(
                    candidate.tooltip and candidate.tooltip.cooldown)
                or tonumber(ambient.cooldown) or 1.5)
            local after = math.max(0, (tonumber(candidate.downtime) or 0) -
                (tonumber(context and context.applicationOffset) or 0))
            ambient.readyIn = math.max(0.1, cooldown - after)
        end
    end
end

local function eventState(source, candidate, context, entry)
    local base = source
    if entry.targetLocal then
        base = State.HostileContext
            and State:HostileContext(source, entry.targetKey) or nil
        if not base then return nil end
    end
    local state = Effects:StateAtImpact(base, entry.offset)
    if state and context and context.applicationOffset
        and entry.offset >= context.applicationOffset
        and Targets:CandidateMatches(candidate, entry)
        and context.ChangesHostileTarget and context.ProjectCurrentApplication
        and context:ChangesHostileTarget() then
        state = State:Copy(state)
        context:ProjectCurrentApplication(state,
            entry.offset - context.applicationOffset)
    end
    return state
end

local function petPower(pet, ambient)
    local power = math.max(0, tonumber(ambient.power) or 0)
    if XelAssist.Game.Pets and XelAssist.Game.Pets.Effects then
        power = power * XelAssist.Game.Pets.Effects:DamageMultiplier(pet)
    end
    return power
end

local function attributableLivePetAura(target, pet, ambient)
    local aura = target.targetAuras and target.targetAuras[ambient.name]
    if type(aura) ~= "table" then return nil end
    if aura.spellId ~= nil and ambient.spellId ~= nil
        and tonumber(aura.spellId) ~= tonumber(ambient.spellId) then return nil end
    if aura.sourceGUID ~= nil then
        if pet.guid ~= nil and aura.sourceGUID == pet.guid then return aura end
        return nil
    end
    if aura.sourceUnit ~= nil then
        if aura.sourceUnit == "pet" then return aura end
        return nil
    end
    if aura.playerOrPet == true and aura.mine ~= true then return aura end
    return nil
end

local function deliveryFor(source, candidate, context, entry, ambient, power)
    local state = eventState(source, candidate, context, entry)
    local delivery, decision, conditional = 1, 1, 1
    if XelAssist.Combat.Resistance then
        if not state then return nil, nil, nil, nil end
        local tooltip = ambient.tooltip or {}
        local estimate = XelAssist.Combat.Resistance:Estimate(
            ambient, "target", tooltip, state)
        decision, delivery = Effects:Decision(estimate, state, true)
        if ambient.kind == "dot" then
            local duration = tonumber(tooltip.duration)
                or tonumber(ambient.facts and ambient.facts.duration)
            conditional = Effects:OverWindow(ambient, "target", tooltip,
                state, 0, duration, "periodic", true) or 1
        end
    end
    return power * (decision or 1), delivery or 1, conditional, state
end

local function activeAt(aura, offset)
    if type(aura) ~= "table" then return false end
    local remaining = tonumber(aura.remaining)
    return remaining == nil or remaining > offset
end

local function stackPriorAtEvent(target, eventTarget, pet, ambient, offset)
    local prior = target.auras and target.auras[ambient.name]
    if type(prior) == "table" then return prior end
    local projected = eventTarget and eventTarget.auras
        and eventTarget.auras[ambient.name]
    if activeAt(projected, offset) then return projected end
    local live = attributableLivePetAura(eventTarget or {}, pet, ambient)
    if activeAt(live, offset) then return live end
    return nil
end

local function applyDot(target, out, source, candidate, context, entry,
    ambient, pet, record, selected)
    local tooltip, facts = ambient.tooltip or {}, ambient.facts or {}
    local duration = tonumber(tooltip.duration) or tonumber(facts.duration)
    if not duration or duration <= 0 then return false end
    local power = petPower(pet, ambient)
    local expected, delivery, conditional, eventTarget = deliveryFor(
        source, candidate, context, entry, ambient, power)
    if expected == nil then return false end
    local stackPrior = stackPriorAtEvent(
        target, eventTarget, pet, ambient, entry.offset)
    local stacks = stackPrior and (stackPrior.expectedStacks
        or stackPrior.stacks or 0) or 0
    local maximum = tonumber(facts.stackable)
    local expectedStacks = maximum
        and math.min(maximum, stacks + delivery) or nil
    local scale = maximum and math.min(maximum, stacks + 1) or 1
    local branches = XelAssist.Graph.EventAuras:ReplaceScheduledAura(out,
        entry.targetKey, entry.targetGuid, ambient.name, delivery,
        target.auras and target.auras[ambient.name])
    target.auras = target.auras or {}
    target.auras[ambient.name] = { remaining = duration, duration = duration,
        mine = true, target = "target", targetKey = entry.targetKey,
        targetGuid = entry.targetGuid, sourceActor = "pet",
        periodicRate = power * scale * delivery * conditional / duration,
        periodicRawRate = not maximum and power / duration or nil,
        periodicAction = ambient,
        periodicTooltip = { school = tooltip.school },
        periodicInterval = tooltip.periodicInterval,
        periodicNextIn = XelAssist.Game.SpellTiming:Next(
            tooltip.periodicInterval, 0),
        periodicThreatActor = "pet",
        periodicThreatMultiplier = Threat:DamageMultiplier(ambient, pet),
        periodicBranches = branches,
        applicationProbability = delivery,
        stacks = maximum and math.min(maximum,
            (stackPrior and stackPrior.stacks or 0) + 1) or nil,
        expectedStacks = expectedStacks }
    Threat:ConsumeMelee(target, out, ambient, entry.targetGuid, delivery,
        record, selected)
    return true
end

local function applyDamage(target, out, source, candidate, context, entry,
    ambient, pet, record, selected)
    local power = petPower(pet, ambient)
    local expected, delivery = deliveryFor(
        source, candidate, context, entry, ambient, power)
    if expected == nil then return false end
    if record then
        local dealt = expected
        if record.healthExact and tonumber(record.health) then
            local beforeHealth = tonumber(record.health)
            record.health = math.max(0, beforeHealth - expected)
            dealt = beforeHealth - record.health
            if record.health <= 0 then
                record.dead, record.projectedDefeated = true, true
            end
        end
        Threat:AddDamage(record, ambient, dealt, pet)
    elseif target.targetHealthExact then
        target.targetHealth = math.max(0, target.targetHealth - expected)
    end
    Threat:ConsumeMelee(target, out, ambient, entry.targetGuid, delivery,
        record, selected)
    return true
end

local function applyUnknownWhiteOutcome(target, out, source, candidate,
    context, entry, ambient, pet, record, selected, consumeMelee)
    local delivery
    if consumeMelee then
        _, delivery = deliveryFor(
            source, candidate, context, entry, ambient, 1)
        if delivery == nil then return false end
    end
    if record then
        record.healthExact = false
        record.whiteSwingDamageUnknown = true
        record.threat = record.threat or {}
        record.threat.petDeltaExact = false
        record.threat.whiteSwingDamageUnknown = true
    else
        target.targetHealthExact = false
        target.whiteSwingDamageUnknown = true
    end
    pet.whiteSwingMagnitudeUnknown = true
    if consumeMelee then
        Threat:ConsumeMelee(target, out, ambient, entry.targetGuid,
            delivery, record, selected)
    else
        local _, effect
        for _, effect in pairs(pet.pendingMeleeEffects or {}) do
            if effect.targetGuid == entry.targetGuid then
                effect.outcomeUnknown = true
            end
        end
        pet.pendingMeleeEffectsExact = false
    end
    return true
end

local function applyThreat(target, out, source, candidate, context, entry,
    ambient, record, selected)
    local _, delivery = deliveryFor(
        source, candidate, context, entry, ambient, 1)
    if delivery == nil then return false end
    return Threat:ApplyRelative(target, out, ambient, record, selected, delivery)
end

local function applyTaunt(target, out, source, candidate, context, entry,
    ambient, record, selected)
    local _, delivery = deliveryFor(
        source, candidate, context, entry, ambient, 1)
    if delivery == nil then return false end
    return Threat:ApplyTaunt(
        target, out, ambient, record, selected, delivery)
end

local function refreshRecord(out, record, changed)
    if record and changed and State.RefreshHostileRecord then
        State:RefreshHostileRecord(out, record.key)
    end
end
local function tiedHostileValid(out, pet, entry)
    if not entry.pendingCompletion then
        if not pet.targetExists then return false end
        local currentGuid, currentKey = Targets:Capture(out, pet)
        if currentGuid ~= entry.targetGuid or currentKey ~= entry.targetKey then
            return false
        end
    end
    return Targets:Resolve(out, entry) ~= nil
end

local function startTargetValid(out, pet, entry)
    if entry.targetIndependent then return true end
    if not pet.targetExists then return false end
    local guid, key = Targets:Capture(out, pet)
    return guid == entry.targetGuid and key == entry.targetKey
        and Targets:Resolve(out, entry) ~= nil
end

local function applyWhiteSwing(out, source, candidate, context, entry, pet)
    if not Swings:StillCurrent(out, pet, entry) then return false end
    local target, _, record, selected = Targets:Resolve(out, entry)
    if not target then return false end
    local changed = applyUnknownWhiteOutcome(target, out, source, candidate,
        context, entry, entry.ambient, pet, record, selected, true)
    refreshRecord(out, record, changed)
    return changed and true or false
end

local function applyTiedReservation(out, source, candidate, context, entry, pet)
    local reserved = entry.kind == "petAutocastUnknown"
        and CastRuntime:ReserveTied(
            out, pet, entry, tiedHostileValid(out, pet, entry)) or false
    if not (reserved and entry.meleeOrderUnknown) then return reserved end
    local target, _, record, selected = Targets:Resolve(out, entry)
    if not target then return reserved end
    applyUnknownWhiteOutcome(target, out, source, candidate,
        context, entry, entry.tiedWhiteAmbient, pet, record, selected, false)
    pet.resourceExact, pet.actionReadyExact = false, false
    pet.resourceUnknownReason = "companion melee order"
    pet.companionTimelineExact = false
    pet.companionTimelineUnknownReason = "companion melee order"
    refreshRecord(out, record, true)
    return reserved
end

local function applyUnknownAutocast(out, source, candidate, context,
    entry, ambient, pet, target, record, selected)
    if entry.meleeOrderUnknown then
        applyUnknownWhiteOutcome(target, out, source, candidate,
            context, entry, entry.tiedWhiteAmbient, pet,
            record, selected, false)
        pet.resourceExact, pet.actionReadyExact = false, false
        pet.resourceUnknownReason = "companion melee order"
        pet.companionTimelineExact = false
        pet.companionTimelineUnknownReason = "companion melee order"
        refreshRecord(out, record, true)
    end
    return true
end

function C:Apply(out, source, candidate, context, entry)
    local pet = out.actors and out.actors.pet
    if not pet then return false end
    if pet.companionTimelineExact == false then return false end
    if entry.kind == "petAutocastTimelineCap" then
        pet.resourceExact, pet.actionReadyExact = false, false
        pet.resourceUnknownReason = "companion autocast timeline cap"
        return true
    end
    if entry.kind == "petSwingTimelineCap" then
        if pet.attackRound then
            pet.attackRound.phaseExact, pet.attackRound.projectable = false, false
            pet.attackRound.reason = "companion white-swing timeline cap"
        end
        return true
    end
    if entry.kind == "petWhiteSwing" then
        return applyWhiteSwing(out, source, candidate, context, entry, pet)
    end
    if entry.kind == "petAutocastStart" then
        return CastRuntime:Begin(
            out, pet, entry, startTargetValid(out, pet, entry))
    end
    if not CastEvents:Started(entry) then return false end
    if entry.tiedReservation then
        return applyTiedReservation(
            out, source, candidate, context, entry, pet)
    end
    local _, ambient = Scheduler:FindAmbient(pet, entry)
    if not ambient then return false end
    if entry.targetIndependent then
        return entry.kind == "petAutocastUnknown"
            and CastRuntime:Reserve(out, pet, ambient, entry) or false
    end
    if not entry.pendingCompletion then
        if not pet.targetExists then return false end
        local currentGuid, currentKey = Targets:Capture(out, pet)
        if currentGuid ~= entry.targetGuid or currentKey ~= entry.targetKey then
            return false
        end
    end
    local target, _, record, selected = Targets:Resolve(out, entry)
    if not target then
        if entry.pendingCompletion then
            return CastRuntime:Reserve(out, pet, ambient, entry)
        end
        return false
    end
    if not CastRuntime:Reserve(out, pet, ambient, entry) then return false end
    if entry.kind == "petAutocastUnknown" then
        return applyUnknownAutocast(out, source, candidate, context,
            entry, ambient, pet, target, record, selected)
    end
    local changed
    if ambient.kind == "dot" then
        changed = applyDot(target, out, source, candidate, context, entry,
            ambient, pet, record, selected)
    elseif ambient.kind == "damage" then
        changed = applyDamage(target, out, source, candidate, context, entry,
            ambient, pet, record, selected)
    elseif ambient.kind == "petThreat" then
        changed = applyThreat(target, out, source, candidate, context, entry,
            ambient, record, selected)
    elseif ambient.kind == "taunt" then
        changed = applyTaunt(target, out, source, candidate, context, entry,
            ambient, record, selected)
    end
    refreshRecord(out, record, changed)
    if not record and out.targetHealthExact and out.targetHealth <= 0 then
        out.hostile = false
        if out.autoShot then out.autoShot.active = false end
    end
    return changed and true or false
end
