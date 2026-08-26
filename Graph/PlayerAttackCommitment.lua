-- A running melee auto-attack is a useful graph edge, not an empty horizon.
-- This instruction advances exact main-hand rounds until either the next
-- learned rage threshold or the target's predicted death. It never presses a
-- client button, so repeated macro input remains harmless while rage builds.
XelAssist.Graph.PlayerAttackCommitment = {}
local C = XelAssist.Graph.PlayerAttackCommitment
local Targets = XelAssist.Graph.CompanionTargets
local Swings = XelAssist.Graph.PlayerSwings
local Rage = XelAssist.Graph.PlayerRage
local PlayerThreat = XelAssist.Graph.PlayerThreat

local ACTION = { name = "Continue Attack", rank = 0, actor = "player",
    executor = "instruction", texture = "Interface\\Icons\\Ability_MeleeDamage",
    facts = { kind = "playerAttackContinuation",
        playerAttackContinuation = true, gcd = 0 } }
local function actionFacts(state, action)
    local root = XelAssist.Graph.RootObservation
    if root and root.Facts then
        local facts, status = root:Facts(state, action)
        if status == "known" then return facts end
        if status ~= "absent" then return {} end
    end
    return XelAssist.Game.Actors:Facts(action) or {}
end

local function insertCost(out, cost)
    local i
    for i = 1, table.getn(out) do
        if out[i] == cost then return end
        if out[i] > cost then table.insert(out, i, cost); return end
    end
    table.insert(out, cost)
end

function C:Prepare(state, actions)
    local attack = state and state.playerAttack
    if not attack then return end
    attack.rageCosts = nil
    if not (Rage and Rage:Is(state)) then return end
    local costs, i = {}, nil
    for i = 1, table.getn(actions or {}) do
        local action = actions[i]
        if (action.actor or "player") == "player"
            and action.executor ~= "instruction"
            and not (action.facts and action.facts.playerAttack) then
            local tooltip = actionFacts(state, action)
            local cost = tonumber(tooltip.cost)
            if cost and cost > 0
                and cost <= (tonumber(state.resourceMax) or cost) then
                insertCost(costs, cost)
            end
        end
    end
    if table.getn(costs) > 0 then attack.rageCosts = costs end
end

local function geometry(state, record)
    local observed = record and record.geometry and record.geometry.player
    if not observed then
        observed = { distance = state.targetDistance,
            distanceKind = state.targetDistanceKind }
    end
    local distance = tonumber(observed.distance)
    local kind = observed.distanceKind or observed.source
    return distance and distance <= 5
        and (kind == "hitbox" or kind == "combat reach")
end

local function selected(state, round)
    if not (state.hostile and round.targetGuid == state.targetGUID) then
        return nil, nil
    end
    local key, record = Targets:ForGuid(state, round.targetGuid)
    if Targets:Hostiles(state) then
        if not key or Targets:ProvenDead(record) then return nil, nil end
        return key, record
    end
    if state.targetHealthExact and (tonumber(state.targetHealth) or 0) <= 0 then
        return nil, nil
    end
    return state.targetGUID, nil
end

local function nextCost(state, attack)
    local available = math.max(0, (tonumber(state.resource) or 0)
        - (tonumber(state.playerResourceReserved) or 0))
    local i
    for i = 1, table.getn(attack.rageCosts or {}) do
        if attack.rageCosts[i] > available then return attack.rageCosts[i] end
    end
    return nil
end

function C:Candidate(state)
    local attack = state and state.playerAttack
    local round = attack and attack.attackRound
    if not (attack and attack.activeKnown == true and attack.active == true
        and round and round.projectable and round.phaseKnown
        and round.verified and round.normalDamageKnown == true
        and tonumber(round.power) and tonumber(round.interval)) then return nil end
    local key, record = selected(state, round)
    if not key or not geometry(state, record) then return nil end
    local perHit, delivery = Swings:ExpectedWhite(state, round.targetGuid)
    if not perHit or perHit <= 0 then return nil end
    local first = Swings:ImpactDelay(state)
    if not first then return nil end
    local count, threshold, pending = 1, nextCost(state, attack), attack.onSwing
    local pendingRound = pending and pending.occupied
    if not pendingRound and not threshold then return nil end
    local ragePerHit = Rage and Rage:FromOutgoingDamage(state, perHit) or 0
    if not pendingRound and threshold and ragePerHit > 0 then
        local available = math.max(0, (tonumber(state.resource) or 0)
            - (tonumber(state.playerResourceReserved) or 0))
        count = math.max(1, math.ceil((threshold - available) / ragePerHit))
        count = math.min(8, count)
    end
    local health = record and tonumber(record.health)
        or tonumber(state.targetHealth)
    local healthExact = record and record.healthExact == true
        or not record and state.targetHealthExact == true
    local finishes = false
    if healthExact and health and health > 0 then
        local lethal = math.max(1, math.ceil(health / perHit))
        if lethal <= count then count, finishes = lethal, true end
    end
    local interval = math.max(0.1, tonumber(round.interval) or 0.1)
    local wait = first + math.max(0, count - 1) * interval
    local power = perHit * count
    if healthExact and health then power = math.min(power, health) end
    local reason = finishes and "finishes the target with sustained melee attacks"
        or "continues sustained melee attacks"
    if pendingRound then
        reason = "waits for the armed melee attack to resolve"
    elseif threshold and not finishes then
        reason = "continues melee attacks toward " .. tostring(threshold) .. " rage"
    end
    local ref = record and record.targetRef or state.targetRef
    local threat, threatExact, threatMultiplier = power, true, 1
    if PlayerThreat then
        threat, threatExact, threatMultiplier =
            PlayerThreat:Scale(state, "player", power, 0)
    end
    return { action = ACTION, value = 0.01, reason = reason,
        target = "target", targetKey = key, targetGUID = round.targetGuid,
        targetRelation = "hostile", targetSource = "active melee attack",
        targetRef = ref, cost = 0, costKnown = true,
        cast = 0, wait = wait, occupancy = 0, downtime = wait,
        valueDowntime = wait, actionStart = (tonumber(state.time) or 0) + wait,
        gcd = 0, normalGcd = false,
        tooltip = { cost = 0, cast = 0, gcd = 0,
            source = Rage and Rage:Is(state)
                and "exact main-hand clock; estimated rage"
                or "exact player main-hand clock" },
        power = power, rawPower = tonumber(round.power) * count,
        effectivePower = power, expectedPower = power,
        effectDelivery = delivery, threat = threat,
        playerThreatExact = threatExact,
        playerThreatMultiplier = threatMultiplier,
        estimated = Rage and Rage:Is(state) or threatExact == false,
        projectedRage = ragePerHit * count,
        playerAttackCommitment = true }
end
