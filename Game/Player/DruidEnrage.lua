-- Exact installed Enrage identity. The periodic rage is a stock aura; the
-- armor loss is exposed by the installed spell scalar/tooltip but its private
-- mitigation arithmetic is represented downstream as a conservative bound.
XelAssist.Game.Player.DruidEnrage = {}
local E = XelAssist.Game.Player.DruidEnrage

E.SPELL_ID, E.DRUID_FAMILY, E.RAGE = 5229, 7, 1
E.DURATION, E.INTERVAL, E.RAGE_PER_TICK = 10, 1, 2
E.TICKS, E.TOTAL_RAGE, E.ARMOR_RETAINED = 10, 20, 0.25
local CACHE

local function integer(value, low, high)
    value = tonumber(value)
    if value == nil or value ~= value or value == math.huge
        or value == -math.huge or value < low or value > high
        or math.floor(value) ~= value then return nil end
    return value
end
local function copy(source)
    local out, key, value = {}, nil, nil
    for key, value in pairs(source or {}) do out[key] = value end
    return out
end
local function scalar(field, signed)
    if type(GetSpellRecField) ~= "function" then return nil end
    local ok, value = pcall(GetSpellRecField, E.SPELL_ID, field)
    value = ok and integer(value, signed and -2147483648 or 0,
        4294967295) or nil
    if signed and value and value >= 2147483648 then
        value = value - 4294967296
    end
    return value
end
local function triple(field, signed)
    if type(GetSpellRecField) ~= "function" then return nil end
    local ok, values = pcall(GetSpellRecField, E.SPELL_ID, field, 1)
    if not ok or type(values) ~= "table" then return nil end
    local out, count, key, index = {}, 0, nil, nil
    for key in pairs(values) do
        if integer(key, 1, 3) == nil then return nil end
        count = count + 1
    end
    if count ~= 3 then return nil end
    for index = 1, 3 do
        out[index] = integer(values[index], signed and -2147483648 or 0,
            4294967295)
        if out[index] == nil then return nil end
        if signed and out[index] >= 2147483648 then
            out[index] = out[index] - 4294967296
        end
    end
    return out
end
local function equal(values, a, b, c)
    return values and values[1] == a and values[2] == b and values[3] == c
end
local function duration()
    if type(GetSpellDuration) ~= "function" then return nil end
    local ok, value = pcall(GetSpellDuration, E.SPELL_ID, 1)
    value = ok and integer(value, 1, 60000) or nil
    return value and value / 1000 or nil
end
local function classToken()
    if type(UnitClass) ~= "function" then return nil end
    local ok, _, token = pcall(UnitClass, "player")
    return ok and token or nil
end

local function classify()
    if CACHE then return copy(CACHE) end
    local points, dice = triple("effectBasePoints", true),
        triple("effectBaseDice", true)
    local valid = scalar("attributes") == 262416
        and scalar("stances") == 144
        and scalar("recoveryTime") == 60000
        and scalar("durationIndex") == 1 and duration() == E.DURATION
        and scalar("powerType", true) == E.RAGE
        and scalar("spellFamilyName") == E.DRUID_FAMILY
        and scalar("spellFamilyFlags") == 524288
        and equal(triple("effect"), 6, 3, 6)
        and equal(triple("effectApplyAuraName"), 24, 0, 94)
        and equal(triple("effectImplicitTargetA"), 1, 0, 1)
        and equal(triple("effectAmplitude"), 1000, 0, 0)
        and equal(triple("effectMiscValue"), E.RAGE, 0, 0)
        and points and dice and points[1] + dice[1] == 20
        and points[2] + dice[2] == -75
    CACHE = { recognized = true, valid = valid == true,
        exact = valid == true, spellId = E.SPELL_ID,
        duration = E.DURATION, interval = E.INTERVAL,
        ragePerTick = E.RAGE_PER_TICK, ticks = E.TICKS,
        totalRage = E.TOTAL_RAGE, armorDummyMagnitude = 75,
        bearArmorDescriptionPercent = 27,
        direBearArmorDescriptionPercent = 16,
        armorRetained = E.ARMOR_RETAINED, powerType = E.RAGE,
        cooldown = 60, gcd = 0,
        armorCounterfactualBound = 4,
        source = "installed Octo patch-5 Enrage topology" }
    if not valid then CACHE.reason = "Enrage DBC topology is incomplete" end
    return copy(CACHE)
end

function E:InferKnowledge(spellId)
    if tonumber(spellId) ~= self.SPELL_ID then return nil, nil, false end
    if classToken() ~= "DRUID" then
        return nil, "player is not an exactly identified Druid", true
    end
    local found = classify()
    if not found.valid then return nil, found.reason, true end
    return { inferred = true, kind = "resource", kindExact = true,
        self = true, fixedTarget = "player", transientResource = true,
        resourceType = "rage", druidEnrage = true,
        routineResourceCooldown = true, requiresExactUsability = true,
        submissionGuarded = true, druidEnrageEvidence = found,
        source = found.source }, nil, true
end

function E:Evidence(subject)
    local facts = type(subject) == "table" and subject.facts or subject
    local found = facts and facts.druidEnrageEvidence
    if not (facts and facts.druidEnrage == true and found
        and found.valid == true and found.exact == true
        and found.spellId == self.SPELL_ID and found.duration == 10
        and found.interval == 1 and found.ragePerTick == 2
        and found.ticks == 10 and found.totalRage == 20
        and found.armorDummyMagnitude == 75
        and found.bearArmorDescriptionPercent == 27
        and found.direBearArmorDescriptionPercent == 16
        and found.armorRetained == 0.25
        and found.armorCounterfactualBound == 4
        and found.powerType == self.RAGE) then return nil end
    return copy(found)
end

function E:CaptureFacts(action, facts)
    local out = copy(facts)
    local found = action and self:Evidence(action)
    if not found then return out end
    out.druidEnrage, out.druidEnrageEvidence = true, found
    out.resourceGain, out.resourceImmediate = found.totalRage, 0
    out.resourcePeriodic, out.resourceType = found.totalRage, "rage"
    out.powerType, out.cost, out.cast = self.RAGE, 0, 0
    out.cooldown, out.duration, out.gcd = 60, 10, 0
    return out
end

local function activeRemaining()
    if type(GetPlayerBuff) ~= "function"
        or type(GetPlayerBuffID) ~= "function"
        or type(GetPlayerBuffTimeLeft) ~= "function" then return nil, false end
    local index
    for index = 0, 31 do
        local ok, slot = pcall(GetPlayerBuff, index, "HELPFUL")
        if not ok then return nil, false end
        if slot and slot ~= -1 then
            local idOK, id = pcall(GetPlayerBuffID, slot)
            if not idOK then return nil, false end
            if tonumber(id) == E.SPELL_ID then
                local timeOK, remaining = pcall(GetPlayerBuffTimeLeft, slot)
                remaining = timeOK and tonumber(remaining) or nil
                return remaining, remaining ~= nil
            end
        end
    end
    return nil, true
end

function E:Snapshot()
    if classToken() ~= "DRUID" then return nil end
    local found = classify()
    if not found.valid then return { available = false, exact = false,
        reason = found.reason } end
    local remaining, observed = activeRemaining()
    if not observed then return { available = false, exact = false,
        reason = "Enrage aura evidence unavailable" } end
    return { available = true, exact = true,
        active = remaining ~= nil and remaining > 0,
        remaining = remaining, profile = found }
end

function E:Invalidate() CACHE = nil end
