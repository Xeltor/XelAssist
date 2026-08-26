-- Exact Hunter's Mark evidence from the installed build-5875 Spell.dbc.
-- Numeric identities select rows, but every rank must retain the complete
-- aura/recipient shape before the graph may use its target-local ranged AP.
-- Localized names and rank text never select mechanics or action order.
XelAssist.Game.Player = XelAssist.Game.Player or {}
XelAssist.Game.Player.HunterMark = {}
local H = XelAssist.Game.Player.HunterMark

H.HUNTER_FAMILY = 9
H.HUNTER_MARK_FLAG = 1024
H.MARK_AURA = 68
H.RANGED_AP_ATTACKER_AURA = 127
H.MAX_CACHE = 4

local RANKS = {
    [1130] = { rank = 1, level = 6, cost = 15, base = 19, bonus = 20 },
    [14323] = { rank = 2, level = 22, cost = 30, base = 44, bonus = 45 },
    [14324] = { rank = 3, level = 40, cost = 45, base = 74, bonus = 75 },
    [14325] = { rank = 4, level = 58, cost = 60, base = 109, bonus = 110 },
}
local CACHE, CACHE_COUNT = {}, 0

local function finite(value, low, high)
    if type(value) ~= "number" or value ~= value
        or value == math.huge or value == -math.huge
        or value < low or value > high then return nil end
    return value
end

local function integer(value, low, high)
    value = finite(value, low, high)
    return value and math.floor(value) == value and value or nil
end

local function copy(source)
    local out, key, value = {}, nil, nil
    for key, value in pairs(source or {}) do out[key] = value end
    return out
end

local function classToken()
    if type(UnitClass) ~= "function" then return nil end
    local ok, _, token = pcall(UnitClass, "player")
    return ok and type(token) == "string" and token or nil
end

local function scalar(spellId, field)
    if type(GetSpellRecField) ~= "function" then return nil end
    local ok, value = pcall(GetSpellRecField, spellId, field)
    return ok and finite(value, -2147483648, 4294967295) or nil
end

local function triple(spellId, field)
    if type(GetSpellRecField) ~= "function" then return nil end
    local ok, values = pcall(GetSpellRecField, spellId, field, 1)
    if not ok or type(values) ~= "table" then return nil end
    local out, count, key, index = {}, 0, nil, nil
    for key in pairs(values) do
        if integer(key, 1, 3) == nil then return nil end
        count = count + 1
    end
    if count ~= 3 then return nil end
    for index = 1, 3 do
        out[index] = finite(values[index], -2147483648, 4294967295)
        if out[index] == nil then return nil end
    end
    return out
end

local function equal(values, expected)
    return values and expected and values[1] == expected[1]
        and values[2] == expected[2] and values[3] == expected[3]
end

local function duration(spellId)
    if type(GetSpellDuration) ~= "function" then return nil end
    local ok, milliseconds = pcall(GetSpellDuration, spellId, 1)
    milliseconds = ok and integer(milliseconds, 1, 3600000) or nil
    return milliseconds and milliseconds / 1000 or nil
end

local function range(spellId)
    if scalar(spellId, "rangeIndex") ~= 6
        or type(GetSpellRangeData) ~= "function" then return nil, nil end
    local ok, minimum, maximum = pcall(GetSpellRangeData, 6)
    minimum, maximum = tonumber(minimum), tonumber(maximum)
    if not ok or minimum ~= 0 or maximum ~= 100 then return nil, nil end
    return minimum, maximum
end

local function scalarsMatch(spellId, rank)
    return scalar(spellId, "school") == 6
        and scalar(spellId, "category") == 0
        and scalar(spellId, "castUI") == 0
        and scalar(spellId, "dispel") == 1
        and scalar(spellId, "mechanic") == 0
        and scalar(spellId, "attributes") == 67174400
        and scalar(spellId, "attributesEx") == 1056
        and scalar(spellId, "attributesEx2") == 0
        and scalar(spellId, "attributesEx3") == 196609
        and scalar(spellId, "attributesEx4") == 0
        and scalar(spellId, "stances") == 0
        and scalar(spellId, "stancesNot") == 0
        and scalar(spellId, "targets") == 0
        and scalar(spellId, "targetCreatureType") == 0
        and scalar(spellId, "requiresSpellFocus") == 0
        and scalar(spellId, "casterAuraState") == 0
        and scalar(spellId, "targetAuraState") == 0
        and scalar(spellId, "castingTimeIndex") == 1
        and scalar(spellId, "recoveryTime") == 0
        and scalar(spellId, "categoryRecoveryTime") == 0
        and scalar(spellId, "interruptFlags") == 0
        and scalar(spellId, "auraInterruptFlags") == 0
        and scalar(spellId, "channelInterruptFlags") == 0
        and scalar(spellId, "procFlags") == 0
        and scalar(spellId, "procChance") == 101
        and scalar(spellId, "procCharges") == 0
        and scalar(spellId, "maxLevel") == 0
        and scalar(spellId, "baseLevel") == rank.level
        and scalar(spellId, "spellLevel") == rank.level
        and scalar(spellId, "durationIndex") == 4
        and scalar(spellId, "powerType") == 0
        and scalar(spellId, "manaCost") == rank.cost
        and scalar(spellId, "manaCostPerlevel") == 0
        and scalar(spellId, "manaPerSecond") == 0
        and scalar(spellId, "manaPerSecondPerLevel") == 0
        and scalar(spellId, "modalNextSpell") == 0
        and scalar(spellId, "stackAmount") == 0
        and scalar(spellId, "equippedItemClass") == -1
        and scalar(spellId, "equippedItemSubClassMask") == 0
        and scalar(spellId, "equippedItemInventoryTypeMask") == 0
        and scalar(spellId, "manaCostPercentage") == 0
        and scalar(spellId, "startRecoveryCategory") == 133
        and scalar(spellId, "startRecoveryTime") == 1500
        and scalar(spellId, "spellFamilyName") == H.HUNTER_FAMILY
        and scalar(spellId, "spellFamilyFlags") == H.HUNTER_MARK_FLAG
        and scalar(spellId, "maxAffectedTargets") == 0
        and scalar(spellId, "dmgClass") == 0
        and scalar(spellId, "preventionType") == 0
