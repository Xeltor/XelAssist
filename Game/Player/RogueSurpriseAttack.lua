-- Exact installed patch-5 Surprise Attack identity. The DBC proves one combo
-- point and avoidance immunity, but does not make the ordinary miss roll hit.
XelAssist.Game.Player.RogueSurpriseAttack = {}
local S = XelAssist.Game.Player.RogueSurpriseAttack

S.SPELL_ID = 45603
S.IMPOSSIBLE_DODGE_PARRY_BLOCK = 2097152

local PROFILE

local function scalar(field)
    if type(GetSpellRecField) ~= "function" then return nil end
    local ok, value = pcall(GetSpellRecField, S.SPELL_ID, field)
    return ok and tonumber(value) or nil
end

local function triple(field)
    if type(GetSpellRecField) ~= "function" then return nil end
    local ok, values = pcall(GetSpellRecField, S.SPELL_ID, field, 1)
    if not ok or type(values) ~= "table" then return nil end
    local out, count, key, index = {}, 0, nil, nil
    for key in pairs(values) do
        if type(key) ~= "number" or key < 1 or key > 3
            or math.floor(key) ~= key then return nil end
        count = count + 1
    end
    if count ~= 3 then return nil end
    for index = 1, 3 do
        out[index] = tonumber(values[index])
        if out[index] == nil then return nil end
    end
    return out
end

local function equal(values, one, two, three)
    return values and values[1] == one and values[2] == two
        and values[3] == three
end

local function copy(source)
    local out, key, value = {}, nil, nil
    for key, value in pairs(source or {}) do out[key] = value end
    return out
end

local function rogue()
    if type(UnitClass) ~= "function" then return false end
    local ok, _, token = pcall(UnitClass, "player")
    return ok and token == "ROGUE"
end

local function exactRange()
    if scalar("rangeIndex") ~= 2 or type(GetSpellRangeData) ~= "function" then
        return false
    end
    local ok, minimum, maximum = pcall(GetSpellRangeData, 2)
    return ok and tonumber(minimum) == 0 and tonumber(maximum) == 5
end

local function topology()
    local attributes = scalar("attributes")
    return scalar("school") == 0 and scalar("category") == 0
        and scalar("mechanic") == 0 and attributes == 2424848
        and math.floor(attributes / S.IMPOSSIBLE_DODGE_PARRY_BLOCK)
            - math.floor(attributes / (S.IMPOSSIBLE_DODGE_PARRY_BLOCK * 2)) * 2 == 1
        and scalar("attributesEx") == 134218240
        and scalar("attributesEx2") == 0 and scalar("attributesEx3") == 1024
        and scalar("attributesEx4") == 0 and scalar("stances") == 0
        and scalar("stancesNot") == 0 and scalar("castingTimeIndex") == 1
        and scalar("recoveryTime") == 15000
        and scalar("categoryRecoveryTime") == 0
        and scalar("durationIndex") == 0 and scalar("powerType") == 3
        and scalar("manaCost") == 10 and scalar("manaCostPerlevel") == 0
        and scalar("baseLevel") == 22 and scalar("spellLevel") == 22
        and scalar("maxLevel") == 0 and scalar("spellFamilyName") == 8
        and scalar("spellFamilyFlags") == 0
        and scalar("startRecoveryCategory") == 133
        and scalar("startRecoveryTime") == 1000
        and scalar("dmgClass") == 2 and scalar("preventionType") == 2
        and scalar("equippedItemClass") == 2
        and scalar("equippedItemSubClassMask") == 173555
        and equal(triple("effect"), 31, 80, 0)
        and equal(triple("effectDieSides"), 1, 1, 1)
        and equal(triple("effectBaseDice"), 1, 1, 1)
        and equal(triple("effectDicePerLevel"), 0, 0, 0)
        and equal(triple("effectRealPointsPerLevel"), 0, 0, 0)
        and equal(triple("effectBasePoints"), 89, 0, 0)
        and equal(triple("effectImplicitTargetA"), 6, 6, 0)
        and equal(triple("effectImplicitTargetB"), 0, 0, 0)
        and equal(triple("effectApplyAuraName"), 0, 0, 0)
        and equal(triple("effectTriggerSpell"), 0, 0, 0)
        and exactRange()
end

function S:Profile()
    if PROFILE then return PROFILE.valid and copy(PROFILE) or nil, PROFILE.reason end
    if not topology() then
        PROFILE = { valid = false, exact = false,
            reason = "Surprise Attack DBC topology is incomplete" }
        return nil, PROFILE.reason
    end
    PROFILE = { valid = true, exact = true, spellId = self.SPELL_ID,
        weaponPercent = 90, comboGain = 1, energyCost = 10,
        cooldown = 15, gcd = 1, minRange = 0, maxRange = 5,
        bypassesDodge = true, bypassesParry = true, bypassesBlock = true,
        bypassesOrdinaryMiss = false, requiresMainHandWeapon = true,
        source = "installed patch-5 Spell.dbc Surprise Attack topology" }
    return copy(PROFILE)
end

function S:InferKnowledge(spellId)
    if tonumber(spellId) ~= self.SPELL_ID then
        return nil, "not Surprise Attack", false
    end
    if not rogue() then return nil, "player is not a Rogue", false end
    local found, reason = self:Profile()
    if not found then return nil, reason, true end
    return { inferred = true, kind = "builder", kindExact = true,
        melee = true, school = 0, comboBuilder = true,
        comboGain = found.comboGain, weaponPercent = found.weaponPercent,
        surpriseAttack = true, surpriseAttackEvidence = found,
        deliveryModel = "physical", deliverySubtype = "melee",
        usesWeaponSkill = true, weaponHand = "main",
        bypassesDodge = true, bypassesParry = true, bypassesBlock = true,
        alwaysHit = false, requiresExactUsability = true,
        submissionGuarded = true, source = found.source }, nil, true
end

function S:Invalidate() PROFILE = nil end
