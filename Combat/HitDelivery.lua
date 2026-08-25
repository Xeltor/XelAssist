-- Character hit evidence shared by physical and magical delivery. Equipment
-- values are exact when ClassicAPI proves them; unresolved talent/aura hit is
-- kept separate so a gear-only lower bound never masquerades as a full total.
XelAssist.Combat.HitDelivery = {}
local H = XelAssist.Combat.HitDelivery

function H:Bonuses(state, actor)
    if actor ~= "player" then return nil end
    return state and state.hitBonuses or XelAssist.Game.HitBonuses
        and XelAssist.Game.HitBonuses:Snapshot() or nil
end

function H:Token(bonuses)
    if not bonuses then return nil end
    if not bonuses.equipmentKnown then return "?" end
    return tostring(bonuses.melee or 0) .. ":"
        .. tostring(bonuses.ranged or 0) .. ":"
        .. tostring(bonuses.spell or 0)
end

function H:MagicPrior(base, bonuses)
    local equipped = bonuses and bonuses.equipmentKnown
        and tonumber(bonuses.spell) or 0
    return math.min(0.99, base + math.max(0, equipped or 0) / 100)
end

function H:ApplyMagicResult(result, bonuses)
    result.hitBonus = bonuses and bonuses.equipmentKnown
        and tonumber(bonuses.spell) or 0
    result.equipmentHitKnown = bonuses and bonuses.equipmentKnown and true or false
    result.hitBonusKnown = bonuses and bonuses.totalKnown and true or false
    result.hitBonusSource = bonuses and bonuses.source or "+hit unavailable"
    result.hitBonusGap = bonuses and bonuses.gap
        or "equipment, talent and aura +hit"
end

function H:ApplyPhysicalResult(result, physical, alwaysHit)
    result.weaponHand, result.weaponSkill = physical.hand, physical.weaponSkill
    result.weaponSkillKnown, result.weaponSkillSource =
        physical.weaponSkillKnown, physical.weaponSkillSource
    result.usesActualWeaponSkill = physical.usesWeaponSkill
    result.targetDefense, result.targetDefenseKnown =
        physical.targetDefense, physical.targetDefenseKnown
    result.targetDefenseSource = physical.targetDefenseSource
    result.weaponMissChance, result.weaponBaseMissChance =
        physical.missChance, physical.baseMissChance
    result.hitBonus, result.equipmentHitKnown =
        physical.hitBonus, physical.equipmentHitKnown
    result.hitBonusKnown, result.hitBonusSource =
        physical.hitBonusKnown, physical.hitBonusSource
    result.attackPosition, result.positionKnown =
        physical.attackPosition, physical.positionKnown
    result.positionRelevant, result.positionSource =
        physical.positionRelevant, physical.positionSource
    result.ordinaryMissBypassed = alwaysHit and true or false
    result.dualWieldWhitePenalty = physical.dualWieldWhitePenalty
    result.dualWieldStateKnown = physical.dualWieldStateKnown
    result.formWeaponUseKnown = physical.formWeaponUseKnown
    result.deliveryPriorGaps, result.deliveryPriorUnknown =
        physical.priorGaps, physical.unknown
end

function H:PhysicalSuffix(physical)
    local out = ""
    if physical.equipmentHitKnown then
        out = out .. "; equipped +" .. tostring(physical.hitBonus or 0)
            .. "% hit applied"
    end
    if not physical.hitBonusKnown then
        out = out .. "; " .. tostring(physical.hitBonusGap or "remaining +hit")
            .. " excluded"
    end
    return out
end

function H:AppendMagicSource(result, bonuses)
    if not bonuses then return end
    if result.equipmentHitKnown then
        result.source = tostring(result.source) .. "; equipped +"
            .. tostring(result.hitBonus or 0) .. "% spell hit applied"
    end
    if not result.hitBonusKnown then
        result.source = tostring(result.source) .. "; "
            .. tostring(result.hitBonusGap or "remaining +hit") .. " excluded"
    end
end
