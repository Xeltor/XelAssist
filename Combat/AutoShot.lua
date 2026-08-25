-- Hunter Auto Shot observation and phase projection. Auto Shot is a sustained
-- ambient attack, not an ordinary repeatable cast and not an encoded rotation.
XelAssist.Combat.AutoShot = {}
local A = XelAssist.Combat.AutoShot
local Range = XelAssist.Combat.AutoShotRange
local Flights = XelAssist.Combat.AutoShotFlights

local AUTO_SHOT_ID = 75
local AUTO_SHOT_IDS = { [75] = true, [1583] = true,
    [52636] = true, [52637] = true }
local ACTION_SLOTS = 120
local START_GUARD = 1.5
local RESUME_FLOOR = 0.5
local ACTION_TIP_NAME = "XelAssistAutoShotScanTooltip"
local actionTip

local function now()
    return GetTime and GetTime() or 0
end

local function unitGuid(unit)
    if not UnitExists then return nil end
    local ok, exists, guid = pcall(UnitExists, unit)
    if not ok or not exists then return nil end
    return guid
end

local function truthy(value)
    return value == true or value == 1
end

local function matchingTarget(observed, current)
    return observed ~= nil and current ~= nil and observed == current
end

local function arrayCount(values)
    local count = 0
    while values[count + 1] ~= nil do count = count + 1 end
    return count
end

local function currentHostileGuid()
    local guid = unitGuid("target")
    if guid == nil then return nil end
    if UnitIsDead and UnitIsDead("target") then return nil end
    if UnitCanAttack and not UnitCanAttack("player", "target") then return nil end
    return guid
end

function A:IsHunter()
    if not UnitClass then return false end
    local ok, _, class = pcall(UnitClass, "player")
    return ok and class == "HUNTER"
end

function A:CanonicalSpellId(spellId)
    if AUTO_SHOT_IDS[tonumber(spellId)] then
        return Range:CanonicalSpellId(spellId)
    end
    return AUTO_SHOT_ID
end

function A:EvidenceSpellId()
    if self.activeSpellId then return self:CanonicalSpellId(self.activeSpellId) end
    local capabilities = XelAssist.Game and XelAssist.Game.Capabilities
    local actions = capabilities and capabilities.Actions
        and capabilities:Actions() or {}
    local found, i, action = nil, nil, nil
    for i = 1, arrayCount(actions) do
        action = actions[i]
        if action and action.facts and action.facts.autoRepeat
            and tonumber(action.spellId) then
            local canonical = self:CanonicalSpellId(action.spellId)
            if found and found ~= canonical then return 0 end
            found = canonical
        end
    end
    return found or AUTO_SHOT_ID
end

function A:RangedSpeed()
    if UnitRangedDamage then
        local ok, speed = pcall(UnitRangedDamage, "player")
        if ok and type(speed) == "number" and speed > 0 then
            return speed, "live ranged speed"
        end
    end
    return 2.8, "fallback ranged speed"
end

local function actionSpellName(slot)
    if not (CreateFrame and getglobal and GetActionTexture
        and GetActionText and IsEquippedAction) then return nil end
    local ok, texture = pcall(GetActionTexture, slot)
    if not ok or not texture then return nil end
    ok, texture = pcall(GetActionText, slot)
    if not ok or texture then return nil end
    ok, texture = pcall(IsEquippedAction, slot)
    if not ok or truthy(texture) then return nil end
    if not actionTip then
        actionTip = CreateFrame("GameTooltip", ACTION_TIP_NAME,
            nil, "GameTooltipTemplate")
        if not (actionTip and actionTip.SetAction and actionTip.ClearLines) then
            actionTip = false
        elseif actionTip.SetOwner then actionTip:SetOwner(UIParent, "ANCHOR_NONE") end
    end
    if not actionTip then return nil end
    actionTip:ClearLines()
    ok = pcall(actionTip.SetAction, actionTip, slot)
    if not ok then return nil end
    local line = getglobal(ACTION_TIP_NAME .. "TextLeft1")
    return line and line.GetText and line:GetText() or nil
end

function A:DiscoverSlots()
    if self.repeatSlots then return self.repeatSlots end
    local slots, expected, slot = {}, SpellInfo and SpellInfo(AUTO_SHOT_ID)
        or "Auto Shot", nil
    for slot = 1, ACTION_SLOTS do
        if actionSpellName(slot) == expected then table.insert(slots, slot) end
    end
    self.repeatSlots = slots
    return slots
