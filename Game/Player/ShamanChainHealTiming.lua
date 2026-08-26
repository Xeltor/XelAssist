-- Octo replaces the ordinary Chain Heal throughput talent with five ranks of
-- cast-time reduction.  Installed DBC topology identifies both the consumers
-- and modifier ranks; C_Spell supplies the engine-effective result.  This leaf
-- does not infer jump recipients or healing amounts.
XelAssist.Game.Player.ShamanChainHealTiming = {}
local T = XelAssist.Game.Player.ShamanChainHealTiming

T.SHAMAN_FAMILY = 11
T.CHAIN_FLAG = 256
T.CAST_MODIFIER = 10
T.CHAIN = { [1064] = true, [10622] = true, [10623] = true }
T.TALENTS = { [51374] = 200, [51375] = 400, [51376] = 600,
    [51377] = 800, [51378] = 1000 }
local CACHE = {}

local function finite(value)
    value = tonumber(value)
    if value == nil or value ~= value then return nil end
    return value
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

local function token()
    if type(UnitClass) ~= "function" then return nil end
    local ok, _, class = pcall(UnitClass, "player")
    return ok and class or nil
end

local function validConsumer(id)
    return scalar(id, "spellFamilyName") == T.SHAMAN_FAMILY
        and scalar(id, "spellFamilyFlags") == T.CHAIN_FLAG
        and scalar(id, "castTime") == 2500
        and equal(triple(id, "effect"), 10, 0, 0)
        and equal(triple(id, "effectImplicitTargetA"), 21, 0, 0)
end

local function signed(value)
    value = finite(value)
    if value and value >= 2147483648 then value = value - 4294967296 end
    return value
end

local function validTalent(id, reduction)
    local points = triple(id, "effectBasePoints")
    return scalar(id, "spellFamilyName") == T.SHAMAN_FAMILY
        and equal(triple(id, "effect"), 6, 0, 0)
        and equal(triple(id, "effectApplyAuraName"), 107, 0, 0)
        and equal(triple(id, "effectMiscValue"), T.CAST_MODIFIER, 0, 0)
        and scalar(id, "spellFamilyFlags") == T.CHAIN_FLAG
        and points and signed(points[1]) == -reduction - 1
end

local function topology(id)
    if CACHE[id] ~= nil then return CACHE[id] end
    local valid = T.CHAIN[id] and validConsumer(id) or false
    CACHE[id] = valid
    return valid
end

function T:InferKnowledge(spellId)
    if token() ~= "SHAMAN" then return nil, nil, false end
    local id = tonumber(spellId)
    if not T.CHAIN[id] then return nil, nil, false end
    if not topology(id) then
        return nil, "Octo Chain Heal timing topology is incomplete", true
    end
    return { inferred = true, kind = "heal", kindExact = true, aoe = true,
        shamanChainHealTiming = true,
        requiresExactShamanChainHealTiming = true,
        source = "installed Octo Chain Heal timing topology" }, nil, true
end

local function activeTalent()
    if type(IsPlayerSpell) ~= "function" then
        return nil, "Shaman Chain Heal talent ownership unavailable"
    end
    local found, count, id, reduction = nil, 0, nil, nil
    for id, reduction in pairs(T.TALENTS) do
        local ok, active = pcall(IsPlayerSpell, id)
        if not ok or (active ~= true and active ~= false
            and active ~= 1 and active ~= 0) then
            return nil, "Shaman Chain Heal talent ownership unavailable"
        end
        if active == true or active == 1 then
            if not validTalent(id, reduction) then
                return nil, "Octo improved Chain Heal topology is incomplete"
            end
            found, count = id, count + 1
        end
    end
    if count > 1 then
        return nil, "multiple improved Chain Heal ranks are active"
    end
    return found, nil
end

function T:CaptureFacts(action, facts)
    local out, key, value = {}, nil, nil
    for key, value in pairs(facts or {}) do out[key] = value end
    local id = tonumber(action and action.spellId)
    if not (id and T.CHAIN[id] and out.shamanChainHealTiming) then return out end
    if not topology(id) then
        out.shamanChainHealTimingReason =
            "Octo Chain Heal timing topology is incomplete"
        return out
    end
    local talent, ownershipReason = activeTalent()
    local api = C_Spell and C_Spell.GetSpellCastTime
    if type(api) ~= "function" then
        out.shamanChainHealTimingReason =
            "effective Chain Heal cast time unavailable"
        return out
    end
    local ok, milliseconds = pcall(api, id)
    milliseconds = ok and finite(milliseconds) or nil
    if not milliseconds or milliseconds < 0 or milliseconds > 2500 then
        out.shamanChainHealTimingReason =
            "effective Chain Heal cast time is not exact"
        return out
    end
    out.cast = milliseconds / 1000
    out.shamanChainHealCastExact = true
    out.shamanChainHealTalentSpellId = talent
    out.shamanChainHealTalentOwnershipReason = ownershipReason
    out.shamanChainHealTimingSource =
        "engine-effective cast time plus installed Octo talent topology"
    return out
end

function T:Invalidate() CACHE = {} end
