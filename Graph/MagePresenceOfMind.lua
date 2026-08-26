-- Search-pure Presence of Mind transition and one-charge cast-time effect.
-- Root facts prove both eligibility and the cast that would occur without the
-- aura; graph value therefore emerges only through an earlier later action.
XelAssist.Graph.MagePresenceOfMind = {}
local P = XelAssist.Graph.MagePresenceOfMind
P.CONSUMER_KEY = "magePresenceOfMind:affectedCast"

local function finite(value, low, high)
    value = tonumber(value)
    if value == nil or value ~= value or value == math.huge
        or value == -math.huge or value < low or value > high then return nil end
    return value
end

local function copy(source)
    local out, key, value = {}, nil, nil
    for key, value in pairs(source or {}) do out[key] = value end
    return out
end

local function runtime()
    return XelAssist.Game and XelAssist.Game.Player
        and XelAssist.Game.Player.MagePresenceOfMind
end

local function exactState(state)
    local found, owner = state and state.magePresenceOfMind, runtime()
    local profile = found and found.profile
    if not (owner and found and found.available == true and found.exact == true
        and type(profile) == "table" and profile.valid == true
        and profile.exact == true and profile.spellId == owner.SPELL_ID
        and profile.family == owner.MAGE_FAMILY
        and profile.familyFlags == owner.FAMILY_FLAGS
        and profile.affectMask == owner.AFFECT_MASK
        and profile.modifier == owner.CASTING_TIME_MODIFIER
        and profile.modifierPercent == owner.MODIFIER_PERCENT
        and profile.charges == 1 and profile.indefinite == true) then return nil end
    return found
end

function P:Copy(source, target)
    if not (source and target) then return false end
    local found = source.magePresenceOfMind
    target.magePresenceOfMind = found and copy(found) or nil
    if target.magePresenceOfMind and found.profile then
        target.magePresenceOfMind.profile = copy(found.profile)
    end
    return target.magePresenceOfMind ~= nil
end

function P:PrepareSetup(action, state, tooltip)
    local owner = runtime()
    if not (owner and (owner:Is(action) or owner:Is(tooltip))) then
        return nil, nil, false
    end
    local evidence = owner:Evidence(tooltip) or owner:Evidence(action)
    local current = exactState(state)
    if not evidence then
        return nil, "Presence of Mind root evidence unavailable", true
    elseif not current then
        return nil, "Presence of Mind aura state unavailable", true
    elseif current.active == true then
        return nil, "Presence of Mind already active", true
    elseif tooltip and tooltip.cost ~= nil
        and finite(tooltip.cost, 0, 1000000000) ~= 0 then
        return nil, "Presence of Mind activation cost is not exact", true
    end
    local out = copy(tooltip)
    out.cost, out.powerType = 0, 0
    out.magePresenceOfMindTransition = {
        kind = "magePresenceOfMind", spellId = owner.SPELL_ID,
        charges = 1, indefinite = true, affectMask = evidence.affectMask,
        modifier = evidence.modifier,
        modifierPercent = evidence.modifierPercent,
        evidenceExact = true, source = evidence.source,
    }
    out.classMechanic = "magePresenceOfMind"
    return out, nil, true
end

function P:PrepareLegal(action, state, tooltip)
    local prepared, reason, handled = self:PrepareSetup(action, state, tooltip)
    if handled then return prepared, reason, true end
    local current = exactState(state)
    local playerSpell = action and (action.actor or "player") == "player"
        and action.executor == "playerSpell"
    local contract = tooltip and tooltip.magePresenceOfMindCast
    if not current then
        if contract then return nil, "Presence of Mind aura state unavailable", true end
        return tooltip, nil, false
    end
    if current.active ~= true then
        if not contract then return tooltip, nil, false end
        if contract.exact == true and contract.eligible == true then
            local baseline = finite(contract.baselineCast, 0.001, 9.999)
            if not baseline then
                return nil, "Presence of Mind baseline cast unavailable", true
            end
            local out = copy(tooltip)
            out.cast = baseline
            return out, nil, true
        end
        return tooltip, nil, true
    end
    if not playerSpell then return tooltip, nil, false end
    if not contract then
        return nil, "active Presence of Mind action contract unavailable", true
    elseif contract.claimed ~= true or contract.spellId ~= action.spellId
        or contract.exact ~= true then
        return nil, contract.reason
            or "Presence of Mind cast consequence unavailable", true
    elseif contract.eligible ~= true then
        return tooltip, nil, true
    end
    local baseline = finite(contract.baselineCast, 0.001, 9.999)
    if not baseline then
        return nil, "Presence of Mind baseline cast unavailable", true
    end
    local out = copy(tooltip)
    out.cast = 0
    out.magePresenceOfMindConsumption = {
        exact = true, spellId = action.spellId, baselineCast = baseline,
        modifierPercent = current.profile.modifierPercent,
        source = contract.source,
    }
    return out, nil, true
