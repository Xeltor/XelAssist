-- One conservative actor clock for enabled pet autocasts. It arbitrates
-- simultaneous readiness without inventing a class or family rotation.
XelAssist.Graph.CompanionScheduler = {}
local S = XelAssist.Graph.CompanionScheduler
local Tie = XelAssist.Graph.CompanionTieScheduler
local Resources = XelAssist.Graph.CompanionResources
local CastEvents = XelAssist.Graph.CompanionCastEvents

local MAX_EVENTS = 8

local function addUnknown(candidate, reason)
    candidate.companionUnknowns = candidate.companionUnknowns or {}
    local i
    for i = 1, table.getn(candidate.companionUnknowns) do
        if candidate.companionUnknowns[i] == reason then return end
    end
    table.insert(candidate.companionUnknowns, reason)
end

local function isArea(ambient)
    return ambient.facts and ambient.facts.aoe
        or ambient.tooltip and ambient.tooltip.topology
            and ambient.tooltip.topology.area
end

local function supported(ambient)
    if ambient.kind == "damage" or ambient.kind == "taunt"
        or ambient.kind == "petThreat" then return true end
    local duration = ambient.tooltip and tonumber(ambient.tooltip.duration)
        or ambient.facts and tonumber(ambient.facts.duration)
    return ambient.kind == "dot" and duration and duration > 0
        and (tonumber(ambient.power) or 0) > 0
end

local function targetIndependent(ambient)
    return ambient and ambient.facts and ambient.facts.self and true or false
end

local function sameSpell(left, right)
    if left == right then return left ~= nil end
    local leftNumber, rightNumber = tonumber(left), tonumber(right)
    return leftNumber ~= nil and rightNumber ~= nil
        and leftNumber == rightNumber
end

local function sameAmbient(ambient, index, identity)
    if not (ambient and identity) then return false end
    if identity.autocastSpellId ~= nil then
        return sameSpell(ambient.spellId, identity.autocastSpellId)
    end
    return index == identity.autocastIndex
        and ambient.name == identity.autocastName
end

local function findAmbient(pet, identity)
    if not identity then return nil, nil end
    local index = identity.autocastIndex
    local ambient = index and pet.autocasts and pet.autocasts[index]
    if sameAmbient(ambient, index, identity) then return index, ambient end
    if identity.autocastSpellId == nil then return nil, nil end
    local i
    for i = 1, table.getn(pet.autocasts or {}) do
        ambient = pet.autocasts[i]
        if sameAmbient(ambient, i, identity) then return i, ambient end
    end
    return nil, nil
end

function S:FindAmbient(pet, identity) return findAmbient(pet, identity) end

function S:MatchesAction(action, ambient)
    if not (action and ambient) then return false end
    if action.spellId ~= nil or ambient.spellId ~= nil then
        return action.spellId ~= nil and ambient.spellId ~= nil
            and sameSpell(action.spellId, ambient.spellId)
    end
    return action.name ~= nil and action.name == ambient.name
end

local function chosen(candidate, ambient)
    local action = candidate and candidate.action
    return action and action.actor == "pet" and action.executor == "petAbility"
        and S:MatchesAction(action, ambient)
end

local function geometry(pet, record)
    local observed = record and record.geometry and record.geometry.pet
    if observed then return observed end
    return { distance = pet.distance, lineOfSight = pet.lineOfSight,
        behind = pet.behind, source = pet.distanceKind }
end

local function legality(pet, record, ambient)
    local observed, tooltip, facts = geometry(pet, record),
        ambient.tooltip or {}, ambient.facts or {}
    local distance = tonumber(observed.distance)
    local minimum = math.max(0, tonumber(tooltip.minRange) or 0)
    local maximum = tonumber(tooltip.maxRange)
    if not maximum and facts.melee then maximum = 5 end
    if distance and (distance < minimum or maximum and distance > maximum) then
        return false, "range"
    end
    if not distance and (minimum > 0 or maximum
        or facts.melee or facts.ranged) then
        return nil, "companion autocast geometry"
    end
    return true, nil
end

