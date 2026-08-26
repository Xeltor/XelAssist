-- Pure adapter from a scored graph context to HealingTriage's frozen evidence
-- contract. It reads only copied graph state. Hostile casts contribute damage
-- only when recipient, timing, probability, magnitude and absorbs are exact.
XelAssist.Graph.HealingTriageEvidence = {}
local E = XelAssist.Graph.HealingTriageEvidence
local Triage = XelAssist.Graph.HealingTriage
local State = XelAssist.Graph.State
local Incoming = XelAssist.Graph.IncomingConsequences

E.MAX_CASTS = 24

local EPSILON = 0.0001

local function nonnegative(value)
    value = tonumber(value)
    if value == nil or value < 0 or value ~= value
        or value == math.huge then return nil end
    return value
end

local function validKey(value)
    local kind = type(value)
    return (kind == "string" and value ~= "")
        or kind == "number" and value == value
end

local function validGuid(guid)
    return type(guid) == "string" and guid ~= ""
        and guid ~= "0x000000000" and guid ~= "0x0000000000000000"
end

local function listCount(values, maximum)
    if type(values) ~= "table" then return nil end
    local count, highest, key = 0, 0, nil
    for key in pairs(values) do
        if type(key) ~= "number" or key < 1 or key ~= math.floor(key) then
            return nil
        end
        count = count + 1
        highest = math.max(highest, key)
        if count > maximum or highest > maximum then return nil end
    end
    if count ~= highest then return nil end
    return count
end

local function exactTiming(context, facts, tooltip)
    local state = context.state
    local now = nonnegative(state and state.time)
    local cast = nonnegative(context.cast)
    local gcd = nonnegative(context.gcd)
    local wait = nonnegative(context.wait)
    local start = nonnegative(context.actionStart)
    local baseCast = nonnegative(facts.cast)
    if baseCast == nil then baseCast = nonnegative(tooltip.cast) end
    local baseGcd = nonnegative(facts.gcd)
    if baseGcd == nil then baseGcd = nonnegative(tooltip.gcd) end
    if now == nil or cast == nil or gcd == nil or wait == nil
        or start == nil or baseCast == nil or baseGcd == nil
        or math.abs(start - now - wait) > EPSILON then
        return nil, "healing timing evidence unavailable"
    end
    local expectedCast = state.instantNext == true and baseCast > 0
        and 0 or baseCast
    if math.abs(cast - expectedCast) > EPSILON
        or math.abs(gcd - baseGcd) > EPSILON then
        return nil, "healing timing evidence unavailable"
    end
    return { now = now, cast = cast, gcd = gcd, wait = wait }, nil
end

local function actionEvidence(context)
    local action = context and context.action
    local facts = context and context.facts
    local tooltip = context and context.tooltip
    if type(action) ~= "table" or type(facts) ~= "table"
        or type(tooltip) ~= "table" or context.kind ~= "heal"
        or facts.kind ~= "heal" or facts.channel == true
        or facts.consumable == true or action.executor == "item" then
        return nil, "unsupported healing action"
    end
    local observed = XelAssist.Graph.RootObservation
    local actionKey = observed and type(observed.ActionKey) == "function"
        and observed:ActionKey(action) or nil
    local power = nonnegative(context.power)
    local cost = nonnegative(context.cost)
    local powerEvidence = context.powerEvidence
    if not validKey(actionKey) or not power or power <= 0 or cost == nil
        or context.costKnown ~= true or context.estimated == true
        or type(powerEvidence) == "table" and (powerEvidence.unknown == true
            or powerEvidence.exact == false
            or powerEvidence.complete == false) then
        return nil, "heal evidence unavailable"
    end
    local timing, reason = exactTiming(context, facts, tooltip)
    if not timing then return nil, reason end
    local guaranteed = nonnegative(tooltip.low)
    local guaranteedKnown = guaranteed ~= nil
    if not guaranteedKnown and type(powerEvidence) == "table"
        and powerEvidence.exact == true and powerEvidence.complete == true then
        guaranteed, guaranteedKnown = power, true
    end
    if guaranteed ~= nil and guaranteed > power then
        return nil, "heal range evidence invalid"
    end
    return { actionKey = actionKey, kind = "heal", delivery = "direct",
        actor = action.actor or "player", power = power, powerKnown = true,
        guaranteedPower = guaranteed,
        guaranteedPowerKnown = guaranteedKnown,
        cost = cost, costKnown = true, cast = timing.cast,
        wait = timing.wait, gcd = timing.gcd, timingKnown = true,
        healingThreatFactor = facts.threat,
        healingThreatActor = facts.healingThreatActor
            or action.actor or "player" }, nil
end

