-- Search-pure Blessing-of-Might consequence. The cast has no fixed utility;
-- descendants value only its root-relative main-hand attack-power delta.
XelAssist.Graph.PaladinMight = {}
local M = XelAssist.Graph.PaladinMight

local function finite(value, low, high)
    value = tonumber(value)
    if value == nil or value ~= value or value == math.huge
        or value == -math.huge or value < low or value > high then return nil end
    return value
end

local function integer(value, low, high)
    value = finite(value, low, high)
    return value and math.floor(value) == value and value or nil
end

local function copy(source)
    local out, key, value = {}, nil, nil
    for key, value in pairs(source or {}) do
        out[key] = type(value) == "table" and copy(value) or value
    end
    return out
end

local function runtime()
    return XelAssist.Game and XelAssist.Game.Player
        and XelAssist.Game.Player.PaladinMight
end

local function validGUID(value)
    return value ~= nil and value ~= "" and value ~= "0x000000000"
        and value ~= "0x0000000000000000"
end

local function profile(subject)
    local owner = runtime()
    return owner and owner:Profile(subject) or nil
end

local function embeddedProfile(value)
    return value and profile({ paladinMightEvidence = value,
        paladinMightProfile = value }) or nil
end

local function exactEffect(value, found)
    return type(value) == "table" and value.exact == true
        and value.kind == "playerMeleeAttackPowerAura"
        and value.actor == "recipient" and found
        and value.sourceSpellId == found.spellId
        and value.attackPower == found.attackPower
        and value.duration == found.duration
        and value.recipientShape == "single" and value or nil
end

local function rootPlayer(state)
    local root = state and state.paladinAuraState
    local player = root and root.player
    if not (root and root.available == true and player
        and player.available == true and player == root.byKey[root.playerKey]
        and validGUID(root.playerGUID) and player.guid == root.playerGUID
        and player.playerGUID == root.playerGUID
        and player.recipientRelation == "self") then return nil, nil end
    return root, player
end

local function exactRoot(state)
    local found, lane = state and state.paladinMightRoot,
        state and state.paladinMightRoot and state.paladinMightRoot.lane
    if not (found and found.available == true and found.exact == true
        and found.portfolio == "paladinMight" and type(lane) == "table"
        and lane.valid == true and lane.exact == true
        and finite(lane.speed, 0.01, 20)
        and finite(lane.damageMultiplier, 0.0001, 100)
        and lane.damageMultiplierUnits == "factor"
        and finite(found.baselineAttackPower, 0, 100000)) then return nil end
    if found.activeSpellId ~= nil then
        local current = embeddedProfile(found.activeProfile)
        if not (current and current.spellId == found.activeSpellId
            and current.attackPower == found.baselineAttackPower
            and finite(found.activeRemaining, 0.0001, 3600)) then return nil end
    elseif found.baselineAttackPower ~= 0 then return nil end
    return found
end

local function exactComponent(state)
    local component = state and state.paladinMight
    local observed = exactRoot(state)
    local baseline = component and finite(
        component.baselineAttackPower, 0, 100000)
    local current = component and finite(component.currentAttackPower, 0, 100000)
    local delta = component and finite(component.deltaAttackPower, -100000, 100000)
    if not (component and observed and component.available == true
        and component.exact == true and baseline == observed.baselineAttackPower
        and current and delta and delta == current - baseline) then
        return nil
    end
    if component.activeSpellId ~= nil then
        local found = embeddedProfile(component.activeProfile)
        if not (found and found.spellId == component.activeSpellId
            and found.attackPower == current
            and finite(component.remaining, 0.0001, 3600)
            and component.ownOtherBlessingSpellId == nil) then return nil end
    elseif current ~= 0 or component.activeProfile ~= nil
        or component.remaining ~= nil then return nil end
    if component.ownOtherBlessingSpellId ~= nil
        and not integer(component.ownOtherBlessingSpellId, 1, 4294967295) then
        return nil
    end
    return component
end

function M:Attach(state)
    if type(state) ~= "table" then return false end
    local owner, root, player = runtime(), rootPlayer(state)
    local observed = owner and root and owner:ObserveRoot(player, root.playerGUID)
    state.paladinMightRoot = observed
    local available = observed and observed.available == true
        and observed.exact == true
    state.paladinMight = { available = available or false,
        exact = available or false,
        baselineAttackPower = observed and observed.baselineAttackPower or 0,
        currentAttackPower = observed and observed.baselineAttackPower or 0,
        deltaAttackPower = 0,
        activeSpellId = observed and observed.activeSpellId,
        activeProfile = observed and observed.activeProfile
            and copy(observed.activeProfile) or nil,
        remaining = observed and observed.activeRemaining,
        ownOtherBlessingSpellId = observed
            and observed.ownOtherBlessingSpellId or nil,
        source = "projected Paladin Might consequence",
        reason = observed and observed.reason or "Might root evidence unavailable" }
    return available and exactComponent(state) ~= nil or false
