-- Policy and projection for controlled-companion threat actions. This module
-- records relative bounds and deltas; it never treats an estimated threat
-- change as proof that the hostile target changed victims.
XelAssist.Graph.CompanionThreat = {}
local T = XelAssist.Graph.CompanionThreat

local VALID_POLICY = { tank = true, assist = true, avoid = true }

local function petOf(state)
    return state and state.actors and state.actors.pet or nil
end

local function factsOf(subject)
    if type(subject) ~= "table" then return nil end
    if type(subject.facts) == "table" then return subject.facts end
    if subject.action and type(subject.action.facts) == "table" then
        return subject.action.facts
    end
    return subject
end

local function directionOf(subject)
    local facts = factsOf(subject)
    if not facts then return nil end
    if facts.petThreatDrop then return "drop" end
    if facts.petThreatGain then return "gain" end
    if facts.kind ~= "petThreat" then return nil end
    local direction = facts.petThreatDirection or facts.direction
    if direction == "drop" or direction == "gain" then return direction end
    if type(facts.petThreat) == "number" and facts.petThreat < 0 then
        return "drop"
    end
    return "gain"
end

local function amountOf(subject, direction)
    local facts = factsOf(subject) or {}
    local flagged = direction == "gain" and facts.petThreatGain
        or facts.petThreatDrop
    if type(flagged) == "number" then return math.abs(flagged), true end
    local amount = facts.petThreatAmount or facts.petThreatValue
    if amount == nil and type(facts.petThreat) == "number" then
        amount = facts.petThreat
    end
    if type(amount) == "number" then return math.abs(amount), true end
    -- One relative unit keeps the transition visible without inventing the
    -- static threat value of an unknown rank.
    return 1, false
end

local function copyEstimate(estimate)
    local out, key, value = {}, nil, nil
    for key, value in pairs(estimate or {}) do out[key] = value end
    return out
end

local function liveEstimate(pet)
    local current = pet and pet.threatEstimate
    if type(current) == "table"
        and current.observedHasAggro == pet.hasAggro then
        return copyEstimate(current)
    end
    local observed = pet and pet.hasAggro
    local estimate = { delta = 0, known = false,
        observedHasAggro = observed }
    if pet and pet.hasAggro == true then
        estimate.lower = 0
        estimate.source = "live companion aggro lower bound"
        estimate.confidence = "live bound"
    elseif pet and pet.hasAggro == false then
        estimate.upper = 0
        estimate.source = "live companion no-aggro upper bound"
        estimate.confidence = "live bound"
    else
        estimate.source = "companion aggro unavailable"
        estimate.confidence = "unknown"
    end
    return estimate
end

function T:ResolvePolicy(state, requested)
    local configured = requested
    if configured == nil and XelAssistCharDB then
        configured = XelAssistCharDB.petThreat
    end
    if VALID_POLICY[configured] then return configured, "explicit" end
    local pet = petOf(state)
    if (tonumber(state and state.groupSize) or 0) <= 0 then
        return "tank", "solo inference"
    end
    if state and (state.tank or state.hasAggro) then
        return "assist", "player threat inference"
    end
    if pet and pet.hasAggro then
        return "avoid", "live companion aggro"
    end
    return "avoid", "group victim inference"
end

-- Returns a reason only when policy makes this threat action ineligible.
function T:Block(state, subject, requested)
    local direction = directionOf(subject)
    if not direction then return nil end
    local pet = petOf(state)
    if not pet then return "companion unavailable" end
    local policy = self:ResolvePolicy(state, requested)
    if direction == "gain" then
        if policy == "avoid" then return "companion threat avoidance" end
        if policy == "assist" and not (state.hasAggro and not state.tank) then
            return "companion assist threat policy"
        end
    elseif policy == "tank" then
        return "companion tank threat policy"
    end
    return nil
end

-- Returns score delta, explanation, and evidence confidence. The graph still
-- compares this utility with focus cost, cooldown, damage, and survival.
function T:Score(state, subject, requested)
    local direction = directionOf(subject)
    local pet = petOf(state)
    if not direction or not pet then return 0, nil, "unknown" end
    local policy = self:ResolvePolicy(state, requested)
    local amount, amountKnown = amountOf(subject, direction)
    local magnitude = amountKnown and math.min(700, math.sqrt(amount) * 24) or 90
    local value, reason
    if direction == "gain" then
        if policy == "tank" then
            value = ((state.groupSize or 0) <= 0 and 900 or 550) + magnitude
            if state.hasAggro and not state.tank then value = value + 1000 end
            if pet.hasAggro then value = value - 450 end
            reason = pet.hasAggro and "reinforces companion threat"
                or "builds companion tank threat"
        elseif policy == "assist" and state.hasAggro and not state.tank then
            value, reason = 700 + magnitude, "helps peel unwanted player aggro"
        else
            value, reason = -1400 - magnitude, "avoids displacing the group tank"
        end
    elseif policy == "tank" then
        value, reason = -1200 - magnitude, "preserves companion tank threat"
    elseif pet.hasAggro then
        value = (policy == "avoid" and 1900 or 1200) + magnitude
        reason = "reduces unwanted companion aggro"
    else
        value = (policy == "avoid" and 250 or -250) + magnitude * 0.2
        reason = "reduces companion threat risk"
    end
    local evidence = liveEstimate(pet)
    local confidence = amountKnown and (evidence.confidence or "unknown")
        or "uncertain relative amount"
    return value, reason, confidence
end

-- Mutates only the companion's threat estimate. Bounds are relative to the
-- victim-change threshold: live aggro supplies a lower bound of zero, while
-- live no-aggro supplies an upper bound of zero.
function T:Apply(state, subject, requested, delivery)
    local direction = directionOf(subject)
    local pet = petOf(state)
    if not direction then return false, "not a companion threat action" end
    if not pet then return false, "companion unavailable" end
    local amount, known = amountOf(subject, direction)
    local probability = tonumber(delivery)
    if probability == nil then probability = 1 end
    probability = math.max(0, math.min(1, probability))
    local threatMultiplier = XelAssist.Game and XelAssist.Game.Pets
        and XelAssist.Game.Pets.Effects
        and XelAssist.Game.Pets.Effects:ThreatMultiplier(pet) or 1
    local change = amount * probability * threatMultiplier
    if direction == "drop" then change = -change end
    local estimate = liveEstimate(pet)
    if estimate.lower ~= nil then estimate.lower = estimate.lower + change end
    if estimate.upper ~= nil then estimate.upper = estimate.upper + change end
    estimate.delta = (tonumber(estimate.delta) or 0) + change
    estimate.known = false
    estimate.projected = true
    estimate.lastDirection = direction
    estimate.lastAmount = amount
    estimate.amountKnown = known
    estimate.delivery = probability
    estimate.threatMultiplier = threatMultiplier
    estimate.policy = self:ResolvePolicy(state, requested)
    estimate.source = direction == "gain" and "projected companion threat gain"
        or "projected companion threat reduction"
    estimate.confidence = known and probability >= 1
        and "projected from live bound" or "uncertain projection"
    pet.threatEstimate = estimate
    return true, estimate
end
