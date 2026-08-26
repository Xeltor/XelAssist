-- Exact Battle Shout discovery and root evidence for build 5875. Numeric
-- identities select rows, but every rank must retain its installed DBC shape.
-- Current level, spell modifiers, auras, group state and melee lane are frozen
-- before graph search; localized names never select mechanics or action order.
XelAssist.Game.Player = XelAssist.Game.Player or {}
XelAssist.Game.Player.WarriorBattleShout = {}
local B = XelAssist.Game.Player.WarriorBattleShout

B.WARRIOR_FAMILY = 4
B.FAMILY_FLAG = 65536
B.ATTACK_POWER_AURA = 99
B.RAGE = 1
B.RAGE_SCALE = 10
B.ALL_EFFECTS_MOD = 8
B.ATTACK_POWER_MOD = 3
B.COST_MOD = 14
local RANKS = {
    [6673] = { rank = 1, baseLevel = 1, spellLevel = 1, maxLevel = 11,
        basePoints = 14, perLevel = 0.5, flatThreat = 1 },
    [5242] = { rank = 2, baseLevel = 12, spellLevel = 12, maxLevel = 21,
        basePoints = 34, perLevel = 0.5, flatThreat = 12 },
    [6192] = { rank = 3, baseLevel = 22, spellLevel = 22, maxLevel = 31,
        basePoints = 54, perLevel = 0.5, flatThreat = 22 },
    [11549] = { rank = 4, baseLevel = 32, spellLevel = 32, maxLevel = 41,
        basePoints = 84, perLevel = 1, flatThreat = 32 },
    [11550] = { rank = 5, baseLevel = 42, spellLevel = 42, maxLevel = 51,
        basePoints = 129, perLevel = 1, flatThreat = 42 },
    [11551] = { rank = 6, baseLevel = 52, spellLevel = 52, maxLevel = 61,
        basePoints = 184, perLevel = 1, flatThreat = 52 },
    [25289] = { rank = 7, baseLevel = 60, spellLevel = 60, maxLevel = 61,
        basePoints = 231, perLevel = 1, flatThreat = 60 },
}
local CACHE = {}
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
local function equal(values, first, second, third)
    return values and values[1] == first and values[2] == second
        and values[3] == third
end
local function duration(spellId, ignoreModifiers)
    if type(GetSpellDuration) ~= "function" then return nil end
    local ok, milliseconds = pcall(GetSpellDuration, spellId,
        ignoreModifiers and 1 or nil)
    milliseconds = ok and integer(milliseconds, 1, 3600000) or nil
    return milliseconds and milliseconds / 1000 or nil
end
local function scalarsMatch(spellId, rank)
    return scalar(spellId, "school") == 0
        and scalar(spellId, "category") == 0
        and scalar(spellId, "castUI") == 0
        and scalar(spellId, "dispel") == 0
        and scalar(spellId, "mechanic") == 0
        and scalar(spellId, "attributes") == 327696
        and scalar(spellId, "attributesEx") == 0
        and scalar(spellId, "attributesEx2") == 0
        and scalar(spellId, "attributesEx3") == 0
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
        and scalar(spellId, "maxLevel") == rank.maxLevel
        and scalar(spellId, "baseLevel") == rank.baseLevel
        and scalar(spellId, "spellLevel") == rank.spellLevel
        and scalar(spellId, "durationIndex") == 4
        and scalar(spellId, "powerType") == B.RAGE
        and scalar(spellId, "manaCost") == 100
        and scalar(spellId, "manaCostPerlevel") == 0
        and scalar(spellId, "manaPerSecond") == 0
        and scalar(spellId, "manaPerSecondPerLevel") == 0
        and scalar(spellId, "rangeIndex") == 1
        and scalar(spellId, "speed") == 0
        and scalar(spellId, "modalNextSpell") == 0
        and scalar(spellId, "stackAmount") == 0
        and scalar(spellId, "equippedItemClass") == -1
        and scalar(spellId, "equippedItemSubClassMask") == -1
        and scalar(spellId, "equippedItemInventoryTypeMask") == 0
        and scalar(spellId, "manaCostPercentage") == 0
        and scalar(spellId, "startRecoveryCategory") == 133
        and scalar(spellId, "startRecoveryTime") == 1500
        and scalar(spellId, "maxTargetLevel") == 0
        and scalar(spellId, "spellFamilyName") == B.WARRIOR_FAMILY
        and scalar(spellId, "spellFamilyFlags") == B.FAMILY_FLAG
        and scalar(spellId, "maxAffectedTargets") == 0
        and scalar(spellId, "dmgClass") == 1
        and scalar(spellId, "preventionType") == 1
