-- Installed Octo Resurgent Shield identity and observed Resurgence evidence.
-- The shield-break script and its absorption-dependent amounts are private to
-- the server, so this owner deliberately does not derive them from tooltip
-- prose or the static fallback amounts on spell 51477.
XelAssist.Game.Player = XelAssist.Game.Player or {}
XelAssist.Game.Player.PriestResurgentShield = {}
local R = XelAssist.Game.Player.PriestResurgentShield

R.TALENT_ID, R.RESULT_ID = 45560, 51477
R.PRIEST_FAMILY, R.HOLY_SCHOOL = 6, 1
R.MAX_AURAS = 48

local PROFILE

local function finite(value)
    value = tonumber(value)
    return value and value == value and value > -1e308
        and value < 1e308 and value or nil
end

local function scalar(id, field)
    if type(GetSpellRecField) ~= "function" then return nil end
    local ok, value = pcall(GetSpellRecField, id, field)
    return ok and finite(value) or nil
end

local function triple(id, field)
    if type(GetSpellRecField) ~= "function" then return nil end
    local ok, values = pcall(GetSpellRecField, id, field, 1)
    if not ok or type(values) ~= "table" or values[4] ~= nil then return nil end
    local out, index = {}, nil
    for index = 1, 3 do
        out[index] = finite(values[index])
        if out[index] == nil then return nil end
    end
    return out
end

local function equal(values, first, second, third)
    return values and values[1] == first and values[2] == second
        and values[3] == third
end

local function profile()
    if PROFILE ~= nil then return PROFILE or nil end
    local talent = scalar(R.TALENT_ID, "spellFamilyName") == R.PRIEST_FAMILY
        and scalar(R.TALENT_ID, "attributes") == 464
        and scalar(R.TALENT_ID, "durationIndex") == 21
        and scalar(R.TALENT_ID, "rangeIndex") == 1
        and equal(triple(R.TALENT_ID, "effect"), 6, 6, 0)
        and equal(triple(R.TALENT_ID, "effectApplyAuraName"), 4, 4, 0)
        and equal(triple(R.TALENT_ID, "effectBasePoints"), 9, 24, 0)
        and equal(triple(R.TALENT_ID, "effectBaseDice"), 1, 1, 0)
        and equal(triple(R.TALENT_ID, "effectImplicitTargetA"), 1, 1, 0)
        and equal(triple(R.TALENT_ID, "effectTriggerSpell"), 0, 0, 0)
    local result = scalar(R.RESULT_ID, "school") == R.HOLY_SCHOOL
        and scalar(R.RESULT_ID, "spellFamilyName") == R.PRIEST_FAMILY
        and scalar(R.RESULT_ID, "durationIndex") == 31
        and scalar(R.RESULT_ID, "rangeIndex") == 5
        and equal(triple(R.RESULT_ID, "effect"), 6, 6, 30)
        and equal(triple(R.RESULT_ID, "effectApplyAuraName"), 13, 135, 0)
        and equal(triple(R.RESULT_ID, "effectBasePoints"), 4, 4, 24)
        and equal(triple(R.RESULT_ID, "effectBaseDice"), 1, 1, 1)
        and equal(triple(R.RESULT_ID, "effectImplicitTargetA"), 1, 1, 1)
        and equal(triple(R.RESULT_ID, "effectMiscValue"), 2, 2, 0)
        and equal(triple(R.RESULT_ID, "effectTriggerSpell"), 0, 0, 0)
    PROFILE = talent and result and { exact = true, talentId = R.TALENT_ID,
        resultId = R.RESULT_ID, tooltipHolyPercent = 10,
        tooltipRefundPercent = 25, staticDamageAmount = 5,
        staticHealingAmount = 5, staticEnergizeAmount = 25,
        dynamicAmountsProjectable = false,
        source = "installed patch-5 Resurgent Shield and Resurgence topology" }
        or false
    return PROFILE or nil
end

local function classToken()
    if type(UnitClass) ~= "function" then return nil end
    local ok, _, token = pcall(UnitClass, "player")
    return ok and token or nil
end

local function learned()
    if type(IsPlayerSpell) ~= "function" then return nil end
    local ok, known = pcall(IsPlayerSpell, R.TALENT_ID)
    if not ok or type(known) ~= "boolean" then return nil end
    return known
end

local function activeResult()
    if not (C_UnitAuras and type(C_UnitAuras.GetUnitAuras) == "function") then
        return nil, nil
    end
    local ok, list = pcall(C_UnitAuras.GetUnitAuras, "player", "HELPFUL")
    if not ok or type(list) ~= "table" or table.getn(list) > R.MAX_AURAS then
        return nil, nil
    end
    local active, remaining, index = false, nil, nil
    for index = 1, table.getn(list) do
        local aura = list[index]
        local id = type(aura) == "table" and finite(aura.spellId) or nil
        if not id then return nil, nil end
        if id == R.RESULT_ID then
            if active then return nil, nil end
            active = true
            local expiration, now = finite(aura.expirationTime), nil
            if type(GetTime) == "function" then
                local timeOK, value = pcall(GetTime)
                now = timeOK and finite(value) or nil
            end
            if expiration and expiration > 0 and now then
                remaining = math.max(0, expiration - now)
            end
        end
    end
    return active, remaining
end

function R:Snapshot(knownClass)
    if knownClass ~= nil and knownClass ~= "PRIEST" then return nil end
    if classToken() ~= "PRIEST" then return nil end
    local owned = learned()
    if owned == nil then return { available = false, exact = false,
        reason = "Resurgent Shield ownership unavailable" } end
    if not owned then return { available = true, exact = true, learned = false } end
    local found = profile()
    if not found then return { available = false, exact = false, learned = true,
        reason = "Resurgent Shield topology incomplete" } end
    local active, remaining = activeResult()
    if active == nil then return { available = false, exact = false, learned = true,
        reason = "Resurgence numeric self-aura evidence unavailable" } end
    return { available = true, exact = true, learned = true,
        active = active, remaining = remaining, talentId = found.talentId,
        resultId = found.resultId, dynamicAmountsProjectable = false,
        unresolved = "shield-break refund and Holy bonus magnitude require runtime evidence",
        source = found.source }
end

function R:Profile()
    local found = profile()
    if not found then return nil end
    local out, key, value = {}, nil, nil
    for key, value in pairs(found) do out[key] = value end
    return out
end

function R:Invalidate() PROFILE = nil end
