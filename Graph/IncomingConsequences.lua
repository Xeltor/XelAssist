-- Exact-recipient graph consequences for conservatively admitted hostile
-- spells. Live absorb amounts remain unknown unless this graph created them.
XelAssist.Graph.IncomingConsequences = {}
local I = XelAssist.Graph.IncomingConsequences
local State = XelAssist.Graph.State

local function friendlyByGuid(state, guid)
    local friendlies = state and state.friendlies
    local i, key, record
    for i = 1, table.getn(friendlies and friendlies.order or {}) do
        key = friendlies.order[i]
        record = friendlies.byKey and friendlies.byKey[key]
        if record and record.guid == guid then return record, key end
    end
    return nil, nil
end

local function hostileByGuid(state, guid)
    local hostiles = state and state.hostiles
    local i, key, record
    for i = 1, table.getn(hostiles and hostiles.order or {}) do
        key = hostiles.order[i]
        record = hostiles.byKey and hostiles.byKey[key]
        if record and (record.guid or key) == guid then return record, key end
    end
    return nil, nil
end

function I:RecipientGuid(cast)
    local facts = cast and cast.consequence
    if not facts then return nil end
    if facts.targetMode == "self" then return cast.casterGuid end
    return facts.targetGuid or cast.targetGuid
end

function I:Resolve(state, guid)
    if guid == nil then return nil end
    local actors = state and state.actors or {}
    local friendly, friendlyKey = friendlyByGuid(state, guid)
    if actors.player and actors.player.guid == guid then
        return { kind = "player", relation = "friendly",
            actor = actors.player, friendly = friendly,
            friendlyKey = friendlyKey, guid = guid }
    end
    if actors.pet and actors.pet.guid == guid then
        return { kind = "pet", relation = "friendly",
            actor = actors.pet, friendly = friendly,
            friendlyKey = friendlyKey, guid = guid }
    end
    if friendly then
        return { kind = "ally", relation = "friendly",
            friendly = friendly, friendlyKey = friendlyKey, guid = guid }
    end
    local hostile, hostileKey = hostileByGuid(state, guid)
    if hostile then
        return { kind = "hostile", relation = "hostile",
            hostile = hostile, hostileKey = hostileKey, guid = guid }
    end
    return nil
end

local function healthOf(recipient)
    local record = recipient.hostile or recipient.friendly or recipient.actor
    if not record then return nil, nil, false end
    local exact = record.healthExact
    if exact == nil then exact = record.exact end
    return tonumber(record.health), tonumber(record.healthMax), exact == true
end

local function absorbNames(absorbs)
    local names, name, value = {}, nil, nil
    for name, value in pairs(absorbs or {}) do
        if name ~= "available" and (type(value) == "number"
            or type(value) == "table" and tonumber(value.amount)) then
            table.insert(names, name)
        end
    end
    table.sort(names)
    return names
end

local function consumeSet(absorbs, damage, castProbability, seen)
    local names, absorbed, partial = absorbNames(absorbs), 0, false
    local i, name, entry, amount, probability, used, conditionalUsed
    local hitRemaining, survival, expectedRemaining, remainingProbability
    for i = 1, table.getn(names) do
        name = names[i]
        if not seen[name] and damage > 0 then
            entry = absorbs[name]
            amount = type(entry) == "table" and tonumber(entry.amount)
                or tonumber(entry) or 0
            probability = type(entry) == "table"
                and tonumber(entry.applicationProbability) or 1
            probability = math.max(0, math.min(1, probability or 1))
            if probability > 0 then seen[name] = true end
            -- Keep the shield amount conditional on that shield existing. A
            -- 50%-likely hit that would consume it may consume only 50% of its
            -- projected amount; the no-hit branch still owns the other half.
            conditionalUsed = math.min(damage, amount)
            used = conditionalUsed * probability
            damage = math.max(0, damage - used)
            absorbed = absorbed + used * castProbability
            hitRemaining = math.max(0, amount - conditionalUsed)
            survival = 1 - castProbability
                + (hitRemaining > 0 and castProbability or 0)
            expectedRemaining = (1 - castProbability) * amount
                + castProbability * hitRemaining
            remainingProbability = probability * survival
            if survival > 0 then expectedRemaining = expectedRemaining / survival end
            if remainingProbability <= 0 or expectedRemaining <= 0 then
                absorbs[name] = nil
            elseif type(entry) == "table" then
                entry.amount = expectedRemaining
                entry.applicationProbability = remainingProbability
            else
                absorbs[name] = remainingProbability < 1
                    and { amount = expectedRemaining,
                        applicationProbability = remainingProbability }
                    or expectedRemaining
            end
            if probability < 1 or castProbability < 1 then partial = true end
        end
    end
    return damage, absorbed, partial
end

local function consumeAbsorbs(state, recipient, damage, castProbability)
    local seen, absorbed, partial = {}, 0, false
    if recipient.friendly then
        local used
        damage, used, partial = consumeSet(
            recipient.friendly.absorbs, damage, castProbability, seen)
        absorbed = absorbed + used
        if recipient.friendly.absorbs
            and recipient.friendly.absorbs.available == false then
            partial = true
        end
    elseif recipient.kind == "player" or recipient.kind == "pet" then
        -- A capped friendly snapshot can still resolve these through actors.
        -- That proves health identity, but not absence of live absorb auras.
        partial = true
    end
    if recipient.kind == "player" and state.absorbs then
        local used, rootPartial
        damage, used, rootPartial = consumeSet(
            state.absorbs, damage, castProbability, seen)
        absorbed, partial = absorbed + used, partial or rootPartial
    end
    return damage * castProbability, absorbed, partial
