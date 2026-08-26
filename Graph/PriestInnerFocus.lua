-- Search-pure Inner Focus transition and one-charge mana consequence. The
-- root owner seals exact family-mask eligibility and baseline cost; branches
-- only copy, apply, and consume that contract. Critical utility is withheld.
XelAssist.Graph.PriestInnerFocus = {}
local I = XelAssist.Graph.PriestInnerFocus
I.CONSUMER_KEY = "priestInnerFocus:affectedCost"

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
        and XelAssist.Game.Player.PriestInnerFocus
end

local function exactState(state)
    local found = state and state.priestInnerFocus
    if not (found and found.available == true and found.exact == true
        and type(found.profile) == "table" and found.profile.valid == true
        and found.profile.exact == true) then return nil end
    return found
end

function I:Copy(source, target)
    if not (source and target) then return false end
    local found = source.priestInnerFocus
    target.priestInnerFocus = found and copy(found) or nil
    if target.priestInnerFocus and found.profile then
        target.priestInnerFocus.profile = copy(found.profile)
    end
    return target.priestInnerFocus ~= nil
end

function I:PrepareSetup(action, state, tooltip)
    local owner = runtime()
    if not (owner and (owner:Is(action) or owner:Is(tooltip))) then
        return nil, nil, false
    end
    local evidence = owner:Evidence(tooltip) or owner:Evidence(action)
    local current = exactState(state)
    if not evidence then
        return nil, "Inner Focus root evidence unavailable", true
    elseif not current then
        return nil, "Inner Focus aura state unavailable", true
    elseif current.active == true then
        return nil, "Inner Focus already active", true
    elseif finite(tooltip and tooltip.cost, 0, 1000000000) ~= 0 then
        return nil, "Inner Focus activation cost is not exact", true
    end
    local out = copy(tooltip)
    out.cost, out.powerType = 0, owner.MANA
    out.priestInnerFocusTransition = { kind = "priestInnerFocus",
        spellId = owner.SPELL_ID, charges = 1, indefinite = true,
        costMask = evidence.costMask, critMask = evidence.critMask,
        costPercent = evidence.costPercent,
        critFlatUnvalued = evidence.critFlat,
        evidenceExact = true, source = evidence.source }
    out.classMechanic = "priestInnerFocus"
    return out, nil, true
end

function I:PrepareLegal(action, state, tooltip)
    local prepared, reason, handled = self:PrepareSetup(action, state, tooltip)
    if handled then return prepared, reason, true end
    local contract = tooltip and tooltip.priestInnerFocusCost
    if not contract then return tooltip, nil, false end
    local current = exactState(state)
    if not current then
        return nil, "Inner Focus aura state unavailable", true
    elseif current.active ~= true then
        if contract.claimed == true and contract.exact == true
            and contract.costAffected == true then
            local baseline = finite(contract.baselineCost, 0.001, 1000000000)
            if not baseline then
                return nil, "Inner Focus baseline mana cost unavailable", true
            end
            local out = copy(tooltip)
            out.cost = baseline
            return out, nil, true
        end
        return tooltip, nil, true
    end
    if contract.claimed ~= true or contract.spellId ~= action.spellId
        or contract.exact ~= true then
        return nil, contract.reason
            or "Inner Focus cost consequence unavailable", true
    end
    if contract.costAffected ~= true then return tooltip, nil, true end
    local baseline = finite(contract.baselineCost, 0.001, 1000000000)
    if not baseline then
        return nil, "Inner Focus baseline mana cost unavailable", true
    end
    local out = copy(tooltip)
    out.cost = 0
    out.priestInnerFocusConsumption = { exact = true,
        spellId = action.spellId, baselineCost = baseline,
        costPercent = current.profile.costPercent,
        critFlatUnvalued = contract.critFlatUnvalued,
        source = contract.source }
    return out, nil, true
end

function I:Score(context, projection)
    local transition = projection and projection.priestInnerFocusTransition
        or context and context.tooltip
            and context.tooltip.priestInnerFocusTransition
    local owner = runtime()
    if not (owner and transition and transition.evidenceExact == true
        and transition.kind == "priestInnerFocus"
        and transition.spellId == owner.SPELL_ID and transition.charges == 1
        and transition.indefinite == true
        and transition.costMask == owner.COST_MASK
        and transition.critMask == owner.CRIT_MASK
        and transition.costPercent == owner.COST_PERCENT) then
        return false, "Inner Focus transition evidence unavailable"
    end
    context.power, context.expectedPower, context.effectivePower = 0, 0, 0
    context.value, context.estimated = 0, false
    context.reason = "arms an exact one-use spell modifier"
    return true
end

function I:Apply(state, candidate)
    local transition = candidate and candidate.priestInnerFocusTransition
        or candidate and candidate.tooltip
            and candidate.tooltip.priestInnerFocusTransition
        or candidate and candidate.classMechanicProjection
            and candidate.classMechanicProjection.priestInnerFocusTransition
    local current, owner = exactState(state), runtime()
    if not (current and owner and current.active ~= true and transition
        and transition.kind == "priestInnerFocus"
        and transition.evidenceExact == true
        and transition.spellId == owner.SPELL_ID and transition.charges == 1
        and transition.costMask == owner.COST_MASK
        and transition.critMask == owner.CRIT_MASK
        and transition.costPercent == owner.COST_PERCENT) then return false end
    current.active, current.projected, current.consumed = true, true, nil
    current.source = "projected exact Inner Focus activation"
    return true
end

function I:Consume(state, candidate)
    local marker = candidate and candidate.tooltip
        and candidate.tooltip.priestInnerFocusConsumption
    local action, current = candidate and candidate.action, exactState(state)
    if not (marker and marker.exact == true and action and current
        and current.active == true and marker.spellId == action.spellId
        and finite(marker.baselineCost, 0.001, 1000000000)
        and tonumber(candidate.cost) == 0) then return false end
    current.active, current.consumed = false, true
    current.savedMana, current.projected = marker.baselineCost, true
    current.source = "projected exact Inner Focus charge consumption"
    return true
end

function I:PotentialConsumer(facts)
    local found = facts and facts.priestInnerFocusCost
    return found and found.claimed == true and found.exact == true
        and found.costAffected == true
        and finite(found.baselineCost, 0.001, 1000000000) ~= nil or false
end

function I:ConsumerKey(facts)
    return self:PotentialConsumer(facts) and self.CONSUMER_KEY or nil
end

-- Candidate and ResourceInvestment consume this mechanical identity. It opens
-- one bounded, zero-value setup lane; only an exact affected cost can close it.
function I:StrategicSetup(tooltip)
    local transition = tooltip and tooltip.priestInnerFocusTransition
    local owner = runtime()
    if not (owner and transition and transition.evidenceExact == true
        and transition.kind == "priestInnerFocus"
        and transition.spellId == owner.SPELL_ID and transition.charges == 1
        and transition.indefinite == true
        and transition.costMask == owner.COST_MASK
        and transition.critMask == owner.CRIT_MASK
        and transition.costPercent == owner.COST_PERCENT) then return nil end
    return { key = "priestInnerFocus:" .. tostring(transition.spellId),
        consumerKey = self.CONSUMER_KEY }
end
