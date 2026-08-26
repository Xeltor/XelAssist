-- Exact installed Octo Devastate identity.  The client row proves the weapon
-- packet and its Sunder-stack damage term.  It does not encode the private
-- server's additional-threat arithmetic, so that part deliberately stays nil.
XelAssist.Game.Player.WarriorDevastate = {}
local D = XelAssist.Game.Player.WarriorDevastate

D.SPELL_ID = 45579
D.SUNDER_NAME = "Sunder Armor"
local PROFILE

local function scalar(field)
    if type(GetSpellRecField) ~= "function" then return nil end
    local ok, value = pcall(GetSpellRecField, D.SPELL_ID, field)
    return ok and tonumber(value) or nil
end

local function triple(field, one, two, three)
    if type(GetSpellRecField) ~= "function" then return false end
    local ok, values = pcall(GetSpellRecField, D.SPELL_ID, field, 1)
    if not ok or type(values) ~= "table" or values[4] ~= nil then return false end
    return tonumber(values[1]) == one and tonumber(values[2]) == two
        and tonumber(values[3]) == three
end

local function rangeExact()
    if scalar("rangeIndex") ~= 2 or type(GetSpellRangeData) ~= "function" then
        return false
    end
    local ok, minimum, maximum = pcall(GetSpellRangeData, 2)
    return ok and tonumber(minimum) == 0 and tonumber(maximum) == 5
end

local function topology()
    return scalar("school") == 0 and scalar("attributes") == 327696
        and scalar("attributesEx") == 134218240
        and scalar("attributesEx2") == 0 and scalar("attributesEx3") == 0
        and scalar("attributesEx4") == 0 and scalar("stances") == 196608
        and scalar("stancesNot") == 0 and scalar("castingTimeIndex") == 1
        and scalar("recoveryTime") == 0 and scalar("categoryRecoveryTime") == 0
        and scalar("durationIndex") == 0 and scalar("powerType") == 1
        and scalar("manaCost") == 50 and scalar("baseLevel") == 1
        and scalar("spellLevel") == 1 and scalar("spellFamilyName") == 4
        and scalar("spellFamilyFlags") == 0
        and scalar("equippedItemClass") == 2
        and scalar("equippedItemSubClassMask") == 173555
        and scalar("equippedItemInventoryTypeMask") == 0
        and scalar("startRecoveryCategory") == 133
        and scalar("startRecoveryTime") == 1500
        and scalar("dmgClass") == 2 and scalar("preventionType") == 2
        and triple("effect", 31, 121, 0)
        and triple("effectDieSides", 1, 1, 0)
        and triple("effectBaseDice", 1, 1, 0)
        and triple("effectBasePoints", 49, 14, 0)
        and triple("effectImplicitTargetA", 6, 6, 0)
        and triple("effectImplicitTargetB", 0, 0, 0)
        and triple("effectApplyAuraName", 0, 0, 0)
        and triple("effectTriggerSpell", 0, 0, 0) and rangeExact()
end

local function copy(source)
    local out, key, value = {}, nil, nil
    for key, value in pairs(source or {}) do out[key] = value end
    return out
end

local function warrior()
    if type(UnitClass) ~= "function" then return false end
    local ok, _, token = pcall(UnitClass, "player")
    return ok and token == "WARRIOR"
end

local function learned()
    if type(IsPlayerSpell) ~= "function" then return nil end
    local ok, value = pcall(IsPlayerSpell, D.SPELL_ID)
    if not ok or type(value) ~= "boolean" then return nil end
    return value
end

function D:Profile()
    if PROFILE then return PROFILE.valid and copy(PROFILE) or nil, PROFILE.reason end
    if not topology() then
        PROFILE = { valid = false, exact = false,
            reason = "Devastate DBC topology is incomplete" }
        return nil, PROFILE.reason
    end
    PROFILE = { valid = true, exact = true, spellId = self.SPELL_ID,
        weaponPercent = 50, damagePerSunder = 15, rageCost = 5,
        stanceMask = 196608, requiresMainHandWeapon = true,
        minRange = 0, maxRange = 5, supplementalThreatExact = false,
        source = "installed Octo patch-5 Devastate DBC topology" }
    return copy(PROFILE)
end

function D:InferKnowledge(spellId)
    if tonumber(spellId) ~= self.SPELL_ID then
        return nil, "not installed Devastate", false
    end
    if not warrior() then return nil, "player is not a Warrior", false end
    local owns = learned()
    if owns ~= true then
        return nil, owns == false and "Devastate is not learned"
            or "Devastate ownership is unavailable", true
    end
    local found, reason = self:Profile()
    if not found then return nil, reason, true end
    return { inferred = true, kind = "damage", kindExact = true,
        melee = true, school = 0, resourceType = "rage",
        stanceMask = found.stanceMask, weaponPercent = found.weaponPercent,
        weaponHand = "main", usesWeaponSkill = true,
        requiresMainHandWeapon = true, requiresExactUsability = true,
        submissionGuarded = true, warriorDevastate = true,
        warriorDevastateEvidence = found, supplementalThreatUnknown = true,
        deliveryModel = "physical", deliverySubtype = "melee",
        source = found.source }, nil, true
end

function D:Invalidate() PROFILE = nil end
