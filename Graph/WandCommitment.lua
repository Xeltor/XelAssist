-- Sustained wanding is a graph commitment, not repeated instant Shoot casts.
-- Continuing the next swing and clipping the repeat with another player action
-- remain competing branches.
XelAssist.Graph.WandCommitment = {}
local W = XelAssist.Graph.WandCommitment
local State = XelAssist.Graph.State
local HostileEffects = XelAssist.Graph.HostileEffects

local ACTION = { name = "Continue Shoot", rank = 0, actor = "player",
    executor = "instruction", facts = { kind = "wandContinuation",
        wandContinuation = true, gcd = 0 } }
local DAMAGE_FACTS = { kind = "damage" }
local DAMAGE_ACTION = { name = "Wand shot", actor = "player",
    facts = DAMAGE_FACTS }

local function actionFacts(state, action)
    local root = XelAssist.Graph.RootObservation
    if root and root.Facts then
        local facts, status = root:Facts(state, action)
        if status == "known" then return facts end
        if status ~= "absent" then return {} end
    end
    return XelAssist.Game.Actors:Facts(action) or {}
end

local function sameTarget(state, wand)
    return state.hostile and wand.targetGuid ~= nil
        and wand.targetGuid == state.targetGUID
end

local function canContinue(state, wand)
    if state.moving or state.playerCasting then return false end
    local tooltip = wand.tooltip or {}
    local minimum = math.max(0, tonumber(tooltip.minRange) or 0)
    local maximum = tonumber(tooltip.maxRange)
    if minimum > 0 or maximum then
        local distance = tonumber(state.targetDistance)
        if distance == nil then return false end
        if distance < minimum or maximum and distance > maximum then
            return false
        end
    end
    return true
end

function W:Prepare(state, actions)
    local wand = state and state.wand
    if not wand then return end
    state.manaOpportunityWandAvailable = nil
    local i, action
    for i = 1, table.getn(actions or {}) do
        if actions[i].facts and actions[i].facts.wandRepeat then
            action = actions[i]
            break
        end
    end
    if action then
        wand.action = action
        wand.tooltip = actionFacts(state, action)
        state.manaOpportunityWandAvailable = wand.activeKnown == true
            and (tonumber(wand.damage) or 0) > 0
            and (tonumber(wand.speed) or 0) > 0 and true or nil
    end
end

local function expectedDamage(state, wand)
    local raw = math.max(0, tonumber(wand.damage) or 0)
    local action, tooltip = wand.action, wand.tooltip or {}
    if not (action and XelAssist.Combat.Resistance) then return raw, 1 end
    local estimate = XelAssist.Combat.Resistance:Estimate(
        action, "target", tooltip, state)
    if not estimate then return raw, 1 end
    local decision = XelAssist.Graph.Effects:Decision(estimate, state, true)
    return raw * (tonumber(decision) or 1), tonumber(decision) or 1
end

local function scoreDamageThreat(state, power, value, reason)
    local context = { state = state, action = DAMAGE_ACTION,
        facts = DAMAGE_FACTS, kind = "damage", power = power,
        expectedPower = power, effectivePower = power, cost = 0,
        value = value, reason = reason, estimated = false }
    local scoring = XelAssist.Graph.ThreatScoring
    if scoring then scoring:Apply(context) end
    return context.value, context.threat or power, context.reason,
        context.estimated, context.playerThreatExact,
        context.playerThreatMultiplier
end

function W:Candidate(state)
    local wand = state and state.wand
    if not (wand and wand.active and sameTarget(state, wand)
        and canContinue(state, wand)) then return nil end
    local speed = math.max(0.5, tonumber(wand.speed) or 2)
    local wait = math.max(0.05, tonumber(wand.nextShotIn) or speed)
    local power, delivery = expectedDamage(state, wand)
    local finishes = state.targetHealthExact
        and (tonumber(state.targetHealth) or 0) > 0
        and power >= (tonumber(state.targetHealth) or 0)
    if state.targetHealthExact then
        power = math.min(power, math.max(0, tonumber(state.targetHealth) or 0))
    end
    local value, threat, reason, estimated, threatExact, threatMultiplier =
        scoreDamageThreat(state, power,
        power * 4 / speed + (finishes and 700 or 0),
        finishes and "finishes the target with the next wand shot"
            or "continues sustained wand attacks without spending mana")
    return { action = ACTION, value = value, reason = reason,
        target = "target", targetKey = state.targetGUID,
        targetGUID = state.targetGUID, targetRelation = "hostile",
        targetSource = "active wand repeat", cost = 0, costKnown = true,
        cast = 0, wait = wait, occupancy = 0,
        downtime = wait, valueDowntime = speed,
        gcd = 0, normalGcd = false,
        tooltip = { cost = 0, cast = 0, gcd = 0,
            source = "active wand repeat" },
        power = power, rawPower = tonumber(wand.damage) or 0,
        effectivePower = power, expectedPower = power,
        effectDelivery = delivery, threat = threat,
        estimated = estimated, playerThreatExact = threatExact,
        playerThreatMultiplier = threatMultiplier,
        wandCommitment = wand }
end

function W:Apply(out, candidate)
    local action = candidate and candidate.action
    if not (action and action.facts and action.facts.wandContinuation) then
        return false
    end
    local applied, dealt = HostileEffects:ApplySelectedDamage(
        out, math.max(0, tonumber(candidate.power) or 0))
    if applied and dealt and HostileEffects.ApplyPrimaryThreat then
        HostileEffects:ApplyPrimaryThreat(out, candidate, {
            action = DAMAGE_ACTION, facts = DAMAGE_FACTS,
            appliedHostileDamage = dealt })
    end
    if out.wand then
        out.wand.active = out.hostile and true or false
        out.wand.activeKnown = true
        out.wand.nextShotIn = math.max(0.5,
            tonumber(out.wand.speed) or 2)
    end
    return true
end

function W:AfterAction(out, candidate)
    local wand, action = out and out.wand, candidate and candidate.action
    if not (wand and wand.active and action) then return end
    local facts = action.facts or {}
    if facts.wandContinuation or facts.wandRepeat
        or (action.actor or "player") == "pet" then return end
    wand.active, wand.activeKnown = false, true
    wand.stopReason = facts.movementSetup
        and "movement cancels wand repeat" or "player action cancels wand repeat"
end

function W:Advance(state, elapsed)
    local wand = state and state.wand
    if not (wand and wand.active) then return end
    wand.nextShotIn = math.max(0,
        (tonumber(wand.nextShotIn) or tonumber(wand.speed) or 2)
            - math.max(0, tonumber(elapsed) or 0))
end
