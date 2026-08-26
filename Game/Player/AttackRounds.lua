-- Session-only player main-hand phase evidence. An Attack command, target
-- selection, or weapon speed never invents a phase: only an exact ordinary
-- Nampower AUTO_ATTACK result (or an exactly owned on-swing GO) can anchor it.
XelAssist.Game.Player.AttackRounds = {}
local A = XelAssist.Game.Player.AttackRounds

local CONSERVATIVE_DELAY = 0.05
local RAW_SPEED_SAMPLES = 3
local ATTEMPT_TOMBSTONES = 16

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
    return math.floor(value / flag)
        - math.floor(value / (flag * 2)) * 2 == 1
end

local function safeField(field)
    if type(GetUnitField) ~= "function" then return nil end
    local ok, value = pcall(GetUnitField, "player", field)
    if ok and type(value) == "number" then return value end
    return nil
end

local function liveSpeed()
    if type(UnitAttackSpeed) == "function" then
        local ok, speed = pcall(UnitAttackSpeed, "player")
        if ok and type(speed) == "number" and speed > 0 then
            return speed, "stock player attack speed", true
        end
    end
    local milliseconds = safeField("baseAttackTime")
    if milliseconds and milliseconds > 0 then
        return milliseconds / 1000, "Nampower base attack time", false
    end
    return nil, "player attack speed unavailable", false
end

local function liveDamage()
    if type(UnitDamage) == "function" then
        local ok, minimum, maximum =
            pcall(UnitDamage, "player")
        minimum, maximum = tonumber(minimum), tonumber(maximum)
        if ok and minimum and maximum and minimum >= 0 and maximum >= minimum then
            return minimum, maximum,
                "stock displayed player damage", true
        end
    end
    local minimum, maximum = safeField("minDamage"), safeField("maxDamage")
    if minimum and maximum and minimum >= 0 and maximum >= minimum then
        return minimum, maximum, "raw Nampower player damage fields", false
    end
    return nil, nil, "player damage unavailable", false
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

local function usableAttemptId(value)
    if value == nil then return nil end
    value = tostring(value)
    if value == "" or value == "0" then return nil end
    return value
end

local function classifiedOnSwing(evidence)
    if type(evidence) ~= "table" then return false end
    local action, tooltip = evidence.action, evidence.tooltip
    local facts = action and action.facts or {}
    return evidence.onNextSwing == true or evidence.onSwing == true
        or facts.onNextSwing == true or facts.onSwing == true
        or tooltip and (tooltip.onNextSwing == true
            or tooltip.onSwing == true) and true or false
end

local function exactOnSwing(evidence)
    if not classifiedOnSwing(evidence) then return false end
    if evidence.actor and evidence.actor ~= "player" then return false end
    if evidence.hand and evidence.hand ~= "main" then return false end
    if not usableAttemptId(evidence.attemptId) then return false end
    return evidence.exact == true or evidence.exactAttempt == true
        or evidence.phase == "accepted"
end

function A:Reset(reason)
    self.record, self.lastObservedAt = nil, nil
    self.lastResetReason = reason or "session reset"
end

function A:RegimeChanged(reason)
    self:Reset(reason or "player attack regime changed")
end

function A:AttackStateChanged(active)
    self:Reset(active and "player attack started; awaiting round"
        or "player attack stopped")
end

function A:TargetChanged()
    self:Reset("player attack target changed")
end

function A:SpeedChanged()
    self:Reset("player attack speed changed")
end

function A:EquipmentChanged()
    self:Reset("player weapon changed")
end

function A:FormChanged()
    self:Reset("player form changed")
end

function A:ControlChanged()
    self:Reset("player control regime changed")
end

local function newRecord(owner, actorGuid, targetGuid, speed,
    speedSource, speedTrusted)
    return { actorGuid = actorGuid, targetGuid = targetGuid,
        speed = speed, speedSource = speedSource,
        speedTrusted = speedTrusted, samples = 0 }
end

local function anchor(owner, attackerGuid, targetGuid, result, observedAt,
    phaseSource, roundKind)
    local playerGuid = unitGuid("player")
    if attackerGuid == nil or playerGuid == nil or attackerGuid ~= playerGuid
        or targetGuid == nil then return false end
    observedAt = tonumber(observedAt) or now()
    if not observedAt then return false end
    if owner.lastObservedAt and observedAt <= owner.lastObservedAt then
        return false
    end
    local speed, speedSource, speedTrusted = liveSpeed()
    if not speed then
        owner:Reset("player attack speed unavailable")
        return false
    end

    local record = owner.record
    local same = record and record.actorGuid == attackerGuid
        and record.targetGuid == targetGuid
        and sameSpeedRegime(record.speed, record.speedTrusted,
            speed, speedTrusted)
    if not same then
        record = newRecord(owner, attackerGuid, targetGuid, speed,
            speedSource, speedTrusted)
        owner.record = record
    elseif record.lastRoundAt then
        if record.speedTrusted ~= speedTrusted then
            record.samples = 0
            clearRawCadence(record)
        end
        local interval = observedAt - record.lastRoundAt
        record.observedInterval = interval
        if cleanInterval(interval, speed) then
            record.samples = (record.samples or 0) + 1
            if not speedTrusted then rememberRawInterval(record, interval) end
        elseif not record.speedTrusted then
            record.samples = 0
            clearRawCadence(record)
        end
    end

    record.speed, record.speedSource, record.speedTrusted =
        speed, speedSource, speedTrusted
    local cadence = not speedTrusted and tonumber(record.rawCadence) or speed
    record.interval = math.max(speed, cadence or speed) + CONSERVATIVE_DELAY
    record.lastRoundAt = observedAt
    record.lastOutcome = result and result.outcome or roundKind
    record.lastRoundKind = roundKind
    record.phaseSource = phaseSource
    owner.roundGeneration = (tonumber(owner.roundGeneration) or 0) + 1
    record.generation = owner.roundGeneration
    record.phaseKnown, record.phaseExact = true, true
    record.verified = speedTrusted or record.rawCadence ~= nil
    owner.lastObservedAt, owner.lastResetReason = observedAt, nil
    return true