local function retainedRecipient(context)
    local state, descriptor = context.state, context.descriptor
    if type(descriptor) ~= "table" or descriptor.relation == "hostile"
        or not validKey(descriptor.key) or not validGuid(descriptor.guid)
        or not (State and type(State.FriendlyByKey) == "function") then
        return nil, "healing recipient evidence unavailable"
    end
    local record = State:FriendlyByKey(state, descriptor.key)
    local exact = record and record.healthExact
    if exact == nil and record then exact = record.exact end
    local health = nonnegative(record and record.health)
    local maximum = nonnegative(record and record.healthMax)
    if not record or descriptor.record ~= nil and descriptor.record ~= record
        or context.friendly ~= nil and context.friendly ~= record
        or record.guid ~= descriptor.guid or exact ~= true
        or record.dead == true or health == nil or maximum == nil
        or maximum <= 0 or health > maximum then
        return nil, "healing recipient evidence unavailable"
    end
    return { key = descriptor.key, guid = descriptor.guid,
        health = health, healthMax = maximum,
        healthAt = nonnegative(state.time), healthExact = true,
        incomingKnown = true, incomingFrozen = true, incoming = {} }, nil
end

local function casterDefeated(state, cast)
    local hostiles = state and state.hostiles
    local record = cast.hostileKey ~= nil and hostiles and hostiles.byKey
        and hostiles.byKey[cast.hostileKey] or nil
    if record and (record.guid or cast.hostileKey) ~= cast.casterGuid then
        record = nil
    end
    local index, key
    for index = 1, table.getn(not record and hostiles
        and hostiles.order or {}) do
        key = hostiles.order[index]
        local candidate = hostiles.byKey and hostiles.byKey[key]
        if candidate and (candidate.guid or key) == cast.casterGuid then
            record = candidate
            break
        end
    end
    if not record then return false end
    if record.dead == true or record.projectedDefeated == true then return true end
    return record.healthExact == true and tonumber(record.health) ~= nil
        and record.health <= 0
end

local function castRows(state)
    local collection = state and state.hostileCasts
    local total = listCount(collection and collection.order, E.MAX_CASTS)
    if total == nil or type(collection.byCaster) ~= "table" then
        return nil, "incoming cast snapshot unavailable"
    end
    local mapCount, casterGuid, cast = 0, nil, nil
    for casterGuid, cast in pairs(collection.byCaster) do
        if not validGuid(casterGuid) or type(cast) ~= "table" then
            return nil, "incoming cast snapshot invalid"
        end
        mapCount = mapCount + 1
    end
    if mapCount ~= total then return nil, "incoming cast snapshot invalid" end

    local out, seenCaster, seenGeneration, index = {}, {}, {}, nil
    for index = 1, total do
        casterGuid = collection.order[index]
        cast = collection.byCaster[casterGuid]
        local generation = type(cast) == "table"
            and tonumber(cast.generation) or nil
        local remaining = type(cast) == "table"
            and nonnegative(cast.remaining) or nil
        if not validGuid(casterGuid) or seenCaster[casterGuid]
            or type(cast) ~= "table" or cast.casterGuid ~= casterGuid
            or cast.active == false or not generation or generation <= 0
            or generation ~= math.floor(generation)
            or seenGeneration[generation] or remaining == nil then
            return nil, "incoming cast snapshot invalid"
        end
        seenCaster[casterGuid], seenGeneration[generation] = true, true
        table.insert(out, { casterGuid = casterGuid,
            generation = generation, remaining = remaining,
            order = index, cast = cast })
    end
    table.sort(out, function(left, right)
        if left.remaining ~= right.remaining then
            return left.remaining < right.remaining
        end
        return left.order < right.order
    end)
    return out, nil
end

local function exactRelevantRows(state, recipientGuid, within)
    local rows, reason = castRows(state)
    if not rows then return nil, reason end
    local relevant, index = {}, nil
    for index = 1, table.getn(rows) do
        local row, cast = rows[index], rows[index].cast
        if row.remaining <= within and not casterDefeated(state, cast) then
            local facts = cast.consequence
            local recipient = facts and Incoming:RecipientGuid(cast) or nil
            if not facts then
                if not validGuid(cast.targetGuid) then
                    return nil, "incoming cast recipient evidence unavailable"
                elseif cast.targetGuid == recipientGuid then
                    return nil, cast.consequenceReason
                        or "incoming cast consequence unavailable"
                end
            elseif not validGuid(recipient) then
                return nil, "incoming cast recipient evidence unavailable"
            elseif recipient == recipientGuid then
                local probability = tonumber(cast.probability)
                local amount = nonnegative(facts.amount)
                if facts.kind ~= "damage" or facts.direct ~= true
                    or facts.singleTarget ~= true or facts.exact ~= true
                    or facts.estimated == true or facts.magnitudeEstimated == true
                    or probability ~= 1 or amount == nil or amount <= 0 then
                    return nil, "incoming damage evidence unavailable"
                end
                row.rawDamage = amount
                table.insert(relevant, row)
            end
        end
    end
    return relevant, nil
end

