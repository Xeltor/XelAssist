-- Mutable root observation for Battle Shout. It freezes group membership,
-- the current melee multiplier and numeric aura lifecycle before graph search.
XelAssist.Game.Player.WarriorBattleShoutRoot = {}
local R = XelAssist.Game.Player.WarriorBattleShoutRoot

local MAX_AURAS = 48
local ATTACK_POWER_AURA = 99

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

local function classToken()
    if type(UnitClass) ~= "function" then return nil end
    local ok, _, token = pcall(UnitClass, "player")
    return ok and type(token) == "string" and token or nil
end

local function groupCount(api, maximum)
    if type(api) ~= "function" then return nil end
    local ok, count = pcall(api)
    return ok and integer(count, 0, maximum) or nil
end

local function triple(spellId, field)
    if type(GetSpellRecField) ~= "function" then return nil end
    local ok, values = pcall(GetSpellRecField, spellId, field, 1)
    if not ok or type(values) ~= "table" then return nil end
    local out, count, key, index = {}, 0, nil, nil
    for key in pairs(values) do
        if integer(key, 1, 3) == nil then return nil end
        count = count + 1
    end
    if count ~= 3 then return nil end
    for index = 1, 3 do
        out[index] = finite(values[index], -2147483648, 4294967295)
        if out[index] == nil then return nil end
    end
    return out
end

local function meleeLane()
    if type(UnitAttackSpeed) ~= "function" or type(UnitDamage) ~= "function" then
        return nil, "Warrior melee damage lane unavailable"
    end
    local speedOk, speed = pcall(UnitAttackSpeed, "player")
    local damageOk, low, high, _, _, _, _, percent = pcall(UnitDamage, "player")
    speed, low, high, percent = tonumber(speed), tonumber(low),
        tonumber(high), tonumber(percent)
    if not (speedOk and damageOk and finite(speed, 0.01, 20)
        and finite(low, 0, 10000000) and finite(high, low, 10000000)
        and finite(percent, 0.0001, 100)) then
        return nil, "Warrior melee damage lane unavailable"
    end
    return { valid = true, exact = true, speed = speed,
        damageMultiplier = percent, damageMultiplierUnits = "factor",
        observedLow = low, observedHigh = high,
        source = "root-captured UnitAttackSpeed and UnitDamage multiplier factor" }
end

local function timing(aura, now, permanentAllowed)
    local expiration = type(aura) == "table"
        and finite(aura.expirationTime, 0, 100000000) or nil
    if expiration == nil then return nil, nil, "aura expiration unavailable" end
    if expiration == 0 and permanentAllowed then return nil, true, nil end
    if not now or expiration <= now then
        return nil, nil, "aura expiration unavailable"
    end
    return expiration - now, false, nil
end

local function auraBaseline(owner)
    if not (C_UnitAuras and type(C_UnitAuras.GetUnitAuras) == "function") then
        return nil, "numeric player aura evidence unavailable"
    end
    local ok, list = pcall(C_UnitAuras.GetUnitAuras, "player", "HELPFUL")
    if not ok or type(list) ~= "table" or table.getn(list) > MAX_AURAS then
        return nil, "numeric player aura evidence unavailable"
    end
    local nowOk, now = false, nil
    if type(GetTime) == "function" then nowOk, now = pcall(GetTime) end
    local out, index = { clean = true }, nil
    now = nowOk and finite(now, 0, 100000000) or nil
    for index = 1, table.getn(list) do
        local aura = list[index]
        local spellId = type(aura) == "table"
            and integer(aura.spellId, 1, 4294967295) or nil
        if not spellId then return nil, "numeric player aura evidence unavailable" end
        local profile, profileReason, isShout = owner:CaptureActiveProfile(spellId)
        if isShout and not profile then return nil, profileReason end
        local applications = triple(spellId, "effectApplyAuraName")
        if not applications then return nil, "player aura topology unavailable" end
        if profile then
            if out.activeProfile then return nil, "multiple Battle Shout ranks active" end
            local remaining, _, reason = timing(aura, now, false)
            if not remaining then return nil, "active Battle Shout " .. reason end
            out.activeProfile, out.activeRemaining = profile, remaining
            out.clean = false
        end
        local attackPowerAura = applications[1] == ATTACK_POWER_AURA
            or applications[2] == ATTACK_POWER_AURA
            or applications[3] == ATTACK_POWER_AURA
        if attackPowerAura and not isShout then
            if out.competingAttackPowerAura then
                return nil, "multiple competing attack-power auras active"
            end
            local remaining, permanent, reason = timing(aura, now, true)
            if reason then return nil, "competing attack-power " .. reason end
            out.competingAttackPowerAura = spellId
            out.competingRemaining, out.competingPermanent = remaining, permanent
            out.clean = false
        end
    end
    return out, nil
end

function R:Observe(owner)
    local out = { available = false, exact = false,
        portfolio = "warriorBattleShout" }
    if classToken() ~= "WARRIOR" then
        out.reason = "player is not an exactly identified Warrior"; return out
    end
    if not (owner and type(owner.CaptureActiveProfile) == "function") then
        out.reason = "Battle Shout runtime unavailable"; return out
    end
    local raid, party = groupCount(GetNumRaidMembers, 40),
        groupCount(GetNumPartyMembers, 4)
    local lane, laneReason = meleeLane()
    local baseline, auraReason = auraBaseline(owner)
    if raid == nil or party == nil or not lane or not baseline then
        if raid == nil or party == nil then
            out.reason = "group membership evidence unavailable"
        else
            out.reason = laneReason or auraReason
        end
        return out
    end
    out.available, out.exact, out.auraBaselineExact = true, true, true
    out.raidMembers, out.partyMembers = raid, party
    out.grouped, out.solo = raid > 0 or party > 0, raid == 0 and party == 0
    out.lane, out.baselineClean = lane, baseline.clean
    out.activeProfile, out.activeRemaining = baseline.activeProfile,
        baseline.activeRemaining
    out.competingAttackPowerAura = baseline.competingAttackPowerAura
    out.competingRemaining, out.competingPermanent =
        baseline.competingRemaining, baseline.competingPermanent
    out.source = "frozen group, numeric player aura and melee damage evidence"
    return out
end
