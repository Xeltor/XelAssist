-- Consequence-only Rogue combo investment.  The candidate set already proves
-- which builders and direct finishers are legal on this hostile.  Compare the
-- repeatable damage cycle at the current point count with the same cycle after
-- one more mechanically discovered builder; no spell name or spend threshold
-- participates in the decision.
XelAssist.Graph.RogueComboInvestment = {}
local R = XelAssist.Graph.RogueComboInvestment

local MAX_COMBO = 5
local ROGUE_FAMILY = 8
local ENERGY = 3
local EPSILON = 0.000001

local function facts(candidate)
    return candidate and candidate.action and candidate.action.facts or {}
end

local function tooltip(candidate)
    return candidate and candidate.tooltip or {}
end

local function rogueFamily(candidate)
    return tonumber(tooltip(candidate).spellFamilyName) == ROGUE_FAMILY
end

local function actorIsPlayer(candidate)
    local action = candidate and candidate.action
    return action and (action.actor or "player") == "player"
end

local function comboOwner(candidate)
    if candidate and candidate.comboAllOwners == true then return nil end
    return candidate and (candidate.comboTargetGUID or candidate.targetGUID)
end

local function branchPoints(state, owner)
    local branches = state and state.comboBranches
    if type(branches) ~= "table" then return nil, false end
    local exact, probability, i = nil, 0, nil
    for i = 1, table.getn(branches) do
        local branch = branches[i]
        local chance = tonumber(branch and branch.probability)
        local points = tonumber(branch and branch.points)
        if not chance or chance < 0 or chance > 1 then return nil, true end
        if chance > EPSILON then
            probability = probability + chance
            if branch.targetGUID ~= owner or not points or points < 1
                or math.abs(points - math.floor(points + 0.5)) > EPSILON
                or exact and exact ~= points then return nil, true end
            exact = points
        end
    end
    if not exact or math.abs(probability - 1) > EPSILON then return nil, true end
    return exact, true
end

local function exactPoints(state, candidate)
    local availability = tonumber(candidate and candidate.comboAvailability)
    if availability ~= nil and availability < 1 - EPSILON then return nil end
    if candidate and candidate.comboAllOwners == true then return nil end
    local owner = comboOwner(candidate)
    if owner == nil then return nil end
    local points, branched = branchPoints(state, owner)
    if branched and not points then return nil end
    local combo = XelAssist.Graph.ComboState
    if not branched and combo then
        points = combo:ConditionalExpected(
            state, owner, candidate.comboAllOwners)
    elseif not branched then points = state and state.combo end
    points = tonumber(points)
    if not points or points < 1 or points > MAX_COMBO
        or math.abs(points - math.floor(points + 0.5)) > EPSILON then
        return nil
    end
    return math.floor(points + 0.5)
end

local function decisionMultiplier(candidate)
    local resistance = candidate and candidate.resistance
    if not resistance then return 1 end
    local value = tonumber(resistance.decisionMultiplier)
    if value == nil or value < 0 then return nil end
    return value
end

local function landChance(candidate)
    local resistance = candidate and candidate.resistance
    if not resistance then return 1 end
    local value = tonumber(resistance.landChance)
    if value == nil or value <= 0 or value > 1 then return nil end
    return value
end

local function actionCycle(candidate)
    local value = tonumber(candidate and candidate.valueDowntime)
    if value == nil or value <= 0 then return nil end
    return value
end

local function builderProfile(candidate)
    local found, sealed = facts(candidate), tooltip(candidate)
    local gain = tonumber(sealed.comboGain)
    if sealed.comboGainUnknown or not gain or gain <= 0 or gain > MAX_COMBO
        or found.combo or sealed.comboSpendAll then return nil end
    local cost, cycle = tonumber(candidate.cost), actionCycle(candidate)
    local decision, land = decisionMultiplier(candidate), landChance(candidate)
    local raw = tonumber(candidate.rawPower)
    if not (rogueFamily(candidate) and actorIsPlayer(candidate)
        and candidate.targetRelation == "hostile" and candidate.costKnown == true
        and cost and cost >= 0 and cycle and decision and land and raw
        and raw >= 0) then return nil end
    return { candidate = candidate, gain = gain, land = land,
        damage = raw * decision, cost = cost, cycle = cycle }
end

