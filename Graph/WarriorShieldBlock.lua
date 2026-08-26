-- Branch-local Shield Block prevention. Installed spell topology owns the
-- window and charges; observed same-regime block packets own only a
-- conservative magnitude, while reverse selected-target geometry prevents the
-- graph from crediting an attacker behind the player.
XelAssist.Graph.WarriorShieldBlock = {}
local S = XelAssist.Graph.WarriorShieldBlock

local function copy(source)
    local out, key, value = {}, nil, nil
    for key, value in pairs(source or {}) do
        out[key] = type(value) == "table" and copy(value) or value
    end
    return out
end

local function application(projection)
    local value = projection and projection.warriorShieldBlockApplication
    if type(value) ~= "table" or value.exact ~= true
        or value.spellId ~= 2565
        or (value.charges ~= 1 and value.charges ~= 2)
        or not tonumber(value.duration) or value.duration <= 0
        or value.duration > 60 then return nil end
    return value
end

local function mastery(evidence)
    local value = evidence and evidence.warriorShieldMasteryEvidence
    if not value then return { learned = false, exact = true } end
    if not (value.available == true and value.exact == true) then return nil end
    if value.learned ~= true then return { learned = false, exact = true } end
    if value.portfolio ~= "warriorShieldMastery"
        or value.rootSpellId ~= 45958 or value.blockSpellId ~= 45959
        or value.riposteSpellId ~= 45962 or value.blockDuration ~= 0.25
        or value.riposteDuration ~= 5 or value.blockValueMultiplier ~= 1.5
        or value.revengeDamageMultiplier ~= 2.5 then return nil end
    return value
end

local function defense(state)
    local swings = state and state.hostileSwings
    local profile = swings and swings.playerDefense
    if type(profile) ~= "table" or profile.exact ~= true
        or profile.selectedBehindPlayer ~= false
        or (type(profile.selectedKey) ~= "string"
            and type(profile.selectedKey) ~= "table")
        or not tonumber(profile.blockChance) or profile.blockChance < 0
        or profile.blockChance > 100 then return nil end
    return profile
end

local function laneEvidence(state, profile)
    local lanes = state.hostileSwings and state.hostileSwings.lanes or {}
    local best, i = nil, nil
    for i = 1, table.getn(lanes) do
        local lane = lanes[i]
        if lane.phaseKnown == true and lane.victimKind == "player"
            and lane.attackerKey == profile.selectedKey
            and tonumber(lane.interval) and lane.interval > 0
            and tonumber(lane.nextSwingIn) and lane.nextSwingIn > 0
            and tonumber(lane.blockLowerBound) and lane.blockLowerBound > 0
            and tonumber(lane.blockSamples) and lane.blockSamples > 0 then
            if not best or lane.nextSwingIn < best.nextSwingIn then best = lane end
        end
    end
    return best
end

local function addedChance(profile)
    return math.max(0, math.min(75, 100 - profile.blockChance)) / 100
end

local function expectedBlocks(rounds, added, total, charges)
    local distribution = { [0] = 1 }
    local completed, round, blocks = 0, nil, nil
    for round = 1, rounds do
        local nextDistribution = {}
        for blocks = 0, charges do
            local probability = distribution[blocks] or 0
            if blocks < charges then
                completed = completed + probability * added
                nextDistribution[blocks] = (nextDistribution[blocks] or 0)
                    + probability * (1 - total)
                nextDistribution[blocks + 1] =
                    (nextDistribution[blocks + 1] or 0)
                        + probability * total
            else
                nextDistribution[blocks] = (nextDistribution[blocks] or 0)
                    + probability
            end
        end
        distribution = nextDistribution
    end
    return completed
end

local function preview(state, value, applicationAt)
    local profile = defense(state)
    local lane = profile and laneEvidence(state, profile)
    if not lane then return nil end
    local chance = addedChance(profile)
    if chance <= 0 then return nil end
    local first = lane.nextSwingIn - applicationAt
    if first <= 0 then
        local skipped = math.floor((-first) / lane.interval) + 1
        first = first + skipped * lane.interval
    end
    local rounds = first <= value.duration
        and math.floor((value.duration - first) / lane.interval) + 1 or 0
    rounds = math.max(0, math.min(8, rounds))
    if rounds <= 0 then return nil end
    local perBlock = math.min(lane.blockLowerBound,
        math.max(0, tonumber(lane.expectedDamage) or 0))
    local total = math.min(1, profile.blockChance / 100 + chance)
    local blocks = expectedBlocks(rounds, chance, total, value.charges)
    local masteryProbability = value.shieldMastery
        and 1 - math.pow(1 - total, rounds) or 0
    local masteryPrevented = value.shieldMastery
        and perBlock * (value.shieldMastery.blockValueMultiplier - 1)
            * masteryProbability or 0
    return { exact = false, estimated = true,
        attackerKey = profile.selectedKey, selectedBehindPlayer = false,
        blockChance = profile.blockChance, addedBlockChance = chance,
        blockLowerBound = lane.blockLowerBound,
        blockSamples = lane.blockSamples, rounds = rounds,
        expectedBlocks = blocks, prevented = perBlock * blocks
            + masteryPrevented, shieldMasteryProbability = masteryProbability,
        shieldMasteryPrevented = masteryPrevented,
        source = "same-regime observed block lower bound and selected frontal rounds" }
