-- Session-only resolved auto-attack evidence. A command or active attack-bar
-- glow never establishes swing phase; only an exact ordinary attack round from
-- the current controlled actor can anchor the next projected event.
XelAssist.Game.AttackRounds = {}
local A = XelAssist.Game.AttackRounds

local CONSERVATIVE_DELAY = 0.05
local RAW_SPEED_SAMPLES = 3

local function now()
    if type(GetTime) ~= "function" then return nil end
    local ok, value = pcall(GetTime)
    if ok and type(value) == "number" then return value end
    return nil
end

local function unitGuid(unit)
    if type(UnitExists) ~= "function" then return nil end
    local ok, exists, guid = pcall(UnitExists, unit)
    if ok and exists then return guid end
    return nil
end

local function hasFlag(value, flag)
    value, flag = tonumber(value) or 0, tonumber(flag) or 1
    return math.floor(value / flag) - math.floor(value / (flag * 2)) * 2 == 1
end

local function safeUnitField(field)
    if type(GetUnitField) ~= "function" then return nil end
    local ok, value = pcall(GetUnitField, "pet", field)
    if ok and type(value) == "number" then return value end
    return nil
end

local function liveSpeed()
    if type(UnitAttackSpeed) == "function" then
        local ok, speed = pcall(UnitAttackSpeed, "pet")
        if ok and type(speed) == "number" and speed > 0 then
            return speed, "stock pet attack speed", true
        end
    end
    local milliseconds = safeUnitField("baseAttackTime")
    if milliseconds and milliseconds > 0 then
        return milliseconds / 1000, "Nampower base attack time", false
    end
    return nil, "pet attack speed unavailable", false
end

local function liveDamage()
    if type(UnitDamage) == "function" then
        local ok, minimum, maximum, offMinimum, offMaximum,
            positive, negative, multiplier = pcall(UnitDamage, "pet")
        minimum, maximum = tonumber(minimum), tonumber(maximum)
        if ok and minimum and maximum and minimum >= 0 and maximum >= minimum then
            positive, negative = tonumber(positive) or 0, tonumber(negative) or 0
            multiplier = tonumber(multiplier)
            if multiplier == nil then multiplier = 1 end
            if multiplier >= 0 then
                local fullMinimum = math.max(0,
                    (minimum + positive + negative) * multiplier)
                local fullMaximum = math.max(fullMinimum,
                    (maximum + positive + negative) * multiplier)
                return fullMinimum, fullMaximum,
                    "stock pet damage with physical modifiers", true
            end
        end
    end
    local minimum, maximum = safeUnitField("minDamage"), safeUnitField("maxDamage")
    if minimum and maximum and minimum >= 0 and maximum >= minimum then
        return minimum, maximum, "raw Nampower pet damage fields", false
    end
    return nil, nil, "pet damage unavailable", false
end

local function attackBarState()
    if type(GetPetActionInfo) ~= "function" then return nil end
    local slots, index = NUM_PET_ACTION_SLOTS or 10, nil
    for index = 1, slots do
        local ok, name, _, _, token, active = pcall(GetPetActionInfo, index)
        local upper = ok and type(name) == "string" and string.upper(name) or ""
        if ok and token and string.find(upper, "ATTACK", 1, true) then
            return active and true or false
        end
    end
    return nil
end

local function speedClose(left, right)
    if not (tonumber(left) and tonumber(right)) then return false end
    local tolerance = math.max(0.08, math.max(left, right) * 0.08)
    return math.abs(left - right) <= tolerance
end

local function cleanInterval(interval, speed)
    if not (tonumber(interval) and tonumber(speed)) or interval <= 0 then return false end
    return math.abs(interval - speed) <= math.max(0.20, speed * 0.15)
end

function A:Reset(reason)
    self.record = nil
    self.lastResetReason = reason or "session reset"
end

function A:RegimeChanged(reason)
    self:Reset(reason or "companion attack regime changed")
end

function A:IdentityChanged(previousGuid, currentGuid)
    if previousGuid ~= currentGuid then
        self:Reset("companion identity changed")
        return true
    end
    return false
end

function A:AttackStateChanged(active)
    self:Reset(active and "companion attack started; awaiting round"
        or "companion attack stopped")
end