end
local function arraysMatch(spellId, rank)
    return equal(triple(spellId, "effect"), 6, 0, 0)
        and equal(triple(spellId, "effectDieSides"), 1, 0, 0)
        and equal(triple(spellId, "effectBaseDice"), 1, 0, 0)
        and equal(triple(spellId, "effectDicePerLevel"), 0, 0, 0)
        and equal(triple(spellId, "effectRealPointsPerLevel"),
            rank.perLevel, 0, 0)
        and equal(triple(spellId, "effectBasePoints"),
            rank.basePoints, 0, 0)
        and equal(triple(spellId, "effectMechanic"), 0, 0, 0)
        and equal(triple(spellId, "effectImplicitTargetA"), 20, 0, 0)
        and equal(triple(spellId, "effectImplicitTargetB"), 0, 0, 0)
        and equal(triple(spellId, "effectRadiusIndex"), 9, 0, 0)
        and equal(triple(spellId, "effectApplyAuraName"),
            B.ATTACK_POWER_AURA, 0, 0)
        and equal(triple(spellId, "effectAmplitude"), 0, 0, 0)
        and equal(triple(spellId, "effectMultipleValue"), 0, 0, 0)
        and equal(triple(spellId, "effectChainTarget"), 0, 0, 0)
        and equal(triple(spellId, "effectItemType"), 0, 0, 0)
        and equal(triple(spellId, "effectMiscValue"), 0, 0, 0)
        and equal(triple(spellId, "effectTriggerSpell"), 0, 0, 0)
        and equal(triple(spellId, "effectPointsPerComboPoint"), 0, 0, 0)
end
local function raw(spellId)
    if CACHE[spellId] then
        local cached = copy(CACHE[spellId])
        return cached, cached.reason, cached.recognized == true
    end
    local rank = RANKS[spellId]
    if not rank then return nil, "not an installed Battle Shout identity", false end
    local found = { recognized = true, valid = false, exact = false,
        portfolio = "warriorBattleShout", spellId = spellId,
        source = "installed build-5875 Battle Shout DBC and VMaNGOS threat profile" }
    if not (scalarsMatch(spellId, rank) and arraysMatch(spellId, rank)
        and duration(spellId, true) == 120) then
        found.reason = "Battle Shout DBC topology is incomplete"
    else
        found.valid, found.exact, found.rank = true, true, rank.rank
        found.baseLevel, found.spellLevel, found.maxLevel = rank.baseLevel,
            rank.spellLevel, rank.maxLevel
        found.baseAttackPower, found.attackPowerPerLevel =
            rank.basePoints + 1, rank.perLevel
        found.powerType, found.cost = B.RAGE, 100 / B.RAGE_SCALE
        found.baseDuration, found.gcd, found.cast = 120, 1.5, 0
        found.attackPowerAura, found.recipient =
            B.ATTACK_POWER_AURA, "solo-player-through-party-area"
        found.flatThreat, found.flatThreatExact = rank.flatThreat, true
        found.flatThreatModel = "positive-total-divided-across-hostile-refs"
    end
    CACHE[spellId] = copy(found)
    return copy(found), found.reason, true