end

function M:Copy(source, target)
    if not (source and target and source.paladinMightRoot
        and source.paladinMight) then return false end
    target.paladinMightRoot = source.paladinMightRoot
    target.paladinMight = copy(source.paladinMight)
    return exactComponent(target) ~= nil
end

local function exactSelf(state, projection)
    local root, player = rootPlayer(state)
    local friendlies = state and state.friendlies
    local record = root and friendlies and friendlies.byKey
        and friendlies.byKey[root.playerKey]
    if not (root and projection and projection.kind == "blessing"
        and projection.recipientKey == root.playerKey
        and projection.recipientGUID == root.playerGUID
        and projection.casterGUID == root.playerGUID
        and record and record.unit == "player" and record.relation == "self"
        and record.guid == root.playerGUID
        and player.guid == root.playerGUID) then return nil, nil end
    return root, player
end

local function claimed(facts)
    return facts and (facts.requiresExactPaladinMightProfile == true
        or facts.paladinMightEvidence ~= nil)
end

local function transition(mode, projection, component, found)
    local amount = found and found.attackPower or 0
    return { exact = true, kind = "paladinMightAttackPowerTransition",
        mode = mode, sourceSpellId = projection.actionSpellId,
        replacedMightSpellId = component.activeSpellId,
        fromAttackPower = component.currentAttackPower,
        toAttackPower = amount,
        currentChange = amount - component.currentAttackPower,
        projectedDelta = amount - component.baselineAttackPower,
        duration = found and found.duration or nil,
        profile = found and copy(found) or nil,
        source = "exact own blessing replacement and melee AP profile" }
end

function M:Prepare(state, projection, facts)
    local isMight = claimed(facts)
    if not isMight and not (projection and projection.kind == "blessing") then
        return nil, nil, false
    end
    local root = exactSelf(state, projection)
    if not root then
        return nil, isMight and "Might requires exact self recipient" or nil,
            isMight and true or false
    end
    local component = exactComponent(state)
    if not component or not exactRoot(state) then
        return nil, state and state.paladinMight and state.paladinMight.reason
            or "exact Paladin Might component unavailable", isMight
    end
    local found = profile(facts)
    if isMight then
        if not found or found.actionRepresented ~= true then
            return nil, "captured Might consequence unavailable", true
        end
        if component.ownOtherBlessingSpellId ~= nil then
            return nil, "displaced own blessing consequence is unresolved", true
        end
        if component.activeSpellId == found.spellId then
            return nil, "same Might rank already active", true
        end
        local supplied = exactEffect(facts and facts.paladinDownstreamEffect, found)
        if not supplied or facts.paladinEffectRepresented ~= true then
            return nil, "captured Might consequence unavailable", true
        end
        projection.paladinMightTransition = transition(
            "apply", projection, component, found)
        return projection, nil, true
    end
    if component.activeSpellId == nil then return nil, nil, false end
    if not (facts and facts.paladinEffectRepresented == true
        and type(projection.effect) == "table"
        and projection.effect.exact == true) then return nil, nil, false end
    projection.paladinMightTransition = transition(
        "remove", projection, component, nil)
    return projection, nil, true
end

local function exactTransition(value)
    if not (type(value) == "table" and value.exact == true
        and value.kind == "paladinMightAttackPowerTransition"
        and (value.mode == "apply" or value.mode == "remove")
        and integer(value.sourceSpellId, 1, 4294967295)
        and finite(value.fromAttackPower, 0, 100000)
        and finite(value.toAttackPower, 0, 100000)
        and finite(value.currentChange, -100000, 100000)
        and finite(value.projectedDelta, -100000, 100000)
        and value.currentChange == value.toAttackPower - value.fromAttackPower) then
        return nil
    end
    if value.mode == "apply" then
        local found = embeddedProfile(value.profile)
        if not (found and found.spellId == value.sourceSpellId
            and found.attackPower == value.toAttackPower
            and value.duration == found.duration) then return nil end
    elseif value.toAttackPower ~= 0 or value.profile ~= nil
        or value.duration ~= nil then return nil end
    return value
end

