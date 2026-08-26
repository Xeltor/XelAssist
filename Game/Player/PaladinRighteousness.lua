-- Exact build-5875 Seal/Judgement of Righteousness evidence. Numeric rows,
-- their dummy-effect link and the hidden result topology select the mechanic;
-- localized names and rank order never do. Mutable character modifiers are
-- captured at the root and descendants consume only sealed profiles.
XelAssist.Game.Player.PaladinRighteousness = {}
local R = XelAssist.Game.Player.PaladinRighteousness

R.JUDGEMENT_ID = 20271
R.PALADIN_FAMILY = 10
R.JUDGEMENT_FLAG = 8388608
R.SEAL_FLAG = 68853694464
R.SEAL_LOW_FLAG = 134217728
R.RESULT_FLAG = 1024
R.HOLY_SCHOOL = 1
R.ALL_EFFECTS_MOD = 8
R.DAMAGE_MOD = 0
R.BONUS_COEFFICIENT_MOD = 24

R.RANKS = {
    [21084] = { result = 20187, max = 7, baseLevel = 1, spellLevel = 1,
        points = 14, sides = 1, perLevel = 1.8, coefficient = 0.144 },
    [20287] = { result = 20280, max = 16, baseLevel = 10, spellLevel = 10,
        points = 24, sides = 3, perLevel = 1.9, coefficient = 0.312 },
    [20288] = { result = 20281, max = 24, baseLevel = 18, spellLevel = 18,
        points = 38, sides = 5, perLevel = 2.4, coefficient = 0.462 },
    [20289] = { result = 20282, max = 32, baseLevel = 26, spellLevel = 26,
        points = 56, sides = 7, perLevel = 2.8, coefficient = 0.5 },
    [20290] = { result = 20283, max = 40, baseLevel = 34, spellLevel = 34,
        points = 77, sides = 9, perLevel = 3.1, coefficient = 0.5 },
    [20291] = { result = 20284, max = 48, baseLevel = 42, spellLevel = 42,
        points = 101, sides = 11, perLevel = 3.8, coefficient = 0.5 },
    [20292] = { result = 20285, max = 56, baseLevel = 50, spellLevel = 50,
        points = 130, sides = 13, perLevel = 4.1, coefficient = 0.5 },
    [20293] = { result = 20286, max = 64, baseLevel = 58, spellLevel = 58,
        points = 161, sides = 17, perLevel = 4.1, coefficient = 0.5 },
}

local STATIC_CACHE

local function finite(value, low, high)
    value = tonumber(value)
    if value == nil or value ~= value or value == math.huge
        or value == -math.huge or value < low or value > high then return nil end
    return value
end

local function integer(value, low, high)
    value = finite(value, low, high)
    return value and math.floor(value) == value and value or nil
end

local function copy(source)
    local out, key, value = {}, nil, nil
    for key, value in pairs(source or {}) do
        out[key] = type(value) == "table" and copy(value) or value
    end
    return out
end

local function scalar(spellId, field)
    if type(GetSpellRecField) ~= "function" then return nil end
    local ok, value = pcall(GetSpellRecField, spellId, field)
    return ok and finite(value, -2147483648, 137438953471) or nil
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

local function equal(values, first, second, third)
    return values and values[1] == first and values[2] == second
        and values[3] == third
end

local function near(first, second)
    return first and math.abs(first - second) <= 0.00001
end

local function mainMatches()
    local id = R.JUDGEMENT_ID
    return scalar(id, "school") == R.HOLY_SCHOOL
        and scalar(id, "attributes") == 327680
        and scalar(id, "attributesEx2") == 1048576
        and scalar(id, "attributesEx3") == 512
        and scalar(id, "baseLevel") == 4
        and scalar(id, "spellLevel") == 4
        and scalar(id, "rangeIndex") == 7
        and scalar(id, "recoveryTime") == 10000
        and scalar(id, "spellFamilyName") == R.PALADIN_FAMILY
        and scalar(id, "spellFamilyFlags") == R.JUDGEMENT_FLAG
        and scalar(id, "dmgClass") == 0
        and equal(triple(id, "effect"), 77, 0, 0)
        and equal(triple(id, "effectBasePoints"), -1, 0, 0)
        and equal(triple(id, "effectImplicitTargetA"), 6, 0, 0)
