-- Exact Octo Shadow Mend consequence. The live tooltip supplies the scaled
-- heal range; installed patch-5 identity supplies the 50% caster-health loss.
-- Maximum roll protects legality while the mean roll drives graph projection.
XelAssist.Graph.PriestShadowMend = {}
local M = XelAssist.Graph.PriestShadowMend
local State = XelAssist.Graph.State

local function playerRecord(state)
    return State and State:FriendlyByUnit(state, "player") or nil
end

local function playerGuid(state)
    local actor = state and state.actors and state.actors.player
    if actor and actor.guid ~= nil then return actor.guid end
    local record = playerRecord(state)
    return record and record.guid or nil
end

local function unknownIncoming(state, guid, within)
    local collection = state and state.hostileCasts
    local index, cast
    for index = 1, table.getn(collection and collection.order or {}) do
        cast = collection.byCaster[collection.order[index]]
        if cast and (tonumber(cast.remaining) or 0) <= within + 0.0001
            and cast.targetGuid == guid and not cast.consequence then
            return true
        end
    end
    return false
end

function M:Prepare(context)
    local facts = context and context.facts
    if not (facts and facts.shadowMend) then return true end
    local low = tonumber(context.tooltip and context.tooltip.low)
    local high = tonumber(context.tooltip and context.tooltip.high)
    local power = tonumber(context.power)
    local ratio = tonumber(facts.shadowMendSelfDamageRatio)
    if not (low and low > 0 and high and high >= low and power and power > 0
        and ratio and ratio > 0 and ratio < 1) then
        return nil, "Shadow Mend live heal range unavailable"
    end
    local guid = playerGuid(context.state)
    if guid == nil then return nil, "Shadow Mend caster identity unavailable" end
    local landing = math.max(0, tonumber(context.wait) or 0)
        + math.max(0, tonumber(context.cast) or 0)
    if unknownIncoming(context.state, guid, landing) then
        return nil, "Shadow Mend incoming caster damage unavailable"
    end
    local incoming, exact = 0, true
    local events = XelAssist.Graph.HostileCastEvents
    if events and events.IncomingDamage then
        incoming, exact = events:IncomingDamage(context.state, guid, landing)
    end
    if exact ~= true then
        return nil, "Shadow Mend incoming caster damage unavailable"
    end
    local maximumDamage = high * ratio
    local healthAtLanding = (tonumber(context.state.health) or 0)
        - math.max(0, tonumber(incoming) or 0)
    local record = playerRecord(context.state)
    local selfTarget = record and context.descriptor
        and (context.descriptor.record == record
            or context.descriptor.unit == "player"
            or context.descriptor.guid == record.guid)
    local minimumPost = healthAtLanding - maximumDamage
    if selfTarget then
        local maximumHealth = math.max(0,
            tonumber(context.state.healthMax) or 0)
        local lowPost = math.min(maximumHealth, healthAtLanding + low)
            - low * ratio
        local highPost = math.min(maximumHealth, healthAtLanding + high)
            - high * ratio
        minimumPost = math.min(lowPost, highPost)
    end
    if minimumPost <= 0 then
        return nil, "Shadow Mend could defeat the caster"
    end
    context.shadowMend = { expectedSelfDamage = power * ratio,
        maximumSelfDamage = maximumDamage, incomingDamage = incoming,
        healthAtLanding = healthAtLanding, minimumPostHealth = minimumPost,
        selfTarget = selfTarget and true or false,
        source = "installed Octo Shadow Mend description + live tooltip range" }
    return true
end

function M:Score(context)
    local plan = context and context.shadowMend
    if not plan then return false end
    local healthMax = math.max(1, tonumber(context.state.healthMax) or 0)
    local post = plan.healthAtLanding - plan.expectedSelfDamage
    local risk = plan.expectedSelfDamage / healthMax * 900
    if post / healthMax < 0.35 then
        risk = risk + (0.35 - post / healthMax) * 3000
    end
    if context.state.hasAggro and not context.state.tank then
        risk = risk * 1.2
    end
    if plan.selfTarget then
        context.effectivePower = math.max(0,
            (tonumber(context.effectivePower) or 0)
                - plan.expectedSelfDamage)
    end
    context.value = context.value - risk
    if not (context.healingTriage and context.healingTriage.savesRecipient) then
        context.reason = plan.selfTarget
            and "heals after its exact self-damage cost"
            or "heals an ally with a safe self-damage cost"
    end
    return true
end

function M:Apply(state, candidate)
    local plan = candidate and candidate.shadowMend
    if not plan then return false end
    local damage = math.max(0, tonumber(plan.expectedSelfDamage) or 0)
    local record = playerRecord(state)
    if record then
        record.health = math.max(0, (tonumber(record.health) or 0) - damage)
        record.dead = record.health <= 0 or nil
        record.projectedDefeated = record.dead and true or nil
    end
    state.health = math.max(0, (tonumber(state.health) or 0) - damage)
    local actor = state.actors and state.actors.player
    if actor and actor.health ~= nil then
        actor.health = math.max(0, (tonumber(actor.health) or 0) - damage)
    end
    return true
end
