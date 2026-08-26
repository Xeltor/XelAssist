-- Composes target-side Hunter's Mark and player-side Hawk AP without teaching
-- either mechanic a preferred action order. Root weapon values already include
-- live auras, so only graph-projected deltas are added here.
XelAssist.Graph.HunterRangedPower = {}
local R = XelAssist.Graph.HunterRangedPower
local HunterMark = XelAssist.Graph.HunterMark
local HunterHawk = XelAssist.Graph.HunterHawk

local function projectedHawk(state)
    return HunterHawk and state and state.hunterHawk
        and state.hunterHawk.available == true
end

function R:AutoShotPower(base, state, targetGUID)
    local power = math.max(0, tonumber(base) or 0)
    if HunterMark then
        local bonus = HunterMark:AutoShotBonus(state, targetGUID)
        if tonumber(bonus) then power = power + math.max(0, bonus) end
    end
    if projectedHawk(state) then
        local bonus, _, reason = HunterHawk:AutoShotBonus(state)
        if not tonumber(bonus) then return nil, reason end
        power = power + bonus
    end
    return math.max(0, power), nil
end

function R:WeaponPower(base, action, tooltip, state, targetGUID, evidence)
    if not tooltip.hunterRangedWeaponEvidence then return base, nil end
    if not HunterMark then return nil, "Hunter's Mark graph unavailable" end
    local bonus, _, reason = HunterMark:WeaponActionBonus(
        action, tooltip, state, targetGUID, evidence)
    if bonus == nil then
        return nil, reason or "Hunter's Mark weapon consequence unavailable"
    end
    local power = base + bonus
    if projectedHawk(state) then
        bonus, _, reason = HunterHawk:WeaponActionBonus(
            action, tooltip, state, evidence)
        if bonus == nil then
            return nil, reason or "Hawk weapon consequence unavailable"
        end
        power = power + bonus
    end
    return power, nil
end
