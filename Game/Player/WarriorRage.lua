-- Exact Bloodrage discovery and its finite rage clock. Mutable DBC and aura
-- APIs are used only while building/capturing the root; graph descendants use
-- the sealed evidence and playerResourceClock carried by their state.
XelAssist.Game.Player.WarriorRage = {}
local W = XelAssist.Game.Player.WarriorRage

W.SPELL_ID = 2687
W.AURA_SPELL_ID = 29131
W.WARRIOR_FAMILY = 4
W.WARRIOR_FAMILY_FLAG = 256
W.RAGE = 1
W.RAGE_SCALE = 10
W.MAX_CACHE = 2

local CACHE = {}

local function integer(value, low, high)
    if type(value) ~= "number" or value ~= value
        or value == math.huge or value == -math.huge
        or value < low or value > high or math.floor(value) ~= value then
        return nil
    end
    return value
end

local function finite(value, low, high)
    if type(value) ~= "number" or value ~= value
        or value == math.huge or value == -math.huge
        or value < low or value > high then return nil end
    return value
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
    return ok and type(value) == "number" and value or nil
end

local function textField(spellId, field)
    if type(GetSpellRecField) ~= "function" then return nil end
    local ok, value = pcall(GetSpellRecField, spellId, field)
    return ok and type(value) == "string" and value or nil
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

local function divisible(value, divisor)
    return value - math.floor(value / divisor) * divisor == 0
end

local function duration(spellId)
    if type(GetSpellDuration) ~= "function" then return nil end
    local ok, milliseconds = pcall(GetSpellDuration, spellId, 1)
    milliseconds = ok and integer(milliseconds, 1, 3600000) or nil
    return milliseconds and milliseconds / 1000 or nil
end

local function fixedMagnitude(spellId, index)
    local points = triple(spellId, "effectBasePoints")
    local dice = triple(spellId, "effectBaseDice")
    local sides = triple(spellId, "effectDieSides")
    local dicePerLevel = triple(spellId, "effectDicePerLevel")
    local perLevel = triple(spellId, "effectRealPointsPerLevel")
    local perCombo = triple(spellId, "effectPointsPerComboPoint")
    if not (points and dice and sides and dicePerLevel
        and perLevel and perCombo and sides[index] == 1
        and dice[index] == 1 and dicePerLevel[index] == 0
        and perLevel[index] == 0 and perCombo[index] == 0) then return nil end
    return points[index] + dice[index]
end

local function parentShape()
    return scalar(W.SPELL_ID, "spellFamilyName") == W.WARRIOR_FAMILY
        and scalar(W.SPELL_ID, "spellFamilyFlags") == W.WARRIOR_FAMILY_FLAG
        and scalar(W.SPELL_ID, "school") == 0
        and scalar(W.SPELL_ID, "powerType") == 0
        and scalar(W.SPELL_ID, "manaCost") == 0
        and scalar(W.SPELL_ID, "manaCostPercentage") == 0
        and scalar(W.SPELL_ID, "recoveryTime") == 60000
        and scalar(W.SPELL_ID, "categoryRecoveryTime") == 0
        and scalar(W.SPELL_ID, "startRecoveryTime") == 0
        and equal(triple(W.SPELL_ID, "effect"), 30, 64, 2)
        and equal(triple(W.SPELL_ID, "effectApplyAuraName"), 0, 0, 0)
        and equal(triple(W.SPELL_ID, "effectImplicitTargetA"), 1, 1, 1)
        and equal(triple(W.SPELL_ID, "effectImplicitTargetB"), 0, 0, 0)
        and equal(triple(W.SPELL_ID, "effectMiscValue"), 1, 0, 0)
        and equal(triple(W.SPELL_ID, "effectTriggerSpell"), 0,
            W.AURA_SPELL_ID, 0)
end

