-- Session-only player off-hand phase evidence. Main- and off-hand clocks are
-- independent on the server, so an exact Nampower LEFTSWING result anchors
-- only this lane. Commands, equipment presence and main-hand packets never
-- invent an off-hand phase.
XelAssist.Game.Player.OffhandAttackRounds = {}
local O = XelAssist.Game.Player.OffhandAttackRounds

local CONSERVATIVE_DELAY = 0.05
local RAW_SPEED_SAMPLES = 3

local function now()
    if type(GetTime) ~= "function" then return nil end
    local ok, value = pcall(GetTime)
    return ok and type(value) == "number" and value or nil
end

local function unitGuid(unit)
    if type(UnitExists) ~= "function" then return nil end
    local ok, exists, guid = pcall(UnitExists, unit)
    if ok and (exists == true or exists == 1) then return guid end
    return nil
end

local function hasFlag(value, flag)
    value, flag = tonumber(value) or 0, tonumber(flag) or 1
    return math.floor(value / flag)
        - math.floor(value / (flag * 2)) * 2 == 1
end

local function field(name)
    if type(GetUnitField) ~= "function" then return nil end
    local ok, value = pcall(GetUnitField, "player", name)
    return ok and type(value) == "number" and value or nil
end

local function liveSpeed()
    if type(UnitAttackSpeed) == "function" then
        local ok, _, speed = pcall(UnitAttackSpeed, "player")
        if ok and type(speed) == "number" and speed > 0 then
            return speed, "stock player off-hand attack speed", true
        end
    end
    local milliseconds = field("offhandAttackTime")
    if milliseconds and milliseconds > 0 then
        return milliseconds / 1000,
            "Nampower off-hand attack time", false
    end
    return nil, "off-hand weapon speed unavailable", false
end

local function liveDamage()
    if type(UnitDamage) == "function" then
        local ok, _, _, minimum, maximum =
            pcall(UnitDamage, "player")
        minimum, maximum = tonumber(minimum), tonumber(maximum)
        if ok and minimum and maximum and minimum >= 0
            and maximum >= minimum and maximum > 0 then
            return minimum, maximum,
                "stock displayed player off-hand damage", true
        end
    end
    local minimum, maximum = field("minOffhandDamage"),
        field("maxOffhandDamage")
    if minimum and maximum and minimum >= 0
        and maximum >= minimum and maximum > 0 then
        return minimum, maximum,
            "raw Nampower off-hand damage fields", false
    end
    return nil, nil, "off-hand damage unavailable", false
end

local function speedClose(left, right)
    if not (tonumber(left) and tonumber(right)) then return false end
    local tolerance = math.max(0.08, math.max(left, right) * 0.08)
    return math.abs(left - right) <= tolerance
end

local function sameSpeedRegime(left, leftTrusted, right, rightTrusted)
    if not (tonumber(left) and tonumber(right)) then return false end
    if leftTrusted and rightTrusted then
        return math.abs(left - right) <= 0.001
    end
    return speedClose(left, right)
end

local function cleanInterval(interval, speed)
    if not (tonumber(interval) and tonumber(speed)) or interval <= 0 then
        return false
    end
    return math.abs(interval - speed) <= math.max(0.20, speed * 0.15)
end

local function clearRawCadence(record)
    record.rawCleanIntervals, record.rawCadence = nil, nil
end

-- Raw fields require repeated delivery evidence. A bounded median admits a
-- persistent effective cadence but rejects one delayed cross-hand collision.
local function rememberRawInterval(record, interval)
    local values = record.rawCleanIntervals or {}
    table.insert(values, interval)
    while table.getn(values) > RAW_SPEED_SAMPLES do table.remove(values, 1) end
    record.rawCleanIntervals = values
    if table.getn(values) < RAW_SPEED_SAMPLES then
        record.rawCadence = nil
        return
    end
    local ordered, index = {}, nil
    for index = 1, table.getn(values) do ordered[index] = values[index] end
    table.sort(ordered)
    record.rawCadence = ordered[2]
end

function O:Reset(reason)
    self.record, self.lastObservedAt = nil, nil
    self.lastResetReason = reason or "session reset"
end

function O:RegimeChanged(reason)
    self:Reset(reason or "player off-hand regime changed")
end

function O:AttackStateChanged(active)
    self:Reset(active and "player attack started; awaiting off-hand round"
        or "player attack stopped")
end

function O:TargetChanged()
    self:Reset("player attack target changed")
end

function O:SpeedChanged()
    self:Reset("player off-hand attack speed changed")
end

function O:EquipmentChanged()
    self:Reset("player off-hand weapon changed")
end

function O:FormChanged()
    self:Reset("player form changed")
end

function O:ControlChanged()
    self:Reset("player control regime changed")
end

local function newRecord(actorGuid, targetGuid, speed, source, trusted)
    return { actorGuid = actorGuid, targetGuid = targetGuid,
        speed = speed, speedSource = source, speedTrusted = trusted,
        samples = 0 }
end

