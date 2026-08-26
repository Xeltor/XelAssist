-- Raw action potency from scripted effects, DBC weapon formulas and tooltips.
-- Delivery, resistance, target health and strategic utility stay in Scoring.
XelAssist.Graph.ActionPower = {}
local P = XelAssist.Graph.ActionPower
local Triggered = XelAssist.Combat.TriggeredActions
local HunterRangedPower = XelAssist.Graph.HunterRangedPower
local WarriorBattleShout = XelAssist.Graph.WarriorBattleShout
local PaladinMight = XelAssist.Graph.PaladinMight
local WarlockSoulLink = XelAssist.Graph.WarlockSoulLink

local function comboPower(action, tooltip, state, targetGUID, comboAllOwners)
    if not (action.facts.combo or tooltip.comboSpendAll) then return 0 end
    local points = XelAssist.Graph.ComboState
        and XelAssist.Graph.ComboState:ConditionalExpected(
            state, targetGUID, comboAllOwners)
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
    comboAllOwners, observed, status, effectTargetGUID)
    local coefficient = tonumber(tooltip.weaponCoefficient)
    if coefficient == nil then return nil end
    local basis, evidence = weaponBasis(action, tooltip, observed, status)
    local weapon = tonumber(basis)
    if weapon == nil then return nil end
    local points = XelAssist.Graph.ComboState
        and XelAssist.Graph.ComboState:ConditionalExpected(
            state, targetGUID, comboAllOwners)
        or tonumber(state.combo) or 0
    local percent = tonumber(evidence and evidence.damagePercent) or 1
    local combo = tooltip.weaponComboFlat ~= nil
        and (tonumber(tooltip.weaponComboFlat) or 0) * points * percent
        or comboPower(action, tooltip, state, targetGUID, comboAllOwners)
    local direct = tonumber(tooltip.weaponDirectFlat) or 0
    local power = weapon * coefficient
        + (tonumber(tooltip.weaponFlat) or 0) * percent + combo + direct
    if tooltip.hunterRangedWeaponEvidence then
        if not HunterRangedPower then return nil, { unknown = true,
            gap = "Hunter ranged power graph unavailable" }, true end
        local adjusted, reason = HunterRangedPower:WeaponPower(power,
            action, tooltip, state, effectTargetGUID, evidence)
        if adjusted == nil then return nil, { unknown = true,
            gap = reason or "Hunter weapon consequence unavailable" }, true end
        power = adjusted
    end
    if tooltip.warriorMainHandWeaponEvidence then
        if not WarriorBattleShout then return nil, { unknown = true,
            gap = "Battle Shout graph unavailable" }, true end
        local bonus, _, reason = WarriorBattleShout:WeaponActionBonus(
            action, tooltip, state, evidence)
        if bonus == nil then return nil, { unknown = true,
            gap = reason or "Battle Shout weapon consequence unavailable" }, true end
        power = power + bonus
    end
    if tooltip.paladinMainHandWeaponEvidence then
        if not PaladinMight then return nil, { unknown = true,
            gap = "Paladin Might graph unavailable" }, true end
        local bonus, _, reason = PaladinMight:WeaponActionBonus(
            action, tooltip, state, evidence)
        if bonus == nil then return nil, { unknown = true,
            gap = reason or "Paladin Might weapon consequence unavailable" },
            true end
        power = power + bonus
    end
    return power, evidence, false
end

local function unresolvedWeaponPower(action, tooltip, state, targetGUID,
    comboAllOwners)
    if tonumber(tooltip.weaponCoefficient) == nil then return nil end
    local points = XelAssist.Graph.ComboState
        and XelAssist.Graph.ComboState:ConditionalExpected(
            state, targetGUID, comboAllOwners)
        or tonumber(state.combo) or 0
    local combo = tooltip.weaponComboFlat ~= nil
        and (tonumber(tooltip.weaponComboFlat) or 0) * points
        or comboPower(action, tooltip, state, targetGUID, comboAllOwners)
    return math.max(10, (tonumber(tooltip.weaponFlat) or 0) + combo)
end

local function addSpellBonus(action, tooltip, observed, status, base)
    local kind = action.facts.kind
    if (kind ~= "damage" and kind ~= "dot") or action.actor == "pet" then
        return base, false
    end
    local bonus = status == "known"
        and (observed.bonusCaptured and observed.bonusDamage or 0)
        or XelAssist.Game.Capabilities:BonusDamage(tooltip.school)
    if bonus <= 0 then return base, false end
    local coefficient
    if kind == "dot" then
        coefficient = math.min(1, (tooltip.duration or 15) / 15)
    else
        coefficient = math.min(1, math.max(1.5, tooltip.cast or 0) / 3.5)
    end
    local area = action.facts.aoe or tooltip.topology
        and tooltip.topology.area
    if area then coefficient = coefficient * 0.5 end
    return base + bonus * coefficient, true
end

function P:Estimate(action, tooltip, state, targetGUID, comboAllOwners,
    effectTargetGUID)
    local observed, observationStatus = observedPower(action, state)
    if observationStatus ~= "absent" and observationStatus ~= "known" then
        return 0, true, { unknown = true,
            gap = "action power observation missing" }
    end
    local combo = comboPower(
        action, tooltip, state, targetGUID, comboAllOwners)
    local base, estimated, evidence = nil, nil, nil
    if action.facts.healthConversion and tooltip.resourceGain then
        base, estimated = tooltip.resourceGain, false
    end
    if not base and action.facts.healthFundedChannel
        and tooltip.healthTransfer and tooltip.healthTransfer.exact
        and tonumber(tooltip.healthTransfer.totalHealing) then
        base, estimated = tooltip.healthTransfer.totalHealing, false
        evidence = { source = tooltip.healthTransfer.source,
            exact = true, complete = true }
    end
    if not base and Triggered and Triggered.ScriptedPower then
        base, estimated = Triggered:ScriptedPower(action, state)
    end
    if not base then
        local blocked
        base, evidence, blocked = dbcWeaponPower(action, tooltip, state,
            targetGUID, comboAllOwners, observed, observationStatus,
            effectTargetGUID)
        if blocked then return 0, true, evidence end
        if base ~= nil then estimated = true end
    end
    if not base and tooltip.weaponCoefficient ~= nil then
        base, estimated = unresolvedWeaponPower(
            action, tooltip, state, targetGUID, comboAllOwners), true
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
        and not action.facts.healthFundedChannel
        and tonumber(action.facts.channelTicks) then
        base = base * action.facts.channelTicks
    end
    local bonusEstimated
    base, bonusEstimated = addSpellBonus(
        action, tooltip, observed, observationStatus, base)
    if bonusEstimated then estimated = true end
    local damage = action.facts.kind == "damage"
        or action.facts.kind == "dot" or action.facts.kind == "builder"
    local effectActor = action.facts.damageActor
        or action.facts.effectActor or action.actor
    if damage and effectActor == "pet" and XelAssist.Game.Pets
        and XelAssist.Game.Pets.Effects then
        base = base * XelAssist.Game.Pets.Effects:DamageMultiplier(
            state.actors and state.actors.pet)
    end
    if damage and state.classMechanicClass == "WARLOCK"
        and WarlockSoulLink then
        local adjusted, known, _, reason = WarlockSoulLink:AdjustOutgoing(
            state, effectActor or "player", base)
        if adjusted ~= nil then base = adjusted end
        if known == false then
            estimated = true
            evidence = evidence or {}
            evidence.soulLinkGap = reason or "Soul Link evidence unavailable"
        end
    end
    return base, estimated, evidence
end
