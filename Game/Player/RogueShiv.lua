-- Octo Shiv is a private dummy-effect weapon action. Its installed row proves
-- the off-hand attack, one combo point and dynamic Energy wording; the live
-- tooltip owns the actual weapon-speed-dependent cost. Poison delivery remains
-- deliberately uncredited until the active enchant consequence is projected.
XelAssist.Game.Player.RogueShiv = {}
local S = XelAssist.Game.Player.RogueShiv
S.SPELL_ID = 45609
local PROFILE

local function scalar(field)
    if type(GetSpellRecField) ~= "function" then return nil end
    local ok, value = pcall(GetSpellRecField, S.SPELL_ID, field)
    return ok and tonumber(value) or nil
end
local function triple(field, first, second, third)
    if type(GetSpellRecField) ~= "function" then return false end
    local ok, values = pcall(GetSpellRecField, S.SPELL_ID, field, 1)
    if not ok or type(values) ~= "table" or values[4] ~= nil then return false end
    return tonumber(values[1]) == first and tonumber(values[2]) == second
        and tonumber(values[3]) == third
end
local function rogue()
    if type(UnitClass) ~= "function" then return false end
    local ok, _, token = pcall(UnitClass, "player")
    return ok and token == "ROGUE"
end
local function rangeExact()
    if scalar("rangeIndex") ~= 2 or type(GetSpellRangeData) ~= "function" then
        return false
    end
    local ok, minimum, maximum = pcall(GetSpellRangeData, 2)
    return ok and tonumber(minimum) == 0 and tonumber(maximum) == 5
end
local function topology()
    return scalar("school") == 0 and scalar("attributes") == 2424848
        and scalar("attributesEx") == 134217728
        and scalar("attributesEx2") == 1048576
        and scalar("attributesEx3") == 17235968
        and scalar("attributesEx4") == 1024
        and scalar("castingTimeIndex") == 1
        and scalar("recoveryTime") == 0 and scalar("durationIndex") == 0
        and scalar("powerType") == 3 and scalar("manaCost") == 20
        and scalar("baseLevel") == 60 and scalar("spellLevel") == 60
        and scalar("spellFamilyName") == 8
        and scalar("spellFamilyFlags") == 536870912
        and scalar("equippedItemClass") == 2
        and scalar("equippedItemSubClassMask") == 173555
        and scalar("startRecoveryCategory") == 133
        and scalar("startRecoveryTime") == 1000
        and scalar("dmgClass") == 2 and scalar("preventionType") == 2
        and triple("effect", 3, 0, 0)
        and triple("effectBasePoints", 0, 0, 0)
        and triple("effectImplicitTargetA", 1, 0, 0)
        and triple("effectTriggerSpell", 0, 0, 0) and rangeExact()
end
local function copy(source)
    local out, key, value = {}, nil, nil
    for key, value in pairs(source or {}) do out[key] = value end
    return out
end

function S:Profile()
    if PROFILE then return PROFILE.valid and copy(PROFILE) or nil, PROFILE.reason end
    if not topology() then
        PROFILE = { valid = false, exact = false,
            reason = "Shiv DBC topology is incomplete" }
        return nil, PROFILE.reason
    end
    PROFILE = { valid = true, exact = true, spellId = self.SPELL_ID,
        comboGain = 1, baseEnergyCost = 20, weaponCoefficient = 1,
        requiresOffhandWeapon = true, poisonDelivery = true,
        poisonConsequenceModeled = false,
        source = "installed patch-5 Shiv DBC and tooltip contract" }
    return copy(PROFILE)
end
function S:InferKnowledge(spellId)
    if tonumber(spellId) ~= self.SPELL_ID then return nil, "not Shiv", false end
    if not rogue() then return nil, "player is not a Rogue", false end
    local found, reason = self:Profile()
    if not found then return nil, reason, true end
    return { inferred = true, kind = "builder", kindExact = true,
        melee = true, school = 0, comboBuilder = true, comboGain = 1,
        weaponHand = "off", usesWeaponSkill = true,
        requiresOffhandWeapon = true, requiresExactTooltipCost = true,
        shiv = true, shivEvidence = found,
        poisonDeliveryUncredited = true,
        deliveryModel = "physical", deliverySubtype = "melee",
        requiresExactUsability = true, submissionGuarded = true,
        source = found.source }, nil, true
end
function S:CaptureFacts(action, facts)
    local out = copy(facts)
    local found = action and action.facts and action.facts.shivEvidence
    if not (action and tonumber(action.spellId) == self.SPELL_ID
        and type(found) == "table" and found.valid == true
        and found.exact == true and found.weaponCoefficient == 1
        and found.comboGain == 1 and found.poisonConsequenceModeled == false) then
        return out
    end
    out.weaponCoefficient, out.weaponNormalized = 1, false
    out.comboGain = 1
    out.shivPoisonConsequenceModeled = false
    return out
end
function S:Invalidate() PROFILE = nil end
