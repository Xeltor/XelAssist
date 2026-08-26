-- Selected-hostile threat transition. Damage capping happens before this
-- boundary; exact class packets then compose with player stance or pet threat.
XelAssist.Graph.PrimaryThreatEffects = {}
local P = XelAssist.Graph.PrimaryThreatEffects
local State = XelAssist.Graph.State
local PlayerThreat = XelAssist.Graph.PlayerThreat
local CompanionEventThreat = XelAssist.Graph.CompanionEventThreat
local WarriorThreat = XelAssist.Graph.WarriorThreatPackets

local function activeTarget(state)
    if State.ActiveHostile then return State:ActiveHostile(state) end
    return State.SelectedHostile and State:SelectedHostile(state) or nil
end

local function damageThreat(out, candidate, context, actor)
    local amount, profileExact, handled
    if WarriorThreat then
        amount, profileExact, handled = WarriorThreat:AppliedThreat(
            context, candidate, context.appliedHostileDamage)
    end
    if handled and amount == nil then return nil, nil end
    if not handled then
        amount = math.max(0, context.appliedHostileDamage)
            * (context.facts.threat or 1)
    end
    if actor == "pet" and not handled then
        local pet = out.actors and out.actors.pet
        amount = amount * 0.9 * (XelAssist.Game.Pets
            and XelAssist.Game.Pets.Effects
            and XelAssist.Game.Pets.Effects:ThreatMultiplier(pet) or 1)
        return amount, true
    end
    local stanceExact
    amount, stanceExact = PlayerThreat:Scale(
        out, actor, amount, context.threatSchool)
    return amount, stanceExact ~= false
        and context.facts.threatProfileExact ~= false
        and (not handled or profileExact ~= false)
end

function P:Apply(out, candidate, context)
    local kind = context and context.facts and context.facts.kind
    local baseFlatThreat = context and context.facts
        and context.facts.baseFlatThreatBySpellId
    if candidate.targetRelation ~= "hostile"
        or (kind ~= "damage" and kind ~= "dot" and kind ~= "builder"
            and not baseFlatThreat) then return false end
    local actor = context.facts.damageActor or context.facts.effectActor
        or context.action.actor or "player"
    local amount = math.max(0, tonumber(candidate.threat) or 0)
    local exact = candidate.playerThreatExact ~= false
    if (kind == "damage" or kind == "dot" or kind == "builder")
        and context.appliedHostileDamage ~= nil then
        amount, exact = damageThreat(out, candidate, context, actor)
        if amount == nil then return false end
    elseif actor == "pet" and CompanionEventThreat then
        amount = math.max(0, amount - (CompanionEventThreat:HybridFlatThreat(
            out, context.action, candidate.effectDelivery) or 0))
    end
    if amount <= 0 then return false end
    local record = activeTarget(out)
    if not record or candidate.targetGUID ~= nil
        and record.guid ~= candidate.targetGUID then return false end
    PlayerThreat:AddScaled(record, actor, amount, exact)
    if kind == "dot" and context.appliedHostileDamage == nil then
        record.projectedThreatTimingUnknown = true
    end
    if baseFlatThreat then
        record.threat.playerDeltaExact = false
        record.threat.containsEstimatedBaseThreat = true
        record.threat.projectedSource = context.facts.baseFlatThreatSource
    end
    return true
end