end

local function sourceMatches(spellId, rank)
    local points = triple(spellId, "effectBasePoints")
    return scalar(spellId, "school") == R.HOLY_SCHOOL
        and scalar(spellId, "spellIconID") == 25
        and scalar(spellId, "spellFamilyName") == R.PALADIN_FAMILY
        and scalar(spellId, "spellFamilyFlags") == R.SEAL_FLAG
        and scalar(spellId, "dmgClass") == 1
        and equal(triple(spellId, "effect"), 6, 0, 6)
        and equal(triple(spellId, "effectBaseDice"), 1, 0, 1)
        and points and points[3] == rank.result - 1
        and equal(triple(spellId, "effectImplicitTargetA"), 1, 0, 1)
        and equal(triple(spellId, "effectApplyAuraName"), 42, 0, 4)
end

local function resultMatches(spellId, rank)
    local levels, points = triple(spellId, "effectRealPointsPerLevel"),
        triple(spellId, "effectBasePoints")
    return scalar(spellId, "school") == R.HOLY_SCHOOL
        and scalar(spellId, "attributes") == 2097152
        and scalar(spellId, "attributesEx3") == 262656
        and scalar(spellId, "maxLevel") == rank.max
        and scalar(spellId, "baseLevel") == rank.baseLevel
        and scalar(spellId, "spellLevel") == rank.spellLevel
        and scalar(spellId, "rangeIndex") == 6
        and scalar(spellId, "equippedItemClass") == -1
        and scalar(spellId, "spellIconID") == 25
        and scalar(spellId, "spellFamilyName") == R.PALADIN_FAMILY
        and scalar(spellId, "spellFamilyFlags") == R.RESULT_FLAG
        and scalar(spellId, "dmgClass") == 2
        and equal(triple(spellId, "effect"), 2, 0, 3)
        and equal(triple(spellId, "effectDieSides"), rank.sides, 0, 1)
        and equal(triple(spellId, "effectBaseDice"), 1, 0, 1)
        and equal(triple(spellId, "effectDicePerLevel"), 0, 0, 0)
        and levels and near(levels[1], rank.perLevel)
        and levels[2] == 0 and points and points[1] == rank.points
        and equal(triple(spellId, "effectImplicitTargetA"), 6, 0, 0)
end

local function installed()
    if STATIC_CACHE then return copy(STATIC_CACHE) end
    local out = { recognized = true, available = false, valid = false,
        exact = false, portfolio = "paladinRighteousness",
        judgementSpellId = R.JUDGEMENT_ID, ranks = {},
        source = "installed build-5875 seal link and hidden-result topology" }
    if not mainMatches() then
        out.reason = "Judgement DBC topology is incomplete"
    else
        local sourceId, rank
        for sourceId, rank in pairs(R.RANKS) do
            if not (sourceMatches(sourceId, rank)
                and resultMatches(rank.result, rank)) then
                out.reason = "Righteousness rank DBC topology is incomplete"
                break
            end
            out.ranks[sourceId] = { sourceSealSpellId = sourceId,
                resultSpellId = rank.result, maxLevel = rank.max,
                baseLevel = rank.baseLevel, spellLevel = rank.spellLevel,
                basePoints = rank.points, dieSides = rank.sides,
                pointsPerLevel = rank.perLevel,
                serverBonusCoefficient = rank.coefficient, exact = true }
        end
        if not out.reason then out.available, out.valid, out.exact = true, true, true end
    end
    STATIC_CACHE = copy(out)
    return copy(out)
end

local function exactClassification(facts)
    local found = facts and facts.paladinClassification
    return type(found) == "table" and found.exact == true
        and tonumber(found.spellId) == R.JUDGEMENT_ID
        and found.family == R.PALADIN_FAMILY
        and found.flags == R.JUDGEMENT_FLAG and found.kind == "judgement"
