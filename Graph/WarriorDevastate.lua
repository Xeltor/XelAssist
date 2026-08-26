-- Selected-hostile-local Devastate consequence.  This module prepares exact
-- arithmetic for generic damage/aura consumers; wiring is intentionally kept
-- outside this leaf so an incomplete Sunder record cannot leak a guessed term.
XelAssist.Graph.WarriorDevastate = {}
local D = XelAssist.Graph.WarriorDevastate
local Owner = XelAssist.Game.Player.WarriorDevastate

local function finite(value, low, high)
    return type(value) == "number" and value == value
        and value ~= math.huge and value ~= -math.huge
        and value >= low and value <= high and value or nil
end

local function exactStacks(record)
    if type(record) ~= "table" or record.selected ~= true
        or record.executable ~= true then return nil end
    local aura = record.projectedAuras and record.projectedAuras[Owner.SUNDER_NAME]
    local effect = record.modifierEffects
        and record.modifierEffects[Owner.SUNDER_NAME]
    local stacks = aura and finite(aura.stacks, 0, 5)
    if not (stacks and math.floor(stacks) == stacks and aura.mine == true
        and aura.applicationProbability == 1 and effect
        and effect.activeRoot == true and effect.mine == true
        and effect.deliveryProbability == 1
        and effect.expectedStacks == stacks) then return nil end
    return stacks, aura
end

function D:Prepare(action, state, descriptor)
    local facts = action and action.facts
    local evidence = facts and facts.warriorDevastateEvidence
    if not (action and tonumber(action.spellId) == Owner.SPELL_ID
        and facts.warriorDevastate == true and type(evidence) == "table"
        and evidence.valid == true and evidence.exact == true
        and evidence.weaponPercent == 50 and evidence.damagePerSunder == 15
        and evidence.supplementalThreatExact == false) then
        return nil, "Devastate evidence is incomplete", true
    end
    local record = descriptor and descriptor.record
    local stacks, aura = exactStacks(record)
    if stacks == nil then
        return nil, "exact selected-target Sunder stacks are unavailable", true
    end
    local duration = finite(aura.duration, 0, 3600)
    local refresh = stacks > 0 and duration and duration > 0 and duration or nil
    return { warriorDevastate = true, spellId = Owner.SPELL_ID,
        targetKey = record.key, sunderStacks = stacks,
        weaponPercent = 50, stackDamage = stacks * 15,
        sunderRefreshDuration = refresh,
        supplementalThreat = nil, supplementalThreatExact = false,
        source = evidence.source }, nil, true
end

local function copy(source)
    local out, key, value = {}, nil, nil
    for key, value in pairs(source or {}) do out[key] = value end
    return out
end

function D:PrepareLegal(action, state, descriptor, tooltip)
    if not (action and action.facts and action.facts.warriorDevastate) then
        return tooltip, nil, false
    end
    local projection, reason = self:Prepare(action, state, descriptor)
    if not projection then return nil, reason, true end
    local out = copy(tooltip)
    out.weaponCoefficient = projection.weaponPercent / 100
    out.weaponDirectFlat = projection.stackDamage
    out.warriorDevastateProjection = projection
    return out, nil, true
end

function D:Apply(state, candidate)
    local projection = candidate and candidate.tooltip
        and candidate.tooltip.warriorDevastateProjection
    if not (projection and projection.warriorDevastate == true
        and projection.spellId == Owner.SPELL_ID
        and candidate.action and candidate.action.spellId == projection.spellId
        and candidate.targetKey == projection.targetKey
        and tonumber(candidate.effectDelivery) == 1
        and projection.sunderRefreshDuration) then return false end
    local record = XelAssist.Graph.HostileState
        and XelAssist.Graph.HostileState:ByKey(state, projection.targetKey)
    local aura = record and record.projectedAuras
        and record.projectedAuras[Owner.SUNDER_NAME]
    if not (aura and aura.mine == true and aura.applicationProbability == 1
        and tonumber(aura.stacks) == projection.sunderStacks) then return false end
    aura.duration = projection.sunderRefreshDuration
    aura.remaining = projection.sunderRefreshDuration
    return true
end
