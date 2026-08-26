-- Exact installed-Octo identity for Chastise's polymorphic server-scripted
-- action. The hostile direct-damage lane is usable by the ordinary graph. The
-- friendly lane deliberately remains withheld: it damages its ally, applies
-- haste, has health/level gates and branches its duration on a critical hit.
XelAssist.Game.Player = XelAssist.Game.Player or {}
XelAssist.Game.Player.PriestChastise = {}
local C = XelAssist.Game.Player.PriestChastise

C.SPELL_ID = 51478
C.ALLY_MIN_HEALTH_FRACTION = 0.80
C.ALLY_MIN_LEVEL = 35

local PROFILE

local function scalar(field)
    if type(GetSpellRecField) ~= "function" then return nil end
    local ok, value = pcall(GetSpellRecField, C.SPELL_ID, field)
    value = ok and tonumber(value) or nil
    if value == nil or value ~= value or value == math.huge
        or value == -math.huge then return nil end
    return value
end

local function triple(field)
    if type(GetSpellRecField) ~= "function" then return nil end
    local ok, values = pcall(GetSpellRecField, C.SPELL_ID, field, 1)
    if not ok or type(values) ~= "table" then return nil end
    local out, index, count = {}, nil, 0
    for index in pairs(values) do
        if type(index) ~= "number" or index < 1 or index > 3
            or math.floor(index) ~= index then return nil end
        count = count + 1
    end
    if count ~= 3 then return nil end
    for index = 1, 3 do
        out[index] = tonumber(values[index])
        if out[index] == nil then return nil end
    end
    return out
end

local function equal(values, first, second, third)
    return values and values[1] == first and values[2] == second
        and values[3] == third
end

local function copy(source)
    local out, key, value = {}, nil, nil
    for key, value in pairs(source or {}) do out[key] = value end
    return out
end

local function classToken()
    if type(UnitClass) ~= "function" then return nil end
    local ok, _, token = pcall(UnitClass, "player")
    return ok and token or nil
end

local function exactTopology()
    return scalar("school") == 1
        and scalar("category") == 1162
        and scalar("baseLevel") == 35
        and scalar("spellLevel") == 35
        and scalar("categoryRecoveryTime") == 40000
        and scalar("rangeIndex") == 34
        and scalar("startRecoveryCategory") == 133
        and scalar("startRecoveryTime") == 1000
        and scalar("spellFamilyName") == 6
        and equal(triple("effect"), 2, 3, 0)
        and equal(triple("effectDieSides"), 22, 0, 0)
        and equal(triple("effectBaseDice"), 1, 0, 0)
        and equal(triple("effectDicePerLevel"), 0, 0, 0)
        and equal(triple("effectRealPointsPerLevel"), 0, 0, 0)
        and equal(triple("effectBasePoints"), 138, 0, 0)
        and equal(triple("effectImplicitTargetA"), 25, 25, 0)
        and equal(triple("effectImplicitTargetB"), 0, 0, 0)
        and equal(triple("effectApplyAuraName"), 0, 0, 0)
        and equal(triple("effectAmplitude"), 0, 0, 0)
        and equal(triple("effectTriggerSpell"), 0, 0, 0)
end

local function profile()
    if PROFILE then return PROFILE.valid and copy(PROFILE) or nil, PROFILE.reason end
    PROFILE = { recognized = true, valid = false, exact = false,
        spellId = C.SPELL_ID, allyMinimumHealthFraction =
            C.ALLY_MIN_HEALTH_FRACTION, allyMinimumLevel = C.ALLY_MIN_LEVEL,
        friendlyBranchWithheld = true,
        source = "installed patch-5 Chastise DBC and client branch contract" }
    if not exactTopology() then
        PROFILE.reason = "Chastise DBC topology is incomplete"
        return nil, PROFILE.reason
    end
    PROFILE.valid, PROFILE.exact = true, true
    PROFILE.school, PROFILE.cooldown = 1, 40
    PROFILE.damageLow, PROFILE.damageHigh, PROFILE.damageAverage = 139, 160, 149.5
    PROFILE.recipient = "selected-hostile"
    PROFILE.hostileDisorientSpellId = 51569
    PROFILE.friendlyHasteSpellId = 51481
    PROFILE.friendlyCriticalHasteSpellId = 52658
    return copy(PROFILE)
end

function C:InferKnowledge(spellId)
    if classToken() ~= "PRIEST" then
        return nil, "player is not an exactly identified Priest", false
    end
    if tonumber(spellId) ~= self.SPELL_ID then
        return nil, "spell is not Chastise", false
    end
    local found, reason = profile()
    if not found then return nil, reason, true end
    return { inferred = true, kind = "damage", kindExact = true,
        ranged = true, hostile = true, recipientRelation = "hostile",
        recipientRelationExact = true, priestChastise = true,
        friendlyBranchWithheld = true, requiresExactUsability = true,
        submissionGuarded = true, school = found.school,
        priestChastiseEvidence = found, source = found.source }, nil, true
end

function C:Evidence(subject)
    local facts = type(subject) == "table" and subject.facts or subject
    local found = facts and facts.priestChastiseEvidence
    if not (facts and facts.priestChastise == true
        and facts.friendlyBranchWithheld == true and type(found) == "table"
        and found.valid == true and found.exact == true
        and found.spellId == self.SPELL_ID
        and found.recipient == "selected-hostile"
        and found.friendlyBranchWithheld == true) then return nil end
    return copy(found)
end

function C:Invalidate() PROFILE = nil end
