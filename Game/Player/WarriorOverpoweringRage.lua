-- Exact Octo Overpowering Rage ownership and active-aura evidence. The
-- passive deterministically links a landed Overpower to a five-second
-- fifteen-percent melee-haste aura; names and tooltip prose are not used.
XelAssist.Game.Player = XelAssist.Game.Player or {}
XelAssist.Game.Player.WarriorOverpoweringRage = {}
local O = XelAssist.Game.Player.WarriorOverpoweringRage

O.PASSIVE_ID, O.HASTE_ID = 53203, 53202
O.WARRIOR_FAMILY, O.HASTE_PERCENT, O.DURATION = 4, 15, 5

local function finite(value, low, high)
    value = tonumber(value)
    if value == nil or value ~= value
        or value < low or value > high then return nil end
    return value
end
local function integer(value, low, high)
    value = finite(value, low, high)
    return value and math.floor(value) == value and value or nil
end
local function scalar(id, field)
    if type(GetSpellRecField) ~= "function" then return nil end
    local ok, value = pcall(GetSpellRecField, id, field)
    return ok and finite(value, -2147483648, 4294967295) or nil
end
local function triple(id, field)
    if type(GetSpellRecField) ~= "function" then return nil end
    local ok, values = pcall(GetSpellRecField, id, field, 1)
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
local function equal(values, a, b, c)
    return values and values[1] == a and values[2] == b
        and values[3] == c
end
local function duration(id)
    if type(GetSpellDuration) ~= "function" then return nil end
    local ok, milliseconds = pcall(GetSpellDuration, id, 1)
    milliseconds = ok and integer(milliseconds, 0, 60000) or nil
    return milliseconds and milliseconds / 1000 or nil
end
local function warrior()
    if type(UnitClass) ~= "function" then return false end
    local ok, _, token = pcall(UnitClass, "player")
    return ok and token == "WARRIOR"
end

local function passiveTopology()
    local id = O.PASSIVE_ID
    return scalar(id, "attributes") == 192
        and scalar(id, "procFlags") == 16
        and scalar(id, "procChance") == 100
        and scalar(id, "procCharges") == 0
        and scalar(id, "durationIndex") == 21
        and scalar(id, "spellFamilyName") == O.WARRIOR_FAMILY
        and equal(triple(id, "effect"), 6, 0, 0)
        and equal(triple(id, "effectDieSides"), 1, 0, 0)
        and equal(triple(id, "effectBaseDice"), 1, 0, 0)
        and equal(triple(id, "effectBasePoints"), 99, 0, 0)
        and equal(triple(id, "effectImplicitTargetA"), 1, 0, 0)
        and equal(triple(id, "effectApplyAuraName"), 42, 0, 0)
        and equal(triple(id, "effectTriggerSpell"), O.HASTE_ID, 0, 0)
end

local function hasteTopology()
    local id = O.HASTE_ID
    local points, dice = triple(id, "effectBasePoints"),
        triple(id, "effectBaseDice")
    return scalar(id, "attributes") == 0
        and scalar(id, "procFlags") == 0
        and scalar(id, "procChance") == 101
        and scalar(id, "durationIndex") == 7
        and scalar(id, "rangeIndex") == 1
        and scalar(id, "spellFamilyName") == O.WARRIOR_FAMILY
        and duration(id) == O.DURATION
        and equal(triple(id, "effect"), 6, 0, 0)
        and equal(triple(id, "effectDieSides"), 1, 0, 0)
        and equal(dice, 1, 0, 0)
        and points and points[1] + dice[1] == O.HASTE_PERCENT
        and equal(triple(id, "effectImplicitTargetA"), 1, 0, 0)
        and equal(triple(id, "effectApplyAuraName"), 138, 0, 0)
        and equal(triple(id, "effectTriggerSpell"), 0, 0, 0)
end

local function ownership()
    if not warrior() then return nil, "player is not an exactly identified Warrior" end
    if type(IsPlayerSpell) ~= "function" then
        return nil, "Overpowering Rage ownership unavailable"
    end
    local ok, learned = pcall(IsPlayerSpell, O.PASSIVE_ID)
    if not ok or type(learned) ~= "boolean" then
        return nil, "Overpowering Rage ownership unavailable"
    end
    if not (passiveTopology() and hasteTopology()) then
        return nil, "Overpowering Rage installed topology unavailable"
    end
    return learned
end

local function activeAura()
    if not (C_UnitAuras
        and type(C_UnitAuras.GetPlayerAuraBySpellID) == "function") then
        return nil, nil, "Overpowering Rage aura evidence unavailable"
    end
    local ok, aura = pcall(C_UnitAuras.GetPlayerAuraBySpellID, O.HASTE_ID)
    if not ok then return nil, nil, "Overpowering Rage aura evidence unavailable" end
    if aura == nil then return false, 0, nil end
    if type(aura) ~= "table"
        or aura.spellId ~= nil and tonumber(aura.spellId) ~= O.HASTE_ID
        or type(GetTime) ~= "function" then
        return nil, nil, "Overpowering Rage aura evidence unavailable"
    end
    local timeOK, now = pcall(GetTime)
    local expiration = finite(aura.expirationTime, 0, 100000000)
    now = timeOK and finite(now, 0, 100000000) or nil
    local remaining = expiration and now and expiration - now or nil
    if not remaining or remaining <= 0 or remaining > O.DURATION + 0.25 then
        return nil, nil, "Overpowering Rage aura timing unavailable"
    end
    return true, remaining, nil
end

function O:Snapshot()
    local learned, reason = ownership()
    if learned == nil then return { available = false, exact = false,
        reason = reason, portfolio = "warriorOverpoweringRage" } end
    local out = { available = true, exact = true, learned = learned,
        portfolio = "warriorOverpoweringRage", passiveSpellId = self.PASSIVE_ID,
        hasteSpellId = self.HASTE_ID, hastePercent = self.HASTE_PERCENT,
        duration = self.DURATION,
        source = "installed patch-5 passive/trigger topology and player aura" }
    if not learned then out.active, out.remaining = false, 0; return out end
    local active, remaining, auraReason = activeAura()
    if active == nil then out.available, out.exact, out.reason = false, false,
        auraReason; return out end
    out.active, out.remaining = active, remaining
    return out
end

function O:CaptureFacts(action, facts)
    if not (action and action.facts and action.facts.warriorOverpower == true) then
        return facts
    end
    local out, key, value = {}, nil, nil
    for key, value in pairs(facts or {}) do out[key] = value end
    out.warriorOverpoweringRageEvidence = self:Snapshot()
    return out
end