end

local function syncFriendlyCompatibility(state, recipient)
    local friendly = recipient.friendly
    if friendly and state.friendlies
        and state.friendlies.primaryKey == recipient.friendlyKey then
        state.healHealth, state.healMax = friendly.health, friendly.healthMax
    end
    if recipient.kind == "player" and recipient.actor then
        state.health, state.healthMax = recipient.actor.health,
            recipient.actor.healthMax
    end
end

local function setDead(record, health, exact)
    if type(record) ~= "table" then return end
    if not exact then
        record.dead, record.projectedDefeated = nil, nil
    elseif health <= 0 then
        record.dead, record.projectedDefeated = true, true
    else
        record.dead, record.projectedDefeated = false, nil
    end
end

local function setHealth(state, recipient, health, exact)
    if recipient.actor then
        recipient.actor.health = health
        recipient.actor.healthExact = exact and true or false
        setDead(recipient.actor, health, exact)
    end
    if recipient.friendly then
        recipient.friendly.health = health
        recipient.friendly.exact = exact and true or false
        setDead(recipient.friendly, health, exact)
    end
    if recipient.hostile then
        recipient.hostile.health = health
        recipient.hostile.healthExact = exact and true or false
        setDead(recipient.hostile, health, exact)
        if State and State.RefreshHostileRecord then
            State:RefreshHostileRecord(state, recipient.hostileKey)
        end
    end
    syncFriendlyCompatibility(state, recipient)
end

function I:ExpectedAmount(cast)
    local facts = cast and cast.consequence
    if not facts then return nil end
    local probability = math.max(0, math.min(1,
        tonumber(cast.probability) or 1))
    return math.max(0, tonumber(facts.amount) or 0) * probability
end

local function castProbability(cast)
    return math.max(0, math.min(1,
        tonumber(cast and cast.probability) or 1))
end

local function absorbsExact(recipient)
    if recipient.friendly then
        return recipient.friendly.absorbs
            and recipient.friendly.absorbs.available == true
    end
    if recipient.kind == "player" or recipient.kind == "pet" then return false end
    return true
end

function I:Preview(state, cast)
    local facts = cast and cast.consequence
    local guid = self:RecipientGuid(cast)
    local recipient = self:Resolve(state, guid)
    if not (facts and recipient) then
        return nil, facts and "exact recipient is not retained"
            or cast and cast.consequenceReason or "consequence unavailable"
    end
    local health, maximum, exact = healthOf(recipient)
    if health == nil or maximum == nil or maximum <= 0 then
        return nil, "recipient health is unavailable"
    end
    local probability = castProbability(cast)
    return { facts = facts, recipient = recipient, guid = guid,
        amount = self:ExpectedAmount(cast),
        rawAmount = math.max(0, tonumber(facts.amount) or 0),
        probability = probability, health = health,
        healthMax = maximum, healthExact = exact,
        absorbsExact = absorbsExact(recipient) }
end

function I:Apply(state, cast)
    local preview, reason = self:Preview(state, cast)
    if not preview then return nil, reason end
    local amount, health, exact = preview.amount, preview.health,
        preview.healthExact
    local estimated = preview.facts.estimated and true or false
    local uncertain = estimated or preview.probability < 1 or not exact
    local result = { kind = preview.facts.kind, amount = amount,
        recipient = preview.recipient.kind, recipientGuid = preview.guid,
        estimated = estimated, probability = preview.probability }
    if preview.facts.kind == "damage" then
        local residual, absorbed, partial = consumeAbsorbs(
            state, preview.recipient, preview.rawAmount, preview.probability)
        local after = math.max(0, health - residual)
        result.absorbed, result.effective = absorbed, health - after
        result.partial = partial or uncertain
        setHealth(state, preview.recipient, after, not result.partial)
        if result.partial then state.incomingProjectionPartial = true end
    elseif preview.facts.kind == "heal" then
        local after = math.min(preview.healthMax, health + amount)
        result.effective, result.partial = after - health, uncertain
        setHealth(state, preview.recipient, after, not result.partial)
        if result.partial then state.incomingProjectionPartial = true end
    else return nil, "unsupported consequence kind" end
    state.lastIncomingConsequence = result
    return result
end

function I:PreventedValue(state, cast)
    local preview, reason = self:Preview(state, cast)
    if not preview then return nil, reason end
    local amount, health, maximum = preview.amount, preview.health,
        preview.healthMax
    if preview.facts.kind == "damage" then
        if preview.recipient.relation == "hostile" then
            return -600, "cast would damage an enemy"
        end
        local effective = math.min(amount, health)
        local value = effective * 7 + amount / math.max(1, maximum) * 2400
        local lethal = preview.healthExact and preview.absorbsExact
            and not preview.facts.estimated
            and preview.probability >= 1 and preview.rawAmount >= health
        if lethal then value = value + 5000 end
        if preview.recipient.kind == "player" then value = value * 1.15 end
        return value, lethal and "prevents lethal incoming damage"
            or "prevents incoming damage"
    end
    if preview.recipient.relation ~= "hostile" then
        return -600, "cast would heal an ally"
    end
    local missing = math.max(0, maximum - health)
    local effective = math.min(amount, missing)
    return effective * 5 + effective / math.max(1, maximum) * 1200,
        effective > 0 and "prevents enemy healing" or "enemy healing has no value"
end
