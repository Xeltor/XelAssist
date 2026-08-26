-- Session-only player mana-regeneration evidence. Exact mana-change events
-- learn a conservative passive envelope and an observed post-spend delay;
-- no client-era cadence, suppression duration, or regeneration formula is
-- assumed. Graph arithmetic consumes only the copied Snapshot contract.
XelAssist.Game.Player = XelAssist.Game.Player or {}
XelAssist.Game.Player.ManaEvidence = {}
local M = XelAssist.Game.Player.ManaEvidence

local MANA = 0
-- These are evidence thresholds, not game-mechanic constants.
local MIN_PASSIVE_GAINS = 3
local MIN_POST_SPENDS = 2
-- Nampower cast and unit-change callbacks share one client event path. This is
-- only an attribution timeout; it is not a mana tick or suppression constant.
local SPEND_ATTRIBUTION_WINDOW = 0.5

local function numeric(value)
    value = tonumber(value)
    if not value or value ~= value then return nil end
    return value
end

function M:ClearCandidate(reason)
    self.candidateAmount = nil
    self.candidateIntervalMin, self.candidateIntervalMax = nil, nil
    self.candidateLastAt, self.candidateSamples = nil, 0
    self.currentVerified = false
    self.phaseAt, self.phaseSource = nil, nil
    self.lastResetReason = reason
end

function M:ClearModel(reason)
    self:ClearCandidate(reason)
    self.verifiedAmount, self.verifiedInterval = nil, nil
    self.verifiedIntervalMin, self.verifiedSamples = nil, 0
    self.postSpendDelay, self.postSpendSamples = nil, 0
    self.postSpendVerified, self.postSpendStage = false, nil
    self.postSpendSpellId = nil
    self.lastSpendAt, self.lastSpendStage = nil, nil
    self.lastSpendSpellId, self.awaitingPostSpend = nil, false
end

function M:ClearPostSpend(reason)
    self.postSpendDelay, self.postSpendSamples = nil, 0
    self.postSpendVerified, self.postSpendStage = false, nil
    self.postSpendSpellId = nil
    self.lastSpendAt, self.lastSpendStage = nil, nil
    self.lastSpendSpellId, self.awaitingPostSpend = nil, false
    self.lastResetReason = reason or self.lastResetReason
end

function M:ResetSession()
    self.guid, self.powerType = nil, nil
    self.lastMana, self.lastMaximum, self.lastObservedAt = nil, nil, nil
    self.pendingSpendAt, self.pendingSpendStage = nil, nil
    self.pendingSpendSpellId = nil
    self.quarantinePositive = false
    self:ClearModel("session reset")
end

function M:SetEnergizeEvidenceAvailable(available)
    available = available and true or false
    if self.externalEnergizeAvailable ~= available then
        self:ClearModel("mana energize attribution availability changed")
        self.lastMana, self.lastMaximum, self.lastObservedAt = nil, nil, nil
        self.pendingSpendAt, self.pendingSpendStage = nil, nil
        self.pendingSpendSpellId = nil
        self.quarantinePositive = false
    end
    self.externalEnergizeAvailable = available
end

function M:ModifierChanged(reason)
    self:ClearModel(reason or "mana modifier changed")
    self.lastMana, self.lastMaximum, self.lastObservedAt = nil, nil, nil
    self.pendingSpendAt, self.pendingSpendStage = nil, nil
    self.pendingSpendSpellId = nil
    self.quarantinePositive = false
end

function M:IdentityChanged(guid)
    self.guid, self.powerType = guid, MANA
    self.lastMana, self.lastMaximum, self.lastObservedAt = nil, nil, nil
    self.pendingSpendAt, self.pendingSpendStage = nil, nil
    self.pendingSpendSpellId = nil
    self.quarantinePositive = false
    self:ClearModel("player identity changed")
end

-- The event bridge must call this only for an exact, owned, mana-funded cast
-- boundary. Spell identity keeps custom exemptions and ranks from sharing an
-- unproven suppression contract. Keeping attribution outside UNIT_MANA also
-- prevents hostile drains from teaching the graph a false casting rule.
function M:ObserveSpendBoundary(spellId, stage, at)
    spellId, at = numeric(spellId), numeric(at)
    if not spellId or spellId <= 0 or math.floor(spellId) ~= spellId
        or (stage ~= "start" and stage ~= "go") or not at then return false end
    self.pendingSpendStage, self.pendingSpendAt = stage, at
    self.pendingSpendSpellId = spellId
    return true
end

function M:ClearSpendBoundary()
    -- The bridge must call this for cast failure, interruption, cancellation,
    -- or any owned cast lifecycle that ends without an exact negative delta.
    self.pendingSpendStage, self.pendingSpendAt = nil, nil
    self.pendingSpendSpellId = nil
