-- Search-pure Fel Domination setup and one-use summon consequence. The setup
-- has zero standalone utility; only a root-sealed affected summon can close
-- its bounded strategic lane and consume the projected charge.
XelAssist.Graph.WarlockFelDomination = {}
local F = XelAssist.Graph.WarlockFelDomination
F.CONSUMER_KEY = "warlockFelDomination:affectedSummon"

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
        and XelAssist.Game.Player.WarlockFelDomination
end

local function exactState(state)
    local owner = runtime()
    local found = state and state.warlockFelDomination
    local profile = found and found.profile
    if not (owner and found and found.available == true and found.exact == true
        and type(profile) == "table" and profile.valid == true
        and profile.exact == true and profile.spellId == owner.SPELL_ID
        and profile.family == owner.WARLOCK_FAMILY
        and profile.summonMask == owner.SUMMON_MASK
        and profile.charges == 1 and profile.duration == owner.DURATION
        and profile.castModifier == owner.CAST_MODIFIER
        and profile.castFlat == owner.CAST_FLAT
        and profile.costModifier == owner.COST_MODIFIER
        and profile.costPercent == owner.COST_PERCENT) then return nil end
    if found.active == true
        and not finite(found.remaining, 0.000001, owner.DURATION) then return nil end
    return found
end

function F:Copy(source, target)
    if not (source and target) then return false end
    local found = source.warlockFelDomination
    target.warlockFelDomination = found and copy(found) or nil
    if target.warlockFelDomination and found.profile then
        target.warlockFelDomination.profile = copy(found.profile)
    end
    return target.warlockFelDomination ~= nil
end

function F:PrepareSetup(action, state, tooltip)
    local owner = runtime()
    if not (owner and (owner:Is(action) or owner:Is(tooltip))) then
        return nil, nil, false
    end
    local evidence = owner:Evidence(tooltip) or owner:Evidence(action)
    local current = exactState(state)
    if not evidence then
        return nil, "Fel Domination root evidence unavailable", true
    elseif not current then
        return nil, "Fel Domination aura state unavailable", true
    elseif current.active == true then
        return nil, "Fel Domination already active", true
    elseif tooltip and tooltip.cost ~= nil
        and finite(tooltip.cost, 0, 1000000000) ~= 0 then
        return nil, "Fel Domination activation cost is not exact", true
    elseif tooltip and tooltip.cast ~= nil
        and finite(tooltip.cast, 0, 600) ~= 0 then
        return nil, "Fel Domination activation cast is not exact", true
    end
    local out = copy(tooltip)
    out.cost, out.cast, out.powerType = 0, 0, owner.MANA
    out.warlockFelDominationTransition = {
        kind = "warlockFelDomination", spellId = owner.SPELL_ID,
        charges = 1, duration = owner.DURATION,
        summonMask = evidence.summonMask,
        castModifier = evidence.castModifier, castFlat = evidence.castFlat,
        costModifier = evidence.costModifier, costPercent = evidence.costPercent,
        evidenceExact = true, source = evidence.source,
    }
    out.classMechanic = "warlockFelDomination"
    return out, nil, true
end

local function validContract(action, found)
    return found and found.claimed == true and found.exact == true
        and found.eligible == true and found.spellId == action.spellId
        and found.family == 5 and found.summonEffect == 56
        and finite(found.baselineCast, 0.001, 600)
        and finite(found.affectedCast, 0, 600)
        and finite(found.baselineCost, 0, 1000000000)
        and finite(found.affectedCost, 0, 1000000000)
        and finite(found.savedCast, 0.000001, 600)
        and finite(found.savedMana, 0, 1000000000)
end