end

local ZERO, ONE_FIRST = { 0, 0, 0 }, { 1, 0, 0 }
local EFFECT, TARGET, AURA = { 6, 6, 0 }, { 25, 6, 0 }, { 68, 127, 0 }
local DICE, BASE_DICE = { 1, 1, 0 }, { 1, 1, 0 }

local function arraysMatch(spellId, rank)
    return equal(triple(spellId, "effect"), EFFECT)
        and equal(triple(spellId, "effectDieSides"), DICE)
        and equal(triple(spellId, "effectBaseDice"), BASE_DICE)
        and equal(triple(spellId, "effectDicePerLevel"), ZERO)
        and equal(triple(spellId, "effectRealPointsPerLevel"), ZERO)
        and equal(triple(spellId, "effectBasePoints"),
            { -1, rank.base, 0 })
        and equal(triple(spellId, "effectMechanic"), ZERO)
        and equal(triple(spellId, "effectImplicitTargetA"), TARGET)
        and equal(triple(spellId, "effectImplicitTargetB"), ZERO)
        and equal(triple(spellId, "effectRadiusIndex"), ZERO)
        and equal(triple(spellId, "effectApplyAuraName"), AURA)
        and equal(triple(spellId, "effectAmplitude"), ZERO)
        and equal(triple(spellId, "effectMultipleValue"), ONE_FIRST)
        and equal(triple(spellId, "effectChainTarget"), ZERO)
        and equal(triple(spellId, "effectItemType"), ZERO)
        and equal(triple(spellId, "effectMiscValue"), ZERO)
        and equal(triple(spellId, "effectTriggerSpell"), ZERO)
        and equal(triple(spellId, "effectPointsPerComboPoint"), ZERO)
end

local function raw(spellId)
    if CACHE[spellId] then
        local cached = copy(CACHE[spellId])
        return cached, cached.reason, cached.recognized == true
    end
    local rank = RANKS[spellId]
    if not rank then
        return nil, "not an installed Hunter's Mark identity", false
    end
    local found = { recognized = true, valid = false, exact = false,
        portfolio = "hunterMark", spellId = spellId, rank = rank.rank,
        source = "installed build-5875 Hunter's Mark DBC aura-127 topology" }
    local minimum, maximum = range(spellId)
    if not (scalarsMatch(spellId, rank) and arraysMatch(spellId, rank)
        and duration(spellId) == 120 and minimum == 0 and maximum == 100) then
        found.reason = "Hunter's Mark DBC topology is incomplete"
    else
        found.valid, found.exact = true, true
        found.baseLevel, found.spellLevel = rank.level, rank.level
        found.powerType, found.cost = 0, rank.cost
        found.duration, found.minRange, found.maxRange = 120, minimum, maximum
        found.gcd, found.cast, found.school = 1.5, 0, 6
        found.deliveryModel, found.deliverySubtype = "magic", "spell"
        found.recipient = "selected-hostile"
        found.markAura, found.rangedAttackPowerAura =
            H.MARK_AURA, H.RANGED_AP_ATTACKER_AURA
        found.rangedAttackPowerBonus = rank.bonus
    end
    if CACHE_COUNT < H.MAX_CACHE then
        CACHE[spellId], CACHE_COUNT = copy(found), CACHE_COUNT + 1
    end
    return copy(found), found.reason, true
end

local function sealed(subject)
    local facts = type(subject) == "table" and subject.facts or subject
    local found = type(facts) == "table" and facts.hunterMarkEvidence
    local rank = type(found) == "table" and RANKS[found.spellId] or nil
    if not (rank and found.valid == true and found.exact == true
        and found.portfolio == "hunterMark" and found.rank == rank.rank
        and found.baseLevel == rank.level and found.spellLevel == rank.level
        and found.powerType == 0 and found.cost == rank.cost
        and found.duration == 120 and found.minRange == 0
        and found.maxRange == 100 and found.gcd == 1.5
        and found.cast == 0 and found.school == 6
        and found.deliveryModel == "magic"
        and found.deliverySubtype == "spell"
        and found.recipient == "selected-hostile"
        and found.markAura == H.MARK_AURA
        and found.rangedAttackPowerAura == H.RANGED_AP_ATTACKER_AURA
        and found.rangedAttackPowerBonus == rank.bonus) then return nil end
    return found
