-- Exact Octo Hand of Reckoning identity. Its two DBC effects are the same
-- direct taunt plus forced-attack aura used by vanilla Taunt, but it is a
-- ranged Paladin-family spell with no stance requirement.
XelAssist.Game.Player.PaladinHandOfReckoning = {}
local H = XelAssist.Game.Player.PaladinHandOfReckoning

H.SPELL_ID = 51302
H.PALADIN_FAMILY = 10
H.RANGE_INDEX = 7
H.DURATION_INDEX = 27
H.TAUNT_CATEGORY = 82
H.FOCUS_SECONDS = 3

local CACHE

local function scalar(field)
    if type(GetSpellRecField) ~= "function" then return nil end
    local ok, value = pcall(GetSpellRecField, H.SPELL_ID, field)
    return ok and type(value) == "number" and value or nil
end

local function triple(field)
    if type(GetSpellRecField) ~= "function" then return nil end
    local ok, values = pcall(GetSpellRecField, H.SPELL_ID, field, 1)
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

local function classToken()
    if type(UnitClass) ~= "function" then return nil end
    local ok, _, token = pcall(UnitClass, "player")
    return ok and token or nil
end

local function classify()
    if CACHE then return copy(CACHE) end
    local found = { recognized = true, valid = false, exact = false,
        spellId = H.SPELL_ID, tauntFocusDuration = H.FOCUS_SECONDS,
        source = "installed Octo patch-5 Hand of Reckoning topology" }
    if not (scalar("spellFamilyName") == H.PALADIN_FAMILY
        and scalar("school") == 0
        and scalar("category") == H.TAUNT_CATEGORY
        and scalar("rangeIndex") == H.RANGE_INDEX
        and scalar("durationIndex") == H.DURATION_INDEX
        -- Power type 0 is the client Mana enum. Every cost channel is zero;
        -- the spell is genuinely free rather than an omitted tooltip cost.
        and scalar("powerType") == 0 and scalar("manaCost") == 0
        and scalar("manaCostPerlevel") == 0
        and scalar("manaCostPercentage") == 0
        and scalar("manaPerSecond") == 0
        and scalar("manaPerSecondPerLevel") == 0
        and scalar("recoveryTime") == 0
        and scalar("categoryRecoveryTime") == 10000
        -- Both global-recovery fields are zero in patch-5. This is the exact
        -- evidence that permits the emitted off-GCD contract.
        and scalar("startRecoveryCategory") == 0
        and scalar("startRecoveryTime") == 0
        and equal(triple("effect"), 114, 6, 0)
        and equal(triple("effectApplyAuraName"), 0, 11, 0)
        and equal(triple("effectImplicitTargetA"), 6, 6, 0)
        and equal(triple("effectTriggerSpell"), 0, 0, 0)) then
        found.reason = "Octo Hand of Reckoning DBC topology is incomplete"
        CACHE = copy(found)
        return found
    end
    found.valid, found.exact = true, true
    found.noOpWhenTargetingCaster = true
    found.rangeIndex, found.cooldown = H.RANGE_INDEX, 10
    CACHE = copy(found)
    return found
end

function H:InferKnowledge(spellId)
    if classToken() ~= "PALADIN" or tonumber(spellId) ~= H.SPELL_ID then
        return nil, nil, false
    end
    local found = classify()
    if not found.valid then return nil, found.reason, true end
    return { inferred = true, kind = "taunt", kindExact = true,
        playerTaunt = true, paladinHandOfReckoning = true,
        requiresExactPlayerTaunt = true, tankOnly = true,
        immediateDispatch = true, requiresExactUsability = true,
        submissionGuarded = true, tauntFocusDuration = H.FOCUS_SECONDS,
        gcd = 0, handOfReckoningEvidence = copy(found),
        source = found.source }, nil, true
end

function H:Evidence(subject)
    local facts = type(subject) == "table" and subject.facts or subject
    local found = facts and facts.handOfReckoningEvidence
    if not (facts and facts.paladinHandOfReckoning == true
        and facts.playerTaunt == true and type(found) == "table"
        and found.valid == true and found.exact == true
        and found.spellId == H.SPELL_ID
        and found.noOpWhenTargetingCaster == true
        and found.tauntFocusDuration == H.FOCUS_SECONDS
        and found.rangeIndex == H.RANGE_INDEX and found.cooldown == 10) then
        return nil
    end
    return copy(found)
end

function H:Invalidate() CACHE = nil end
