-- Frozen direct-heal triage. The caller captures exact recipient health,
-- resource, action timing and certain incoming-damage events before graph
-- search. This module performs no live reads and encodes no class, spell name,
-- rank order, or rotation: each action/recipient edge is valued from evidence.
XelAssist.Graph.HealingTriage = {}
local H = XelAssist.Graph.HealingTriage

H.MAX_ACTIONS = 24
H.MAX_RECIPIENTS = 8
H.MAX_EVENTS = 24
H.STABILITY_WINDOW = 2
H.BASE_HEALING_THREAT = 0.5

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

-- Evidence lists are deliberately dense and bounded. A sparse capture could
-- otherwise hide a later lethal event behind Lua's array boundary.
local function listCount(values, maximum)
    if type(values) ~= "table" then return nil end
    local count, highest, key = 0, 0, nil
    for key in pairs(values) do
        if type(key) ~= "number" or key < 1 or key ~= math.floor(key) then
            return nil
        end
        count = count + 1
        if key > highest then highest = key end
        if highest > maximum or count > maximum then return nil end
    end
    if count ~= highest then return nil end
    return count
end

local function actionEvidence(action, state)
    if type(action) ~= "table" or action.kind ~= "heal"
        or action.delivery ~= "direct" then
        return nil, "unsupported healing action"
    end
    if action.powerKnown ~= true or action.costKnown ~= true
        or action.timingKnown ~= true then
        return nil, "heal evidence unavailable"
    end
    local actionKey = action.actionKey or action.spellId or action.key
    local power, cost = nonnegative(action.power), nonnegative(action.cost)
    local guaranteed = nonnegative(action.guaranteedPower)
    local guaranteedKnown = action.guaranteedPowerKnown == true
    local cast, wait = nonnegative(action.cast), nonnegative(action.wait or 0)
    local gcd = nonnegative(action.gcd or 0)
    local now = nonnegative(state and state.time)
    if not validKey(actionKey) or not power or power <= 0 or cost == nil
        or cast == nil or wait == nil or gcd == nil or now == nil
        or guaranteedKnown and guaranteed == nil
        or guaranteed ~= nil and guaranteed > power then
        return nil, "heal evidence unavailable"
    end

    local resource = nonnegative(state and state.resource)
    local resourceExact = state and (state.resourceExact == true
        or state.playerResourceExact == true)
    if cost > 0 and (not resourceExact or resource == nil) then
        return nil, "healing resource evidence unavailable"
    end
    if resource ~= nil and cost > resource then
        return nil, "insufficient healing resource"
    end

    local threatFactor = H.BASE_HEALING_THREAT
    if action.healingThreatFactor ~= nil then
        threatFactor = nonnegative(action.healingThreatFactor)
        if threatFactor == nil then return nil, "healing threat evidence unavailable" end
    end
    local threatActor = action.healingThreatActor or action.actor or "player"
    if type(threatActor) ~= "string" or threatActor == "" then
        return nil, "healing threat evidence unavailable"
    end

    local startsAt = now + wait
    local landsAt = startsAt + cast
    local readyAt = startsAt + math.max(cast, gcd)
    return { actionKey = actionKey, power = power,
        guaranteedPower = guaranteedKnown and guaranteed or nil,
        guaranteedPowerKnown = guaranteedKnown,
        cost = cost,
        cast = cast, wait = wait, gcd = gcd, now = now,
        startsAt = startsAt, landsAt = landsAt, readyAt = readyAt,
        occupancy = readyAt - now, resource = resource,
        resourceAfter = resource and math.max(0, resource - cost) or nil,
        threatActor = threatActor, threatFactor = threatFactor }, nil
end