function F:PrepareLegal(action, state, tooltip, actionStart)
    local prepared, reason, handled = self:PrepareSetup(action, state, tooltip)
    if handled then return prepared, reason, true end
    local found = tooltip and tooltip.warlockFelDominationSummon
    if not found then return tooltip, nil, false end
    local current = exactState(state)
    if not current then
        return nil, "Fel Domination aura state unavailable", true
    elseif current.active ~= true then
        if not validContract(action, found) then return tooltip, nil, false end
        local out = copy(tooltip)
        out.cast, out.cost = found.baselineCast, found.baselineCost
        out.warlockFelDominationConsumption = nil
        out.warlockFelDominationExpiredBeforeStart = nil
        return out, nil, true
    elseif not validContract(action, found) then
        return nil, found.reason
            or "Fel Domination summon consequence unavailable", true
    end
    local now = finite(state and state.time, 0, 1000000000)
    actionStart = finite(actionStart, now or 0, 1000000000)
    if not now or actionStart == nil then
        return nil, "Fel Domination summon start time unavailable", true
    elseif actionStart - now >= current.remaining then
        local out = copy(tooltip)
        out.cast, out.cost = found.baselineCast, found.baselineCost
        out.warlockFelDominationConsumption = nil
        out.warlockFelDominationExpiredBeforeStart = true
        return out, nil, true
    end
    local out = copy(tooltip)
    out.cast, out.cost = found.affectedCast, found.affectedCost
    out.warlockFelDominationExpiredBeforeStart = nil
    out.warlockFelDominationConsumption = {
        exact = true, spellId = action.spellId, epoch = current.epoch,
        summonEffect = found.summonEffect, baselineCast = found.baselineCast,
        affectedCast = found.affectedCast, baselineCost = found.baselineCost,
        affectedCost = found.affectedCost, savedCast = found.savedCast,
        savedMana = found.savedMana, masterSummonerRank = found.masterSummonerRank,
        stackVerified = found.stackVerified, admittedAtStart = actionStart,
        source = found.source,
    }
    return out, nil, true
end

local function admissionShape(tooltip)
    local marker = tooltip and tooltip.warlockFelDominationConsumption
    return tonumber(tooltip and tooltip.cast), tonumber(tooltip and tooltip.cost),
        marker and marker.epoch or nil,
        tooltip and tooltip.warlockFelDominationExpiredBeforeStart == true
end

local function sameAdmission(left, right)
    local leftCast, leftCost, leftEpoch, leftExpired = admissionShape(left)
    local rightCast, rightCost, rightEpoch, rightExpired = admissionShape(right)
    return leftCast == rightCast and leftCost == rightCost
        and leftEpoch == rightEpoch and leftExpired == rightExpired
end

-- Fel Domination can expire while a future node waits for mana, GCD, or an
-- actor clock. Recompute once from the resulting absolute start time; the
-- baseline is never cheaper or faster, so a second change is incoherent.
function F:SettleAdmission(action, state, tooltip)
    local admission = XelAssist.Graph and XelAssist.Graph.ActionAdmission
    if not (admission and type(admission.Start) == "function") then
        return nil, nil, "action admission unavailable"
    end
    local prepared, reason, handled = self:PrepareLegal(
        action, state, tooltip, state and state.time or 0)
    if handled and not prepared then return nil, nil, reason end
    if handled then tooltip = prepared end
    local actionStart, blocker = admission:Start(action, state, tooltip)
    if blocker then return nil, nil, blocker end
    prepared, reason, handled = self:PrepareLegal(
        action, state, tooltip, actionStart)
    if handled and not prepared then return nil, nil, reason end
    if not handled or sameAdmission(tooltip, prepared) then
        return actionStart, handled and prepared or tooltip, nil
    end
    tooltip = prepared
    actionStart, blocker = admission:Start(action, state, tooltip)
    if blocker then return nil, nil, blocker end
    local stable, stableReason, stableHandled = self:PrepareLegal(
        action, state, tooltip, actionStart)
    if stableHandled and not stable then return nil, nil, stableReason end
    if stableHandled and not sameAdmission(tooltip, stable) then
        return nil, nil, "Fel Domination admission did not stabilize"
    end
    return actionStart, stableHandled and stable or tooltip, nil
end

function F:Score(context, projection)
    local transition = projection and projection.warlockFelDominationTransition
        or context and context.tooltip
            and context.tooltip.warlockFelDominationTransition
    local owner = runtime()
    if not (owner and transition and transition.evidenceExact == true
        and transition.kind == "warlockFelDomination"
        and transition.spellId == owner.SPELL_ID and transition.charges == 1
        and transition.duration == owner.DURATION
        and transition.summonMask == owner.SUMMON_MASK
        and transition.castModifier == owner.CAST_MODIFIER
        and transition.castFlat == owner.CAST_FLAT
        and transition.costModifier == owner.COST_MODIFIER
        and transition.costPercent == owner.COST_PERCENT) then
        return false, "Fel Domination transition evidence unavailable"
    end
    context.power, context.expectedPower, context.effectivePower = 0, 0, 0
    context.value, context.estimated = 0, false
    context.reason = "arms one exact summon cast and mana consequence"
    return true
