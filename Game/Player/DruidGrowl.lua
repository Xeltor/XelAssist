-- Exact installed Druid Growl identity. The patch-5 row is a free, off-GCD
-- Bear/Dire Bear player taunt with the same three-second forced-attack aura as
-- Warrior Taunt. Generic taunt semantics are insufficient because execution
-- must retain class-specific form and range legality.
XelAssist.Game.Player.DruidGrowl = {}
local G = XelAssist.Game.Player.DruidGrowl

G.SPELL_ID = 6795
G.DRUID_FAMILY = 7
G.BEAR_FORM_MASK = 144
G.TAUNT_CATEGORY = 82
G.RANGE_INDEX = 2
G.DURATION_INDEX = 27
G.FOCUS_SECONDS = 3
local CACHE

local function scalar(field)
    if type(GetSpellRecField) ~= "function" then return nil end
    local ok, value = pcall(GetSpellRecField, G.SPELL_ID, field)
    return ok and type(value) == "number" and value or nil
end
local function triple(field)
    if type(GetSpellRecField) ~= "function" then return nil end
    local ok, values = pcall(GetSpellRecField, G.SPELL_ID, field, 1)
    if not ok or type(values) ~= "table" then return nil end
    local out, count, index = {}, 0, nil
    for index in pairs(values) do
        if type(index) ~= "number" or index < 1 or index > 3
            or math.floor(index) ~= index then return nil end
        count = count + 1
    end
    if count ~= 3 then return nil end
    for index = 1, 3 do
        if type(values[index]) ~= "number" then return nil end
        out[index] = values[index]
    end
    return out
end
local function equal(values, a, b, c)
    return values and values[1] == a and values[2] == b and values[3] == c
end
local function copy(source)
    local out, key, value = {}, nil, nil
    for key, value in pairs(source or {}) do out[key] = value end
    return out
end
local function druid()
    if type(UnitClass) ~= "function" then return false end
    local ok, _, token = pcall(UnitClass, "player")
    return ok and token == "DRUID"
end

local function classify()
    if CACHE then return copy(CACHE) end
    local found = { recognized = true, valid = false, exact = false,
        spellId = G.SPELL_ID, tauntFocusDuration = G.FOCUS_SECONDS,
        source = "installed Octo patch-5 Druid Growl topology" }
    if scalar("spellFamilyName") ~= G.DRUID_FAMILY
        or scalar("spellFamilyFlags") ~= 0
        or scalar("spellFamilyFlags2") ~= 8
        or scalar("category") ~= G.TAUNT_CATEGORY
        or scalar("stances") ~= G.BEAR_FORM_MASK
        or scalar("stancesNot") ~= 0
        or scalar("rangeIndex") ~= G.RANGE_INDEX
        or scalar("durationIndex") ~= G.DURATION_INDEX
        or scalar("powerType") ~= 1 or scalar("manaCost") ~= 0
        or scalar("manaCostPerlevel") ~= 0
        or scalar("manaCostPercentage") ~= 0
        or scalar("manaPerSecond") ~= 0
        or scalar("manaPerSecondPerLevel") ~= 0
        or scalar("recoveryTime") ~= 0
        or scalar("categoryRecoveryTime") ~= 10000
        or scalar("startRecoveryCategory") ~= 0
        or scalar("startRecoveryTime") ~= 0
        or not equal(triple("effect"), 114, 6, 0)
        or not equal(triple("effectApplyAuraName"), 0, 11, 0)
        or not equal(triple("effectImplicitTargetA"), 0, 0, 0)
        or not equal(triple("effectImplicitTargetB"), 6, 6, 0)
        or not equal(triple("effectTriggerSpell"), 0, 0, 0) then
        found.reason = "Octo Druid Growl DBC topology is incomplete"
        CACHE = copy(found); return found
    end
    found.valid, found.exact = true, true
    found.formMask, found.rangeIndex = G.BEAR_FORM_MASK, G.RANGE_INDEX
    found.cooldown, found.gcd, found.cost, found.powerType = 10, 0, 0, 1
    found.noOpWhenTargetingCaster = true
    CACHE = copy(found); return found
end

function G:InferKnowledge(spellId)
    if not druid() or tonumber(spellId) ~= self.SPELL_ID then
        return nil, nil, false
    end
    local found = classify()
    if not found.valid then return nil, found.reason, true end
    return { inferred = true, kind = "taunt", kindExact = true,
        playerTaunt = true, druidGrowl = true,
        requiresExactPlayerTaunt = true, tankOnly = true,
        immediateDispatch = true, requiresExactUsability = true,
        submissionGuarded = true, tauntFocusDuration = self.FOCUS_SECONDS,
        gcd = 0, druidGrowlEvidence = copy(found), source = found.source }, nil, true
end

function G:Evidence(subject)
    local facts = type(subject) == "table" and subject.facts or subject
    local found = facts and facts.druidGrowlEvidence
    if not (facts and facts.druidGrowl == true and facts.playerTaunt == true
        and type(found) == "table" and found.valid == true
        and found.exact == true and found.spellId == self.SPELL_ID
        and found.formMask == self.BEAR_FORM_MASK
        and found.rangeIndex == self.RANGE_INDEX and found.cooldown == 10
        and found.gcd == 0 and found.cost == 0 and found.powerType == 1
        and found.tauntFocusDuration == self.FOCUS_SECONDS
        and found.noOpWhenTargetingCaster == true) then return nil end
    return copy(found)
end

function G:Invalidate() CACHE = nil end
