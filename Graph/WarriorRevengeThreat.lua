-- Search-pure Revenge threat consequence. The generic threat layer owns tank
-- policy and stance scaling; this leaf only supplies the landed flat packet
-- and the exact damage multiplier from sealed action evidence.
XelAssist.Graph.WarriorRevengeThreat = {}
local R = XelAssist.Graph.WarriorRevengeThreat

local function runtime()
    return XelAssist.Game and XelAssist.Game.Player
        and XelAssist.Game.Player.WarriorRevengeThreat
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

function R:Is(action)
    return action and action.facts
        and action.facts.warriorRevengeThreat == true
end

function R:Evidence(action)
    return evidence(action)
end

function R:Blocker(action, state, descriptor)
    if not self:Is(action) then return nil, false end
    if (action.actor or "player") ~= "player" then
        return "Revenge threat must be player-owned", true
    end
    if not evidence(action) then
        return "Revenge threat evidence unavailable", true
    end
    if not (descriptor and descriptor.relation == "hostile") then
        return "Revenge requires a hostile recipient", true
    end
    return nil, true
end

-- Hook before generic actor/stance scaling. `threat` already contains expected
-- delivered damage times 2.25; only the hit-conditioned flat packet is added.
function R:Augment(context, threat, valueThreat)
    local action = context and context.action
    if not self:Is(action) then return threat, valueThreat, false, nil end
    local found = evidence(action)
    if not found then
        return nil, nil, true, "Revenge threat evidence unavailable"
    end
    local delivered = probability(context and context.effectDelivery)
    threat, valueThreat = nonNegative(threat), nonNegative(valueThreat)
    if delivered == nil or threat == nil or valueThreat == nil
        or context.kind ~= "damage"
        or (action.actor or "player") ~= "player" then
        return nil, nil, true, "Revenge threat context unavailable"
    end
    local flat = found.flatThreat * delivered
    context.warriorRevengeFlatThreat = flat
    context.warriorRevengeDamageThreatMultiplier =
        found.damageThreatMultiplier
    context.warriorRevengeThreatProfileExact = found.runtimeVerified == true
    context.estimated = context.estimated or found.runtimeVerified ~= true
    return threat + flat, valueThreat + flat, true, nil
end

-- Transition hook for the selected hostile. Applied damage is already capped
-- and mitigated; flat threat depends only on the effect landing, not armor.
function R:AppliedThreat(context, candidate, appliedDamage)
    local action = context and context.action
    if not self:Is(action) then return nil, nil, false, nil end
    local found = evidence(action)
    local delivered = probability(candidate and candidate.effectDelivery
        or context and context.effectDelivery)
    appliedDamage = nonNegative(appliedDamage)
    if not found or delivered == nil or appliedDamage == nil then
        return nil, nil, true, "Revenge threat transition unavailable"
    end
    local amount = appliedDamage * found.damageThreatMultiplier
        + found.flatThreat * delivered
    return amount, found.runtimeVerified == true, true, nil
end

-- The official build profile is exact, but OctoWoW does not expose its live
-- spell_threat table. Preserve that boundary in candidate/hostile exactness.
function R:Exactness(context, current)
    if not self:Is(context and context.action) then return current end
    local found = evidence(context.action)
    return found and found.runtimeVerified == true and current ~= false or false
end