local function recipientEvidence(recipient, now)
    local health = nonnegative(recipient and recipient.health)
    local maximum = nonnegative(recipient and recipient.healthMax)
    local healthAt = nonnegative(recipient and recipient.healthAt)
    if type(recipient) ~= "table" or not validKey(recipient.key)
        or not validGuid(recipient.guid) or recipient.healthExact ~= true
        or recipient.dead == true or health == nil or maximum == nil
        or maximum <= 0 or health > maximum or healthAt == nil
        or healthAt > now or recipient.incomingKnown ~= true
        or recipient.incomingFrozen ~= true then
        return nil, "recipient evidence unavailable"
    end
    return { key = recipient.key, guid = recipient.guid, health = health,
        healthMax = maximum, healthAt = healthAt }, nil
end

local function sortedEvents(recipient, target)
    local total = listCount(recipient.incoming, H.MAX_EVENTS)
    if total == nil then
        return nil, type(recipient.incoming) == "table"
            and "incoming event budget or shape invalid"
            or "incoming event evidence unavailable"
    end
    local out, seen, index = {}, {}, nil
    for index = 1, total do
        local event = recipient.incoming[index]
        local at = type(event) == "table" and nonnegative(event.at) or nil
        local damage = type(event) == "table"
            and nonnegative(event.damage) or nil
        local id = type(event) == "table" and event.id or nil
        if type(event) ~= "table" or not validKey(id) or seen[id]
            or event.kind ~= "damage" or event.exact ~= true
            or event.frozen ~= true or tonumber(event.probability) ~= 1
            or event.recipientGUID ~= target.guid or at == nil
            or at < target.healthAt or damage == nil then
            return nil, "incoming event evidence unavailable"
        end
        seen[id] = true
        table.insert(out, { id = id, at = at, damage = damage,
            order = index, recipientGUID = target.guid })
    end
    table.sort(out, function(left, right)
        if left.at ~= right.at then return left.at < right.at end
        return left.order < right.order
    end)
    return out, nil
end

local function applyThrough(events, index, through, health)
    while index <= table.getn(events)
        and events[index].at <= through do
        health = health - events[index].damage
        index = index + 1
    end
    return health, index
end

function H:Plan(action, recipient, state)
    local actionPlan, reason = actionEvidence(action, state)
    if not actionPlan then return nil, reason end
    local target
    target, reason = recipientEvidence(recipient, actionPlan.now)
    if not target then return nil, reason end
    local events
    events, reason = sortedEvents(recipient, target)
    if not events then return nil, reason end

    local health, index = applyThrough(events, 1,
        actionPlan.landsAt, target.health)
    if health <= 0 then return nil, "recipient dies before heal lands" end

    local landingHealth = health
    local missing = math.max(0, target.healthMax - landingHealth)
    local effective = math.min(actionPlan.power, missing)
    if effective <= EPSILON then return nil, "no effective healing" end
    local after = landingHealth + effective
    local guaranteedEffective = actionPlan.guaranteedPowerKnown
        and math.min(actionPlan.guaranteedPower, missing) or nil
    local guaranteedAfter = guaranteedEffective
        and landingHealth + guaranteedEffective or nil

    local withoutHeal, withHeal = landingHealth, after
    local withGuaranteed = guaranteedAfter
    local cumulative, maximumCumulative = 0, 0
    local withoutDies, withSurvives = false, true
    local windowEndsAt = actionPlan.landsAt + H.STABILITY_WINDOW
    while index <= table.getn(events)
        and events[index].at <= windowEndsAt do
        local damage = events[index].damage
        cumulative = cumulative + damage
        maximumCumulative = math.max(maximumCumulative, cumulative)
        withoutHeal, withHeal = withoutHeal - damage, withHeal - damage
        if withGuaranteed ~= nil then withGuaranteed = withGuaranteed - damage end
        if withoutHeal <= 0 then withoutDies = true end
        if withHeal <= 0 then withSurvives = false end
        index = index + 1
    end

    local guaranteedSurvives = withGuaranteed ~= nil and withGuaranteed > 0
    local saves = withoutDies and guaranteedSurvives
    local survivalRequired = math.max(0,
        maximumCumulative - landingHealth + 1)
    local stabilizing = saves and math.min(effective,
        math.max(1, survivalRequired)) or effective
    local surplus = math.max(0, effective - stabilizing)
    local overheal = math.max(0, actionPlan.power - effective)
    local efficiency = effective / math.max(1, actionPlan.cost)
    local healingThreat = effective * actionPlan.threatFactor

    -- Only scalar evidence is retained. Mutating capture tables after this
    -- point cannot alter a queued candidate or its causal threat amount.
    return { actionKey = actionPlan.actionKey, recipient = target.key,
        recipientGUID = target.guid, rawHealing = actionPlan.power,
        effectiveHealing = effective, overheal = overheal,
        guaranteedHealing = guaranteedEffective,
        guaranteedHealingKnown = actionPlan.guaranteedPowerKnown,
        guaranteedProjectedHealth = withGuaranteed
            and math.max(0, withGuaranteed) or nil,
        efficiency = efficiency, savesRecipient = saves,
        deathSaveUnproven = withoutDies and not saves and true or false,
        stabilizingHealing = stabilizing, surplusHealing = surplus,
        landingHealth = landingHealth,
        projectedHealth = math.max(0, withHeal),
        startsAt = actionPlan.startsAt, landsAt = actionPlan.landsAt,
        readyAt = actionPlan.readyAt, occupancy = actionPlan.occupancy,
        cost = actionPlan.cost, resourceAfter = actionPlan.resourceAfter,
        healingThreat = healingThreat,
        healingThreatActor = actionPlan.threatActor,
        threatFactor = actionPlan.threatFactor,
        incomingEvents = table.getn(events),
        healthEvidenceAt = target.healthAt,
        stabilityWindowEndsAt = windowEndsAt, frozen = true,
        source = "exact recipient and frozen incoming-event projection" }, nil