function O:Observe(attackerGuid, targetGuid, result, observedAt)
    if not (result and result.actor == "player" and result.hand == "off"
        and result.exactDelivery == true
        and (result.evidence == "hit"
            or result.evidence == "ordinary-miss")) then return false end
    if attackerGuid == nil or attackerGuid ~= unitGuid("player")
        or targetGuid == nil then return false end
    if type(result.hitInfo) ~= "number"
        or hasFlag(result.hitInfo, 65536) then return false end
    observedAt = tonumber(observedAt) or now()
    if not observedAt or self.lastObservedAt
        and observedAt <= self.lastObservedAt then return false end
    local speed, source, trusted = liveSpeed()
    if not speed then
        self:Reset("off-hand weapon speed unavailable")
        return false
    end

    local record = self.record
    local same = record and record.actorGuid == attackerGuid
        and record.targetGuid == targetGuid
        and sameSpeedRegime(record.speed, record.speedTrusted,
            speed, trusted)
    if not same then
        record = newRecord(attackerGuid, targetGuid, speed, source, trusted)
        self.record = record
    elseif record.lastRoundAt then
        if record.speedTrusted ~= trusted then
            record.samples = 0
            clearRawCadence(record)
        end
        local interval = observedAt - record.lastRoundAt
        record.observedInterval = interval
        if cleanInterval(interval, speed) then
            record.samples = (record.samples or 0) + 1
            if not trusted then rememberRawInterval(record, interval) end
        elseif not record.speedTrusted then
            record.samples = 0
            clearRawCadence(record)
        end
    end

    record.speed, record.speedSource, record.speedTrusted =
        speed, source, trusted
    local cadence = not trusted and tonumber(record.rawCadence) or speed
    record.interval = math.max(speed, cadence or speed) + CONSERVATIVE_DELAY
    record.lastRoundAt = observedAt
    record.lastOutcome = result.outcome
    record.phaseSource = "resolved Nampower player off-hand round"
    self.roundGeneration = (tonumber(self.roundGeneration) or 0) + 1
    record.generation = self.roundGeneration
    record.phaseKnown, record.phaseExact = true, true
    record.verified = trusted or record.rawCadence ~= nil
    self.lastObservedAt, self.lastResetReason = observedAt, nil
    return true
end

local function invalidate(owner, status, reason)
    owner:Reset(reason)
    status.lastResetReason, status.reason = reason, reason
    return status
end

function O:Snapshot(attack)
    local status = { supported = type(UnitAttackSpeed) == "function"
            or type(GetUnitField) == "function",
        hand = "off", phaseKnown = false, phaseExact = false,
        verified = false, projectable = false,
        lastResetReason = self.lastResetReason }
    local speed, speedSource, speedTrusted = liveSpeed()
    local minimum, maximum, damageSource, damageTrusted = liveDamage()
    status.speed, status.speedSource, status.speedTrusted =
        speed, speedSource, speedTrusted
    status.rawMinimum, status.rawMaximum = minimum, maximum
    status.minimum, status.maximum = minimum, maximum
    status.power = minimum and maximum and (minimum + maximum) / 2 or nil
    status.damageSource, status.normalDamageKnown = damageSource, damageTrusted
    status.attackActive = attack and attack.active
    status.attackActiveKnown = attack and attack.activeKnown == true or false
    status.targetGuid = unitGuid("target")

    local playerGuid, record = unitGuid("player"), self.record
    if not speed then
        if record then return invalidate(self, status,
            "off-hand weapon unavailable") end
        status.reason = "off-hand weapon unavailable"
        return status
    end
    if not record then
        status.reason = "awaiting first resolved player off-hand swing"
        return status
    end
    status.samples, status.observedInterval = record.samples,
        record.observedInterval
    status.generation = record.generation
    if not playerGuid or record.actorGuid ~= playerGuid then
        return invalidate(self, status, "player identity changed")
    end
    if not sameSpeedRegime(record.speed, record.speedTrusted,
        speed, speedTrusted) then
        return invalidate(self, status,
            "player off-hand attack speed changed")
    end
    if status.attackActive ~= true then
        if status.attackActive == false then
            return invalidate(self, status, "player attack stopped")
        end
        status.reason = "player attack state unknown"
        return status
    end
    if status.targetGuid == nil or status.targetGuid ~= record.targetGuid then
        return invalidate(self, status, "player attack target changed")
    end
    if not record.verified then
        status.reason = "learning effective player off-hand cadence"
        return status
    end
    local at = now()
    if not at then
        status.reason = "combat clock unavailable"
        return status
    end
    local interval = math.max(0.1, tonumber(record.interval) or speed)
    local due = record.lastRoundAt + interval
    if due <= at then
        return invalidate(self, status,
            "off-hand swing deadline passed without a resolved round")
    end
    status.interval, status.nextSwingIn = interval, due - at
    status.phaseKnown, status.phaseExact = true, true
    status.verified, status.projectable = true, true
    status.phaseSource = record.phaseSource
    status.reason, status.lastResetReason = nil, nil
    return status
end

function O:Attach(attack)
    if attack then attack.offhandAttackRound = self:Snapshot(attack) end
    return attack
end

function O:Status()
    local record, at = self.record, now()
    local phaseKnown = record and record.phaseKnown and true or false
    if phaseKnown and at and record.lastRoundAt and record.interval
        and record.lastRoundAt + record.interval <= at then
        phaseKnown = false
    end
    local speed, _, trusted = liveSpeed()
    if phaseKnown and not sameSpeedRegime(record.speed,
        record.speedTrusted, speed, trusted) then phaseKnown = false end
    return { supported = type(UnitAttackSpeed) == "function"
            or type(GetUnitField) == "function",
        hand = "off", samples = record and record.samples or 0,
        verified = record and record.verified and true or false,
        phaseKnown = phaseKnown, phaseExact = phaseKnown,
        speed = record and record.speed or nil,
        interval = record and record.interval or nil,
        generation = record and record.generation or nil,
        lastResetReason = self.lastResetReason }
end

O.roundGeneration = 0
O:Reset("session start")