local function inflateRecipient(state, guid, health)
    local recipient = Incoming:Resolve(state, guid)
    if not recipient or recipient.guid ~= guid then return nil end
    local record = recipient.friendly or recipient.actor
    if not record then return nil end
    record.health, record.healthMax = health, health
    record.exact, record.healthExact = true, true
    record.dead, record.projectedDefeated = false, nil
    if recipient.actor and recipient.actor ~= record then
        recipient.actor.health, recipient.actor.healthMax = health, health
        recipient.actor.exact, recipient.actor.healthExact = true, true
        recipient.actor.dead, recipient.actor.projectedDefeated = false, nil
    end
    if recipient.kind == "player" then
        state.health, state.healthMax, state.dead = health, health, false
    end
    return recipient
end

local function ageAbsorbSet(absorbs, elapsed)
    if type(absorbs) ~= "table" or elapsed <= 0 then return true end
    local name, entry
    for name, entry in pairs(absorbs) do
        if name ~= "available" then
            if type(entry) ~= "table" then
                return nil, "incoming absorb timing unavailable"
            end
            local remaining = nonnegative(entry.remaining)
            if remaining == nil then
                return nil, "incoming absorb timing unavailable"
            end
            entry.remaining = math.max(0, remaining - elapsed)
            if entry.remaining <= 0 then absorbs[name] = nil end
        end
    end
    return true, nil
end

local function ageRecipientAbsorbs(state, guid, elapsed)
    local recipient = Incoming:Resolve(state, guid)
    if not recipient then return nil, "incoming recipient projection unavailable" end
    local ok, reason = ageAbsorbSet(
        recipient.friendly and recipient.friendly.absorbs, elapsed)
    if not ok then return nil, reason end
    if recipient.kind == "player" then
        ok, reason = ageAbsorbSet(state.absorbs, elapsed)
        if not ok then return nil, reason end
    end
    return true, nil
end

local function incomingEvents(state, recipient, within)
    if not (State and type(State.Copy) == "function" and Incoming
        and type(Incoming.Resolve) == "function"
        and type(Incoming.Preview) == "function"
        and type(Incoming.Apply) == "function") then
        return nil, "incoming evidence adapter unavailable"
    end
    local rows, reason = exactRelevantRows(state, recipient.guid, within)
    if not rows then return nil, reason end
    local totalRaw, index = 0, nil
    for index = 1, table.getn(rows) do
        totalRaw = totalRaw + rows[index].rawDamage
        if totalRaw == math.huge then
            return nil, "incoming damage evidence unavailable"
        end
    end
    if table.getn(rows) == 0 then return {}, nil end

    local work = State:Copy(state)
    local budget = recipient.healthMax + totalRaw + 1
    if budget == math.huge
        or not inflateRecipient(work, recipient.guid, budget) then
        return nil, "incoming recipient projection unavailable"
    end
    local out, elapsed = {}, 0
    for index = 1, table.getn(rows) do
        local row = rows[index]
        local aged
        aged, reason = ageRecipientAbsorbs(
            work, recipient.guid, row.remaining - elapsed)
        if not aged then return nil, reason end
        elapsed = row.remaining
        local cast = work.hostileCasts and work.hostileCasts.byCaster
            and work.hostileCasts.byCaster[row.casterGuid]
        local preview = cast and Incoming:Preview(work, cast) or nil
        if not preview or preview.guid ~= recipient.guid
            or preview.healthExact ~= true or preview.absorbsExact ~= true
            or preview.probability ~= 1 or preview.facts.estimated == true then
            return nil, "incoming damage projection unavailable"
        end
        local result = Incoming:Apply(work, cast)
        local damage = result and nonnegative(result.effective) or nil
        if not result or result.kind ~= "damage" or result.partial == true
            or result.estimated == true or result.probability ~= 1
            or result.recipientGuid ~= recipient.guid or damage == nil then
            return nil, "incoming damage projection unavailable"
        end
        table.insert(out, {
            id = "cast:" .. row.casterGuid .. "\001" .. row.generation,
            kind = "damage", recipientGUID = recipient.guid,
            at = state.time + row.remaining, damage = damage,
            exact = true, frozen = true, probability = 1,
        })
    end
    return out, nil
end

-- The sole orchestration hook. Scoring supplies its already-legal context and
-- receives either a frozen plan or a fail-closed blocker; no API fallback is
-- attempted here or in HealingTriage.
function E:Score(context)
    if not (Triage and type(Triage.Score) == "function") then
        return nil, "healing triage unavailable"
    end
    local action, reason = actionEvidence(context)
    if not action then return nil, reason end
    local recipient
    recipient, reason = retainedRecipient(context)
    if not recipient then return nil, reason end
    local events
    local within = action.wait + action.cast + Triage.STABILITY_WINDOW
    events, reason = incomingEvents(context.state, recipient, within)
    if not events then return nil, reason end
    recipient.incoming = events
    return Triage:Score(action, recipient, {
        time = context.state.time, resource = context.state.resource,
        resourceMax = context.state.resourceMax,
        playerResourceExact = context.state.playerResourceExact,
    })
end