end

function S:Prepare(action, state, tooltip)
    local facts = action and action.facts
    local evidence = facts and facts.warriorShieldBlockEvidence
    if not (facts and facts.warriorShieldBlock) then return tooltip, nil, false end
    if not (evidence and evidence.exact and evidence.spellId == 2565
        and (evidence.charges == 1 or evidence.charges == 2)
        and type(evidence.duration) == "number" and evidence.duration > 0
        and evidence.duration <= 60 and evidence.blockChanceBonus == 75
        and evidence.cost == 10) then
        return nil, "Shield Block evidence incomplete", true
    end
    if not (state and state.playerForm and state.playerForm.available == true
        and state.playerForm.formID == 18 and state.resourceType == 1
        and state.playerResourceExact == true
        and tonumber(state.resource) and state.resource >= 10) then
        return nil, "Shield Block stance or rage unavailable", true
    end
    local offHand = state.inventory and state.inventory.offHand
    if not (offHand and offHand.classificationKnown
        and offHand.classID == 4 and offHand.subClassID == 6
        and offHand.broken == false) then
        return nil, "usable shield unavailable", true
    end
    local out = copy(tooltip)
    local masteryEvidence = mastery(facts)
    if not masteryEvidence then
        return nil, "Shield Mastery evidence incomplete", true
    end
    out.warriorShieldBlockApplication = { exact = true, spellId = 2565,
        charges = evidence.charges, duration = evidence.duration,
        shieldMastery = masteryEvidence.learned == true and {
            exact = true, rootSpellId = masteryEvidence.rootSpellId,
            blockValueMultiplier = masteryEvidence.blockValueMultiplier,
            revengeDamageMultiplier = masteryEvidence.revengeDamageMultiplier,
            riposteDuration = masteryEvidence.riposteDuration } or nil }
    out.classMechanic = "warriorShieldBlock"
    return out, nil, true
end

function S:Score(context, projection)
    local value = application(projection)
    if not value then return false, "Shield Block transition unavailable" end
    local plan = preview(context.state, value,
        (context.wait or 0) + (context.cast or 0))
    context.power, context.expectedPower, context.effectivePower = 0, 0, 0
    context.shieldBlockPrevention = plan
    context.value = plan and plan.prevented or 0
    context.estimated = true
    context.reason = plan and "prevents bounded selected-attacker damage"
        or "block magnitude, frontal attacker, or incoming phase unavailable"
    return true
end

function S:Apply(state, candidate)
    local value = application(candidate and candidate.tooltip)
    if not value then return false end
    local plan = candidate.shieldBlockPrevention
    state.warriorShieldBlock = { active = true, charges = value.charges,
        expectedCharges = value.charges,
        chargeDistribution = { [value.charges] = 1 },
        expiresAt = (tonumber(state.time) or 0) + value.duration,
        attackerKey = plan and plan.attackerKey,
        baseBlockChance = plan and plan.blockChance
            and plan.blockChance / 100 or nil,
        addedBlockChance = plan and plan.addedBlockChance,
        blockLowerBound = plan and plan.blockLowerBound,
        projected = true }
    if value.shieldMastery then
        state.warriorShieldMastery = state.warriorShieldMastery or {}
        state.warriorShieldMastery.pendingProbability = 1
        state.warriorShieldMastery.blockValueMultiplier =
            value.shieldMastery.blockValueMultiplier
        state.warriorShieldMastery.revengeDamageMultiplier =
            value.shieldMastery.revengeDamageMultiplier
        state.warriorShieldMastery.riposteDuration =
            value.shieldMastery.riposteDuration
        state.warriorShieldMastery.riposteProbability =
            math.max(0, math.min(1, tonumber(
                state.warriorShieldMastery.riposteProbability) or 0))
        state.warriorShieldMastery.riposteRemaining = math.max(0,
            tonumber(state.warriorShieldMastery.riposteRemaining) or 0)
    end
    return true
end

