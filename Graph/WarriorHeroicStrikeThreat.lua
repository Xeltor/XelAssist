-- Search-pure Heroic Strike threat consequence. Generic swing logic owns the
-- displaced white hit; this leaf supplies only the server's landed flat packet
-- and its exact 1.0 damage multiplier from sealed action evidence.
XelAssist.Graph.WarriorHeroicStrikeThreat = {}
local H = XelAssist.Graph.WarriorHeroicStrikeThreat

local function runtime()
    return XelAssist.Game and XelAssist.Game.Player
        and XelAssist.Game.Player.WarriorHeroicStrikeThreat
end

local function evidence(subject)
    local owner = runtime()
    return owner and owner.Evidence and owner:Evidence(subject) or nil
end

local function probability(value)
    value = tonumber(value)
    if not value or value ~= value or value == math.huge
        or value == -math.huge or value < 0 or value > 1 then return nil end
    return value
end

local function nonNegative(value)
    value = tonumber(value)
    if not value or value ~= value or value == math.huge
        or value == -math.huge or value < 0 then return nil end
    return value
end

function H:Is(action)
    return action and action.facts
        and action.facts.warriorHeroicStrikeThreat == true
end

function H:Evidence(action)
    return evidence(action)
end

function H:Blocker(action, state, descriptor)
    if not self:Is(action) then return nil, false end
    if (action.actor or "player") ~= "player" then
        return "Heroic Strike threat must be player-owned", true
    end
    if not evidence(action) then
        return "Heroic Strike threat evidence unavailable", true
    end
    if not (descriptor and descriptor.relation == "hostile") then
        return "Heroic Strike requires a hostile recipient", true
    end
    return nil, true
end

-- The generic threat calculation already carries expected full and marginal
-- replacement damage. Flat threat is incremental in both policy lanes and is
-- conditioned on the same landed-effect probability as the yellow hit.
function H:Augment(context, threat, valueThreat)
    local action = context and context.action
    if not self:Is(action) then return threat, valueThreat, false, nil end
    local found = evidence(action)
    if not found then
        return nil, nil, true, "Heroic Strike threat evidence unavailable"
    end
    local delivered = probability(context and context.effectDelivery)
    threat, valueThreat = nonNegative(threat), nonNegative(valueThreat)
    if delivered == nil or threat == nil or valueThreat == nil
        or context.kind ~= "damage" or context.onNextSwing ~= true
        or (action.actor or "player") ~= "player" then
        return nil, nil, true, "Heroic Strike threat context unavailable"
    end
    local flat = found.flatThreat * delivered
    context.warriorHeroicStrikeFlatThreat = flat
    context.warriorHeroicStrikeDamageThreatMultiplier =
        found.damageThreatMultiplier
    context.warriorHeroicStrikeThreatProfileExact =
        found.runtimeVerified == true
    context.estimated = context.estimated or found.runtimeVerified ~= true
    return threat + flat, valueThreat + flat, true, nil
end

-- Applied damage has already paid delivery, mitigation, and target-health caps.
-- Flat threat pays once on the same landed branch and never replaces damage.
function H:AppliedThreat(context, candidate, appliedDamage)
    local action = context and context.action
    if not self:Is(action) then return nil, nil, false, nil end
    local found = evidence(action)
    local delivered = probability(candidate and candidate.effectDelivery
        or context and context.effectDelivery)
    appliedDamage = nonNegative(appliedDamage)
    if not found or delivered == nil or appliedDamage == nil then
        return nil, nil, true,
            "Heroic Strike threat transition unavailable"
    end
    local amount = appliedDamage * found.damageThreatMultiplier
        + found.flatThreat * delivered
    return amount, found.runtimeVerified == true, true, nil
end

function H:Exactness(context, current)
    if not self:Is(context and context.action) then return current end
    local found = evidence(context.action)
    return found and found.runtimeVerified == true
        and current ~= false or false
end
