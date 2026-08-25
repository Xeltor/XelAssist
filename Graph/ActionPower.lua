-- Raw action potency from scripted effects, DBC weapon formulas and tooltips.
-- Delivery, resistance, target health and strategic utility stay in Scoring.
XelAssist.Graph.ActionPower = {}
local P = XelAssist.Graph.ActionPower
local Triggered = XelAssist.Combat.TriggeredActions

local function comboPower(action, tooltip, state, targetGUID)
    if not (action.facts.combo or tooltip.comboSpendAll) then return 0 end
    local points = XelAssist.Graph.ComboState
        and XelAssist.Graph.ComboState:ConditionalExpected(state, targetGUID)
        or tonumber(state.combo) or 0
    return (tonumber(tooltip.comboBonus) or 0)
        * points
end

local function observedPower(action, state)
    local root = XelAssist.Graph.RootObservation
    if not root then return nil, "absent" end
    return root:Power(state, action)
end

local function weaponBasis(action, tooltip, observed, status)
    if status ~= "absent" then
        if status == "known" and observed.weaponBasisCaptured then
            return observed.weaponBasis, observed.weaponEvidence
        end
        return nil, { exact = false, unknown = true,
            gap = "weapon power observation missing" }
    end
    if XelAssist.Game.WeaponPower and XelAssist.Game.WeaponPower.Basis then
        return XelAssist.Game.WeaponPower:Basis(action, tooltip)
    end
    local facts = action.facts or {}
    local value = facts.ranged and tooltip.school == 0
        and XelAssist.Game.Capabilities:RangedDamage()
        or XelAssist.Game.Capabilities:WeaponDamage()
    return value, { exact = false, gap = "weapon power model" }
end

local function dbcWeaponPower(action, tooltip, state, targetGUID,
    observed, status)
    local coefficient = tonumber(tooltip.weaponCoefficient)
    if coefficient == nil then return nil end
    local basis, evidence = weaponBasis(action, tooltip, observed, status)
    local weapon = tonumber(basis)
    if weapon == nil then return nil end
    local points = XelAssist.Graph.ComboState
        and XelAssist.Graph.ComboState:ConditionalExpected(state, targetGUID)
        or tonumber(state.combo) or 0
    local percent = tonumber(evidence and evidence.damagePercent) or 1
    local combo = tooltip.weaponComboFlat ~= nil
        and (tonumber(tooltip.weaponComboFlat) or 0) * points * percent
        or comboPower(action, tooltip, state, targetGUID)
    local direct = tonumber(tooltip.weaponDirectFlat) or 0
    return weapon * coefficient
        + (tonumber(tooltip.weaponFlat) or 0) * percent + combo + direct,
        evidence
end

local function unresolvedWeaponPower(action, tooltip, state, targetGUID)
    if tonumber(tooltip.weaponCoefficient) == nil then return nil end
    local points = XelAssist.Graph.ComboState
        and XelAssist.Graph.ComboState:ConditionalExpected(state, targetGUID)
        or tonumber(state.combo) or 0
    local combo = tooltip.weaponComboFlat ~= nil
        and (tonumber(tooltip.weaponComboFlat) or 0) * points
        or comboPower(action, tooltip, state, targetGUID)
    return math.max(10, (tonumber(tooltip.weaponFlat) or 0) + combo)
end

function P:Estimate(action, tooltip, state, targetGUID)
    local observed, observationStatus = observedPower(action, state)
    if observationStatus ~= "absent" and observationStatus ~= "known" then
        return 0, true, { unknown = true,
            gap = "action power observation missing" }
    end
    local combo = comboPower(action, tooltip, state, targetGUID)
    local base, estimated, evidence = nil, nil, nil
    if action.facts.healthConversion and tooltip.resourceGain then
        base, estimated = tooltip.resourceGain, false
    end
    if not base and Triggered and Triggered.ScriptedPower then
        base, estimated = Triggered:ScriptedPower(action, state)
    end
    if not base then
        base, evidence = dbcWeaponPower(action, tooltip, state, targetGUID,
            observed, observationStatus)
        if base ~= nil then estimated = true end
    end
    if not base and tooltip.weaponCoefficient ~= nil then
        base, estimated = unresolvedWeaponPower(
            action, tooltip, state, targetGUID), true
    end
    if not base and action.facts.kind == "dot"
        and not action.facts.combo and not tooltip.durationComboScaled
        and tooltip.damageTotalSource == "tooltip" and tooltip.average then
        base, estimated = tooltip.average + combo, false
    end
    if not base and action.facts.kind == "dot"
        and not action.facts.combo and not tooltip.durationComboScaled
        and tooltip.dbcEffectComplete and tooltip.dbcEffectAverage then
        base, estimated = tooltip.dbcEffectAverage + combo, true
        evidence = { source = tooltip.dbcEffectSource,
            complete = true, direct = tooltip.dbcEffectDirectDamage,
            periodic = tooltip.dbcEffectPeriodicDamage }
    end
    if not base and tooltip.average then
        base, estimated = tooltip.average + combo, false
    end
    if not base and tooltip.dbcAverage then
        local weapon
        if observationStatus == "known" then
            weapon = observed.dbcWeaponCaptured and observed.dbcWeapon or 0
        else
            weapon = action.facts.melee
                and XelAssist.Game.Capabilities:WeaponDamage() or 0
            if action.facts.ranged and tooltip.school == 0 then
                weapon = XelAssist.Game.Capabilities:RangedDamage() or weapon
            end
        end
        base, estimated = tooltip.dbcAverage + combo + (weapon or 0), true
    end
    if not base then
        base = math.max(10,
            action.rank * 24 + (tooltip.cost or 0) * 0.8)
        estimated = true
    end
    if action.facts.kind == "petHeal"
        and tonumber(action.facts.channelTicks) then
        base = base * action.facts.channelTicks
    end
    if (action.facts.kind == "damage" or action.facts.kind == "dot")
        and action.actor ~= "pet" then
        local bonus = observationStatus == "known"
            and (observed.bonusCaptured and observed.bonusDamage or 0)
            or XelAssist.Game.Capabilities:BonusDamage(tooltip.school)
        if bonus > 0 then
            local coefficient
            if action.facts.kind == "dot" then
                coefficient = math.min(1, (tooltip.duration or 15) / 15)
            else
                coefficient = math.min(1,
                    math.max(1.5, tooltip.cast or 0) / 3.5)
            end
            local area = action.facts.aoe or tooltip.topology
                and tooltip.topology.area
            if area then coefficient = coefficient * 0.5 end
            base, estimated = base + bonus * coefficient, true
        end
    end
    local damage = action.facts.kind == "damage"
        or action.facts.kind == "dot" or action.facts.kind == "builder"
    local effectActor = action.facts.damageActor
        or action.facts.effectActor or action.actor
    if damage and effectActor == "pet" and XelAssist.Game.Pets
        and XelAssist.Game.Pets.Effects then
        base = base * XelAssist.Game.Pets.Effects:DamageMultiplier(
            state.actors and state.actors.pet)
    end
    return base, estimated, evidence
end