end

function H:Value(plan)
    if type(plan) ~= "table" or plan.frozen ~= true then return nil end
    local valuable = plan.stabilizingHealing * 4
        + plan.surplusHealing * (plan.savesRecipient and 0.25 or 4)
    return valuable / math.max(0.5, plan.occupancy)
        + plan.efficiency * 160 - plan.overheal * 2
        - plan.cost * 0.25 + (plan.savesRecipient and 5000 or 0)
end

function H:Score(action, recipient, state)
    local plan, reason = self:Plan(action, recipient, state)
    if not plan then return nil, reason end
    plan.value = self:Value(plan)
    plan.reason = plan.savesRecipient and "prevents proven recipient death"
        or plan.deathSaveUnproven
            and "minimum healing cannot prove survival"
        or plan.overheal > plan.effectiveHealing * 0.35
            and "limits overheal and resource waste"
            or "effective healing per resource"
    return plan, nil
end

local function better(left, right)
    if not right then return true end
    if math.abs(left.value - right.value) > EPSILON then
        return left.value > right.value
    end
    if left.savesRecipient ~= right.savesRecipient then
        return left.savesRecipient
    end
    if left.cost ~= right.cost then return left.cost < right.cost end
    if left.landsAt ~= right.landsAt then return left.landsAt < right.landsAt end
    if tostring(left.recipientGUID) ~= tostring(right.recipientGUID) then
        return tostring(left.recipientGUID) < tostring(right.recipientGUID)
    end
    return tostring(left.actionKey) < tostring(right.actionKey)
end

function H:Best(actions, recipients, state)
    local actionCount = listCount(actions, self.MAX_ACTIONS)
    local recipientCount = listCount(recipients, self.MAX_RECIPIENTS)
    if actionCount == nil or recipientCount == nil then
        return nil, "healing triage budget or shape invalid"
    end
    local best, firstReason, actionIndex, recipientIndex
    for actionIndex = 1, actionCount do
        for recipientIndex = 1, recipientCount do
            local scored, reason = self:Score(actions[actionIndex],
                recipients[recipientIndex], state)
            if not scored then firstReason = firstReason or reason
            elseif better(scored, best) then
                best = scored
                best.actionIndex, best.recipientIndex = actionIndex, recipientIndex
            end
        end
    end
    if best then return best, nil end
    return nil, firstReason or "no exact effective heal"
end