local function childShape()
    return scalar(W.AURA_SPELL_ID, "spellFamilyName") == W.WARRIOR_FAMILY
        and equal(triple(W.AURA_SPELL_ID, "effect"), 6, 6, 0)
        and equal(triple(W.AURA_SPELL_ID, "effectApplyAuraName"), 24, 94, 0)
        and equal(triple(W.AURA_SPELL_ID, "effectImplicitTargetA"), 1, 1, 0)
        and equal(triple(W.AURA_SPELL_ID, "effectImplicitTargetB"), 0, 0, 0)
        and equal(triple(W.AURA_SPELL_ID, "effectMiscValue"), 1, 0, 0)
        and equal(triple(W.AURA_SPELL_ID, "effectAmplitude"), 1000, 0, 0)
        and duration(W.AURA_SPELL_ID) == 10
end

local function classify()
    if CACHE[W.SPELL_ID] then return copy(CACHE[W.SPELL_ID]) end
    local found = { recognized = true, valid = false,
        spellId = W.SPELL_ID, auraSpellId = W.AURA_SPELL_ID,
        source = "installed-client Bloodrage DBC trigger topology" }
    local immediateRaw = fixedMagnitude(W.SPELL_ID, 1)
    local baseHealthPercent = fixedMagnitude(W.SPELL_ID, 3)
    local periodicRaw = fixedMagnitude(W.AURA_SPELL_ID, 1)
    local description = textField(W.SPELL_ID, "description")
    local criticalHealthCost = description and string.find(
        description, "$*2;s3%", 1, true) ~= nil
    if not (parentShape() and childShape() and immediateRaw
        and periodicRaw and baseHealthPercent and immediateRaw > 0
        and periodicRaw > 0 and baseHealthPercent > 0
        and criticalHealthCost
        and divisible(immediateRaw, W.RAGE_SCALE)
        and divisible(periodicRaw, W.RAGE_SCALE)) then
        found.reason = "Bloodrage DBC topology is incomplete"
        CACHE[W.SPELL_ID] = copy(found)
        return found
    end
    local interval, lifetime = 1, 10
    found.valid, found.exact = true, true
    found.immediateGain = immediateRaw / W.RAGE_SCALE
    found.periodicGain = periodicRaw / W.RAGE_SCALE
    found.interval, found.duration = interval, lifetime
    found.ticks = lifetime / interval
    found.totalGain = found.immediateGain + found.periodicGain * found.ticks
    found.baseHealthPercent = baseHealthPercent
    found.healthCriticalMultiplier = 2
    found.healthCostPercent = baseHealthPercent * 2
    found.cooldown, found.gcd = 60, 0
    found.powerType, found.startsCombat = W.RAGE, true
    CACHE[W.SPELL_ID] = copy(found)
    return found
end

function W:Classify(spellId)
    spellId = integer(spellId, 1, 4294967295)
    if spellId ~= self.SPELL_ID then
        return nil, "not the installed Bloodrage identity", false
    end
    local found = classify()
    return found, found.reason, true
end

function W:InferKnowledge(spellId)
    if classToken() ~= "WARRIOR" then
        return nil, "player is not an exactly identified Warrior", false
    end
    local found, reason, recognized = self:Classify(spellId)
    if not (found and found.valid == true) then return nil, reason, recognized end
    return { inferred = true, kind = "resource", kindExact = true,
        self = true, fixedTarget = "player", transientResource = true,
        healthConversion = true, resourceType = "rage", warriorRage = true,
        routineResourceCooldown = true,
        requiresExactUsability = true, submissionGuarded = true,
        warriorRageEvidence = copy(found), source = found.source }, nil, true
end

local function evidence(subject)
    local facts = type(subject) == "table" and subject.facts or subject
    local found = facts and facts.warriorRageEvidence
    if not (facts and facts.warriorRage == true and type(found) == "table"
        and found.valid == true and found.exact == true
        and found.spellId == W.SPELL_ID
        and found.auraSpellId == W.AURA_SPELL_ID
        and found.immediateGain == 10 and found.periodicGain == 1
        and found.interval == 1 and found.duration == 10
        and found.ticks == 10 and found.totalGain == 20
        and found.baseHealthPercent == 10
        and found.healthCriticalMultiplier == 2
        and found.healthCostPercent == 20 and found.cooldown == 60
        and found.gcd == 0 and found.powerType == W.RAGE
        and found.startsCombat == true) then return nil end
    return found
