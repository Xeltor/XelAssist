-- Stable records for projected companion cast starts, pending casts, and
-- completions. A shared ticket makes start-time payment survive graph windows.
XelAssist.Graph.CompanionCastEvents = {}
local C = XelAssist.Graph.CompanionCastEvents

function C:Pending(lane, identity, remaining, costPaid)
    identity = identity or {}
    return { autocastIndex = lane.index, autocastName = lane.ambient.name,
        autocastSpellId = lane.ambient.spellId,
        targetGuid = identity.guid, targetKey = identity.key,
        targetLocal = identity.localTarget,
        targetIndependent = lane.targetIndependent and true or false,
        remaining = remaining, cooldown = lane.cooldown,
        cost = lane.cost, costKnown = lane.costKnown,
        busy = lane.busy, cast = lane.cast,
        costPaid = costPaid and true or false,
        uncertain = lane.uncertain and true or false,
        unknownReason = lane.unknownReason }
end

function C:Event(identity, offset, window, costPaid)
    return { owner = "ongoing",
        kind = identity.uncertain and "petAutocastUnknown" or "petAutocast",
        offset = offset, priority = 50,
        autocastIndex = identity.autocastIndex,
        autocastName = identity.autocastName,
        autocastSpellId = identity.autocastSpellId,
        autocastCost = identity.cost,
        autocastCostKnown = identity.costKnown,
        autocastCooldown = identity.cooldown,
        autocastBusy = identity.busy, autocastCast = identity.cast,
        costPaid = costPaid and true or false,
        windowEnd = window, targetGuid = identity.targetGuid,
        targetKey = identity.targetKey, targetLocal = identity.targetLocal,
        targetIndependent = identity.targetIndependent,
        tiedReservation = identity.tiedReservation,
        tiedAutocasts = identity.tiedAutocasts,
        tiedGroup = identity.tiedGroup,
        reservedChoice = identity.reservedChoice,
        unknownReason = identity.unknownReason,
        castTicket = identity.castTicket,
        requiresCastStart = identity.requiresCastStart }
end

function C:Start(identity, offset, window)
    identity.castTicket = identity.castTicket or { costPaid = false }
    identity.requiresCastStart = true
    local entry = self:Event(identity, offset, window, false)
    entry.kind, entry.priority = "petAutocastStart", 45
    entry.castIdentity = identity
    return entry
end

function C:Paid(entry)
    return entry.costPaid == true
        or entry.castTicket and entry.castTicket.costPaid == true
end

function C:Started(entry)
    return not entry.requiresCastStart
        or entry.castTicket and entry.castTicket.costPaid == true
end

function C:MarkStarted(entry, choice)
    local ticket = entry.castTicket or {}
    entry.castTicket = ticket
    ticket.costPaid, ticket.choice = true, choice
    if entry.castIdentity then
        entry.castIdentity.costPaid = true
        if choice then entry.castIdentity.reservedChoice = choice end
    end
end

function C:MarkFailed(entry)
    if entry.castTicket then entry.castTicket.startFailed = true end
    if entry.castIdentity then entry.castIdentity.startFailed = true end
end

function C:TiedChoice(pet, entry, hostileValid)
    local scheduler = XelAssist.Graph.CompanionScheduler
    local tie = XelAssist.Graph.CompanionTieScheduler
    local resolved, ticketChoice, i = {},
        entry.castTicket and entry.castTicket.choice, nil
    local preferred = ticketChoice or entry.reservedChoice
    for i = 1, table.getn(entry.tiedAutocasts or {}) do
        local choice = entry.tiedAutocasts[i]
        if (choice.targetIndependent or hostileValid)
            and (not ticketChoice or tie:Same(choice, ticketChoice)) then
            local _, ambient = scheduler:FindAmbient(pet, choice)
            if ambient then
                local value = { ambient = ambient, choice = choice }
                if preferred and tie:Same(choice, preferred) then return value end
                table.insert(resolved, value)
            end
        end
    end
    if ticketChoice then return nil end
    return tie:WorstResolved(resolved, entry.tiedGroup)
end