function M:Score(context, projection)
    local found = exactTransition(projection and projection.paladinMightTransition)
    local component = exactComponent(context and context.state)
    if not (found and component
        and found.fromAttackPower == component.currentAttackPower
        and found.projectedDelta == found.toAttackPower
            - component.baselineAttackPower) then
        return false, "exact Might projection unavailable"
    end
    context.power, context.expectedPower, context.effectivePower = 0, 0, 0
    context.value, context.estimated = 0, false
    context.kind = "classMechanic"
    context.reason = found.mode == "apply"
        and "changes exact main-hand attack-power damage"
        or "removes projected main-hand attack-power damage"
    return true
end

function M:Apply(state, projection)
    projection = projection and projection.classMechanicProjection or projection
    local found = exactTransition(projection and projection.paladinMightTransition)
    local component, root, player = exactComponent(state), rootPlayer(state)
    local aura = player and player.blessingsByCaster
        and player.blessingsByCaster[root.playerGUID]
    if not (found and component and root and aura and aura.exact == true
        and aura.spellId == found.sourceSpellId
        and aura.sourceGUID == root.playerGUID
        and type(aura.classification) == "table"
        and aura.classification.exact == true
        and aura.classification.kind == "blessing"
        and tonumber(aura.classification.spellId) == found.sourceSpellId
        and projection.recipientKey == root.playerKey
        and projection.recipientGUID == root.playerGUID
        and projection.casterGUID == root.playerGUID
        and projection.actionSpellId == found.sourceSpellId
        and projection.action
        and tonumber(projection.action.spellId) == found.sourceSpellId
        and found.replacedMightSpellId == component.activeSpellId
        and found.fromAttackPower == component.currentAttackPower
        and found.projectedDelta == found.toAttackPower
            - component.baselineAttackPower) then return false end
    component.currentAttackPower = found.toAttackPower
    component.deltaAttackPower = found.projectedDelta
    component.projected, component.expired = true, nil
    if found.mode == "apply" then
        component.activeSpellId = found.sourceSpellId
        component.activeProfile = copy(found.profile)
        component.remaining = found.duration
        component.ownOtherBlessingSpellId = nil
    else
        component.activeSpellId, component.activeProfile = nil, nil
        component.remaining = nil
        component.ownOtherBlessingSpellId = found.sourceSpellId
    end
    return exactComponent(state) ~= nil
end

function M:Advance(state, elapsed)
    elapsed = finite(elapsed, 0, 3600)
    local component = exactComponent(state)
    if not elapsed or not component or component.activeSpellId == nil then return 0 end
    component.remaining = math.max(0, component.remaining - elapsed)
    if component.remaining > 0 then return component.remaining end
    local root, player = rootPlayer(state)
    local aura = root and player and player.blessingsByCaster
        and player.blessingsByCaster[root.playerGUID]
    if aura and aura.spellId == component.activeSpellId
        and aura.sourceGUID == root.playerGUID then
        player.blessingsByCaster[root.playerGUID] = nil
    end
    component.activeSpellId, component.activeProfile = nil, nil
    component.currentAttackPower, component.remaining = 0, nil
    component.deltaAttackPower = -component.baselineAttackPower
    component.ownOtherBlessingSpellId, component.expired = nil, true
    return 0
end

local function attackPowerDelta(state)
    local component = exactComponent(state)
    return component and component.deltaAttackPower or nil
end

function M:MainHandWhiteBonus(state)
    local root = exactRoot(state)
    local delta = attackPowerDelta(state)
    if not root or delta == nil then
        return nil, false, "exact Paladin Might melee lane unavailable"
    end
    return delta / 14 * root.lane.speed
        * root.lane.damageMultiplier, false, nil
end

local function weaponDescriptor(action, tooltip)
    local found = tooltip and tooltip.paladinMainHandWeaponEvidence
    if not (type(found) == "table" and found.valid == true
        and found.exact == true and found.portfolio == "paladinMight"
        and found.attackType == "main" and found.weaponEffectCount == 1
        and tonumber(action and action.spellId) == tonumber(found.spellId)
        and tonumber(tooltip.weaponCoefficient)
            == tonumber(found.weaponCoefficient)
        and (tooltip.weaponNormalized == true) == (found.normalized == true)) then
        return nil
    end
    return found
end

function M:WeaponActionBonus(action, tooltip, state, evidence)
    local found, root = weaponDescriptor(action, tooltip), exactRoot(state)
    local delta = attackPowerDelta(state)
    if not found or not root or delta == nil then
        return nil, false, "exact Paladin Might weapon consequence unavailable"
    end
    local speed, percent = root.lane.speed, root.lane.damageMultiplier
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