end

-- A matching server energize can arrive before or after the mana-change event.
-- Retire the current phase and candidate in both orders, then quarantine the
-- next positive delta. Historical lower-bound magnitudes remain conservative,
-- but cannot become a live clock until clean evidence is rebuilt.
function M:ObserveEnergize(targetGuid, powerType, at)
    at = numeric(at)
    if tonumber(powerType) ~= MANA or targetGuid == nil
        or targetGuid ~= self.guid or not at then return false end
    self.quarantinePositive = true
    self:ClearSpendBoundary()
    -- When combat-log attribution follows UNIT_MANA, that delta may already
    -- have taught a false spend-to-gain delay. Retire the complete regime.
    self:ClearPostSpend("spell energize invalidated post-spend evidence")
    self:ClearCandidate("spell energize quarantined mana gain")
    return true
end

local function learnPostSpend(self, at)
    local delay = self.lastSpendAt and at - self.lastSpendAt or nil
    self.awaitingPostSpend = false
    if not delay or delay <= 0 then return end
    if self.postSpendStage and (self.postSpendStage ~= self.lastSpendStage
        or self.postSpendSpellId ~= self.lastSpendSpellId) then
        self.postSpendDelay, self.postSpendSamples = nil, 0
        self.postSpendVerified = false
    end
    self.postSpendStage = self.lastSpendStage
    self.postSpendSpellId = self.lastSpendSpellId
    self.postSpendDelay = math.max(self.postSpendDelay or 0, delay)
    self.postSpendSamples = (self.postSpendSamples or 0) + 1
    self.postSpendVerified = self.postSpendSamples >= MIN_POST_SPENDS
end

-- Mixed passive regimes are represented by their observed lower-bound gain and
-- upper-bound cadence. This safely folds stable MP5, Spirit, talents, auras, and
-- server customs into one envelope without deriving any of them from constants.
local function learnPassive(self, delta, at)
    if not self.candidateAmount then
        self.candidateAmount, self.candidateLastAt = delta, at
        self.candidateSamples = 1
    else
        local gap = at - self.candidateLastAt
        if gap <= 0 then
            self:ClearCandidate("mana gain order was not monotonic")
            return false
        end
        self.candidateAmount = math.min(self.candidateAmount, delta)
        self.candidateIntervalMin = math.min(
            self.candidateIntervalMin or gap, gap)
        self.candidateIntervalMax = math.max(
            self.candidateIntervalMax or gap, gap)
        self.candidateLastAt = at
        self.candidateSamples = self.candidateSamples + 1
    end
    self.phaseAt, self.phaseSource = at, "observed clean player mana gain"
    self.verifiedSamples = (self.verifiedSamples or 0) + 1
    if self.candidateSamples >= MIN_PASSIVE_GAINS
        and self.candidateIntervalMax and self.candidateIntervalMax > 0 then
        self.verifiedAmount = math.min(
            self.verifiedAmount or self.candidateAmount, self.candidateAmount)
        self.verifiedInterval = math.max(
            self.verifiedInterval or 0, self.candidateIntervalMax)
        self.verifiedIntervalMin = math.min(
            self.verifiedIntervalMin or self.candidateIntervalMin,
            self.candidateIntervalMin)
        self.currentVerified = true
    end
    return true
end

