-- Session-only Hunter focus learning. It observes exact focus changes but does
-- not project them; Game/Pets/Resources.lua owns graph-clock arithmetic.
XelAssist.Game.Pets = XelAssist.Game.Pets or {}
XelAssist.Game.Pets.FocusEvidence = {}
local E = XelAssist.Game.Pets.FocusEvidence

local FOCUS_POWER_TYPE = 2
local MIN_CLEAN_GAINS = 3
local ENERGIZE_EXCLUSION_SECONDS = 1
local SPEND_EXCLUSION_SECONDS = 0.35

local function numeric(value)
    value = tonumber(value)
    if not value or value ~= value then return nil end
    return value
end

local function clockNow()
    if type(GetTime) ~= "function" then return nil end
    local ok, value = pcall(GetTime)
    if ok then return numeric(value) end
    return nil
end

local function sameIdentity(left, right)
    return left ~= nil and right ~= nil and left == right
end

local function cadenceTolerance(interval)
    return math.max(0.25, (numeric(interval) or 0) * 0.2)
end

local function projectionInterval(interval)
    interval = numeric(interval)
    if not interval then return nil end
    return interval + cadenceTolerance(interval)
end

function E:ClearCandidate(reason)
    self.candidateAmount = nil
    self.candidateInterval = nil
    self.candidateLastGainAt = nil
    self.candidateSamples = 0
    self.lastResetReason = reason
end

function E:ClearModel(reason)
    self:ClearCandidate(reason)
    self.verifiedAmount = nil
    self.verifiedObservedInterval = nil
    self.verifiedInterval = nil
    self.verifiedSamples = 0
    self.phaseAt = nil
    self.phaseSource = nil
end

function E:ClearPhase(reason)
    self.phaseAt = nil
    self.phaseSource = reason
end

function E:AmbiguousGain(reason)
    self:ClearCandidate(reason)
    self:ClearPhase(reason)
end

function E:ResetSession()
    self.guid = nil
    self.lastFocus = nil
    self.lastFocusMax = nil
    self.lastObservedAt = nil
    self.lastSpendAt = nil
    self.energizeGuid = nil
    self.energizeAt = nil
    self.externalEnergizeAvailable = false
    self:ClearModel("session reset")
end

function E:SetEnergizeEvidenceAvailable(available)
    available = available and true or false
    if self.externalEnergizeAvailable ~= available then
        self:ClearModel("focus energize evidence availability changed")
    end
    self.externalEnergizeAvailable = available
end

function E:IdentityChanged(_, newGuid)
    self.guid = newGuid
    self.lastFocus = nil
    self.lastFocusMax = nil
    self.lastObservedAt = nil
    self.lastSpendAt = nil
    self.energizeGuid = nil
    self.energizeAt = nil
    self:ClearModel("pet identity changed")
end

function E:ModifierChanged(reason)
    self:ClearModel(reason or "focus modifier changed")
    self.lastFocus = nil
    self.lastFocusMax = nil
    self.lastObservedAt = nil
    self.lastSpendAt = nil
end

function E:ObserveEnergize(targetGuid, powerType, at)
    if tonumber(powerType) ~= FOCUS_POWER_TYPE
        or not sameIdentity(targetGuid, self.guid) then return false end
    self.energizeGuid = targetGuid
    self.energizeAt = numeric(at) or clockNow()
    -- Delivery may precede or follow UNIT_FOCUS. Full invalidation prevents a
    -- late event from blessing its own gain as passive-regeneration evidence.
    self:ClearModel("spell energize made focus gain ambiguous")
    return true
end

function E:RecentEnergize(guid, at)
    if not sameIdentity(guid, self.energizeGuid) then return false end
    local eventAt, observedAt = numeric(self.energizeAt), numeric(at)
    if not (eventAt and observedAt) then return true end
    local age = observedAt - eventAt
    return age >= 0 and age <= ENERGIZE_EXCLUSION_SECONDS
end

function E:SeedCandidate(delta, at)
    self.candidateAmount = delta
    self.candidateInterval = nil
    self.candidateLastGainAt = at
    self.candidateSamples = 1
end

function E:LearnGain(delta, at)
    if not self.candidateAmount then
        if self.verifiedAmount and delta ~= self.verifiedAmount then
            self:ClearModel("focus gain amount changed")
        end
        self:SeedCandidate(delta, at)
        if self.verifiedAmount == delta then
            self.phaseAt = at
            self.phaseSource = "observed focus tick"
        end
        return
    end
    if delta ~= self.candidateAmount then
        self:ClearModel("focus gain amount changed")
        self:SeedCandidate(delta, at)
        return
    end
    local gap = at - (self.candidateLastGainAt or at)
    if gap <= 0 then
        self:ClearModel("focus gain ordering ambiguous")
        self:SeedCandidate(delta, at)
        return
    end
    if self.candidateInterval and math.abs(gap - self.candidateInterval)
        > cadenceTolerance(self.candidateInterval) then
        self:ClearModel("focus gain cadence changed")
        self:SeedCandidate(delta, at)
        return
    end
    self.candidateInterval = math.max(self.candidateInterval or 0, gap)
    self.candidateLastGainAt = at
    self.candidateSamples = (self.candidateSamples or 1) + 1
    if self.candidateSamples >= MIN_CLEAN_GAINS then
        self.verifiedAmount = self.candidateAmount
        self.verifiedObservedInterval = self.candidateInterval
        self.verifiedInterval = projectionInterval(self.candidateInterval)
        self.verifiedSamples = self.candidateSamples
        self.phaseAt = at
        self.phaseSource = "observed focus tick"
    end