end


function W:Evidence(subject)
    local found = evidence(subject)
    return found and copy(found) or nil
end

-- This root capture validates only the immutable discovery result. It never
-- rereads DBC or aura APIs and is therefore also safe to exercise in tests.
function W:CaptureFacts(action, facts)
    local out = copy(facts)
    local found = action and evidence(action)
    if not found then return out end
    out.warriorRageEvidence = copy(found)
    out.healthCostPercent, out.resourceGain = found.healthCostPercent,
        found.totalGain
    out.resourceImmediate, out.resourcePeriodic = found.immediateGain,
        found.periodicGain * found.ticks
    out.resourceType, out.powerType = "rage", self.RAGE
    out.cost, out.cast, out.gcd = 0, 0, found.gcd
    out.cooldown, out.duration = found.cooldown, found.duration
    return out
end

local function activeBuffRemaining()
    if type(GetPlayerBuff) ~= "function"
        or type(GetPlayerBuffID) ~= "function"
        or type(GetPlayerBuffTimeLeft) ~= "function" then return nil, false end
    local index
    for index = 0, 31 do
        local ok, slot = pcall(GetPlayerBuff, index, "HELPFUL")
        if not ok then return nil, false end
        if slot and slot ~= -1 then
            local idOK, spellId = pcall(GetPlayerBuffID, slot)
            if not idOK then return nil, false end
            if tonumber(spellId) == W.AURA_SPELL_ID then
                local timeOK, remaining = pcall(GetPlayerBuffTimeLeft, slot)
                remaining = timeOK and finite(remaining, 0, 10.25) or nil
                return remaining, remaining ~= nil
            end
        end
    end
    return nil, true
end

function W:Snapshot()
    if classToken() ~= "WARRIOR" then return nil end
    local remaining, exact = activeBuffRemaining()
    if not exact or remaining == nil or remaining <= 0 then return nil end
    local ticks = math.min(10, math.floor(remaining / 1))
    return { kind = "warriorBloodrage", verified = true, active = true,
        exact = false, lowerBound = true, phaseKnown = false,
        resourceType = self.RAGE, amount = 1, interval = 1, nextIn = 1,
        remaining = remaining, ticksRemaining = ticks,
        spellId = self.SPELL_ID, auraSpellId = self.AURA_SPELL_ID,
        source = "live Bloodrage aura with conservative tick phase" }
end

function W:Attach(state)
    if not (state and tonumber(state.resourceType) == self.RAGE) then return false end
    local baseHealth
    if type(GetUnitField) == "function" then
        local ok, value = pcall(GetUnitField, "player", "baseHealth")
        baseHealth = ok and integer(value, 1, 1000000000) or nil
    end
    state.playerBaseHealth = baseHealth
    state.playerBaseHealthExact = baseHealth ~= nil
    local clock = self:Snapshot()
    if clock then state.playerResourceClock = clock end
    return baseHealth ~= nil or clock ~= nil
end

function W:ClockFor(state)
    local clock = state and state.playerResourceClock
    if tonumber(state and state.resourceType) ~= self.RAGE
        or not (clock and clock.kind == "warriorBloodrage"
            and clock.verified == true and clock.active == true
            and clock.resourceType == self.RAGE
            and clock.spellId == self.SPELL_ID
            and clock.auraSpellId == self.AURA_SPELL_ID) then return nil end
    local amount = finite(clock.amount, 0.000001, 100)
    local interval = finite(clock.interval, 0.000001, 60)
    local nextIn = finite(clock.nextIn, 0, interval or 0)
    local remaining = finite(clock.remaining, 0, 10.25)
    local ticks = integer(clock.ticksRemaining, 0, 10)
    if not (amount and interval and nextIn and remaining and ticks) then return nil end
    return clock, amount, interval, nextIn, remaining, ticks