end

function A:ActiveSlot()
    if not IsAutoRepeatAction then return nil, false end
    local slots, slot, queried = self:DiscoverSlots(), self.repeatSlot, true
    local i
    for i = 1, arrayCount(slots) do
        slot = slots[i]
        local ok, active = pcall(IsAutoRepeatAction, slot)
        if ok and truthy(active) then
            self.repeatSlot, self.repeatObserved = slot, true
            return slot, false
        end
        if not ok then queried = false end
    end
    if arrayCount(slots) > 0 and queried then return nil, true end
    return nil, false
end

function A:Ammo()
    if not GetAmmo then return nil, nil, false end
    local ok, itemId, total = pcall(GetAmmo)
    if not ok or type(total) ~= "number" then return nil, nil, false end
    return tonumber(itemId), math.max(0, total), true
end

local function fixedLaunchOutcome(targetGuid, spellId)
    local capabilities = XelAssist.Game and XelAssist.Game.Capabilities
    local raw
    if capabilities and capabilities.RangedDamage then
        local ok, value = pcall(capabilities.RangedDamage, capabilities)
        if ok then raw = tonumber(value) end
    end
    local power, delivery = raw, raw and 1 or nil
    local resolver = XelAssist.Graph and XelAssist.Graph.AutoShotEffects
    if resolver and resolver.CaptureLaunch then
        local ok, resolved, resolvedDelivery = pcall(
            resolver.CaptureLaunch, resolver, targetGuid, spellId, raw)
        if ok and tonumber(resolved) then power = tonumber(resolved) end
        if ok and tonumber(resolvedDelivery) then
            delivery = tonumber(resolvedDelivery)
        end
    end
    return power, delivery, raw
end

function A:RecordLaunch(targetGuid, spellId, launchedAt)
    targetGuid = targetGuid or unitGuid("target")
    if targetGuid == nil then return nil end
    launchedAt = tonumber(launchedAt) or now()
    local canonical = self:CanonicalSpellId(spellId)
    local flight = Range:LaunchTiming(targetGuid, canonical)
    local power, delivery, raw = fixedLaunchOutcome(targetGuid, canonical)
    return Flights:Record(self, targetGuid, canonical, launchedAt, flight,
        { power = power, delivery = delivery, rawPower = raw })
end

function A:InFlight(at)
    at = tonumber(at) or now()
    return Flights:Known(self, at)
end

function A:UnknownInFlight(at)
    at = tonumber(at) or now()
    return Flights:Unknown(self, at)
end

function A:BlockPhase()
    if self.assumedActive or self.lastLaunchAt then
        self.phaseBlocked = true
        self.resumeFloorUntil = nil
    end
end

function A:ResumePhase(forceFloor)
    if not self.phaseBlocked and not forceFloor then return end
    self.phaseBlocked = false
    self.resumeFloorUntil = now() + RESUME_FLOOR
end

function A:ObserveBlock(evidence, active)
    if not active then
        self.phaseBlocked, self.resumeFloorUntil = nil, nil
        return
    end
    if not evidence then return end
    if evidence.moving or evidence.casting or evidence.channeling then
        self:BlockPhase()
    else self:ResumePhase() end
end