local function occupancy(ambient)
    local tooltip, facts = ambient.tooltip or {}, ambient.facts or {}
    return math.max(0.1, tonumber(tooltip.cast) or tonumber(facts.cast) or 0,
        tonumber(tooltip.gcd) or tonumber(facts.gcd) or 1.5)
end

local function castTime(ambient)
    return math.max(0, tonumber(ambient.tooltip and ambient.tooltip.cast)
        or tonumber(ambient.facts and ambient.facts.cast) or 0)
end

local function costOf(ambient)
    local cost = tonumber(ambient.cost)
    if cost == nil then return nil, false end
    return math.max(0, cost), true
end

local function reservation(candidate)
    local action = candidate and candidate.action
    if not (action and action.actor == "pet" and action.executor == "petAbility") then
        return nil, nil
    end
    local first = math.max(0, tonumber(candidate.wait) or 0)
    return first, first + math.max(0.1, tonumber(candidate.cast) or 0,
        tonumber(candidate.tooltip and candidate.tooltip.gcd) or 1.5)
end

local function reservedTime(value, busy, first, last)
    if not first then return value end
    if value < first and value + busy > first then return last end
    if value >= first and value < last then return last end
    return value
end

local function livePending(pet, identity, remaining)
    if pet.castSpellId == nil then return nil end
    local match = { autocastSpellId = pet.castSpellId }
    local index, ambient = findAmbient(pet, match)
    local independent = targetIndependent(ambient)
    if not ambient or not identity and not independent then return nil end
    local area, known = isArea(ambient), supported(ambient)
    local cost, costKnown = costOf(ambient)
    local uncertain, reason = area or not known or independent, nil
    if area then reason = "companion area recipients"
    elseif not known or independent then reason = "companion autocast effect" end
    return CastEvents:Pending({ index = index, ambient = ambient,
        cooldown = math.max(0.1, tonumber(ambient.cooldown) or 1.5),
        cost = cost, costKnown = costKnown, uncertain = uncertain,
        unknownReason = reason, targetIndependent = independent },
        identity, remaining, true)
end

local function markLaneUnknowns(pet, candidate, area, known, costKnown,
    legal, reason)
    local unknownReason
    if legal == nil then
        pet.autocastGeometryUnknown = true
        addUnknown(candidate, reason)
        unknownReason = reason
    end
    if not costKnown then
        pet.autocastCostUnknown = true
        addUnknown(candidate, "companion autocast cost")
        unknownReason = unknownReason or "companion autocast cost"
    end
    if not known then
        pet.autocastEffectUnknown = true
        addUnknown(candidate, "companion autocast effect")
        unknownReason = unknownReason or "companion autocast effect"
    end
    if area then unknownReason = "companion area recipients" end
    return area or not known or legal == nil or not costKnown, unknownReason
end

local function collectLanes(pet, record, candidate, identity, window)
    local lanes, i = {}, nil
    for i = 1, table.getn(pet.autocasts or {}) do
        local ambient = pet.autocasts[i]
        local area, known = isArea(ambient), supported(ambient)
        local independent = targetIndependent(ambient)
        if area then
            pet.areaAutocastUnknown = true
            addUnknown(candidate, "companion area recipients")
        end
        local ready = math.max(0, tonumber(ambient.readyIn) or 0)
        ambient.readyIn = math.max(0, ready - window)
        if not chosen(candidate, ambient) and (identity or independent) then
            local legal, reason = true, nil
            if not independent then legal, reason = legality(pet, record, ambient) end
            local cost, costKnown = costOf(ambient)
            if legal ~= false then
                local uncertain, unknownReason = markLaneUnknowns(pet,
                    candidate, area, known, costKnown, legal, reason)
                if independent then
                    uncertain = true
                    unknownReason = unknownReason or "companion autocast effect"
                    pet.autocastEffectUnknown = true
                    addUnknown(candidate, "companion autocast effect")
                end
                table.insert(lanes, { index = i, ambient = ambient,
                    ready = ready, cooldown = math.max(0.1,
                        tonumber(ambient.cooldown) or 1.5),
                    busy = occupancy(ambient), cast = castTime(ambient),
                    cost = cost, costKnown = costKnown,
                    uncertain = uncertain, unknownReason = unknownReason,
                    targetIndependent = independent })
            end
        end
    end
    return lanes