end

local function transition(candidate)
    return candidate and candidate.warlockFelDominationTransition
        or candidate and candidate.tooltip
            and candidate.tooltip.warlockFelDominationTransition
        or candidate and candidate.classMechanicProjection
            and candidate.classMechanicProjection.warlockFelDominationTransition
end

function F:Apply(state, candidate)
    local projected, owner, current = transition(candidate), runtime(),
        exactState(state)
    if not (owner and current and current.active ~= true and projected
        and projected.kind == "warlockFelDomination"
        and projected.evidenceExact == true
        and projected.spellId == owner.SPELL_ID and projected.charges == 1
        and projected.duration == owner.DURATION
        and projected.summonMask == owner.SUMMON_MASK
        and projected.castModifier == owner.CAST_MODIFIER
        and projected.castFlat == owner.CAST_FLAT
        and projected.costModifier == owner.COST_MODIFIER
        and projected.costPercent == owner.COST_PERCENT) then return false end
    local at = finite(state.time, 0, 1000000000) or 0
    current.active, current.remaining = true, owner.DURATION
    current.epoch = tostring(owner.SPELL_ID) .. ":projected:" .. tostring(at)
    current.projected, current.consumed, current.expired = true, nil, nil
    current.source = "projected exact Fel Domination activation"
    return true
end

function F:Consume(state, candidate)
    local marker = candidate and candidate.tooltip
        and candidate.tooltip.warlockFelDominationConsumption
    local action, current = candidate and candidate.action, exactState(state)
    local facts = action and action.facts or {}
    if not (marker and marker.exact == true and action and current
        and current.consumed ~= true
        and marker.epoch == current.epoch and marker.spellId == action.spellId
        and marker.summonEffect == 56 and facts.kind == "summon"
        and (action.actor or "player") == "player"
        and action.executor == "playerSpell"
        and tonumber(candidate.cast) == marker.affectedCast
        and tonumber(candidate.cost) == marker.affectedCost
        and candidate.tooltip.cast == marker.affectedCast
        and candidate.tooltip.cost == marker.affectedCost) then return false end
    current.active, current.remaining = false, 0
    current.consumed, current.expired, current.projected = true, nil, true
    current.savedCast, current.savedMana = marker.savedCast, marker.savedMana
    current.source = "projected admitted Fel Domination summon consumption"
    return true
end

function F:Advance(state, elapsed)
    local current = exactState(state)
    elapsed = finite(elapsed, 0, 600)
    if not current or current.active ~= true or not elapsed or elapsed <= 0 then
        return false
    end
    current.remaining = math.max(0, current.remaining - elapsed)
    if current.remaining <= 0 then
        current.active, current.expired, current.projected = false, true, true
        current.source = "projected Fel Domination expiration"
    end
    return true
end

function F:PotentialConsumer(facts)
    local found = facts and facts.warlockFelDominationSummon
    return found and found.claimed == true and found.exact == true
        and found.eligible == true and found.summonEffect == 56
        and (finite(found.savedCast, 0.000001, 600)
            or finite(found.savedMana, 0.000001, 1000000000)) and true or false
end

function F:ConsumerKey(facts)
    return self:PotentialConsumer(facts) and self.CONSUMER_KEY or nil
end

function F:StrategicSetup(tooltip)
    local transition = tooltip and tooltip.warlockFelDominationTransition
    local owner = runtime()
    if not (owner and transition and transition.evidenceExact == true
        and transition.kind == "warlockFelDomination"
        and transition.spellId == owner.SPELL_ID and transition.charges == 1
        and transition.duration == owner.DURATION
        and transition.summonMask == owner.SUMMON_MASK
        and transition.castModifier == owner.CAST_MODIFIER
        and transition.castFlat == owner.CAST_FLAT
        and transition.costModifier == owner.COST_MODIFIER
        and transition.costPercent == owner.COST_PERCENT) then return nil end
    return { key = "warlockFelDomination:" .. tostring(transition.spellId),
        consumerKey = self.CONSUMER_KEY }
end