function A:Observe(attackerGuid, targetGuid, result, observedAt)
    if not (result and result.actor == "pet" and result.hand == "main"
        and result.exactDelivery == true
        and (result.evidence == "hit"
            or result.evidence == "ordinary-miss")) then return false end
    if attackerGuid == nil or attackerGuid ~= unitGuid("pet") or targetGuid == nil then
        return false
    end
    if type(result.hitInfo) ~= "number"
        or hasFlag(result.hitInfo, 65536) then return false end
    observedAt = tonumber(observedAt) or now()
    if not observedAt then return false end
    local speed, speedSource, speedTrusted = liveSpeed()
    if not speed then self:Reset("pet attack speed unavailable") return false end

    local record = self.record
    local same = record and record.actorGuid == attackerGuid
        and record.targetGuid == targetGuid and speedClose(record.speed, speed)
    if not same then
        record = { actorGuid = attackerGuid, targetGuid = targetGuid,
            speed = speed, speedSource = speedSource,
            speedTrusted = speedTrusted, samples = 0 }
        self.record = record
    elseif record.lastRoundAt then
        local interval = observedAt - record.lastRoundAt
        record.observedInterval = interval
        if cleanInterval(interval, speed) then
            record.samples = (record.samples or 0) + 1
            record.longestCleanInterval = math.max(
                tonumber(record.longestCleanInterval) or 0, interval)
        elseif not record.speedTrusted then
            record.samples, record.longestCleanInterval = 0, nil
        end
    end
    record.speed, record.speedSource, record.speedTrusted =
        speed, speedSource, speedTrusted
    record.interval = math.max(speed,
        tonumber(record.longestCleanInterval) or 0) + CONSERVATIVE_DELAY
    record.lastRoundAt = observedAt
    record.lastOutcome = result.outcome
    record.phaseKnown = true
    record.verified = speedTrusted or (record.samples or 0) >= RAW_SPEED_SAMPLES
    self.lastResetReason = nil
    return true
end

local function normalizedPower(pet, minimum, maximum)
    if not (minimum and maximum) then return nil, nil, nil end
    local multiplier = XelAssist.Game.Pets and XelAssist.Game.Pets.Effects
        and XelAssist.Game.Pets.Effects:DamageMultiplier(pet) or 1
    multiplier = math.max(0.05, tonumber(multiplier) or 1)
    return minimum / multiplier, maximum / multiplier,
        ((minimum + maximum) / 2) / multiplier
end

function A:Snapshot(pet)
    local status = { supported = type(UnitAttackSpeed) == "function"
            or type(GetUnitField) == "function",
        phaseKnown = false, verified = false, projectable = false,
        lastResetReason = self.lastResetReason }
    if not (pet and pet.guid and pet.guid == unitGuid("pet")) then
        status.reason = "current companion identity unavailable"
        return status
    end
    local speed, speedSource, speedTrusted = liveSpeed()
    local minimum, maximum, damageSource, damageKnown = liveDamage()
    status.speed, status.speedSource, status.speedTrusted =
        speed, speedSource, speedTrusted
    status.damageSource, status.normalDamageKnown = damageSource, damageKnown
    status.damageKnown, status.outcomeMagnitudeKnown = false, false
    status.rawMinimum, status.rawMaximum = minimum, maximum
    status.minimum, status.maximum, status.power =
        normalizedPower(pet, minimum, maximum)
    local active = pet.attackActive
    if pet.attackActiveKnown ~= true then active = attackBarState() end
    status.attackActive = active
    status.attackActiveKnown = active ~= nil
    status.targetGuid = pet.targetGuid

    local record = self.record
    if not record or record.actorGuid ~= pet.guid then
        status.reason = "awaiting first resolved companion swing"
        return status
    end
    status.samples, status.observedInterval = record.samples,
        record.observedInterval
    if not speed or not speedClose(record.speed, speed) then
        status.reason = "companion attack speed changed"
        return status
    end
    if active ~= true then
        status.reason = active == false and "companion attack inactive"
            or "companion attack state unknown"
        return status
    end
    if pet.targetGuid == nil or pet.targetGuid ~= record.targetGuid then
        status.reason = "companion target changed"
        return status
    end
    if not record.verified then
        status.reason = "learning effective companion swing cadence"
        return status
    end
    local at = now()
    if not at then status.reason = "combat clock unavailable" return status end
    local interval = math.max(0.1, tonumber(record.interval) or speed)
    local due = record.lastRoundAt + interval
    if due <= at then
        status.reason = "swing deadline passed without a resolved round"
        return status
    end
    status.interval, status.nextSwingIn = interval, due - at
    status.phaseKnown, status.verified, status.projectable = true, true, true
    status.phaseSource = "resolved Nampower pet attack round"
    status.reason = nil
    return status
end

function A:Attach(pet)
    if pet then pet.attackRound = self:Snapshot(pet) end
    return pet
end

function A:Status()
    local record = self.record
    local phaseKnown = record and record.phaseKnown and true or false
    local at = now()
    if phaseKnown and at and record.lastRoundAt and record.interval
        and record.lastRoundAt + record.interval <= at then
        phaseKnown = false
    end
    local speed = liveSpeed()
    if phaseKnown and not speedClose(record.speed, speed) then
        phaseKnown = false
    end
    return { supported = type(UnitAttackSpeed) == "function"
            or type(GetUnitField) == "function",
        samples = record and record.samples or 0,
        verified = record and record.verified and true or false,
        phaseKnown = phaseKnown,
        speed = record and record.speed or nil,
        interval = record and record.interval or nil,
        outcomeMagnitudeKnown = false,
        lastResetReason = self.lastResetReason }
end

A:Reset("session start")
