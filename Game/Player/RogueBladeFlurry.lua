-- Exact Octo patch-5 Blade Flurry identity.  This is a permanent toggle that
-- trades 20% damage and Energy regeneration for an additional nearby weapon
-- recipient; it is not the short Vanilla burst cooldown.  The recipient is
-- selected by server script and is not exposed by the client, so graph code
-- must fail closed rather than inventing an AoE target.
XelAssist.Game.Player = XelAssist.Game.Player or {}
XelAssist.Game.Player.RogueBladeFlurry = {}
local B = XelAssist.Game.Player.RogueBladeFlurry

B.SPELL_ID = 13877
B.ROGUE_FAMILY = 8
B.ENERGY = 3
B.COST = 25
B.PENALTY_PERCENT = 20
local CACHE

local function finite(value)
    return type(value) == "number" and value == value
        and value >= -2147483648 and value <= 4294967295 and value
end

local function scalar(field)
    if type(GetSpellRecField) ~= "function" then return nil end
    local ok, value = pcall(GetSpellRecField, B.SPELL_ID, field)
    return ok and finite(value) or nil
end

local function triple(field)
    if type(GetSpellRecField) ~= "function" then return nil end
    local ok, values = pcall(GetSpellRecField, B.SPELL_ID, field, 1)
    if not ok or type(values) ~= "table" then return nil end
    local count, index = 0, nil
    for index in pairs(values) do
        if type(index) ~= "number" or index < 1 or index > 3
            or math.floor(index) ~= index then return nil end
        count = count + 1
    end
    if count ~= 3 then return nil end
    return finite(values[1]) and finite(values[2]) and finite(values[3])
        and { values[1], values[2], values[3] } or nil
end

local function equal(values, a, b, c)
    return values and values[1] == a and values[2] == b and values[3] == c
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

local function discover()
    if CACHE then return copy(CACHE) end
    local found = { recognized = true, valid = false, exact = false,
        portfolio = "rogueBladeFlurry", spellId = B.SPELL_ID,
        source = "installed Octo patch-5 Spell.dbc toggle topology" }
    if scalar("school") ~= 0 or scalar("attributes") ~= 262160
        or scalar("castingTimeIndex") ~= 1
        or scalar("recoveryTime") ~= 4000
        or scalar("categoryRecoveryTime") ~= 0
        or scalar("durationIndex") ~= 21
        or scalar("powerType") ~= B.ENERGY
        or scalar("manaCost") ~= B.COST
        or scalar("rangeIndex") ~= 1
        or scalar("startRecoveryCategory") ~= 133
        or scalar("startRecoveryTime") ~= 1000
        or scalar("spellFamilyName") ~= B.ROGUE_FAMILY
        or scalar("spellFamilyFlags") ~= 0
        or not equal(triple("effect"), 6, 6, 6)
        or not equal(triple("effectBasePoints"), -21, 0, -21)
        or not equal(triple("effectImplicitTargetA"), 1, 1, 1)
        or not equal(triple("effectApplyAuraName"), 110, 4, 79)
        or not equal(triple("effectMiscValue"), 3, 0, 127) then
        found.reason = "Blade Flurry patch-5 topology is incomplete"
    else
        found.valid, found.exact = true, true
        found.cost, found.powerType = B.COST, B.ENERGY
        found.cooldown, found.gcd, found.cast = 4, 1, 0
        found.permanentToggle = true
        found.additionalNearbyWeaponRecipient = true
        found.energyRegenMultiplier = 0.8
        found.damageMultiplier = 0.8
        found.recipientSelectionObservable = false
    end
    CACHE = copy(found)
    return copy(found)
end

function B:Classify(spellId)
    if tonumber(spellId) ~= self.SPELL_ID then
        return nil, "not the installed Blade Flurry identity", false
    end
    local found = discover()
    return found, found.reason, true
end

function B:InferKnowledge(spellId)
    if not rogue() then
        return nil, "player is not an exactly identified Rogue", false
    end
    local found, reason, handled = self:Classify(spellId)
    if not (found and found.valid) then return nil, reason, handled end
    return { inferred = true, kind = "buff", kindExact = true, self = true,
        rogueBladeFlurry = true, requiresExactRogueBladeFlurry = true,
        requiresExactUsability = true, submissionGuarded = true,
        cost = found.cost, powerType = found.powerType, gcd = found.gcd,
        cast = found.cast, cooldown = found.cooldown,
        rogueBladeFlurryEvidence = copy(found), source = found.source }, nil, true
end

function B:Evidence(subject)
    local facts = type(subject) == "table" and subject.facts or subject
    local found = facts and facts.rogueBladeFlurryEvidence
    if not (type(found) == "table" and found.valid == true
        and found.exact == true and found.portfolio == "rogueBladeFlurry"
        and found.spellId == self.SPELL_ID and found.cost == self.COST
        and found.powerType == self.ENERGY and found.cooldown == 4
        and found.gcd == 1 and found.cast == 0
        and found.permanentToggle == true
        and found.additionalNearbyWeaponRecipient == true
        and found.energyRegenMultiplier == 0.8
        and found.damageMultiplier == 0.8
        and found.recipientSelectionObservable == false) then return nil end
    return copy(found)
end

function B:Invalidate() CACHE = nil end
