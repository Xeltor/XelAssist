-- Exact Slice and Dice discovery from the installed build-5875 Spell.dbc.
-- Numeric identities only select candidate rows; the full effect topology,
-- combo duration range and self melee-haste aura must agree before graph code
-- may consume the sealed evidence.
XelAssist.Game.Player = XelAssist.Game.Player or {}
XelAssist.Game.Player.RogueSliceAndDice = {}
local S = XelAssist.Game.Player.RogueSliceAndDice

S.ROGUE_FAMILY = 8
S.FAMILY_FLAG = 262144
S.MELEE_HASTE_AURA = 138
S.ENERGY = 3
S.MAX_CACHE = 2
S.RANK_COUNT = 2

local RANKS = {
    [5171] = { rank = 1, level = 10, basePoints = 19, percent = 20 },
    [6774] = { rank = 2, level = 42, basePoints = 29, percent = 30 },
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

local function durationRange(spellId)
    local api = C_Spell and C_Spell.GetSpellDurationRange
    if type(api) ~= "function" then return nil, nil, nil end
    local ok, base, maximum, scaled = pcall(api, spellId)
    base, maximum = tonumber(base), tonumber(maximum)
    if not ok then return nil, nil, nil end
    return base, maximum, scaled and true or false
end

local function scalarsMatch(spellId, rank)
    return scalar(spellId, "school") == 0
        and scalar(spellId, "category") == 0
        and scalar(spellId, "mechanic") == 0
        and scalar(spellId, "attributes") == 537198608
        and scalar(spellId, "attributesEx") == 4195328
        and scalar(spellId, "attributesEx2") == 4
        and scalar(spellId, "attributesEx3") == 1342439424
        and scalar(spellId, "attributesEx4") == 16
        and scalar(spellId, "stances") == 0
        and scalar(spellId, "stancesNot") == 0
        and scalar(spellId, "targets") == 0
        and scalar(spellId, "castingTimeIndex") == 1
        and scalar(spellId, "recoveryTime") == 0
        and scalar(spellId, "categoryRecoveryTime") == 0
        and scalar(spellId, "interruptFlags") == 0
        and scalar(spellId, "auraInterruptFlags") == 0
        and scalar(spellId, "channelInterruptFlags") == 0
        and scalar(spellId, "maxLevel") == 0
        and scalar(spellId, "baseLevel") == rank.level
        and scalar(spellId, "spellLevel") == rank.level
        and scalar(spellId, "durationIndex") == 185
        and scalar(spellId, "powerType") == S.ENERGY
        and scalar(spellId, "manaCost") == 20
        and scalar(spellId, "manaCostPerlevel") == 0
        and scalar(spellId, "manaPerSecond") == 0
        and scalar(spellId, "manaPerSecondPerLevel") == 0
        and scalar(spellId, "rangeIndex") == 6
        and scalar(spellId, "startRecoveryCategory") == 133
        and scalar(spellId, "startRecoveryTime") == 1000
        and scalar(spellId, "spellFamilyName") == S.ROGUE_FAMILY
        and scalar(spellId, "spellFamilyFlags") == S.FAMILY_FLAG
        and scalar(spellId, "maxAffectedTargets") == 0
        and scalar(spellId, "dmgClass") == 0
        and scalar(spellId, "preventionType") == 2
end

local ZERO = { 0, 0, 0 }
local EFFECT, DICE = { 3, 6, 0 }, { 0, 1, 0 }
local TARGET, AURA = { 6, 1, 0 }, { 0, 138, 0 }

local function arraysMatch(spellId, rank)
    return equal(triple(spellId, "effect"), EFFECT)
        and equal(triple(spellId, "effectDieSides"), DICE)
        and equal(triple(spellId, "effectBaseDice"), DICE)
        and equal(triple(spellId, "effectDicePerLevel"), ZERO)
        and equal(triple(spellId, "effectRealPointsPerLevel"), ZERO)
        and equal(triple(spellId, "effectBasePoints"),
            { 0, rank.basePoints, 0 })
        and equal(triple(spellId, "effectMechanic"), ZERO)
        and equal(triple(spellId, "effectImplicitTargetA"), TARGET)
        and equal(triple(spellId, "effectImplicitTargetB"), ZERO)
        and equal(triple(spellId, "effectRadiusIndex"), ZERO)
        and equal(triple(spellId, "effectApplyAuraName"), AURA)
        and equal(triple(spellId, "effectAmplitude"), ZERO)
        and equal(triple(spellId, "effectMultipleValue"), ZERO)
        and equal(triple(spellId, "effectChainTarget"), ZERO)
        and equal(triple(spellId, "effectItemType"), ZERO)
        and equal(triple(spellId, "effectMiscValue"), ZERO)
        and equal(triple(spellId, "effectTriggerSpell"), ZERO)
        and equal(triple(spellId, "effectPointsPerComboPoint"), ZERO)
end

local function classifyRaw(spellId)
    if CACHE[spellId] then return copy(CACHE[spellId]) end
    local rank = RANKS[spellId]
    if not rank then return nil end
    local found = { recognized = true, valid = false, exact = false,
        portfolio = "rogueSliceAndDice", spellId = spellId,
        rank = rank.rank, source = "installed build-5875 Rogue aura-138 topology" }
    local base, maximum, scaled = durationRange(spellId)
    local durationScale = base and base / 6 or nil
    if not (scalarsMatch(spellId, rank) and arraysMatch(spellId, rank)
        and finite(base, 0.001, 120) and finite(maximum, base, 300)
        and finite(durationScale, 0.5, 2)
        and math.abs(maximum - 21 * durationScale) <= 0.01
        and scaled == true) then
        found.reason = "Slice and Dice DBC topology is incomplete"
    else
        found.valid, found.exact = true, true
        found.level, found.powerType, found.cost = rank.level, S.ENERGY, 20
        found.durationBase, found.durationMax = base, maximum
        found.durationComboScaled, found.durationSpellModFactor =
            true, durationScale
        found.hastePercent, found.hasteMultiplier = rank.percent,
            1 + rank.percent / 100
        found.aura, found.recipient = S.MELEE_HASTE_AURA, "player"
        found.gcd, found.cast, found.school = 1, 0, 0
    end
    if CACHE_COUNT < S.MAX_CACHE then
        CACHE[spellId], CACHE_COUNT = copy(found), CACHE_COUNT + 1
    end
    return copy(found)
end

local function sealed(subject)
    local facts = type(subject) == "table" and subject.facts or subject
    local found = type(facts) == "table" and facts.rogueSliceAndDiceEvidence
    local rank = type(found) == "table" and RANKS[found.spellId] or nil
    if not (rank and found.valid == true and found.exact == true
        and found.portfolio == "rogueSliceAndDice"
        and found.rank == rank.rank and found.level == rank.level
        and found.powerType == S.ENERGY and found.cost == 20
        and finite(found.durationBase, 0.001, 120)
        and finite(found.durationMax, found.durationBase, 300)
        and finite(found.durationSpellModFactor, 0.5, 2)
        and math.abs(found.durationBase
            - 6 * found.durationSpellModFactor) <= 0.01
        and math.abs(found.durationMax
            - 21 * found.durationSpellModFactor) <= 0.01
        and found.durationComboScaled == true
        and found.hastePercent == rank.percent
        and found.hasteMultiplier == 1 + rank.percent / 100
        and found.aura == S.MELEE_HASTE_AURA
        and found.recipient == "player" and found.gcd == 1
        and found.cast == 0 and found.school == 0) then return nil end
    return found
end

function S:Classify(spellId)
    spellId = integer(spellId, 1, 4294967295)
    if not spellId or not RANKS[spellId] then
        return nil, "not an installed Slice and Dice identity", false
    end
    local found = classifyRaw(spellId)
    return found, found and found.reason or nil, true
end

function S:InferKnowledge(spellId)
    if classToken() ~= "ROGUE" then
        return nil, "player is not an exactly identified Rogue", false
    end
    local found, reason, handled = self:Classify(spellId)
    if not (found and found.valid == true) then return nil, reason, handled end
    return { inferred = true, kind = "buff", kindExact = true,
        self = true, combo = true, comboSpendAll = true,
        rogueSliceAndDice = true, playerMeleeHaste = true,
        requiresExactRogueMeleeHaste = true,
        requiresExactUsability = true, submissionGuarded = true,
        rogueSliceAndDiceEvidence = copy(found), source = found.source }, nil, true
end

function S:Evidence(subject)
    local found = sealed(subject)
    return found and copy(found) or nil
end

function S:CaptureFacts(action, facts)
    local out, found = copy(facts), self:Evidence(action) or self:Evidence(facts)
    if not found then return out end
    out.rogueSliceAndDice, out.playerMeleeHaste = true, true
    out.rogueSliceAndDiceEvidence = copy(found)
    out.self, out.combo, out.comboSpendAll = true, true, true
    out.powerType, out.cost = found.powerType, found.cost
    out.durationBase, out.durationMax = found.durationBase, found.durationMax
    out.durationComboScaled = true
    out.gcd, out.cast, out.school = found.gcd, found.cast, found.school
    out.meleeHastePercent = found.hastePercent
    return out
end

local function liveAura()
    local api = C_UnitAuras and C_UnitAuras.GetUnitAuras
    if type(api) ~= "function" then
        return { valid = false, exact = false,
            reason = "numeric player aura evidence unavailable" }
    end
    local ok, list = pcall(api, "player", "HELPFUL")
    if not ok or type(list) ~= "table" then
        return { valid = false, exact = false,
            reason = "numeric player aura evidence unavailable" }
    end
    local active, index
    for index = 1, table.getn(list) do
        local aura = list[index]
        local spellId = type(aura) == "table" and tonumber(aura.spellId)
        if not spellId then
            return { valid = false, exact = false,
                reason = "player aura identity is incomplete" }
        end
        local rank = RANKS[spellId]
        if rank then
            if active then
                return { valid = false, exact = false,
                    reason = "multiple melee-haste ranks are unresolved" }
            end
            local found = classifyRaw(spellId)
            local expiration = tonumber(aura.expirationTime)
            local at = type(GetTime) == "function" and tonumber(GetTime()) or nil
            local remaining = expiration and at and expiration - at or nil
            if not (found and found.valid and remaining and remaining > 0) then
                return { valid = false, exact = false,
                    reason = "active melee-haste expiration is unavailable" }
            end
            active = { spellId = spellId, percent = rank.percent,
                remaining = remaining }
        end
    end
    return { valid = true, exact = true, active = active ~= nil,
        spellId = active and active.spellId or nil,
        percent = active and active.percent or nil,
        remaining = active and active.remaining or nil,
        source = "ClassicAPI numeric player aura snapshot" }
end

function S:RootEvidence()
    local out = { valid = classToken() == "ROGUE", exact = true,
        portfolio = "rogueSliceAndDice", ranks = {}, aura = liveAura() }
    local spellId, found
    for spellId in pairs(RANKS) do
        found = classifyRaw(spellId)
        if not (found and found.valid) then
            out.valid, out.exact = false, false
            out.reason = found and found.reason
                or "Slice and Dice rank evidence unavailable"
        end
        out.ranks[spellId] = found
    end
    if not (out.aura and out.aura.valid) then
        out.valid, out.exact = false, false
        out.reason = out.aura and out.aura.reason
            or "numeric player aura evidence unavailable"
    end
    return out
end

function S:Invalidate()
    CACHE, CACHE_COUNT = {}, 0
end