end

local function completePending(clock, pending)
    local completion = math.max(0,
        tonumber(pending.remaining) or clock.initialCast)
    if completion > clock.window then
        pending.remaining = completion - clock.window
        clock.pet.pendingAutocast = pending
        return
    end
    local entry = CastEvents:Event(
        pending, completion, clock.window, pending.costPaid)
    entry.pendingCompletion = true
    table.insert(clock.events, entry)
    clock.emitted = clock.emitted + 1
    local i
    for i = 1, table.getn(clock.lanes) do
        local lane = clock.lanes[i]
        local cooldown
        if pending.tiedReservation and pending.reservedChoice
            and sameAmbient(lane.ambient, lane.index,
                pending.reservedChoice) then
            cooldown = pending.reservedChoice.autocastCooldown
        elseif sameAmbient(lane.ambient, lane.index, pending) then
            cooldown = pending.cooldown
        end
        if cooldown then
            lane.ready = math.max(lane.ready, completion + cooldown)
        end
    end
    clock.pet.pendingAutocast = nil
    if sameSpell(clock.pet.castSpellId, pending.autocastSpellId) then
        clock.pet.castSpellId = nil
    end
end

local function laneTime(clock, lane)
    local at = math.max(lane.ready, clock.actorReady)
    local i
    for i = 1, 3 do
        at = reservedTime(at, lane.busy,
            clock.chosenFirst, clock.chosenLast)
        local focused = Resources:Earliest(
            clock.resourceClock, lane.cost, lane.costKnown, at)
        if not focused then return nil end
        if focused == at then return at end
        at = focused
    end
    return at
end

local function nextLane(clock)
    local bestTime, tied, i = nil, {}, nil
    for i = 1, table.getn(clock.lanes) do
        local lane = clock.lanes[i]
        local at = laneTime(clock, lane)
        if at then
            if not bestTime or at < bestTime then
                bestTime, tied = at, { lane }
            elseif at == bestTime then table.insert(tied, lane) end
        end
    end
    return tied[1], bestTime, tied
end

local function beginPending(clock, best, bestTime, impact)
    local pending = CastEvents:Pending(best, clock.identity,
        impact - clock.window, false)
    clock.pet.pendingAutocast = pending
    clock.pet.castSpellId = best.ambient.spellId
    clock.pet.autocastCompletionUnknown = true
    addUnknown(clock.candidate, "companion cast completion")
    table.insert(clock.events,
        CastEvents:Start(pending, bestTime, clock.window))
    clock.emitted = clock.emitted + 1
    clock.actorReady = bestTime + best.busy
end

local function tiedIdentity(clock, tied)
    local reserved, busy, cast = Tie:Envelope(tied)
    local identity = CastEvents:Pending(
        reserved, clock.identity, 0, false)
    clock.tiedGroup = clock.tiedGroup or Tie:Group()
    identity.uncertain = true
    identity.unknownReason = "companion autocast order"
    identity.tiedReservation = true
    identity.tiedAutocasts = Tie:Choices(tied)
    identity.tiedGroup = clock.tiedGroup
    identity.reservedChoice = Tie:Choice(reserved)
    identity.autocastIndex, identity.autocastName,
        identity.autocastSpellId, identity.cooldown = nil, nil, nil, nil
    return identity, reserved, busy, cast
end

local function emitTie(clock, tied, bestTime)
    local identity, reserved, busy, cast = tiedIdentity(clock, tied)
    local impact = bestTime + cast
    clock.pet.autocastOrderUnknown = true
    addUnknown(clock.candidate, "companion autocast order")
    if not Resources:Reserve(clock.resourceClock,
        bestTime, identity.cost, identity.costKnown) then return false end
    reserved.ready = impact + reserved.cooldown
    clock.actorReady = bestTime + busy
    if cast > 0 then
        table.insert(clock.events,
            CastEvents:Start(identity, bestTime, clock.window))
    end
    if impact > clock.window then
        identity.remaining = impact - clock.window
        clock.pet.pendingAutocast = identity
        clock.pet.castSpellId = nil
        clock.pet.autocastCompletionUnknown = true
        addUnknown(clock.candidate, "companion cast completion")
        clock.emitted = clock.emitted + 1
        return false
    end
    local entry = CastEvents:Event(identity, impact, clock.window, false)
    if cast > 0 then entry.pendingCompletion = true end
    table.insert(clock.events, entry)
    clock.emitted = clock.emitted + 1
    return true
