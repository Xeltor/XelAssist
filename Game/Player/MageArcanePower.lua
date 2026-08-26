-- Exact identity guard for Octo's rewritten Arcane Power. Unlike Vanilla's
-- ordinary damage cooldown, it periodically drains maximum mana, suppresses
-- mana gain, cannot be cancelled and has a terminal low-mana branch. Until
-- those consequences exist in branch-local graph state, it must not fall
-- through to generic buff scoring.
XelAssist.Game.Player.MageArcanePower = {}
local A = XelAssist.Game.Player.MageArcanePower

A.SPELL_ID = 12042
local PROFILE

local function signed(value)
    value = tonumber(value)
    if value == nil then return nil end
    if value >= 2147483648 then value = value - 4294967296 end
    return value
end

local function scalar(field, asSigned)
    if type(GetSpellRecField) ~= "function" then return nil end
    local ok, value = pcall(GetSpellRecField, A.SPELL_ID, field)
    if not ok then return nil end
    return asSigned and signed(value) or tonumber(value)
end

local function triple(field, asSigned)
    if type(GetSpellRecField) ~= "function" then return nil end
    local ok, values = pcall(GetSpellRecField, A.SPELL_ID, field, 1)
    if not ok or type(values) ~= "table" then return nil end
    local out, count, key, index = {}, 0, nil, nil
    for key in pairs(values) do
        if type(key) ~= "number" or key < 1 or key > 3
            or key ~= math.floor(key) then return nil end
        count = count + 1
    end
    if count ~= 3 then return nil end
    for index = 1, 3 do
        out[index] = asSigned and signed(values[index])
            or tonumber(values[index])
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

local function profile()
    if PROFILE then return PROFILE.valid and copy(PROFILE) or nil, PROFILE.reason end
    PROFILE = { valid = false, exact = false, spellId = A.SPELL_ID,
        source = "installed Octo patch-5 Arcane Power DBC topology" }
    if scalar("school") ~= 6 or scalar("attributes") ~= 2147811328
        or scalar("attributesEx") ~= 0 or scalar("recoveryTime") ~= 180000
        or scalar("durationIndex") ~= 18 or scalar("powerType", true) ~= 0
        or scalar("manaCost") ~= 0 or scalar("spellFamilyName") ~= 3
        or scalar("spellFamilyFlags") ~= 0
        or scalar("spellFamilyFlags2") ~= 32
        or not equal(triple("effect"), 6, 6, 6)
        or not equal(triple("effectApplyAuraName"), 65, 64, 214)
        or not equal(triple("effectBasePoints", true), 29, 0, -51)
        or not equal(triple("effectImplicitTargetA"), 1, 1, 1)
        or not equal(triple("effectAmplitude"), 0, 1000, 0) then
        PROFILE.reason = "Arcane Power DBC topology is incomplete"
        return nil, PROFILE.reason
    end
    PROFILE.valid, PROFILE.exact = true, true
    PROFILE.cooldown, PROFILE.castSpeedPercent = 180, 30
    PROFILE.manaDrainPeriod, PROFILE.manaDrainPercent = 1, 1
    PROFILE.manaGainPercent = -50
    PROFILE.lowManaTerminalThresholdPercent = 10
    PROFILE.cancellable, PROFILE.consequencesModeled = false, false
    return copy(PROFILE)
end

function A:InferKnowledge(spellId)
    if tonumber(spellId) ~= self.SPELL_ID then
        return nil, "spell is not Arcane Power", false
    end
    local found, reason = profile()
    if not found then return nil, reason, true end
    local blocker = "Arcane Power periodic mana drain and terminal branch are not modeled"
    return { inferred = true, kind = "buff", kindExact = true, self = true,
        cooldown = true, mageArcanePower = true,
        mageArcanePowerEvidence = found, unmodeledUnsafe = blocker,
        unsafeDependencies = { "branch-local maximum-mana drain",
            "mana-gain suppression", "uncancellable lifetime",
            "low-mana terminal health consequence" }, source = found.source }, nil, true
end

function A:Evidence(subject)
    local facts = type(subject) == "table" and subject.facts or subject
    local found = facts and facts.mageArcanePowerEvidence
    if not (facts and facts.mageArcanePower == true
        and type(found) == "table" and found.valid == true
        and found.exact == true and found.spellId == self.SPELL_ID
        and found.manaDrainPeriod == 1 and found.manaDrainPercent == 1
        and found.manaGainPercent == -50
        and found.lowManaTerminalThresholdPercent == 10
        and found.cancellable == false
        and found.consequencesModeled == false) then return nil end
    return copy(found)
end

function A:Invalidate() PROFILE = nil end
