-- Search-pure Battle Shout projection. The action earns no fixed buff utility;
-- descendants value only the main-hand damage added by its exact melee AP.
-- Server flat threat is retained as a bound, never guessed per hostile.
XelAssist.Graph.WarriorBattleShout = {}
local B = XelAssist.Graph.WarriorBattleShout
local PlayerThreat = XelAssist.Graph.PlayerThreat

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
        and XelAssist.Game.Player.WarriorBattleShout
end

local function root(state)
    local found, lane = state and state.warriorBattleShoutRoot,
        state and state.warriorBattleShoutRoot
            and state.warriorBattleShoutRoot.lane
    if not (type(found) == "table" and found.available == true
        and found.exact == true and found.portfolio == "warriorBattleShout"
        and type(lane) == "table" and lane.valid == true and lane.exact == true
        and finite(lane.speed, 0.01, 20)
        and finite(lane.damageMultiplier, 0.0001, 100)
        and lane.damageMultiplierUnits == "factor") then
        return nil, found and found.reason
            or "exact Warrior melee damage lane unavailable"
    end
    return found, nil
end

local function captured(action, tooltip)
    local owner = runtime()
    if not owner then return nil, "Battle Shout runtime unavailable", false end
    local found, reason, handled = owner:CapturedEvidence(tooltip)
    if handled then return found, reason, true end
    return owner:CapturedEvidence(action)
end

local function active(state)
    local component = state and state.warriorBattleShout
    if not (type(component) == "table" and component.available == true
        and component.exact == true and component.projected == true
        and component.active == true and component.evidenceExact == true
        and finite(component.attackPower, 0.0001, 100000)
        and finite(component.remaining, 0, 3600)) then return nil end
    if component.remaining <= 0 then return nil end
    return component
end

local function componentState(state)
    local component = state and state.warriorBattleShout
    if not (type(component) == "table" and component.available == true
        and component.exact == true and component.projected == true
        and component.evidenceExact == true
        and type(component.active) == "boolean"
        and finite(component.baselineAttackPower, 0, 100000)
        and type(component.baselineCorrectionExact) == "boolean") then
        return nil, "Battle Shout projection state unavailable"
    end
    if component.active == true and not active(state) then
        return nil, "active Battle Shout projection is incomplete"
    end
    if component.competingAttackPowerAura
        and not (finite(component.competingAttackPowerAura, 1, 4294967295)
            and math.floor(component.competingAttackPowerAura)
                == component.competingAttackPowerAura
            and (component.competingPermanent == true
                or finite(component.competingRemaining, 0.0001, 3600))) then
        return nil, "competing attack-power aura lifecycle unavailable"
    end
    return component, nil
end

function B:Attach(state)
    if type(state) ~= "table" then return false end
    local owner = runtime()
    local observed = owner and owner:ObserveRoot() or nil
    local profile = observed and observed.activeProfile
    local available = observed and observed.available == true
        and observed.exact == true
    state.warriorBattleShoutRoot = observed
    state.warriorBattleShout = { available = available or false,
        exact = available or false, active = profile ~= nil,
        projected = true, evidenceExact = available or false,
        spellId = profile and profile.spellId or nil,
        attackPower = profile and profile.attackPower or nil,
        remaining = profile and observed.activeRemaining or nil,
        activeSource = profile and "root" or nil,
        baselineAttackPower = profile and profile.attackPower or 0,
        baselineCorrectionExact = observed
            and observed.auraBaselineExact == true or false,
        competingAttackPowerAura = observed
            and observed.competingAttackPowerAura or nil,
        competingRemaining = observed and observed.competingRemaining or nil,
        competingPermanent = observed and observed.competingPermanent or nil,
        source = "projected Battle Shout consequence" }
    return available or false
end

function B:Copy(source, target)
    if not (source and target and source.warriorBattleShoutRoot
        and source.warriorBattleShout) then return false end
    target.warriorBattleShoutRoot = source.warriorBattleShoutRoot
    target.warriorBattleShout = copy(source.warriorBattleShout)
    return true
end

function B:Is(action, tooltip)
    local _, _, handled = captured(action, tooltip)
    return handled == true
end