local function finisherProfile(state, candidate)
    local found, sealed = facts(candidate), tooltip(candidate)
    local spends = found.combo == true or sealed.comboSpendAll == true
    local bonus = tonumber(sealed.comboBonus)
    local points = exactPoints(state, candidate)
    local raw, cost, cycle = tonumber(candidate.rawPower),
        tonumber(candidate.cost), actionCycle(candidate)
    local decision = decisionMultiplier(candidate)
    if not (spends and found.kind == "damage" and bonus and bonus > 0
        and points and points < MAX_COMBO and raw and raw >= 0
        and rogueFamily(candidate) and actorIsPlayer(candidate)
        and candidate.targetRelation == "hostile" and not candidate.onNextSwing
        and candidate.costKnown == true and cost and cost >= 0
        and cycle and decision) then return nil end
    local base = raw - bonus * points
    if base < -EPSILON then return nil end
    return { candidate = candidate, points = points,
        base = math.max(0, base), bonus = bonus, decision = decision,
        cost = cost, cycle = cycle, owner = comboOwner(candidate) }
end

local function energyRate(state)
    local clock = state and state.playerResourceClock
    local amount = clock and tonumber(clock.amount)
    local interval = clock and tonumber(clock.interval)
    if tonumber(state and state.resourceType) ~= ENERGY
        or not (clock and clock.verified == true
            and clock.externalEnergizeExcluded == true
            and tonumber(clock.resourceType) == ENERGY)
        or not amount or amount <= 0 or not interval or interval <= 0 then
        return nil
    end
    return amount / interval
end

local function cycleRate(finisher, builder, points, resourceRate)
    local pointYield = builder.gain * builder.land
    if pointYield <= 0 then return nil end
    -- Expected attempts includes failed builders: they still spend time and
    -- energy and deal their already delivery-weighted expected damage.
    local attempts = points / pointYield
    local damage = attempts * builder.damage
        + (finisher.base + finisher.bonus * points) * finisher.decision
    local laneSeconds = attempts * builder.cycle + finisher.cycle
    local energySeconds = (attempts * builder.cost + finisher.cost)
        / resourceRate
    local seconds = math.max(laneSeconds, energySeconds)
    if seconds <= 0 then return nil end
    return damage / seconds, attempts, damage, seconds
end

local function aliveAt(time, lower, upper)
    if time <= lower then return 1 end
    if time >= upper then return 0 end
    return 1 - (time - lower) / math.max(EPSILON, upper - lower)
end

local function retentionSurvival(state, finisher, found, resourceRate)
    local builder = found.builder
    if not (state and state.targetHealthExact == true
        and tonumber(state.targetHealth) and state.targetHealth > 0) then
        return nil
    end
    if state.targetGUID ~= finisher.owner then return nil end
    if finisher.candidate.reason == "finishes the target" then return 0 end
    if builder.candidate.reason == "finishes the target" then return 0 end
    local learned = state.targetSurvival
    local incoming = learned and tonumber(learned.incomingDps)
    local lower = learned and tonumber(
        learned.lowerTimeToDie or learned.timeToDie)
    local upper = learned and tonumber(
        learned.upperTimeToDie or learned.timeToDie)
    if not (learned and learned.available == true and incoming
        and incoming > 0 and lower and upper and lower >= 0
        and upper >= lower) then return nil end
    local begins = math.max(0, tonumber(state.time) or 0)
    local wait = math.max(0, tonumber(builder.candidate.wait) or 0)
    local extraPoints = found.nextPoints - finisher.points
    local pointYield = builder.gain * builder.land
    if extraPoints <= 0 or pointYield <= 0 then return nil end
    -- A resisted builder advances neither the combo state nor liquidation.
    -- Reserve the expected number of complete attempts needed to earn the
    -- additional point instead of assuming that the first attempt lands.
    local extraAttempts = extraPoints / pointYield
    local resource = tonumber(state.resource)
    local reserved = math.max(0,
        tonumber(state.playerResourceReserved) or 0)
    if not resource or resource < reserved or not resourceRate
        or resourceRate <= 0 then return nil end
    local laneReady = wait + extraAttempts * builder.cycle
    local totalCost = extraAttempts * builder.cost + finisher.cost
    local resourceReady = math.max(0,
        (totalCost - (resource - reserved)) / resourceRate)
    local liquidationAt = begins
        + math.max(laneReady, resourceReady) + finisher.cycle
    return aliveAt(liquidationAt, lower, upper), liquidationAt, extraAttempts
