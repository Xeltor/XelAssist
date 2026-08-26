-- Search-pure Aspect-of-the-Hawk consequence. The component tracks ranged AP
-- relative to the root character-sheet lane so an already-active aura is not
-- counted twice and rank replacements contribute only their exact delta.
XelAssist.Graph.HunterHawk = {}
local H = XelAssist.Graph.HunterHawk

local function finite(value, low, high)
    value = tonumber(value)
    if value == nil or value ~= value or value == math.huge
        or value == -math.huge or value < low or value > high then return nil end
    return value
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
        and XelAssist.Game.Player.HunterHawk
end

local function validGUID(value)
    return value ~= nil and value ~= "" and value ~= "0x000000000"
        and value ~= "0x0000000000000000"
end

local function profile(subject)
    local owner = runtime()
    return owner and owner:Profile(subject) or nil
end

local function lane(state)
    local root = state and state.hunterMarkRoot
    local found = root and root.lane
    if not (root and root.valid == true and root.exact == true
        and root.portfolio == "hunterMark" and type(found) == "table"
        and found.valid == true and found.exact == true
        and finite(found.speed, 0.01, 20)
        and finite(found.damageMultiplier, 0.0001, 100)
        and found.damageMultiplierUnits == "factor") then return nil end
    return found
end

local function rootPlayer(state)
    local friendlies = state and state.friendlies
    local key = friendlies and friendlies.byUnit
        and friendlies.byUnit.player or nil
    local player = key and friendlies.byKey and friendlies.byKey[key] or nil
    if not (player and player.unit == "player" and player.relation == "self"
        and validGUID(player.guid)) then return nil, nil end
    return player, key
end

local function exactComponent(state)
    local component = state and state.hunterHawk
    local ranged = component and component.lane
    local baseline = component and finite(
        component.baselineRangedAttackPower, 0, 100000)
    local active = component and finite(
        component.activeRangedAttackPower, 0, 100000)
    local delta = component and finite(
        component.deltaRangedAttackPower, -100000, 100000)
    if not (component and component.available == true
        and component.exact == true and ranged and baseline
        and active and delta and delta == active - baseline
        and finite(ranged.speed, 0.01, 20)
        and finite(ranged.damageMultiplier, 0.0001, 100)
        and ranged.damageMultiplierUnits == "factor") then return nil end
    if component.activeSpellId ~= nil then
        local current = profile({ hunterHawkProfile = component.activeProfile })
        if not (current and current.spellId == component.activeSpellId
            and current.rangedAttackPower == active) then return nil end
    elseif active ~= 0 then return nil end
    return component
end

function H:Attach(state)
    if type(state) ~= "table" then return false end
    local owner, player = runtime(), rootPlayer(state)
    local ranged = lane(state)
    local observed = owner and player and owner:Observe(player.guid) or nil
    local out = { available = false, exact = false,
        baselineRangedAttackPower = 0, activeRangedAttackPower = 0,
        deltaRangedAttackPower = 0, lane = ranged and copy(ranged) or nil,
        source = "numeric Hawk aura plus root Hunter ranged damage lane" }
    state.hunterHawk = out
    if not player or not ranged or not (observed
        and observed.available == true and observed.exact == true
        and observed.guid == player.guid) then
        out.reason = observed and observed.reason
            or "exact Hunter Hawk root evidence unavailable"
        return false
    end
    out.available, out.exact = true, true
    out.activeSpellId = observed.activeSpellId
    out.activeRangedAttackPower = observed.activeRangedAttackPower
    out.baselineRangedAttackPower = observed.activeRangedAttackPower
    out.activeProfile = observed.activeProfile and copy(observed.activeProfile)
    return exactComponent(state) ~= nil
end

function H:Copy(source, target)
    if not (source and target and source.hunterHawk) then return false end
    target.hunterHawk = copy(source.hunterHawk)
    return exactComponent(target) ~= nil
end

local function exactSelf(state, descriptor)
    local player, key = rootPlayer(state)
    if not (player and descriptor and descriptor.unit == "player"
        and descriptor.relation == "self" and descriptor.key == key
        and descriptor.guid == player.guid
        and (descriptor.record == nil or descriptor.record == player)) then
        return nil, nil
    end
    return player, key
end