function A:Snapshot(evidence)
    if not self:IsHunter() then return { supported = false, active = false } end
    local at = now()
    local currentTargetGuid = unitGuid("target")
    local evidenceSpellId = self.activeSpellId
        or evidence and evidence.rangeSpellId or self:EvidenceSpellId()
    evidence = Range:Evidence(evidence, currentTargetGuid, evidenceSpellId)
    local speed, speedSource = self:RangedSpeed()
    local activeSlot, repeatInactive = self:ActiveSlot()
    local submitPending = self.submittedAt
        and at - self.submittedAt <= START_GUARD
    if repeatInactive and not submitPending then
        self.assumedActive, self.knownInactive = false, true
        self.lastLaunchAt, self.lastLaunchTargetGuid = nil, nil
        self.activeTargetGuid = nil
    elseif activeSlot then
        self.assumedActive, self.knownInactive = true, false
        self.startConfirmed = true
        self.activeTargetGuid = currentTargetGuid
    elseif self.submittedAt and not submitPending and not self.lastLaunchAt then
        self.assumedActive, self.knownInactive = false, false
        self.submittedAt, self.submittedTargetGuid = nil, nil
    end
    local active = activeSlot ~= nil or self.assumedActive and true or false
    local uncertain = not active and not self.knownInactive
    self:ObserveBlock(evidence, active)
    local source, confidence = "proven inactive", "live"
    if activeSlot then source, confidence = "action bar repeat", "live"
    elseif submitPending then source, confidence = "start submitted", "pending"
    elseif self.lastLaunchAt then
        source, confidence = "exact launch event", "observed"
    elseif active then source, confidence = "assumed repeat", "uncertain"
    elseif uncertain then source, confidence = "repeat state unknown", "unknown" end
    local targetGuid = self.activeTargetGuid
        or self.lastLaunchTargetGuid or self.submittedTargetGuid
    local validTarget = Range:TargetEligible(
        evidence, currentTargetGuid, evidenceSpellId)
    local _, eligibilityReason = Range:StartEligible(
        evidence, currentTargetGuid, evidenceSpellId)
    local projectable = active and validTarget
        and Range:Projectable(evidence, currentTargetGuid, evidenceSpellId)
        and matchingTarget(targetGuid, currentTargetGuid)
    local nextLaunchIn
    if active then
        if self.lastLaunchAt then
            nextLaunchIn = math.max(0, self.lastLaunchAt + speed - at)
        else nextLaunchIn = RESUME_FLOOR end
        if not self.phaseBlocked and self.resumeFloorUntil then
            nextLaunchIn = math.max(nextLaunchIn,
                self.resumeFloorUntil - at)
        end
        if not self.phaseBlocked then nextLaunchIn = math.max(0.05, nextLaunchIn) end
    end
    local ammoId, ammoCount, ammoKnown = self:Ammo()
    local shotDamage
    if XelAssist.Game and XelAssist.Game.Capabilities
        and XelAssist.Game.Capabilities.RangedDamage then
        shotDamage = XelAssist.Game.Capabilities:RangedDamage()
    end
    return { supported = true,
        spellId = self:CanonicalSpellId(evidenceSpellId),
        active = active, activeSource = source, confidence = confidence,
        stateUncertain = uncertain, knownInactive = self.knownInactive,
        actionSlot = activeSlot, targetGuid = targetGuid,
        currentTargetGuid = currentTargetGuid,
        rangeChecked = evidence.rangeChecked,
        rangeVerdict = evidence.rangeVerdict,
        rangeIdentityVerified = evidence.rangeIdentityVerified,
        rangeTargetGuid = evidence.rangeTargetGuid,
        rangeSpellId = evidence.rangeSpellId,
        distance = evidence.distance, distanceKind = evidence.distanceKind,
        projectileDistance = evidence.projectileDistance,
        projectileDistanceKind = evidence.projectileDistanceKind,
        projectable = projectable, eligibilityReason = eligibilityReason,
        blocked = self.phaseBlocked and true or false,
        lastLaunchAt = self.lastLaunchAt,
        lastLaunchTargetGuid = self.lastLaunchTargetGuid,
        nextLaunchIn = nextLaunchIn,
        rangedSpeed = speed, rangedSpeedSource = speedSource,
        projectileSpeed = evidence.projectileSpeed,
        projectileSpeedSource = evidence.projectileSpeedSource,
        ammoId = ammoId, ammoCount = ammoCount, ammoKnown = ammoKnown,
        shotDamage = shotDamage, inFlight = self:InFlight(at),
        unknownInFlight = self:UnknownInFlight(at),
        launchTimingUnknown = self.launchTimingUnknown,
        flightOverflowGlobal = self.flightOverflowGlobal }
end

function A:CanStart(snapshot)
    snapshot = snapshot or self:Snapshot()
    if not snapshot.supported then return false, "not a Hunter" end
    if snapshot.active then return false, "Auto Shot already active" end
    if snapshot.stateUncertain then return false, "Auto Shot state uncertain" end
    if snapshot.currentTargetGuid == nil then return false, "target identity unavailable" end
    if snapshot.eligibilityReason then return false, snapshot.eligibilityReason end
    if snapshot.ammoKnown and (snapshot.ammoCount or 0) <= 0 then
        return false, "ammunition"
    end
    return true, nil
end

