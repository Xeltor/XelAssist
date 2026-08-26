-- Exact installed Shock shared-cooldown topology plus the engine-effective
-- Reverberation SpellMod. Graph search consumes only this root-captured fact.
XelAssist.Game.Player.ShamanShockCooldown = {}
local S = XelAssist.Game.Player.ShamanShockCooldown

S.COOLDOWN_MODIFIER = 11
S.COOLDOWN_GROUP = 19
S.BASE_COOLDOWN = 6

local SHOCKS = {
    [8042] = true, [8044] = true, [8045] = true, [8046] = true,
    [10412] = true, [10413] = true, [10414] = true,
    [8050] = true, [8052] = true, [8053] = true,
    [10447] = true, [10448] = true, [29228] = true,
    [8056] = true, [8058] = true, [10472] = true, [10473] = true,
}
local TALENTS = {
    [16040] = { rank = 1, milliseconds = -333, basePoints = -334 },
    [16113] = { rank = 2, milliseconds = -666, basePoints = -667 },
    [16114] = { rank = 3, milliseconds = -1000, basePoints = -1001 },
}
local ORDER = { 16114, 16113, 16040 }

local function integer(value, low, high)
    value = tonumber(value)
    return value and value == value and math.floor(value) == value
        and value >= low and value <= high and value or nil
end

local function signed(value)
    value = integer(value, -2147483648, 4294967295)
    if value and value >= 2147483648 then value = value - 4294967296 end
    return value
end

local function scalar(spellId, field)
    if type(GetSpellRecField) ~= "function" then return nil end
    local ok, value = pcall(GetSpellRecField, spellId, field)
    return ok and integer(value, -2147483648, 4294967295) or nil
end

local function triple(spellId, field)
    if type(GetSpellRecField) ~= "function" then return nil end
    local ok, values = pcall(GetSpellRecField, spellId, field, 1)
    if not ok or type(values) ~= "table" or values[4] ~= nil then return nil end
    local out, index = {}, nil
    for index = 1, 3 do
        out[index] = signed(values[index])
        if out[index] == nil then return nil end
    end
    return out
end

local function equal(values, first, second, third)
    return values and values[1] == first and values[2] == second
        and values[3] == third
end

local function shockTopology(spellId)
    return SHOCKS[spellId] and scalar(spellId, "category") == S.COOLDOWN_GROUP
        and scalar(spellId, "categoryRecoveryTime") == 6000
        and scalar(spellId, "spellFamilyName") == 11
end

local function talentTopology(spellId, expected)
    return scalar(spellId, "spellFamilyName") == 11
        and equal(triple(spellId, "effect"), 6, 0, 0)
        and equal(triple(spellId, "effectApplyAuraName"), 107, 0, 0)
        and equal(triple(spellId, "effectMiscValue"), 11, 0, 0)
        and equal(triple(spellId, "effectBasePoints"),
            expected.basePoints, 0, 0)
end

local function learnedTalent()
    if type(IsPlayerSpell) ~= "function" then return nil, nil end
    local index, spellId
    for index = 1, table.getn(ORDER) do
        spellId = ORDER[index]
        local ok, learned = pcall(IsPlayerSpell, spellId)
        if ok and (learned == true or learned == 1) then
            return spellId, TALENTS[spellId]
        end
    end
    return false, { rank = 0, milliseconds = 0 }
end

local function modifier(spellId)
    if type(GetSpellModifiers) ~= "function" then return nil end
    local ok, flat, percent, changed = pcall(
        GetSpellModifiers, spellId, S.COOLDOWN_MODIFIER)
    flat, percent = ok and signed(flat) or nil, ok and signed(percent) or nil
    changed = ok and integer(changed, 0, 4294967295) or nil
    if flat == nil or percent == nil or changed == nil then return nil end
    if (flat ~= 0 or percent ~= 0) ~= (changed ~= 0) then return nil end
    return flat, percent
end

function S:CaptureFacts(action, facts)
    local spellId = action and integer(action.spellId, 1, 4294967295)
    if not (spellId and SHOCKS[spellId] and type(facts) == "table") then
        return facts
    end
    facts.shamanShockCooldownExact = nil
    if not shockTopology(spellId) then
        facts.shamanShockCooldownReason = "installed Shock topology shifted"
        return facts
    end
    local talentId, talent = learnedTalent()
    local flat, percent = modifier(spellId)
    if talentId == nil or flat == nil or percent ~= 0
        or flat ~= talent.milliseconds
        or talentId and not talentTopology(talentId, talent) then
        facts.shamanShockCooldownReason =
            "engine Reverberation evidence unavailable or contradictory"
        return facts
    end
    facts.cooldownGroup = S.COOLDOWN_GROUP
    facts.categoryCooldown = (6000 + flat) / 1000
    facts.shamanShockCooldownExact = true
    facts.shamanReverberationRank = talent.rank
    facts.shamanReverberationSpellId = talentId or nil
    facts.shamanShockCooldownSource =
        "installed patch-5 Shock topology and engine SpellMod"
    return facts
end
