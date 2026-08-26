-- Exact installed-client defensive companion actions.  DBC topology proves
-- the aura arithmetic; autonomous trigger policy and pet white-damage output
-- remain separate evidence domains.
XelAssist.Game.Pets = XelAssist.Game.Pets or {}
XelAssist.Game.Pets.DefensiveActions = {}
local D = XelAssist.Game.Pets.DefensiveActions

D.SHELL_SHIELD = 26064

local function copy(source)
    local out, key, value = {}, nil, nil
    for key, value in pairs(source or {}) do out[key] = value end
    return out
end

local function scalar(id, field)
    if type(GetSpellRecField) ~= "function" then return nil end
    local ok, value = pcall(GetSpellRecField, id, field)
    return ok and tonumber(value) or nil
end

local function signed32(value)
    value = tonumber(value)
    if value and value >= 2147483648 then value = value - 4294967296 end
    return value
end

local function triple(id, field, signed)
    if type(GetSpellRecField) ~= "function" then return nil end
    local ok, value = pcall(GetSpellRecField, id, field, 1)
    if not ok or type(value) ~= "table" then return nil end
    local out, count, key, index = {}, 0, nil, nil
    for key in pairs(value) do
        if type(key) ~= "number" or key < 1 or key > 3
            or key ~= math.floor(key) then return nil end
        count = count + 1
    end
    if count ~= 3 then return nil end
    for index = 1, 3 do
        out[index] = signed and signed32(value[index])
            or tonumber(value[index])
        if out[index] == nil then return nil end
    end
    return out
end

local function equal(value, a, b, c)
    return value and value[1] == a and value[2] == b and value[3] == c
end

local function duration(id)
    if type(GetSpellDuration) ~= "function" then return nil end
    local ok, value = pcall(GetSpellDuration, id, 1)
    return ok and tonumber(value) or nil
end

local function shellShield()
    local id = D.SHELL_SHIELD
    return scalar(id, "school") == 0
        and scalar(id, "attributes") == 536870928
        and scalar(id, "castingTimeIndex") == 1
        and scalar(id, "recoveryTime") == 60000
        and scalar(id, "categoryRecoveryTime") == 0
        and scalar(id, "durationIndex") == 29 and duration(id) == 12
        and scalar(id, "powerType") == 2 and scalar(id, "manaCost") == 10
        and scalar(id, "rangeIndex") == 1
        and scalar(id, "startRecoveryCategory") == 133
        and scalar(id, "startRecoveryTime") == 1500
        and scalar(id, "spellFamilyName") == 9
        and scalar(id, "spellFamilyFlags") == 0
        and scalar(id, "spellFamilyFlags2") == 128
        and equal(triple(id, "effect"), 6, 6, 0)
        and equal(triple(id, "effectDieSides"), 1, 1, 0)
        and equal(triple(id, "effectBasePoints", true), -51, -36, 0)
        and equal(triple(id, "effectImplicitTargetA"), 0, 0, 0)
        and equal(triple(id, "effectImplicitTargetB"), 1, 1, 0)
        and equal(triple(id, "effectApplyAuraName"), 87, 138, 0)
        and equal(triple(id, "effectMiscValue"), 127, 0, 0)
        and equal(triple(id, "effectTriggerSpell"), 0, 0, 0)
end

function D:CaptureFacts(spellId, facts, source)
    local out = copy(facts)
    if tonumber(spellId) ~= self.SHELL_SHIELD
        or source ~= "octowow dbc id" then return out end
    if not shellShield() then
        out.petDefensiveProfileReason = "Shell Shield DBC topology changed"
        return out
    end
    local profile = { exact = true, kind = "shellShield",
        spellId = self.SHELL_SHIELD, duration = 12,
        incomingDamageMultiplier = 0.5, meleeAttackTimeMultiplier = 1.35,
        offensiveTimingExact = false,
        source = "installed patch-5 Shell Shield aura topology" }
    out.petDefensiveProfile = profile
    out.petCombatEffects = { { key = "shellShield", duration = 12,
        incomingDamageMultiplier = 0.5, meleeAttackTimeMultiplier = 1.35,
        offensiveTimingExact = false, sourceSpellId = self.SHELL_SHIELD } }
    return out
end

function D:Profile(subject)
    local facts = type(subject) == "table" and subject.facts or subject
    local found = facts and facts.petDefensiveProfile
    return type(found) == "table" and found.exact == true
        and found.kind == "shellShield"
        and found.spellId == self.SHELL_SHIELD and found.duration == 12
        and found.incomingDamageMultiplier == 0.5
        and found.meleeAttackTimeMultiplier == 1.35
        and found.offensiveTimingExact == false and copy(found) or nil
end