end
local function sealed(subject)
    local facts = type(subject) == "table" and subject.facts or subject
    local found = type(facts) == "table" and facts.warriorBattleShoutEvidence
    local rank = type(found) == "table" and RANKS[found.spellId] or nil
    if not (rank and found.valid == true and found.exact == true
        and found.portfolio == "warriorBattleShout"
        and found.rank == rank.rank and found.baseLevel == rank.baseLevel
        and found.spellLevel == rank.spellLevel and found.maxLevel == rank.maxLevel
        and found.baseAttackPower == rank.basePoints + 1
        and found.attackPowerPerLevel == rank.perLevel
        and found.powerType == B.RAGE and found.cost == 10
        and found.baseDuration == 120 and found.gcd == 1.5
        and found.cast == 0 and found.attackPowerAura == B.ATTACK_POWER_AURA
        and found.recipient == "solo-player-through-party-area"
        and found.flatThreat == rank.flatThreat
        and found.flatThreatExact == true
        and found.flatThreatModel
            == "positive-total-divided-across-hostile-refs") then return nil end
    return found
end
function B:Classify(spellId)
    spellId = integer(spellId, 1, 4294967295)
    if not spellId then return nil, "Battle Shout identity unavailable", false end
    return raw(spellId)
end

function B:InferKnowledge(spellId)
    if classToken() ~= "WARRIOR" then
        return nil, "player is not an exactly identified Warrior", false
    end
    local found, reason, handled = self:Classify(spellId)
    if not (found and found.valid == true) then return nil, reason, handled end
    return { inferred = true, kind = "buff", kindExact = true,
        self = true, fixedTarget = "player", warriorBattleShout = true,
        partyArea = true, meleeAttackPower = true,
        requiresExactBattleShoutDownstream = true,
        requiresExactUsability = true, submissionGuarded = true,
        warriorBattleShoutEvidence = copy(found), source = found.source }, nil, true
end

function B:Evidence(subject)
    local found = sealed(subject)
    return found and copy(found) or nil
end
local function modifiersUnchanged(spellId)
    if type(GetSpellModifiers) ~= "function" then
        return false, "Battle Shout modifier evidence unavailable"
    end
    local kinds, index = { B.ALL_EFFECTS_MOD, B.ATTACK_POWER_MOD, B.COST_MOD }, nil
    for index = 1, table.getn(kinds) do
        local ok, flat, percent, changed = pcall(
            GetSpellModifiers, spellId, kinds[index])
        flat, percent, changed = tonumber(flat), tonumber(percent), tonumber(changed)
        if not ok or flat == nil or percent == nil or changed == nil then
            return false, "Battle Shout modifier evidence unavailable"
        end
        if flat ~= 0 or percent ~= 0 or changed ~= 0 then
            return false, "modified Battle Shout magnitude or cost is unresolved"
        end
    end
    return true, nil
end
local function capturedProfile(found)
    local out = { recognized = true, valid = false, exact = false,
        portfolio = "warriorBattleShout", spellId = found.spellId,
        source = found.source }
    if classToken() ~= "WARRIOR" or type(UnitLevel) ~= "function" then
        out.reason = "Warrior level evidence unavailable"; return out
    end
    local ok, level = pcall(UnitLevel, "player")
    level = ok and integer(level, 1, 255) or nil
    local unchanged, reason = modifiersUnchanged(found.spellId)
    local actualDuration = duration(found.spellId, false)
    if not level or not unchanged or not actualDuration then
        out.reason = reason or "Battle Shout duration evidence unavailable"
        return out
    end
    local effective = math.max(found.baseLevel, level)
    if found.maxLevel > 0 then effective = math.min(found.maxLevel, effective) end
    local amount = found.baseAttackPower
        + (effective - found.spellLevel) * found.attackPowerPerLevel
    if not finite(amount, 0.0001, 100000) then
        out.reason = "Battle Shout attack power magnitude unavailable"; return out
    end
    out.valid, out.exact, out.playerLevel = true, true, level
    out.effectiveLevel, out.attackPower = effective, amount
    out.duration, out.cost, out.powerType = actualDuration, found.cost, found.powerType
    out.gcd, out.cast = found.gcd, found.cast
    out.flatThreat, out.flatThreatExact = found.flatThreat, true
    out.flatThreatModel, out.recipient = found.flatThreatModel, found.recipient
    return out
end