function H:Prepare(action, state, descriptor, tooltip)
    local facts = tooltip or action and action.facts or {}
    if facts.hunterHawk ~= true then return nil, nil, false end
    if (action.actor or "player") ~= "player" then
        return nil, "Hawk requires the player actor", true
    end
    local player, key = exactSelf(state, descriptor)
    if not player then return nil, "Hawk requires exact self recipient", true end
    local component, found = exactComponent(state), profile(facts)
    if not component then
        return nil, state and state.hunterHawk and state.hunterHawk.reason
            or "exact Hunter Hawk component unavailable", true
    end
    if not (found and facts.hunterAspectEffectRepresented == true) then
        return nil, "captured Hawk consequence unavailable", true
    end
    if component.activeSpellId == found.spellId then
        return nil, "same Hawk rank already active", true
    end
    local change = found.rangedAttackPower
        - component.activeRangedAttackPower
    local projected = found.rangedAttackPower
        - component.baselineRangedAttackPower
    return { kind = "hunterHawk", classMechanic = "hunterHawk",
        action = action, actionSpellId = found.spellId,
        recipientKey = key, recipientGUID = player.guid,
        profile = copy(found), hunterHawk = true,
        effect = { exact = true, kind = "playerRangedAttackPowerDelta",
            currentChange = change, projectedDelta = projected,
            rangedAttackPower = found.rangedAttackPower,
            sourceSpellId = found.spellId, recipient = "self" },
        source = "exact Hawk exclusive-aura ranged AP replacement" }, nil, true
end

function H:Blocker(action, state, descriptor, tooltip)
    local projection, reason, handled = self:Prepare(
        action, state, descriptor, tooltip)
    if not handled then return nil, false end
    if not projection then return reason, true, nil end
    return nil, true, projection
end

local function exactProjection(projection)
    local effect, found = projection and projection.effect,
        projection and profile({ hunterHawkProfile = projection.profile })
    if not (projection and projection.hunterHawk == true and found
        and type(effect) == "table" and effect.exact == true
        and effect.kind == "playerRangedAttackPowerDelta"
        and effect.sourceSpellId == found.spellId
        and effect.rangedAttackPower == found.rangedAttackPower
        and effect.recipient == "self") then return nil, nil end
    return effect, found
end

function H:Score(context, projection)
    local effect = exactProjection(projection)
    local component = exactComponent(context and context.state)
    if not effect or not component then
        return false, "exact Hawk projection unavailable"
    end
    context.power, context.expectedPower, context.effectivePower = 0, 0, 0
    context.value, context.estimated = 0, false
    context.kind = "classMechanic"
    context.reason = "changes exact ranged weapon damage"
    return true
end

function H:Apply(state, candidate)
    local projection = candidate and candidate.classMechanicProjection
        or candidate and candidate.hunterHawkProjection or candidate
    local effect, found = exactProjection(projection)
    local component = exactComponent(state)
    local player, key = rootPlayer(state)
    if not (effect and found and component and player
        and projection.recipientKey == key
        and projection.recipientGUID == player.guid
        and projection.actionSpellId == found.spellId
        and projection.action and tonumber(projection.action.spellId)
            == found.spellId
        and component.activeSpellId ~= found.spellId
        and effect.currentChange == found.rangedAttackPower
            - component.activeRangedAttackPower
        and effect.projectedDelta == found.rangedAttackPower
            - component.baselineRangedAttackPower) then return false end
    component.activeSpellId = found.spellId
    component.activeRangedAttackPower = found.rangedAttackPower
    component.deltaRangedAttackPower = effect.projectedDelta
    component.activeProfile, component.projected = copy(found), true
    player.hunterHawkExact, player.hunterHawkSpellId = true, found.spellId
    player.hunterHawkRangedAttackPower = found.rangedAttackPower
    return exactComponent(state) ~= nil
end

local function delta(state)
    local component = exactComponent(state)
    if not component then
        return nil, state and state.hunterHawk and state.hunterHawk.reason
            or "exact Hawk component unavailable"
    end
    return component.deltaRangedAttackPower, nil, component
end

function H:AutoShotBonus(state)
    local amount, reason, component = delta(state)
    if amount == nil then return nil, false, reason end
    return amount / 14 * component.lane.speed
        * component.lane.damageMultiplier, false, nil
end

local function weaponDescriptor(action, tooltip)
    local found = tooltip and tooltip.hunterRangedWeaponEvidence
    if not (type(found) == "table" and found.valid == true
        and found.exact == true and found.portfolio == "hunterMark"
        and found.attackType == "ranged" and found.weaponEffectCount == 1
        and tonumber(action and action.spellId) == tonumber(found.spellId)
        and tonumber(tooltip.weaponCoefficient)
            == tonumber(found.weaponCoefficient)
        and (tooltip.weaponNormalized == true) == (found.normalized == true)) then
        return nil
    end
    return found
end

function H:WeaponActionBonus(action, tooltip, state, evidence)
    local found = weaponDescriptor(action, tooltip)
    if not found then return nil, false,
        "exact Hunter ranged weapon evidence unavailable" end
    local amount, reason, component = delta(state)
    if amount == nil then return nil, false, reason end
    local speed = component.lane.speed
    if found.normalized then
        if not (type(evidence) == "table" and evidence.exact == true
            and evidence.normalized == true
            and finite(evidence.normalizedSpeed, 0.01, 20)) then
            return nil, false, "exact normalized ranged weapon lane unavailable"
        end
        speed = evidence.normalizedSpeed
    end
    return amount / 14 * speed * component.lane.damageMultiplier
        * found.weaponCoefficient, false, nil
end