local function targetExact(descriptor)
    return descriptor and descriptor.unit == "player"
        and descriptor.relation ~= "hostile"
end

function B:Prepare(action, state, descriptor, tooltip)
    local found, reason, handled = captured(action, tooltip)
    if not handled then return nil, nil, false end
    if not found then return nil, reason or "Battle Shout profile unavailable", true end
    if not action or (action.actor or "player") ~= "player" then
        return nil, "Battle Shout is player-owned", true
    end
    if not targetExact(descriptor) then
        return nil, "Battle Shout requires the player", true
    end
    local observed
    observed, reason = root(state)
    if not observed then return nil, reason, true end
    local component
    component, reason = componentState(state)
    if not component then return nil, reason, true end
    if observed.grouped then
        return nil, "Battle Shout group fanout is unresolved", true
    end
    if component.baselineCorrectionExact ~= true then
        return nil, component.baselineReason
            or "Battle Shout attack-power baseline is unresolved", true
    end
    if component.competingAttackPowerAura then
        return nil, "competing melee attack-power aura is active", true
    end
    local current = active(state)
    if current then
        return nil, current.activeSource == "root"
            and "live Battle Shout baseline is already active"
            or "projected Battle Shout is active", true
    end
    return { kind = "warriorBattleShout", classMechanic = "warriorBattleShout",
        spellId = found.spellId, attackPower = found.attackPower,
        duration = found.duration, cost = found.cost, powerType = found.powerType,
        flatThreat = found.flatThreat, flatThreatExact = true,
        flatThreatModel = found.flatThreatModel, evidenceExact = true,
        source = found.source }, nil, true
end

function B:Blocker(action, state, descriptor, tooltip)
    local projection, reason, handled = self:Prepare(
        action, state, descriptor, tooltip)
    if not handled then return nil, false end
    return projection and nil or reason or "Battle Shout unavailable", true,
        projection
end

function B:Score(context, projection)
    if not (context and projection and projection.kind == "warriorBattleShout"
        and projection.evidenceExact == true) then return false end
    context.power, context.expectedPower, context.effectivePower = 0, 0, 0
    context.value, context.estimated = 0, false
    context.kind = "classMechanic"
    context.warriorBattleShoutAttackPower = projection.attackPower
    context.warriorBattleShoutFlatThreatEvidence = projection.flatThreat
    context.reason = "enables exact main-hand attack-power damage"
    return true
end

local function invalidateThreat(state, component, projection)
    if state.inCombat == false then
        component.flatThreatMinimum, component.flatThreatMaximum = 0, 0
        component.flatThreatApplicationExact = true
        return
    end
    local maximum, multiplierExact, multiplier = projection.flatThreat, false, 1
    if PlayerThreat and PlayerThreat.Scale then
        maximum, multiplierExact, multiplier = PlayerThreat:Scale(
            state, "player", projection.flatThreat, 0)
    end
    component.flatThreatMinimum = 0
    component.flatThreatMaximum = math.max(0, tonumber(maximum) or 0)
    component.flatThreatApplicationExact = false
    component.flatThreatMultiplierExact = multiplierExact
    component.flatThreatMultiplier = multiplier
    component.flatThreatReason = "hostile-reference count is hidden"
    local hostiles, index, record = state.hostiles, nil, nil
    for index = 1, table.getn(hostiles and hostiles.order or {}) do
        record = hostiles.byKey and hostiles.byKey[hostiles.order[index]]
        if record and record.dead ~= true then
            record.threat = record.threat or {}
            record.threat.playerDeltaExact = false
            record.threat.containsUnresolvedBattleShoutThreat = true
        end
    end
    state.targetPlayerThreatDeltaExact = false
end