local WEAPON_EFFECT = { [17] = true, [31] = true, [58] = true, [121] = true }
local function meleeWeapon(action, facts)
    local coefficient = type(facts) == "table"
        and finite(tonumber(facts.weaponCoefficient), 0.0001, 100) or nil
    if classToken() ~= "WARRIOR" or not (action and action.actor ~= "pet"
        and tonumber(action.spellId) and coefficient
        and facts.weaponFormulaSource == "OctoWoW VMaNGOS weapon effects"
        and scalar(action.spellId, "dmgClass") == 2) then return nil end
    local attributes, effects = scalar(action.spellId, "attributesEx3"),
        triple(action.spellId, "effect")
    if not attributes or not effects
        or math.floor(attributes / 16777216) - math.floor(attributes / 33554432) * 2
            == 1 then return nil end
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
    return { valid = true, exact = true, portfolio = "warriorBattleShout",
        spellId = action.spellId, attackType = "main", weaponEffectCount = 1,
        normalized = normalized, weaponCoefficient = coefficient,
        source = "installed-client main-hand weapon effect and DmgClass" }
end

function B:CaptureFacts(action, facts)
    local out = copy(facts)
    local found = self:Evidence(action) or self:Evidence(facts)
    if found then
        local profile = capturedProfile(found)
        out.warriorBattleShout, out.meleeAttackPower = true, true
        out.warriorBattleShoutEvidence = copy(found)
        out.warriorBattleShoutProfile = profile
        out.powerType, out.cost = found.powerType, found.cost
        out.gcd, out.cast, out.duration = found.gcd, found.cast,
            profile.valid and profile.duration or found.baseDuration
    end
    local weapon = meleeWeapon(action, out)
    if weapon then out.warriorMainHandWeaponEvidence = weapon end
    return out
end

function B:CapturedEvidence(subject)
    local facts = type(subject) == "table" and subject.facts or subject
    if not (type(facts) == "table" and facts.warriorBattleShout == true) then
        return nil, nil, false
    end
    local found, profile = sealed(facts), facts.warriorBattleShoutProfile
    local effective = type(profile) == "table"
        and integer(profile.effectiveLevel, 1, 255) or nil
    local expected = found and effective
        and found.baseAttackPower + (effective - found.spellLevel)
            * found.attackPowerPerLevel or nil
    if not (found and type(profile) == "table"
        and profile.valid == true and profile.exact == true
        and profile.portfolio == "warriorBattleShout"
        and profile.spellId == found.spellId
        and integer(profile.playerLevel, 1, 255)
        and effective == math.min(found.maxLevel,
            math.max(found.baseLevel, profile.playerLevel))
        and profile.attackPower == expected
        and finite(profile.duration, 0.001, 3600)
        and profile.cost == found.cost and profile.powerType == found.powerType
        and profile.gcd == found.gcd and profile.cast == found.cast
        and profile.flatThreat == found.flatThreat
        and profile.flatThreatExact == true
        and profile.flatThreatModel == found.flatThreatModel
        and profile.recipient == found.recipient) then
        return nil, profile and profile.reason
            or "Battle Shout root profile unavailable", true
    end
    return copy(profile), nil, true
end

function B:CaptureActiveProfile(spellId)
    spellId = integer(spellId, 1, 4294967295)
    if not spellId then return nil, "Battle Shout identity unavailable", false end
    local found, reason, handled = raw(spellId)
    if not handled then return nil, reason, false end
    if not (found and found.valid == true) then return nil, reason, true end
    local profile = capturedProfile(found)
    if profile.valid ~= true or profile.exact ~= true then
        return nil, profile.reason or "active Battle Shout profile unavailable", true
    end
    return copy(profile), nil, true
end

function B:ObserveRoot()
    local observer = XelAssist.Game.Player.WarriorBattleShoutRoot
    if observer and observer.Observe then return observer:Observe(self) end
    return { available = false, exact = false,
        portfolio = "warriorBattleShout",
        reason = "Battle Shout root observer unavailable" }
end
function B:Invalidate()
    CACHE = {}
end