function M:Observe(guid, mana, maximum, at, exactEvent, powerType)
    mana, maximum, at = numeric(mana), numeric(maximum), numeric(at)
    powerType = tonumber(powerType)
    if powerType ~= MANA then
        if self.powerType == MANA then
            self:ModifierChanged("player power type changed")
        end
        self.powerType = powerType
        return nil
    end
    if guid == nil or not mana or not maximum or maximum <= 0 or not at then
        self:ModifierChanged("mana observation unavailable")
        return nil
    end
    if guid ~= self.guid then self:IdentityChanged(guid) end
    if exactEvent ~= true then
        self:ModifierChanged("mana change event was not exact")
        self.guid, self.powerType = guid, MANA
        return nil
    end
    if self.lastObservedAt and at < self.lastObservedAt then
        self:ModifierChanged("mana observation time moved backwards")
        self.guid, self.powerType = guid, MANA
    end
    if self.lastMaximum and maximum ~= self.lastMaximum then
        self:ModifierChanged("maximum mana changed")
        self.guid, self.powerType = guid, MANA
    end
    local prior = self.lastMana
    self.lastMana, self.lastMaximum, self.lastObservedAt = mana, maximum, at
    if mana >= maximum then
        self:ClearCandidate("mana cap obscured passive gains")
        self:ClearSpendBoundary()
        self.awaitingPostSpend = false
        self.phaseSource = "mana cap erased tick phase"
        return self:Snapshot(guid, mana, maximum, at)
    end
    if prior == nil then return self:Snapshot(guid, mana, maximum, at) end
    local delta = mana - prior
    if delta < 0 then
        local boundaryAge = self.pendingSpendAt and at - self.pendingSpendAt
            or nil
        local attributed = boundaryAge and boundaryAge >= 0
            and boundaryAge <= SPEND_ATTRIBUTION_WINDOW
        self.lastSpendAt = attributed and self.pendingSpendAt or nil
        self.lastSpendStage = attributed and self.pendingSpendStage or nil
        self.lastSpendSpellId = attributed and self.pendingSpendSpellId or nil
        self.awaitingPostSpend = attributed and true or false
        self:ClearSpendBoundary()
        self:ClearCandidate(attributed
            and "attributed mana spend started a new regime"
            or "unattributed mana loss retired the live phase")
    elseif delta > 0 then
        -- A positive net change cannot prove that an armed cost was paid. A
        -- later go/start event can arm the actual boundary again if needed.
        self:ClearSpendBoundary()
        if not self.externalEnergizeAvailable then
            self:ClearCandidate("mana energize attribution unavailable")
            self.awaitingPostSpend = false
        elseif self.quarantinePositive then
            self.quarantinePositive = false
            self.awaitingPostSpend = false
            self:ClearCandidate("quarantined ambiguous positive mana delta")
        else
            if self.awaitingPostSpend then learnPostSpend(self, at) end
            learnPassive(self, delta, at)
        end
    else
        -- A boundary is valid only for the immediately correlated exact power
        -- observation. Cast failures/stops should also call ClearSpendBoundary.
        self:ClearSpendBoundary()
    end
    return self:Snapshot(guid, mana, maximum, at)
end

-- Snapshot is allocation-only and reads no live API. Callers receive no opaque
-- identity and no mutable reference to the session learner.
function M:Snapshot(guid, mana, maximum, at)
    mana, maximum, at = numeric(mana), numeric(maximum), numeric(at)
    if not self.verifiedAmount or not self.verifiedInterval
        or guid == nil or guid ~= self.guid or not mana or not maximum
        or mana ~= self.lastMana or maximum ~= self.lastMaximum or not at
        or self.powerType ~= MANA then return nil end
    local attributed = self.externalEnergizeAvailable
        and not self.quarantinePositive
    local phaseKnown = attributed and self.currentVerified
        and self.phaseAt ~= nil and mana < maximum and at >= self.phaseAt
    local nextIn
    if phaseKnown then
        local age = at - self.phaseAt
        if age >= self.verifiedInterval then phaseKnown = false
        else nextIn = self.verifiedInterval - age end
    end
    local out = { verified = true, resourceType = MANA,
        amount = self.verifiedAmount, interval = self.verifiedInterval,
        observedIntervalMin = self.verifiedIntervalMin,
        samples = self.verifiedSamples, phaseKnown = phaseKnown and true or false,
        nextIn = nextIn, phaseSource = self.phaseSource,
        externalEnergizeExcluded = attributed and true or false,
        postSpendKnown = self.postSpendVerified and true or false,
        postSpendDelay = self.postSpendVerified and self.postSpendDelay or nil,
        postSpendSamples = self.postSpendSamples,
        source = "session-learned exact player mana delta envelope" }
    if self.postSpendVerified then
        out.postSpend = { verified = true, delay = self.postSpendDelay,
            amount = self.verifiedAmount, interval = self.verifiedInterval,
            samples = self.postSpendSamples, boundary = self.postSpendStage,
            spellId = self.postSpendSpellId,
            source = "observed spend-to-passive-mana envelope" }
    end
    return out
end

function M:Status(at)
    if not self.guid then return nil end
    local snapshot = self:Snapshot(self.guid, self.lastMana,
        self.lastMaximum, numeric(at) or self.lastObservedAt)
    return { verified = self.verifiedAmount ~= nil,
        executable = snapshot and snapshot.phaseKnown and true or false,
        amount = self.verifiedAmount, interval = self.verifiedInterval,
        observedInterval = self.verifiedIntervalMin,
        samples = self.verifiedSamples or self.candidateSamples or 0,
        phaseKnown = snapshot and snapshot.phaseKnown and true or false,
        energizeAttribution = self.externalEnergizeAvailable and true or false,
        postSpendKnown = self.postSpendVerified and true or false,
        postSpendDelay = self.postSpendDelay,
        postSpendBoundary = self.postSpendStage,
        postSpendSpellId = self.postSpendSpellId,
        lastResetReason = self.lastResetReason }
end

M.externalEnergizeAvailable = false
M:ResetSession()
