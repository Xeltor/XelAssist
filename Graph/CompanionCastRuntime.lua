-- Resource, ticket, cooldown, and occupancy commits at companion event time.
XelAssist.Graph.CompanionCastRuntime = {}
local R = XelAssist.Graph.CompanionCastRuntime
local Resources = XelAssist.Graph.CompanionResources
local CastEvents = XelAssist.Graph.CompanionCastEvents
local Scheduler = XelAssist.Graph.CompanionScheduler
local Tie = XelAssist.Graph.CompanionTieScheduler

local function spend(pet, entry, override, known)
    if CastEvents:Paid(entry) then return true end
    if entry.requiresCastStart then return false end
    if known == nil then known = entry.autocastCostKnown end
    local cost = tonumber(override) or tonumber(entry.autocastCost) or 0
    return Resources:SpendActor(pet, cost, known)
end

local function remaining(entry, duration)
    local after = math.max(0, (tonumber(entry.windowEnd) or 0)
        - (tonumber(entry.offset) or 0))
    return math.max(0, (tonumber(duration) or 0) - after)
end

local function commitActor(out, pet, entry, busy)
    local left = remaining(entry, busy)
    pet.actionReadyIn = math.max(tonumber(pet.actionReadyIn) or 0, left)
    if out then
        out.actorReadyAt = out.actorReadyAt or {}
        local finish = (tonumber(entry.windowStart) or 0)
            + (tonumber(entry.windowEnd) or 0) + left
        out.actorReadyAt.pet = math.max(
            tonumber(out.actorReadyAt.pet) or 0, finish)
    end
end

local function commitCooldown(ambient, entry, cooldown, cast)
    ambient.readyIn = remaining(entry,
        math.max(0, tonumber(cast) or 0)
            + math.max(0.1, tonumber(cooldown) or 1.5))
end

local function divergenceBlocked(entry)
    local group = entry.tiedGroup
    return group and group.diverged
        and (not group.allowedTicket
            or group.allowedTicket ~= entry.castTicket)
end

local function markDivergence(pet, entry, choice)
    if not (entry.reservedChoice and choice)
        or Tie:Same(entry.reservedChoice, choice) then return end
    entry.tiedGroup.diverged = true
    entry.tiedGroup.allowedTicket = entry.castTicket
    pet.resourceExact, pet.actionReadyExact = false, false
    pet.resourceUnknownReason = "companion autocast tie changed"
end

function R:Reserve(out, pet, ambient, entry)
    if entry.autocastCost == nil then
        entry.autocastCost = tonumber(ambient.cost)
    end
    if not spend(pet, entry) then return false end
    commitCooldown(ambient, entry,
        entry.autocastCooldown or ambient.cooldown, 0)
    if not entry.pendingCompletion then
        commitActor(out, pet, entry, entry.autocastBusy)
    end
    return true
end

function R:ReserveTied(out, pet, entry, hostileValid)
    entry.tiedGroup = entry.tiedGroup or Tie:Group()
    if divergenceBlocked(entry) then return false end
    local selected = CastEvents:TiedChoice(pet, entry, hostileValid)
    if not selected or not spend(pet, entry,
        selected.choice.autocastCost,
        selected.choice.autocastCostKnown) then return false end
    commitCooldown(selected.ambient, entry,
        selected.choice.autocastCooldown or selected.ambient.cooldown, 0)
    if not entry.pendingCompletion then
    commitActor(out, pet, entry, selected.choice.autocastBusy)
    end
    markDivergence(pet, entry, selected.choice)
    Tie:Mark(entry.tiedGroup, selected.choice)
    return true
end

local function failed(pet, entry)
    CastEvents:MarkFailed(entry)
    if pet.pendingAutocast == entry.castIdentity then
        pet.pendingAutocast, pet.castSpellId = nil, nil
        pet.castRemaining, pet.casting = 0, false
    end
    return false
end

function R:Begin(out, pet, entry, targetValid)
    local choice, ambient, cost, known, busy, cast, cooldown
    if entry.tiedReservation then
        entry.tiedGroup = entry.tiedGroup or Tie:Group()
        if divergenceBlocked(entry) then return failed(pet, entry) end
        local selected = CastEvents:TiedChoice(
            pet, entry, targetValid and true or false)
        if not selected then return failed(pet, entry) end
        choice, ambient = selected.choice, selected.ambient
        cost, known = choice.autocastCost, choice.autocastCostKnown
        busy, cast, cooldown = choice.autocastBusy,
            choice.autocastCast, choice.autocastCooldown
    else
        local index
        index, ambient = Scheduler:FindAmbient(pet, entry)
        if not ambient or not targetValid then return failed(pet, entry) end
        cost, known = entry.autocastCost, entry.autocastCostKnown
        busy, cast, cooldown = entry.autocastBusy,
            entry.autocastCast, entry.autocastCooldown
    end
    if not Resources:SpendActor(pet, cost, known) then
        return failed(pet, entry)
    end
    CastEvents:MarkStarted(entry, choice)
    commitCooldown(ambient, entry, cooldown or ambient.cooldown, cast)
    commitActor(out, pet, entry, busy)
    if choice then markDivergence(pet, entry, choice) end
    local left = remaining(entry, cast)
    if left > 0 and entry.castIdentity then
        pet.pendingAutocast = entry.castIdentity
        pet.castSpellId = choice and choice.autocastSpellId
            or entry.autocastSpellId
        pet.castRemaining, pet.casting = left, true
    end
    return true
end