end

function P:Score(context, projection)
    local transition = projection and projection.magePresenceOfMindTransition
        or context and context.tooltip
            and context.tooltip.magePresenceOfMindTransition
    local owner = runtime()
    if not (owner and transition and transition.evidenceExact == true
        and transition.kind == "magePresenceOfMind"
        and transition.spellId == owner.SPELL_ID and transition.charges == 1
        and transition.indefinite == true
        and transition.affectMask == owner.AFFECT_MASK
        and transition.modifier == owner.CASTING_TIME_MODIFIER
        and transition.modifierPercent == owner.MODIFIER_PERCENT) then
        return false, "Presence of Mind transition evidence unavailable"
    end
    context.power, context.expectedPower, context.effectivePower = 0, 0, 0
    context.value, context.estimated = 0, false
    context.reason = "arms one exact instant-cast consequence"
    return true
end

function P:Apply(state, candidate)
    local transition = candidate and candidate.magePresenceOfMindTransition
        or candidate and candidate.tooltip
            and candidate.tooltip.magePresenceOfMindTransition
        or candidate and candidate.classMechanicProjection
            and candidate.classMechanicProjection.magePresenceOfMindTransition
    local current, owner = exactState(state), runtime()
    if not (current and owner and current.active ~= true and transition
        and transition.kind == "magePresenceOfMind"
        and transition.evidenceExact == true
        and transition.spellId == owner.SPELL_ID and transition.charges == 1
        and transition.indefinite == true
        and transition.affectMask == owner.AFFECT_MASK
        and transition.modifier == owner.CASTING_TIME_MODIFIER
        and transition.modifierPercent == owner.MODIFIER_PERCENT) then return false end
    current.active, current.projected, current.consumed = true, true, nil
    current.source = "projected exact Presence of Mind activation"
    return true
end

function P:Consume(state, candidate)
    local marker = candidate and candidate.tooltip
        and candidate.tooltip.magePresenceOfMindConsumption
    local action, current = candidate and candidate.action, exactState(state)
    if not (marker and marker.exact == true and action and current
        and current.active == true and marker.spellId == action.spellId
        and (action.actor or "player") == "player"
        and action.executor == "playerSpell"
        and finite(marker.baselineCast, 0.001, 9.999)
        and tonumber(candidate.cast) == 0
        and tonumber(candidate.tooltip.cast) == 0) then return false end
    current.active, current.consumed = false, true
    current.savedCastTime, current.projected = marker.baselineCast, true
    current.source = "projected exact Presence of Mind charge consumption"
    return true
end

function P:PotentialConsumer(facts)
    local found = facts and facts.magePresenceOfMindCast
    return found and found.claimed == true and found.exact == true
        and found.eligible == true
        and finite(found.baselineCast, 0.001, 9.999) ~= nil or false
end

function P:ConsumerKey(facts)
    return self:PotentialConsumer(facts) and self.CONSUMER_KEY or nil
end

-- Candidate and ResourceInvestment may use this mechanical identity to open
-- one bounded zero-value lane. Only an exact affected cast can close it.
function P:StrategicSetup(tooltip)
    local transition = tooltip and tooltip.magePresenceOfMindTransition
    local owner = runtime()
    if not (owner and transition and transition.evidenceExact == true
        and transition.kind == "magePresenceOfMind"
        and transition.spellId == owner.SPELL_ID and transition.charges == 1
        and transition.indefinite == true
        and transition.affectMask == owner.AFFECT_MASK
        and transition.modifier == owner.CASTING_TIME_MODIFIER
        and transition.modifierPercent == owner.MODIFIER_PERCENT) then return nil end
    return { key = "magePresenceOfMind:" .. tostring(transition.spellId),
        consumerKey = self.CONSUMER_KEY }
end