end

function A:Observe(attackerGuid, targetGuid, result, observedAt)
    if not (result and result.actor == "player" and result.hand == "main"
        and result.exactDelivery == true
        and (result.evidence == "hit"
            or result.evidence == "ordinary-miss")) then return false end
    if type(result.hitInfo) ~= "number"
        or hasFlag(result.hitInfo, 65536) then return false end
    return anchor(self, attackerGuid, targetGuid, result, observedAt,
        "resolved Nampower player attack round", "ordinary-main-hand")
end

local function rememberAttempt(owner, attemptId)
    attemptId = usableAttemptId(attemptId)
    if not attemptId then return false end
    if owner.onSwingAttemptSet[attemptId] then return false end
    owner.onSwingAttemptSet[attemptId] = true
    table.insert(owner.onSwingAttemptOrder, attemptId)
    if table.getn(owner.onSwingAttemptOrder) > ATTEMPT_TOMBSTONES then
        local expired = table.remove(owner.onSwingAttemptOrder, 1)
        owner.onSwingAttemptSet[expired] = nil
    end
    return true
end

-- A correctly correlated on-next-swing SPELL_GO proves that the main-hand
-- round occurred even though Nampower deliberately excludes its NOACTION melee
-- packet from ordinary white-hit evidence. The caller must supply an exact,
-- nonzero attempt identity and DBC/action on-swing classification.
function A:ObserveOnSwingGo(attackerGuid, targetGuid, evidence, observedAt)
    if not exactOnSwing(evidence) then return false end
    if attackerGuid == nil or attackerGuid ~= unitGuid("player")
        or targetGuid == nil then return false end
    if evidence.targetGuid ~= nil
        and evidence.targetGuid ~= targetGuid then return false end
    if not rememberAttempt(self, evidence.attemptId) then return false end
    local result = { outcome = evidence.outcome or "on-swing-go" }
    return anchor(self, attackerGuid, targetGuid, result, observedAt,
        "exact owned on-swing SPELL_GO", "on-swing-main-hand")
end

local function invalidate(owner, status, reason)
    owner:Reset(reason)
    status.lastResetReason, status.reason = reason, reason
    return status
end

function A:Snapshot(attack)
    local status = { supported = type(UnitAttackSpeed) == "function"
            or type(GetUnitField) == "function",
        phaseKnown = false, phaseExact = false,
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
    status.damageKnown, status.outcomeMagnitudeKnown = false, false
    status.attackActive = attack and attack.active
    status.attackActiveKnown = attack and attack.activeKnown == true or false
    status.targetGuid = unitGuid("target")

    local playerGuid, record = unitGuid("player"), self.record
    if not record then
        status.reason = "awaiting first resolved player swing"
        return status
    end
    status.samples, status.observedInterval = record.samples,
        record.observedInterval
    status.generation, status.lastRoundKind = record.generation,
        record.lastRoundKind
    if not playerGuid or record.actorGuid ~= playerGuid then
        return invalidate(self, status, "player identity changed")
    end
    if not speed or not sameSpeedRegime(record.speed, record.speedTrusted,
        speed, speedTrusted) then
        return invalidate(self, status, "player attack speed changed")
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
        status.reason = "learning effective player swing cadence"
        return status
    end
    local at = now()
    if not at then status.reason = "combat clock unavailable" return status end
    local interval = math.max(0.1, tonumber(record.interval) or speed)
    local due = record.lastRoundAt + interval
    if due <= at then
        return invalidate(self, status,
            "swing deadline passed without a resolved round")
    end
    status.interval, status.nextSwingIn = interval, due - at
    status.phaseKnown, status.phaseExact = true, true
    status.verified, status.projectable = true, true
    status.phaseSource = record.phaseSource
        or "resolved Nampower player attack round"
    status.reason, status.lastResetReason = nil, nil
    return status
end

function A:Attach(attack)
    if attack then attack.attackRound = self:Snapshot(attack) end
    return attack
end

-- Privacy-safe diagnostics deliberately omit actor and target identities.
function A:Status()
    local record, at = self.record, now()
    local phaseKnown = record and record.phaseKnown and true or false
    if phaseKnown and at and record.lastRoundAt and record.interval
        and record.lastRoundAt + record.interval <= at then phaseKnown = false end
    local speed, _, speedTrusted = liveSpeed()
    if phaseKnown and not sameSpeedRegime(record.speed, record.speedTrusted,
        speed, speedTrusted) then phaseKnown = false end
    return { supported = type(UnitAttackSpeed) == "function"
            or type(GetUnitField) == "function",
        samples = record and record.samples or 0,
        verified = record and record.verified and true or false,
        phaseKnown = phaseKnown, phaseExact = phaseKnown,
        speed = record and record.speed or nil,
        interval = record and record.interval or nil,
        generation = record and record.generation or nil,
        lastRoundKind = record and record.lastRoundKind or nil,
        lastResetReason = self.lastResetReason }
end

A.roundGeneration = 0
A.onSwingAttemptSet, A.onSwingAttemptOrder = {}, {}
A:Reset("session start")