end

local function modifier(spellId, operation)
    if type(GetSpellModifiers) ~= "function" then return nil end
    local ok, flat, percent, changed = pcall(
        GetSpellModifiers, spellId, operation)
    flat = ok and finite(flat, -100000, 100000) or nil
    percent = ok and finite(percent, -100, 100000) or nil
    changed = ok and integer(changed, 0, 4294967295) or nil
    if flat == nil or percent == nil or changed == nil
        or ((flat ~= 0 or percent ~= 0) ~= (changed ~= 0)) then return nil end
    return { operation = operation, flat = flat,
        percent = percent, changed = changed, exact = true }
end

local function modifierSafe()
    if type(GetSpellPower) ~= "function" or type(UnitDamage) ~= "function" then
        return nil, "Righteousness outgoing modifier evidence unavailable"
    end
    local ok, physical, holy, fire, nature, frost, shadow, arcane =
        pcall(GetSpellPower)
    local schools = { physical, holy, fire, nature, frost, shadow, arcane }
    local index
    if not ok then return nil, "Righteousness spell-power evidence unavailable" end
    for index = 1, 7 do
        if finite(schools[index], -1000000, 1000000) ~= 0 then
            return nil, "nonzero Righteousness spell-power lane is withheld"
        end
    end
    local damageOk, _, _, _, _, _, _, multiplier = pcall(UnitDamage, "player")
    if not damageOk or finite(multiplier, 0.0001, 1000) ~= 1 then
        return nil, "modified Righteousness outgoing damage lane is withheld"
    end
    return true, nil
end

local function baseMean(rank, playerLevel)
    local level = math.max(rank.baseLevel, playerLevel)
    if rank.maxLevel > 0 then level = math.min(level, rank.maxLevel) end
    local delta = level - rank.spellLevel
    return rank.basePoints + rank.pointsPerLevel * delta
        + (1 + rank.dieSides) / 2, delta
end

local function captureProfile(rank, playerLevel)
    local all = modifier(rank.resultSpellId, R.ALL_EFFECTS_MOD)
    local damage = modifier(rank.resultSpellId, R.DAMAGE_MOD)
    local coefficient = modifier(rank.resultSpellId, R.BONUS_COEFFICIENT_MOD)
    if not (all and damage and coefficient) then return nil end
    local mean, delta = baseMean(rank, playerLevel)
    mean = (mean + all.flat) * (100 + all.percent) / 100
    mean = (mean + damage.flat) * (100 + damage.percent) / 100
    local bonus = (rank.serverBonusCoefficient * 100 + coefficient.flat)
        * (100 + coefficient.percent) / 100 / 100
    if not finite(mean, 0.0001, 10000000)
        or not finite(bonus, 0, 1000) then return nil end
    local out = copy(rank)
    out.portfolio, out.valid, out.exact = "paladinRighteousness", true, true
    out.playerLevel, out.scaledLevelDelta = playerLevel, delta
    out.allEffectsModifier, out.damageModifier = all, damage
    out.bonusCoefficientModifier, out.effectiveBonusCoefficient =
        coefficient, bonus
    out.spellPower, out.outgoingDamageMultiplier = 0, 1
    out.meanDamage = mean
    out.source = "root-captured modifier-safe hidden Judgement result"
    return out
end