function B:Apply(state, candidate)
    local projection = candidate and candidate.classMechanicProjection
        or candidate and candidate.warriorBattleShoutProjection
    if not (projection and projection.kind == "warriorBattleShout"
        and projection.evidenceExact == true) then return false end
    local descriptor = { unit = candidate.target or "player",
        relation = candidate.targetRelation or "friendly" }
    local prepared = self:Prepare(candidate.action, state, descriptor,
        candidate.tooltip)
    if not prepared or prepared.spellId ~= projection.spellId
        or prepared.attackPower ~= projection.attackPower
        or prepared.duration ~= projection.duration then return false end
    local component = state.warriorBattleShout
    component.available, component.exact = true, true
    component.active, component.projected = true, true
    component.evidenceExact, component.spellId = true, projection.spellId
    component.activeSource, component.expired = "projected", nil
    component.attackPower, component.remaining =
        projection.attackPower, projection.duration
    component.duration, component.source = projection.duration, projection.source
    component.flatThreatEvidence = projection.flatThreat
    component.flatThreatEvidenceExact = projection.flatThreatExact
    component.flatThreatModel = projection.flatThreatModel
    invalidateThreat(state, component, projection)
    return true
end

function B:Advance(state, elapsed)
    elapsed = finite(elapsed, 0, 3600)
    local component = componentState(state)
    if not elapsed or not component then return 0 end
    if component.active == true then
        component.remaining = math.max(0,
            (finite(component.remaining, 0, 3600) or 0) - elapsed)
        if component.remaining <= 0 then
            component.active, component.attackPower = false, nil
            component.spellId, component.activeSource = nil, nil
            component.expired = true
        end
    end
    if component.competingAttackPowerAura and component.competingRemaining then
        component.competingRemaining = math.max(0,
            component.competingRemaining - elapsed)
        if component.competingRemaining <= 0 then
            component.competingAttackPowerAura = nil
            component.competingRemaining = nil
            component.baselineCorrectionExact = false
            component.baselineReason =
                "competing attack-power baseline expired without exact magnitude"
        end
    end
    return component.active and component.remaining or 0
end

local function attackPowerDelta(state)
    local component, reason = componentState(state)
    if not component then return nil, reason end
    if component.baselineCorrectionExact ~= true then
        return nil, component.baselineReason
            or "Battle Shout attack-power baseline is unresolved"
    end
    local current = component.active and component.attackPower or 0
    return current - component.baselineAttackPower, nil
end

function B:MainHandWhiteBonus(state)
    if state and state.playerForm and state.playerForm.projected == true then
        return nil, false, "projected Warrior stance melee lane unavailable"
    end
    local observed, reason = root(state)
    if not observed then return nil, false, reason end
    local delta
    delta, reason = attackPowerDelta(state)
    if delta == nil then return nil, false, reason end
    return delta / 14 * observed.lane.speed
        * observed.lane.damageMultiplier, false, nil
end

local function weaponDescriptor(action, tooltip)
    local found = tooltip and tooltip.warriorMainHandWeaponEvidence
    if not (type(found) == "table" and found.valid == true
        and found.exact == true and found.portfolio == "warriorBattleShout"
        and found.attackType == "main" and found.weaponEffectCount == 1
        and tonumber(action and action.spellId) == tonumber(found.spellId)
        and tonumber(tooltip.weaponCoefficient)
            == tonumber(found.weaponCoefficient)
        and (tooltip.weaponNormalized == true) == (found.normalized == true)) then
        return nil
    end
    return found
end

function B:WeaponActionBonus(action, tooltip, state, evidence)
    local found = weaponDescriptor(action, tooltip)
    if not found then return nil, false,
        "exact Warrior main-hand weapon evidence unavailable" end
    if state and state.playerForm and state.playerForm.projected == true then
        return nil, false, "projected Warrior stance melee lane unavailable"
    end
    local observed, reason = root(state)
    if not observed then return nil, false,
        reason or "exact Warrior melee damage lane unavailable" end
    local delta
    delta, reason = attackPowerDelta(state)
    if delta == nil then return nil, false, reason end
    local speed, percent = observed.lane.speed, observed.lane.damageMultiplier
    if found.normalized then
        if not (type(evidence) == "table" and evidence.exact == true
            and evidence.normalized == true
            and finite(evidence.normalizedSpeed, 0.01, 20)
            and finite(evidence.damagePercent, 0.0001, 100)) then
            return nil, false, "exact normalized main-hand lane unavailable"
        end
        speed, percent = evidence.normalizedSpeed, evidence.damagePercent
    end
    return delta / 14 * speed * percent
        * found.weaponCoefficient, false, nil
end