function S:AdjustProjectedSwing(state, event, amount)
    local window = state and state.warriorShieldBlock
    amount = math.max(0, tonumber(amount) or 0)
    if not (window and window.active and window.projected
        and type(event) == "table"
        and window.attackerKey == event.attackerKey
        and event.victimKind == "player"
        and type(window.chargeDistribution) == "table"
        and tonumber(window.baseBlockChance)
        and tonumber(window.addedBlockChance)
        and tonumber(window.blockLowerBound)) then return amount end
    local added, total = window.addedBlockChance,
        math.min(1, window.baseBlockChance + window.addedBlockChance)
    local used, consumed, nextDistribution = 0, 0, {}
    local remaining, probability
    for remaining, probability in pairs(window.chargeDistribution) do
        if remaining > 0 then
            used = used + probability * added
            consumed = consumed + probability * total
            nextDistribution[remaining] = (nextDistribution[remaining] or 0)
                + probability * (1 - total)
            nextDistribution[remaining - 1] =
                (nextDistribution[remaining - 1] or 0) + probability * total
        else
            nextDistribution[0] = (nextDistribution[0] or 0) + probability
        end
    end
    local prevented = math.min(amount, window.blockLowerBound) * used
    local shieldMastery = state.warriorShieldMastery
    if shieldMastery and shieldMastery.pendingProbability > 0 then
        local triggered = shieldMastery.pendingProbability * total
        shieldMastery.pendingProbability = shieldMastery.pendingProbability
            * (1 - total)
        shieldMastery.riposteProbability = math.max(
            shieldMastery.riposteProbability or 0, triggered)
        if triggered > 0 then
            shieldMastery.riposteRemaining = shieldMastery.riposteDuration
            prevented = prevented + math.min(math.max(0, amount - prevented),
                window.blockLowerBound
                    * (shieldMastery.blockValueMultiplier - 1)) * triggered
        end
    end
    window.chargeDistribution = nextDistribution
    window.expectedCharges = math.max(0, window.expectedCharges - consumed)
    if window.expectedCharges <= 0 then window.active = false end
    return math.max(0, amount - prevented)
end

function S:Advance(state, elapsed)
    local window = state and state.warriorShieldBlock
    if window and (tonumber(state.time) or 0) + (tonumber(elapsed) or 0)
        >= window.expiresAt then
        window.active, window.charges, window.expectedCharges = false, 0, 0
        if state.warriorShieldMastery then
            state.warriorShieldMastery.pendingProbability = 0
        end
    end
    local masteryState = state and state.warriorShieldMastery
    if masteryState and masteryState.riposteRemaining then
        masteryState.riposteRemaining = math.max(0,
            masteryState.riposteRemaining - (tonumber(elapsed) or 0))
        if masteryState.riposteRemaining <= 0 then
            masteryState.riposteProbability = 0
        end
    end
end

function S:Copy(source, target)
    if not target then return false end
    target.warriorShieldBlock = source and source.warriorShieldBlock
        and copy(source.warriorShieldBlock) or nil
    target.warriorShieldMastery = source and source.warriorShieldMastery
        and copy(source.warriorShieldMastery) or nil
    return target.warriorShieldBlock ~= nil
end

function S:AdjustRevenge(context)
    local facts = context and context.action and context.action.facts
    local evidence = mastery(facts)
    if not (evidence and evidence.learned == true
        and facts.warriorRevengeThreat == true) then return false, nil end
    local current = context.state and context.state.warriorShieldMastery
    local delay = math.max(0, tonumber(context.impactDelay)
        or (tonumber(context.wait) or 0) + (tonumber(context.cast) or 0))
    local probability = current and current.riposteRemaining > delay
        and math.max(0, math.min(1,
            tonumber(current.riposteProbability) or 0)) or 0
    if probability <= 0 then return false, nil end
    local base = tonumber(context.expectedPower)
    if not base or base < 0 then
        return false, "Shield Mastery Revenge power unavailable"
    end
    context.expectedPower = base * (1
        + (evidence.revengeDamageMultiplier - 1) * probability)
    context.warriorShieldMasteryConsumption = { exact = true,
        activeProbability = probability, riposteSpellId = 45962 }
    return true, nil
end

function S:ConsumeRevenge(state, candidate)
    local marker = candidate and candidate.warriorShieldMasteryConsumption
    local current = state and state.warriorShieldMastery
    local delivery = tonumber(candidate and candidate.effectDelivery)
    if not (marker and marker.exact == true and marker.riposteSpellId == 45962
        and current and delivery and delivery >= 0 and delivery <= 1) then
        return false
    end
    current.riposteProbability = math.max(0,
        (tonumber(current.riposteProbability) or 0) * (1 - delivery))
    if current.riposteProbability <= 0 then current.riposteRemaining = 0 end
    return true
end

function S:ConsumeObservedBlock(state, event)
    local window = state and state.warriorShieldBlock
    if not (window and window.active and window.charges > 0 and event
        and event.whiteSwing == true and event.victimKind == "player"
        and event.outcomeExact == true and tonumber(event.blockedAmount)
        and event.blockedAmount > 0) then return false end
    window.charges = window.charges - 1
    window.expectedCharges = window.charges
    window.chargeDistribution = { [window.charges] = 1 }
    local masteryState = state.warriorShieldMastery
    if masteryState and masteryState.pendingProbability > 0 then
        masteryState.pendingProbability = 0
        masteryState.riposteProbability = 1
        masteryState.riposteRemaining = masteryState.riposteDuration
    end
    if window.charges == 0 then window.active = false end
    return true
end