local function sealedProfile(value)
    local static = value and R.RANKS[value.sourceSealSpellId]
    local rank = static and { sourceSealSpellId = value.sourceSealSpellId,
        resultSpellId = static.result, maxLevel = static.max,
        baseLevel = static.baseLevel, spellLevel = static.spellLevel,
        basePoints = static.points, dieSides = static.sides,
        pointsPerLevel = static.perLevel,
        serverBonusCoefficient = static.coefficient } or nil
    local level = value and integer(value.playerLevel, 1, 255)
    local all = value and value.allEffectsModifier
    local damage = value and value.damageModifier
    local coefficient = value and value.bonusCoefficientModifier
    if not (rank and level and value.valid == true and value.exact == true
        and value.portfolio == "paladinRighteousness"
        and value.resultSpellId == rank.resultSpellId
        and value.basePoints == rank.basePoints
        and near(value.pointsPerLevel, rank.pointsPerLevel)
        and value.dieSides == rank.dieSides and value.spellPower == 0
        and value.outgoingDamageMultiplier == 1
        and all and all.operation == R.ALL_EFFECTS_MOD and all.exact == true
        and damage and damage.operation == R.DAMAGE_MOD and damage.exact == true
        and coefficient and coefficient.operation == R.BONUS_COEFFICIENT_MOD
        and coefficient.exact == true) then return nil end
    local mean = baseMean(rank, level)
    mean = (mean + all.flat) * (100 + all.percent) / 100
    mean = (mean + damage.flat) * (100 + damage.percent) / 100
    if not near(mean, value.meanDamage) then return nil end
    return value
end

function R:Promote(spellId, facts)
    if tonumber(spellId) ~= self.JUDGEMENT_ID
        or not (facts and facts.paladinJudgement == true
            and exactClassification(facts)) then return facts end
    local found = installed()
    if not (found.valid == true and found.exact == true) then return facts end
    local out = copy(facts)
    out.paladinRighteousness = true
    out.requiresExactPaladinRighteousnessOutcome = true
    out.paladinRighteousnessEvidence = found
    out.paladinEffectRepresented = false
    return out
end

function R:CaptureFacts(action, facts, state)
    if not (facts and facts.paladinRighteousness == true
        and tonumber(action and action.spellId) == self.JUDGEMENT_ID) then
        return facts
    end
    local out, level = copy(facts), integer(state and state.playerLevel, 1, 255)
    local safe, reason = modifierSafe()
    out.paladinEffectRepresented = false
    out.paladinRighteousnessProfiles = nil
    if not (level and safe) then
        out.paladinRighteousnessReason = reason
            or "Righteousness player level unavailable"
        return out
    end
    local installedFacts, profiles = installed(), {}
    if not (installedFacts.valid == true and installedFacts.exact == true) then
        out.paladinRighteousnessReason = installedFacts.reason
        return out
    end
    local sourceId, rank
    for sourceId, rank in pairs(installedFacts.ranks) do
        profiles[sourceId] = captureProfile(rank, level)
        if not profiles[sourceId] then
            out.paladinRighteousnessReason =
                "Righteousness result modifier evidence unavailable"
            return out
        end
    end
    out.paladinRighteousnessProfiles = profiles
    out.paladinEffectRepresented = true
    out.paladinLifecycleRepresented = true
    out.paladinRighteousnessReason = nil
    return out
end

function R:Profile(subject, sourceSealSpellId)
    local facts = type(subject) == "table" and subject.facts or subject
    local profiles = facts and facts.paladinRighteousnessProfiles
    local found = type(profiles) == "table"
        and profiles[tonumber(sourceSealSpellId)] or nil
    found = sealedProfile(found)
    return found and copy(found) or nil
end

function R:CapturedEffect(subject, sourceSealSpellId)
    local found = self:Profile(subject, sourceSealSpellId)
    if not found then return nil end
    return { exact = true, kind = "paladinRighteousnessDirectHolyDamage",
        actor = "player", sourceSealSpellId = found.sourceSealSpellId,
        resultSpellId = found.resultSpellId, school = self.HOLY_SCHOOL,
        meanDamage = found.meanDamage, deliveryModel = "physical",
        deliverySubtype = "melee", usesWeaponSkill = false,
        alwaysHit = true, source = found.source }
end

function R:Inspect(spellId)
    spellId = integer(spellId, 1, 4294967295)
    if spellId == self.JUDGEMENT_ID then
        local found = installed()
        return found, found.reason, true
    end
    local found, rank = installed(), spellId and self.RANKS[spellId] or nil
    if not rank then return nil, "not a Righteousness portfolio identity", false end
    local result = found.ranks and found.ranks[spellId]
    return result and copy(result) or nil, found.reason, true
end

function R:Invalidate()
    STATIC_CACHE = nil
end
