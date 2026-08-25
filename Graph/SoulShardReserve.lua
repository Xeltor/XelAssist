-- Marginal Soul Shard stock value. Drain Soul remains an ordinary discovered
-- damage channel; this module adds value only when live evidence predicts a
-- valid kill during the channel and this character is below its reserve.
XelAssist.Graph.SoulShardReserve = {}
local R = XelAssist.Graph.SoulShardReserve
local Shards = XelAssist.Game.SoulShards

R.MIN_GENERATION_CHANCE = 0.60
R.FULL_RESERVE_PENALTY = 4200
R.BASE_SHARD_VALUE = 900

local function clamp(value)
    return math.max(0, math.min(1, tonumber(value) or 0))
end

local function aliveAt(time, lower, upper)
    if time <= lower then return 1 end
    if time >= upper then return 0 end
    return 1 - (time - lower) / math.max(0.001, upper - lower)
end

function R:Relevant(actions)
    local i
    for i = 1, table.getn(actions or {}) do
        local action = actions[i]
        local facts = action and action.facts or {}
        if Shards:IsGenerator(action)
            or facts.reagentName == Shards.REAGENT_NAME then return true end
    end
    return false
end

local function targetEligibility(state, descriptor)
    local root = XelAssist.Graph.RootObservation
    if root then
        local observed, status = root:Target(state, descriptor)
        if status == "known" then
            return Shards:TargetEligibility(state, descriptor, observed)
        end
        if status ~= "absent" then return false,
            "target tap evidence unavailable" end
    end
    return Shards:TargetEligibility(state, descriptor)
end

function R:Prepare(state)
    state.soulShards = Shards:Snapshot(state.inventory)
    state.soulShards.targets = {}
    local hostiles = state.hostiles
    if hostiles and hostiles.byKey then
        local i, key, record
        for i = 1, table.getn(hostiles.order or {}) do
            key, record = hostiles.order[i], hostiles.byKey[hostiles.order[i]]
            if record then
                local descriptor = { unit = record.unit, relation = "hostile",
                    key = key, guid = record.guid, record = record }
                local eligible, reason = targetEligibility(state, descriptor)
                state.soulShards.targets[key] = {
                    eligible = eligible, reason = reason }
            end
        end
    end
    return state.soulShards
end

local function eligibility(state, descriptor)
    local ledger = state.soulShards
    local key = descriptor and descriptor.key
    local cached = ledger and ledger.targets and key ~= nil
        and ledger.targets[key] or nil
    if cached then return cached.eligible, cached.reason end
    return targetEligibility(state, descriptor)
end

local function forecast(context, health, wait, duration)
    local learned = context.state.targetSurvival
    if type(learned) ~= "table" or learned.available ~= true
        or learned.confidence ~= "observed" then return 0, 1 end
    local rate = tonumber(learned.incomingDps)
    local base = tonumber(learned.timeToDie)
    if not rate or rate <= 0 or not base or base <= 0 then return 0, 1 end
    local current = health / rate
    local lower = current * math.max(0,
        (tonumber(learned.lowerTimeToDie) or base) / base)
    local upper = current * math.max(0,
        (tonumber(learned.upperTimeToDie) or base) / base)
    upper = math.max(lower, upper)
    local aliveStart = aliveAt(wait, lower, upper)
    return math.max(0, aliveStart
        - aliveAt(wait + duration, lower, upper)), aliveStart
end

local function ownKill(context, health, wait, duration)
    local learned = context.state.targetSurvival
    local rate = type(learned) == "table"
        and tonumber(learned.incomingDps) or 0
    local startHealth = health - math.max(0, rate or 0) * wait
    if startHealth <= 0 then return 0, false end
    local delivery = clamp(context.effectDelivery or 1)
    local output = math.max(0, tonumber(context.power) or 0) * delivery
    if output < startHealth or duration <= 0 then return 0, false end
    local certainty = context.estimated and 0.75 or 1
    local chance = delivery * certainty
    local guaranteed = certainty == 1 and delivery >= 0.999
    return chance, guaranteed
end