end

local function emitLane(clock, best, bestTime, tied)
    if table.getn(tied) > 1 or clock.tiedGroup then
        return emitTie(clock, tied, bestTime)
    end
    if not Resources:Reserve(clock.resourceClock,
        bestTime, best.cost, best.costKnown) then return false end
    local impact = bestTime + best.cast
    if impact > clock.window then
        beginPending(clock, best, bestTime, impact)
        return false
    end
    local uncertain = best.uncertain
    local identity = CastEvents:Pending(best, clock.identity, 0, false)
    identity.uncertain = uncertain
    identity.unknownReason = best.unknownReason
    if best.cast > 0 then
        table.insert(clock.events,
            CastEvents:Start(identity, bestTime, clock.window))
    end
    local entry = CastEvents:Event(identity, impact, clock.window, false)
    if best.cast > 0 then entry.pendingCompletion = true end
    table.insert(clock.events, entry)
    best.ready, clock.actorReady = impact + best.cooldown,
        bestTime + best.busy
    clock.emitted = clock.emitted + 1
    return true
end

local function schedule(clock)
    while clock.emitted < MAX_EVENTS do
        local best, bestTime, tied = nextLane(clock)
        if not best or bestTime > clock.window then break end
        if not emitLane(clock, best, bestTime, tied) then break end
    end
    if clock.emitted == MAX_EVENTS then
        local best, at = nextLane(clock)
        if best and at <= clock.window then
            clock.cappedAt = at
            table.insert(clock.events, { owner = "ongoing",
                kind = "petAutocastTimelineCap", offset = at,
                priority = 15, windowEnd = clock.window })
        end
    end
end

local function finishClock(clock)
    local pet = clock.pet
    pet.actionReadyIn = math.max(0,
        clock.initialActorReady - clock.window)
    if pet.pendingAutocast then
        pet.castRemaining = math.max(0,
            tonumber(pet.pendingAutocast.remaining) or 0)
    else
        pet.castRemaining = math.max(0, clock.initialCast - clock.window)
        if pet.castRemaining <= 0 then pet.castSpellId = nil end
    end
    pet.casting = pet.castRemaining > 0
    if clock.cappedAt then
        pet.autocastTimelineCapped = true
        addUnknown(clock.candidate, "companion autocast timeline cap")
    end
end

function S:Events(pet, record, candidate, identity)
    local window = math.max(0, tonumber(candidate.downtime) or 0)
    local initialCast = math.max(0, tonumber(pet.castRemaining) or 0)
    local pending = pet.pendingAutocast
    if not pending and initialCast > 0 then
        pending = livePending(pet, identity, initialCast)
        pet.pendingAutocast = pending
    end
    local chosenFirst, chosenLast = reservation(candidate)
    local clock = { pet = pet, candidate = candidate, identity = identity,
        window = window, initialCast = initialCast, events = {},
        lanes = collectLanes(pet, record, candidate, identity, window),
        resourceClock = Resources:Create(pet, candidate),
        actorReady = math.max(initialCast, tonumber(pet.actionReadyIn) or 0),
        initialActorReady = math.max(initialCast,
            tonumber(pet.actionReadyIn) or 0),
        chosenFirst = chosenFirst, chosenLast = chosenLast, emitted = 0,
        tiedGroup = pending and pending.tiedGroup or nil }
    if pending then completePending(clock, pending)
    elseif initialCast > 0 then
        pet.autocastCompletionUnknown = true
        addUnknown(candidate, "companion cast completion")
    end
    schedule(clock)
    finishClock(clock)
    return clock.events
end