end

local function sameOwner(finisher, builder)
    local candidate = builder.candidate
    return finisher.owner ~= nil and candidate.targetGUID == finisher.owner
        and candidate.targetRelation == "hostile"
end

local function investment(finisher, builder, resourceRate)
    if not sameOwner(finisher, builder) then return nil end
    local nextPoints = math.min(MAX_COMBO,
        finisher.points + builder.gain)
    if nextPoints <= finisher.points then return nil end
    local current = cycleRate(
        finisher, builder, finisher.points, resourceRate)
    local future, attempts, damage, seconds = cycleRate(
        finisher, builder, nextPoints, resourceRate)
    if not current or not future then return nil end
    return { builder = builder, currentRate = current, nextRate = future,
        nextPoints = nextPoints, nextAttempts = attempts,
        nextDamage = damage, nextSeconds = seconds }
end

local function bestInvestment(candidates, finisher, resourceRate)
    local best, currentBest, i = nil, nil, nil
    for i = 1, table.getn(candidates) do
        local builder = builderProfile(candidates[i])
        local found = builder and investment(finisher, builder, resourceRate)
        if found and (not currentBest
            or found.currentRate > currentBest) then
            currentBest = found.currentRate
        end
        if found and (not best or found.nextRate > best.nextRate) then
            best = found
        end
    end
    if best then best.currentRate = currentBest end
    return best
end

local function adjustFinisher(candidates, state, candidate, resourceRate)
    local finisher = finisherProfile(state, candidate)
    if not finisher or candidate.reason == "finishes the target" then return false end
    local best = bestInvestment(candidates, finisher, resourceRate)
    if not best then return false end
    local legacy = math.max(0,
        tonumber(candidate.comboEfficiencyPenalty) or 0)
    local unadjusted = (tonumber(candidate.value) or 0) + legacy
    local function publish(penalty, survival, liquidationAt,
            extraAttempts, decision)
        candidate.value = unadjusted - penalty
        candidate.comboEfficiencyPenalty = penalty > EPSILON and penalty or nil
        candidate.rogueComboInvestment = {
            source = "sealed combo curve, candidate builder and energy clock",
            points = finisher.points, nextPoints = best.nextPoints,
            currentRate = best.currentRate, nextRate = best.nextRate,
            retentionSurvival = survival, liquidationAt = liquidationAt,
            extraBuilderAttempts = extraAttempts,
            builderSpellId = best.builder.candidate.action.spellId,
            nextAttempts = best.nextAttempts, nextDamage = best.nextDamage,
            nextSeconds = best.nextSeconds, penalty = penalty,
            decision = decision,
        }
    end
    if best.nextRate <= best.currentRate + EPSILON then
        publish(0, nil, nil, nil, "spend cycle is at least as efficient")
        return false
    end
    local survival, liquidationAt, extraAttempts = retentionSurvival(
        state, finisher, best, resourceRate)
    if survival == nil then return false end
    if survival <= 0 then
        publish(0, survival, liquidationAt, extraAttempts,
            "points are at imminent risk")
        return false
    end
    if unadjusted <= 0 then return false end
    local efficiencyFactor = math.max(0, math.min(1,
        best.currentRate / best.nextRate))
    local penalty = unadjusted * (1 - efficiencyFactor) * survival
    if penalty <= EPSILON then return false end
    publish(penalty, survival, liquidationAt, extraAttempts,
        "retaining one builder improves the damage cycle")
    best.builder.candidate.reason =
        "retains combo points for a more efficient damage cycle"
    return true
end

-- This runs after legal candidates are flattened, before beam-width pruning.
-- It performs no client calls and is linear in finishers times legal builders;
-- a Rogue action book keeps both sets small relative to candidate evaluation.
function R:Adjust(candidates, state)
    if type(candidates) ~= "table" or type(state) ~= "table" then return 0 end
    local resourceRate = energyRate(state)
    if not resourceRate then return 0 end
    local adjusted, i = 0, nil
    for i = 1, table.getn(candidates) do
        if adjustFinisher(candidates, state, candidates[i], resourceRate) then
            adjusted = adjusted + 1
        end
    end
    return adjusted
end