function A:Submitted(targetGuid, spellId)
    self.activeBeforeSubmit = self.assumedActive and true or false
    self.submittedAt = now()
    self.submittedTargetGuid = targetGuid or unitGuid("target")
    self.activeTargetGuid = self.submittedTargetGuid
    self.activeSpellId = self:CanonicalSpellId(spellId)
    self.lastLaunchAt, self.lastLaunchTargetGuid = nil, nil
    self.assumedActive, self.knownInactive = false, false
    self.startConfirmed = false
end

local function isAutoShot(spellId)
    if AUTO_SHOT_IDS[tonumber(spellId)] then return true end
    if not (spellId and SpellInfo) then return false end
    local ok, name = pcall(SpellInfo, spellId)
    return ok and name == "Auto Shot"
end

function A:UnitCast(casterGuid, targetGuid, castType, spellId)
    if not self:IsHunter() or casterGuid == nil
        or casterGuid ~= unitGuid("player") then return end
    if not isAutoShot(spellId) then
        if castType == "START" or castType == "CHANNEL" then self:BlockPhase()
        elseif castType == "CAST" then self:ResumePhase(true)
        elseif castType == "FAIL" then self:ResumePhase() end
        return
    end
    if castType == "CAST" then
        self.lastLaunchAt = now()
        self.lastLaunchTargetGuid = targetGuid
        self.activeTargetGuid = targetGuid
        self.activeSpellId = self:CanonicalSpellId(spellId)
        self.assumedActive, self.knownInactive = true, false
        self.startConfirmed = true
        self.phaseBlocked, self.resumeFloorUntil = false, nil
        self.submittedAt, self.submittedTargetGuid = nil, nil
        self:RecordLaunch(targetGuid, self.activeSpellId, self.lastLaunchAt)
    elseif castType == "FAIL" then self:Reset(true, true) end
end

function A:Reset(provenInactive, preserveInFlight)
    self.repeatSlot = nil
    self.repeatObserved = nil
    self.lastLaunchAt, self.lastLaunchTargetGuid = nil, nil
    self.submittedAt, self.submittedTargetGuid = nil, nil
    self.activeTargetGuid = nil
    self.activeSpellId = nil
    self.startConfirmed = nil
    self.assumedActive, self.activeBeforeSubmit = false, false
    self.phaseBlocked, self.resumeFloorUntil = nil, nil
    Flights:Reset(self, preserveInFlight)
    self.knownInactive = provenInactive and true or false
end

function A:OnEvent(name, a1, a2, a3, a4)
    if name == "UNIT_CASTEVENT" then self:UnitCast(a1, a2, a3, a4)
    elseif name == "START_AUTOREPEAT_SPELL" then
        local slot = self:ActiveSlot()
        local pending = self.submittedAt
            and now() - self.submittedAt <= START_GUARD
        if slot or pending then
            self.assumedActive, self.knownInactive = true, false
            self.startConfirmed = true
            self.submittedAt, self.submittedTargetGuid = nil, nil
            self.activeTargetGuid = unitGuid("target")
        end
    elseif name == "STOP_AUTOREPEAT_SPELL" then self:Reset(true, true)
    elseif name == "PLAYER_ENTERING_WORLD" then self:Reset(false)
    elseif name == "PLAYER_REGEN_ENABLED" then Flights:Prune(self, now())
    elseif name == "PLAYER_TARGET_CHANGED" then
        local guid = currentHostileGuid()
        if guid and (self.assumedActive or self.lastLaunchAt) then
            self.activeTargetGuid = guid
        end
    elseif name == "ACTIONBAR_SLOT_CHANGED" then
        self.repeatSlot, self.repeatSlots = nil, nil
    end
end

if A.knownInactive == nil then A.knownInactive = false end

if CreateFrame then
    local frame = CreateFrame("Frame")
    frame:RegisterEvent("PLAYER_ENTERING_WORLD")
    frame:RegisterEvent("PLAYER_REGEN_ENABLED")
    frame:RegisterEvent("PLAYER_TARGET_CHANGED")
    frame:RegisterEvent("START_AUTOREPEAT_SPELL")
    frame:RegisterEvent("STOP_AUTOREPEAT_SPELL")
    frame:RegisterEvent("ACTIONBAR_UPDATE_STATE")
    frame:RegisterEvent("ACTIONBAR_SLOT_CHANGED")
    if SpellInfo then frame:RegisterEvent("UNIT_CASTEVENT") end
    frame:SetScript("OnEvent", function()
        A:OnEvent(event, arg1, arg2, arg3, arg4)
    end)
    A.frame = frame
end