function R:Opportunity(context)
    local action, state = context.action, context.state
    if not Shards:IsGenerator(action) then return nil end
    local ledger = state and state.soulShards
    local out = { generator = true, chance = 0,
        reserve = ledger and ledger.reserve or Shards:Reserve(),
        count = ledger and ledger.expected or nil }
    if not ledger or ledger.known ~= true or ledger.expected == nil then
        out.reason = "Soul Shard count unavailable"
        return out
    end
    local eligible, reason = eligibility(state, context.descriptor)
    out.targetEligible, out.targetReason = eligible, reason
    if not eligible then out.reason = reason; return out end
    if not state.targetHealthExact then
        out.reason = "exact target health unavailable"
        return out
    end
    local health = tonumber(state.targetHealth)
    local duration = math.max(0, tonumber(context.cast) or 0)
    local wait = math.max(0, tonumber(context.wait) or 0)
    if not health or health <= 0 or duration <= 0
        or not (action.facts and action.facts.channel) then
        out.reason = "full channel death window unavailable"
        return out
    end
    local observedChance, aliveStart = forecast(context, health, wait, duration)
    local actionChance, guaranteed = ownKill(context, health, wait, duration)
    out.chance = math.max(observedChance, actionChance)
    out.aliveAtStart = aliveStart
    out.guaranteed = guaranteed
    out.sufficient = aliveStart >= self.MIN_GENERATION_CHANCE
        and out.chance >= self.MIN_GENERATION_CHANCE
    out.reason = out.sufficient and "target death is likely during the channel"
        or "target death during the channel is not sufficiently proven"
    return out
end

function R:Score(context)
    local facts = context.action and context.action.facts or {}
    if facts.reagentName == Shards.REAGENT_NAME
        and not Shards:IsGenerator(context.action) then
        local ledger = context.state and context.state.soulShards
        if not ledger or ledger.known ~= true then return false end
        local reserve = math.max(0, tonumber(ledger.reserve) or 0)
        local count = math.max(0, tonumber(ledger.expected) or 0)
        local after = math.max(0, count - 1)
        if after < reserve then
            local scarcity = reserve > 0 and (reserve - after) / reserve or 0
            local stockCost = self.BASE_SHARD_VALUE * (1 + scarcity)
            context.value = (tonumber(context.value) or 0) - stockCost
            context.soulShardStockCost = stockCost
        end
        return true
    end
    local opportunity = self:Opportunity(context)
    if not opportunity then return false end
    context.soulShardOpportunity = opportunity
    if not opportunity.sufficient then return false end
    local reserve = math.max(0, tonumber(opportunity.reserve) or 0)
    local count = math.max(0, tonumber(opportunity.count) or 0)
    local deficit = math.max(0, reserve - count)
    if deficit > 0 then
        local urgency = reserve > 0 and deficit / reserve or 0
        local stockValue = opportunity.chance * self.BASE_SHARD_VALUE
            * (1 + urgency)
        context.value = (tonumber(context.value) or 0) + stockValue
        context.soulShardStockValue = stockValue
        context.reason = "banks a needed Soul Shard ("
            .. tostring(math.floor(count + 0.001)) .. "/"
            .. tostring(reserve) .. ")"
    else
        local penalty = opportunity.chance * self.FULL_RESERVE_PENALTY
        context.value = (tonumber(context.value) or 0) - penalty
        context.soulShardStockValue = 0
        context.soulShardOvercapPenalty = penalty
        context.reason = "Soul Shard reserve already satisfied"
    end
    return true
end

local function inventoryCount(state, fallback)
    local reagents = state.inventory and state.inventory.reagentCounts
    local count = reagents and tonumber(reagents[Shards.REAGENT_NAME])
    return count ~= nil and math.max(0, count) or fallback
end

function R:Apply(out, candidate)
    local prior = out.soulShards
    if not prior then return false end
    local ledger, key, value = {}, nil, nil
    for key, value in pairs(prior) do ledger[key] = value end
    ledger.targets = prior.targets
    local actual = inventoryCount(out, tonumber(prior.actual) or 0)
    local expected = math.max(0, (tonumber(prior.expected) or actual)
        + actual - (tonumber(prior.actual) or actual))
    local facts = candidate.action and candidate.action.facts or {}
    if facts.reagentName == Shards.REAGENT_NAME then
        -- ActionConsumption has already changed the exact inventory count.
        expected = math.max(actual, expected)
    end
    local opportunity = candidate.soulShardOpportunity
    if Shards:IsGenerator(candidate.action) and opportunity
        and opportunity.sufficient and expected < ledger.reserve then
        local chance = clamp(opportunity.chance)
        expected = math.min(ledger.reserve, expected + chance)
        if opportunity.guaranteed and out.targetHealthExact
            and (tonumber(out.targetHealth) or 1) <= 0 then
            actual = math.min(ledger.reserve, actual + 1)
            expected = math.max(expected, actual)
            if out.inventory then
                out.inventory.reagentCounts = out.inventory.reagentCounts or {}
                out.inventory.reagentCounts[Shards.REAGENT_NAME] = actual
            end
        end
    end
    ledger.actual, ledger.expected = actual, expected
    ledger.deficit = math.max(0, (tonumber(ledger.reserve) or 0) - expected)
    out.soulShards = ledger
    return true
end
