-- Exact-recipient graph consequences for conservatively admitted hostile
-- spells. Live absorb amounts remain unknown unless this graph created them.
XelAssist.Graph.IncomingConsequences = {}
local I = XelAssist.Graph.IncomingConsequences
local State = XelAssist.Graph.State
local IncomingAbsorbs = XelAssist.Graph.IncomingAbsorbs
local PriestShadowform = XelAssist.Graph.PriestShadowform
local WarriorStances = XelAssist.Graph.WarriorStances
local WarriorShieldWall = XelAssist.Graph.WarriorShieldWall
local WarlockSoulLink = XelAssist.Graph.WarlockSoulLink

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
    local rawAmount = math.max(0, tonumber(facts.amount) or 0)
    if facts.kind == "damage" then
        local adjusted, adjustmentReason, handled
        if WarriorStances then
            adjusted, adjustmentReason, handled = WarriorStances:AdjustIncoming(
                state, recipient, rawAmount)
            if handled and adjusted == nil then return nil, adjustmentReason end
            if handled then rawAmount = adjusted end
        end
        if PriestShadowform then
            adjusted, adjustmentReason, handled = PriestShadowform:AdjustIncoming(
                state, recipient, rawAmount, facts.school)
            if handled and adjusted == nil then return nil, adjustmentReason end
            if handled then rawAmount = adjusted end
        end
        if WarriorShieldWall then
            adjusted, adjustmentReason, handled = WarriorShieldWall:AdjustIncoming(
                state, recipient, rawAmount, facts.school)
            if handled and adjusted == nil then return nil, adjustmentReason end
            if handled then rawAmount = adjusted end
        end
    end
    return { facts = facts, recipient = recipient, guid = guid,
        amount = rawAmount * probability, rawAmount = rawAmount,
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
        local residual, absorbed, partial = IncomingAbsorbs:Consume(state,
            preview.recipient, preview.rawAmount, preview.probability,
            preview.facts.school)
        if WarlockSoulLink and preview.recipient.kind == "player" then
            local split, plan, applied, splitReason =
                WarlockSoulLink:ApplyResidual(state, preview.recipient,
                    residual, not (partial or uncertain))
            residual = split
            if applied then
                result.soulLinkSplit = plan
                partial = partial or plan.exact ~= true
            elseif state.classMechanicClass == "WARLOCK" then
                local _, known = WarlockSoulLink:Active(state)
                if known == false then
                    partial = true
                    result.soulLinkReason = splitReason
                end
            end
        end
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