end

function E:Observe(guid, focus, focusMax, at, isFocusEvent, ownerClass)
    focus, focusMax, at = numeric(focus), numeric(focusMax),
        numeric(at) or clockNow()
    if ownerClass ~= "HUNTER" then
        self:IdentityChanged(self.guid, nil)
        return nil
    end
    if guid == nil or not focus or not focusMax or focusMax <= 0 or not at then
        self:ClearModel("focus observation unavailable")
        self.lastFocus, self.lastFocusMax, self.lastObservedAt = nil, nil, nil
        self.lastSpendAt = nil
        return nil
    end
    if not sameIdentity(guid, self.guid) then self:IdentityChanged(self.guid, guid) end
    if self.lastFocusMax and focusMax ~= self.lastFocusMax then
        self:ClearModel("maximum focus changed")
        self.lastFocus = nil
    end
    local prior = self.lastFocus
    self.lastFocus, self.lastFocusMax, self.lastObservedAt = focus, focusMax, at
    if focus >= focusMax then
        self:ClearCandidate("focus cap obscured passive gains")
        self:ClearPhase("focus cap erased tick phase")
        return self:Snapshot(guid, focus, focusMax, at)
    end
    if prior == nil then return self:Snapshot(guid, focus, focusMax, at) end
    local delta = focus - prior
    if delta < 0 then
        self.lastSpendAt = at
        if self.verifiedAmount and not self.phaseAt then
            self.phaseAt = at
            self.phaseSource = "lower bound after observed spend"
        end
        return self:Snapshot(guid, focus, focusMax, at)
    end
    if delta <= 0 then return self:Snapshot(guid, focus, focusMax, at) end
    local recentSpend = self.lastSpendAt
        and at - self.lastSpendAt >= 0
        and at - self.lastSpendAt <= SPEND_EXCLUSION_SECONDS
    if not isFocusEvent or self:RecentEnergize(guid, at) or recentSpend
        or prior >= focusMax or focus >= focusMax then
        self:AmbiguousGain("positive focus gain was not an uncapped passive tick")
        return nil
    end
    self:LearnGain(delta, at)
    return self:Snapshot(guid, focus, focusMax, at)
end

function E:Snapshot(guid, focus, focusMax, at)
    focus, focusMax, at = numeric(focus), numeric(focusMax),
        numeric(at) or clockNow()
    if not self.verifiedAmount or not self.verifiedInterval
        or not sameIdentity(guid, self.guid) or not focus or not focusMax
        or not at or focusMax ~= self.lastFocusMax then return nil end
    local phaseKnown = self.externalEnergizeAvailable
        and self.phaseAt ~= nil and focus < focusMax
    local nextIn
    if phaseKnown then
        local age = math.max(0, at - self.phaseAt)
        if age >= self.verifiedInterval then
            self:ClearPhase("expected focus tick was not observed")
            phaseKnown = false
        else nextIn = math.max(0, self.verifiedInterval - age) end
    end
    return { verified = true, resourceType = FOCUS_POWER_TYPE,
        amount = self.verifiedAmount, interval = self.verifiedInterval,
        observedInterval = self.verifiedObservedInterval, nextIn = nextIn,
        phaseKnown = phaseKnown, phaseSource = self.phaseSource,
        samples = self.verifiedSamples,
        source = "live UNIT_FOCUS conservative envelope", sourceGuid = guid,
        externalEnergizeExcluded = self.externalEnergizeAvailable and true or false }
end

function E:Status()
    if not self.guid then return nil end
    local snapshot = self:Snapshot(self.guid, self.lastFocus,
        self.lastFocusMax, clockNow() or self.lastObservedAt)
    local executable = snapshot and snapshot.phaseKnown and true or false
    return { verified = self.verifiedAmount ~= nil,
        executable = executable,
        amount = self.verifiedAmount, interval = self.verifiedInterval,
        observedInterval = self.verifiedObservedInterval,
        samples = self.verifiedSamples or self.candidateSamples or 0,
        phaseKnown = executable,
        energizeAttribution = self.externalEnergizeAvailable and true or false,
        lastResetReason = self.lastResetReason }
end

E:ResetSession()
