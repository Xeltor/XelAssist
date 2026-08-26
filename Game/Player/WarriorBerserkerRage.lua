-- Exact installed Berserker Rage topology. The client proves the finite
-- self-aura and its 30-percent incoming-rage modifier; fear/incapacitate
-- immunity is retained as evidence but receives no utility without a hostile
-- control ledger.
XelAssist.Game.Player.WarriorBerserkerRage = {}
local B = XelAssist.Game.Player.WarriorBerserkerRage

B.SPELL_ID = 18499
B.WARRIOR_FAMILY = 4
B.WARRIOR_FAMILY_FLAG = 268435456
B.RAGE_MULTIPLIER = 1.3
local CACHE

local function finite(value, low, high)
    local huge = math.huge
    if type(value) ~= "number" or value ~= value
        or huge and (value == huge or value == -huge)
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
        if not integer(key, 1, 3) then return nil end
        count = count + 1
    end
    if count ~= 3 then return nil end
    for index = 1, 3 do
        out[index] = finite(values[index], -2147483648, 4294967295)
        if out[index] == nil then return nil end
    end
    return out
end
local function equal(values, a, b, c)
    return values and values[1] == a and values[2] == b and values[3] == c
end
local function duration()
    if type(GetSpellDuration) ~= "function" then return nil end
    local ok, milliseconds = pcall(GetSpellDuration, B.SPELL_ID, 1)
    milliseconds = ok and integer(milliseconds, 1, 600000) or nil
    return milliseconds and milliseconds / 1000 or nil
end
local function classToken()
    if type(UnitClass) ~= "function" then return nil end
    local ok, _, token = pcall(UnitClass, "player")
    return ok and token or nil
end

local function classify()
    if CACHE then return copy(CACHE) end
    local found = { recognized = true, valid = false, exact = false,
        spellId = B.SPELL_ID,
        source = "installed Octo patch-5 Berserker Rage DBC topology" }
    if scalar(B.SPELL_ID, "spellFamilyName") ~= B.WARRIOR_FAMILY
        or scalar(B.SPELL_ID, "spellFamilyFlags") ~= B.WARRIOR_FAMILY_FLAG
        or scalar(B.SPELL_ID, "powerType") ~= 0
        or scalar(B.SPELL_ID, "manaCost") ~= 0
        or not equal(triple(B.SPELL_ID, "effect"), 6, 6, 6)
        or not equal(triple(B.SPELL_ID, "effectApplyAuraName"), 77, 77, 226)
        or not equal(triple(B.SPELL_ID, "effectBasePoints"), -1, -1, 29)
        or not equal(triple(B.SPELL_ID, "effectImplicitTargetA"), 0, 0, 0)
        or not equal(triple(B.SPELL_ID, "effectImplicitTargetB"), 1, 1, 1)
        or not equal(triple(B.SPELL_ID, "effectMiscValue"), 5, 14, 0)
        or duration() ~= 10 then
        found.reason = "Berserker Rage DBC topology is incomplete"
        CACHE = copy(found)
        return found
    end
    found.valid, found.exact = true, true
    found.duration, found.incomingRagePercent = 10, 30
    found.incomingRageMultiplier = B.RAGE_MULTIPLIER
    found.fearMechanic, found.incapacitateMechanic = 5, 14
    found.controlUtilityMode = "ledger-required"
    CACHE = copy(found)
    return found
end

function B:Classify(spellId)
    if integer(spellId, 1, 4294967295) ~= self.SPELL_ID then
        return nil, "not the installed Berserker Rage identity", false
    end
    local found = classify()
    return found, found.reason, true
end

function B:InferKnowledge(spellId)
    if classToken() ~= "WARRIOR" then
        return nil, "player is not an exactly identified Warrior", false
    end
    local found, reason, handled = self:Classify(spellId)
    if not (found and found.valid) then return nil, reason, handled end
    return { inferred = true, kind = "buff", kindExact = true,
        self = true, fixedTarget = "player", warriorBerserkerRage = true,
        requiresExactUsability = true, submissionGuarded = true,
        warriorBerserkerRageEvidence = copy(found), source = found.source },
        nil, true
end

function B:Evidence(subject)
    local facts = type(subject) == "table" and subject.facts or subject
    local found = facts and facts.warriorBerserkerRageEvidence
    if not (facts and facts.warriorBerserkerRage == true
        and type(found) == "table" and found.valid == true
        and found.exact == true and found.spellId == self.SPELL_ID
        and found.duration == 10 and found.incomingRagePercent == 30
        and found.incomingRageMultiplier == self.RAGE_MULTIPLIER
        and found.fearMechanic == 5 and found.incapacitateMechanic == 14
        and found.controlUtilityMode == "ledger-required") then return nil end
    return copy(found)
end

function B:CaptureFacts(action, facts)
    local out, found = copy(facts), self:Evidence(action)
    if not found then return out end
    out.warriorBerserkerRageEvidence = copy(found)
    out.duration, out.cost, out.cast = found.duration, 0, 0
    return out
end

function B:Snapshot()
    if classToken() ~= "WARRIOR" or type(GetPlayerBuff) ~= "function"
        or type(GetPlayerBuffID) ~= "function"
        or type(GetPlayerBuffTimeLeft) ~= "function" then return nil end
    local index
    for index = 0, 31 do
        local ok, slot = pcall(GetPlayerBuff, index, "HELPFUL")
        if not ok then return nil end
        if slot and slot ~= -1 then
            local idOK, spellId = pcall(GetPlayerBuffID, slot)
            if not idOK then return nil end
            if tonumber(spellId) == self.SPELL_ID then
                local timeOK, remaining = pcall(GetPlayerBuffTimeLeft, slot)
                remaining = timeOK and finite(remaining, 0, 10.25) or nil
                if remaining and remaining > 0 then
                    return { active = true, exact = true,
                        spellId = self.SPELL_ID, remaining = remaining,
                        incomingRageMultiplier = self.RAGE_MULTIPLIER,
                        source = "live exact Berserker Rage aura" }
                end
                return nil
            end
        end
    end
    return nil
end

function B:Invalidate() CACHE = nil end