end

function H:Classify(spellId)
    spellId = integer(spellId, 1, 4294967295)
    if not spellId then return nil, "Hunter's Mark identity unavailable", false end
    return raw(spellId)
end

function H:InferKnowledge(spellId)
    if classToken() ~= "HUNTER" then
        return nil, "player is not an exactly identified Hunter", false
    end
    local found, reason, handled = self:Classify(spellId)
    if not (found and found.valid == true) then return nil, reason, handled end
    return { inferred = true, kind = "debuff", kindExact = true,
        hunterMark = true, hostile = true, ranged = true,
        targetLocalRangedAttackPower = true,
        requiresExactHunterMarkDownstream = true,
        requiresExactUsability = true, submissionGuarded = true,
        school = found.school, deliveryModel = found.deliveryModel,
        deliverySubtype = found.deliverySubtype,
        hunterMarkEvidence = copy(found), source = found.source }, nil, true
end

function H:Evidence(subject)
    local found = sealed(subject)
    return found and copy(found) or nil
end

local WEAPON_EFFECT = { [17] = true, [31] = true, [58] = true, [121] = true }
local function rangedWeapon(action, facts)
    if not (action and action.actor ~= "pet" and tonumber(action.spellId)
        and type(facts) == "table" and tonumber(facts.weaponCoefficient)
        and facts.weaponFormulaSource == "OctoWoW VMaNGOS weapon effects"
        and scalar(action.spellId, "dmgClass") == 3) then return nil end
    local effects = triple(action.spellId, "effect")
    if not effects then return nil end
    local count, normalized, index = 0, false, nil
    for index = 1, 3 do
        local opcode = tonumber(effects[index]) or 0
        if opcode == 2 then return nil end
        if WEAPON_EFFECT[opcode] then
            count = count + 1
            if opcode == 121 then normalized = true end
        end
    end
    if count ~= 1 then return nil end
    return { valid = true, exact = true, portfolio = "hunterMark",
        spellId = action.spellId, attackType = "ranged",
        weaponEffectCount = count, normalized = normalized,
        weaponCoefficient = facts.weaponCoefficient,
        source = "installed-client ranged weapon effect and DmgClass" }
end

-- Root capture consumes already-sealed mark evidence for the mark itself and
-- may additionally seal a ranged weapon action while live DBC is permitted.
function H:CaptureFacts(action, facts)
    local out = copy(facts)
    local mark = self:Evidence(action)
    if mark then
        out.hunterMark, out.targetLocalRangedAttackPower = true, true
        out.hunterMarkEvidence = copy(mark)
        out.powerType, out.cost = mark.powerType, mark.cost
        out.duration, out.minRange, out.maxRange = mark.duration,
            mark.minRange, mark.maxRange
        out.gcd, out.cast, out.school = mark.gcd, mark.cast, mark.school
        out.deliveryModel, out.deliverySubtype = mark.deliveryModel,
            mark.deliverySubtype
    end
    local weapon = rangedWeapon(action, out)
    if weapon then out.hunterRangedWeaponEvidence = weapon end
    return out
end

function H:CaptureRangedLane()
    if classToken() ~= "HUNTER" or type(UnitRangedDamage) ~= "function" then
        return { valid = false, exact = false,
            reason = "exact Hunter ranged damage lane unavailable" }
    end
    local ok, speed, low, high, _, _, percent = pcall(
        UnitRangedDamage, "player")
    speed, low, high, percent = tonumber(speed), tonumber(low),
        tonumber(high), tonumber(percent)
    if not (ok and finite(speed, 0.01, 20)
        and finite(low, 0, 10000000) and finite(high, low, 10000000)
        and finite(percent, 0.0001, 100)) then
        return { valid = false, exact = false,
            reason = "exact Hunter ranged damage lane unavailable" }
    end
    return { valid = true, exact = true, speed = speed,
        damageMultiplier = percent, damageMultiplierUnits = "factor",
        observedLow = low, observedHigh = high,
        source = "root-captured UnitRangedDamage speed and multiplier factor" }
end

function H:RootEvidence()
    local out = { valid = classToken() == "HUNTER", exact = true,
        portfolio = "hunterMark", ranks = {}, lane = self:CaptureRangedLane() }
    local spellId, found
    for spellId in pairs(RANKS) do
        found = self:Classify(spellId)
        out.ranks[spellId] = found
        if not (found and found.valid == true) then out.exact = false end
    end
    if not out.valid or not out.lane.valid then out.exact = false end
    return out
end

function H:Invalidate()
    CACHE, CACHE_COUNT = {}, 0
end