end

local function sync(state)
    local actor = state.actors and state.actors.player
    if actor then actor.resource = state.resource end
end

function W:Advance(state, elapsed)
    elapsed = math.max(0, tonumber(elapsed) or 0)
    local clock, amount, interval, nextIn, remaining, ticks = self:ClockFor(state)
    if elapsed <= 0 or not clock then return 0 end
    local due = 0
    if ticks > 0 and elapsed >= nextIn then
        due = 1 + math.floor((elapsed - nextIn) / interval)
        due = math.min(ticks, due)
    end
    clock.remaining = math.max(0, remaining - elapsed)
    clock.ticksRemaining = ticks - due
    if due > 0 then
        local afterFirst = elapsed - nextIn
        local residual = afterFirst - math.floor(afterFirst / interval) * interval
        clock.nextIn = interval - residual
    else clock.nextIn = math.max(0, nextIn - elapsed) end
    local prior = tonumber(state.resource) or 0
    local maximum = math.max(prior, tonumber(state.resourceMax) or prior)
    state.resource = math.min(maximum, prior + due * amount)
    sync(state)
    if due > 0 then
        state.playerResourceProjected = true
        state.playerRageProjection = { exact = clock.exact == true,
            lowerBound = clock.lowerBound == true, gained = state.resource - prior,
            source = clock.source }
    end
    if clock.remaining <= 0 or clock.ticksRemaining <= 0 then
        state.playerResourceClock = nil
    end
    return state.resource - prior
end

local function probe(state, at)
    local out = { time = state.time, resource = tonumber(state.resource),
        resourceMax = tonumber(state.resourceMax), resourceType = state.resourceType,
        playerResourceReserved = tonumber(state.playerResourceReserved) or 0,
        playerResourceClock = copy(state.playerResourceClock), actors = {} }
    W:Advance(out, math.max(0, (tonumber(at) or 0)
        - (tonumber(state.time) or 0)))
    return out
end

function W:ResourceAt(state, at)
    local out = probe(state, at)
    return out.resource and out.resource - out.playerResourceReserved or nil
end

function W:Earliest(state, cost, readyAt)
    cost, readyAt = math.max(0, tonumber(cost) or 0),
        math.max(tonumber(state.time) or 0, tonumber(readyAt) or 0)
    local out = probe(state, readyAt)
    local available = (tonumber(out.resource) or 0) - out.playerResourceReserved
    if available >= cost then return readyAt end
    if (tonumber(out.resourceMax) or 0) - out.playerResourceReserved < cost then
        return nil
    end
    local _, amount, interval, nextIn, _, ticks = self:ClockFor(out)
    if not amount then return nil end
    local needed = math.ceil((cost - available) / amount)
    if needed > ticks then return nil end
    return readyAt + nextIn + math.max(0, needed - 1) * interval
end

function W:Start(state, subject)
    local found = evidence(subject)
    if not (state and found and tonumber(state.resourceType) == self.RAGE
        and state.playerResourceExact == true) then return false end
    local prior = tonumber(state.resource)
    local maximum = tonumber(state.resourceMax)
    if not prior or not maximum or prior < 0 or maximum < prior then return false end
    state.resource = math.min(maximum, prior + found.immediateGain)
    state.playerResourceClock = { kind = "warriorBloodrage", verified = true,
        active = true, exact = true, lowerBound = true, phaseKnown = true,
        resourceType = self.RAGE, amount = found.periodicGain,
        interval = found.interval, nextIn = found.interval,
        remaining = found.duration, ticksRemaining = found.ticks,
        spellId = found.spellId, auraSpellId = found.auraSpellId,
        source = found.source }
    state.playerResourceProjected = true
    state.playerRageProjection = { exact = true,
        gained = state.resource - prior, source = found.source }
    sync(state)
    return true
end

function W:Active(state)
    return self:ClockFor(state) ~= nil
end

function W:Invalidate()
    CACHE = {}
end
