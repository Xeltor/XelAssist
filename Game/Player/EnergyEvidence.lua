-- Session-only player energy tick learning. Exact change events establish a
-- conservative amount/cadence envelope; spell energize events exclude active
-- gains. Graph arithmetic lives in Player/Resources.lua.
XelAssist.Game.Player = XelAssist.Game.Player or {}
XelAssist.Game.Player.EnergyEvidence = {}
local E = XelAssist.Game.Player.EnergyEvidence

local ENERGY = 3
local MIN_GAINS = 3
local ENERGIZE_WINDOW = 1
local SPEND_WINDOW = 0.35

local function numeric(value)
    value = tonumber(value)
    if not value or value ~= value then return nil end
    return value
end

local function now()
    if type(GetTime) ~= "function" then return nil end
    local ok, value = pcall(GetTime)
    return ok and numeric(value) or nil
end

local function tolerance(interval)
    return math.max(0.25, (numeric(interval) or 0) * 0.2)
end

function E:ClearCandidate(reason)
    self.candidateAmount, self.candidateInterval = nil, nil
    self.candidateLastAt, self.candidateSamples = nil, 0
    self.lastResetReason = reason
end

function E:ClearModel(reason)
    self:ClearCandidate(reason)
    self.verifiedAmount, self.verifiedInterval = nil, nil
    self.verifiedObservedInterval, self.verifiedSamples = nil, 0
    self.phaseAt, self.phaseSource = nil, nil
end

function E:ResetSession()
    self.guid, self.lastEnergy, self.lastMaximum = nil, nil, nil
    self.powerType = nil
    self.lastObservedAt, self.lastSpendAt = nil, nil
    self.energizeGuid, self.energizeAt = nil, nil
    self.externalEnergizeAvailable = false
    self:ClearModel("session reset")
end

function E:SetEnergizeEvidenceAvailable(available)
    available = available and true or false
    if self.externalEnergizeAvailable ~= available then
        self:ClearModel("energy attribution availability changed")
    end
    self.externalEnergizeAvailable = available
end

function E:ModifierChanged(reason)
    self:ClearModel(reason or "energy modifier changed")
    self.lastEnergy, self.lastMaximum, self.lastObservedAt = nil, nil, nil
    self.lastSpendAt = nil
end

function E:IdentityChanged(guid)
    self.guid, self.lastEnergy, self.lastMaximum = guid, nil, nil
    self.lastObservedAt, self.lastSpendAt = nil, nil
    self.energizeGuid, self.energizeAt = nil, nil
    self:ClearModel("player identity changed")
end

function E:ObserveEnergize(targetGuid, powerType, at)
    if tonumber(powerType) ~= ENERGY or targetGuid == nil
        or targetGuid ~= self.guid then return false end
    self.energizeGuid, self.energizeAt = targetGuid, numeric(at) or now()
    self:ClearModel("spell energize made energy gain ambiguous")
    return true
end

function E:RecentEnergize(guid, at)
    if guid == nil or guid ~= self.energizeGuid then return false end
    local age = numeric(at) and numeric(self.energizeAt)
        and at - self.energizeAt or nil
    return age == nil or age >= 0 and age <= ENERGIZE_WINDOW
end

local function seed(self, delta, at)
    self.candidateAmount, self.candidateLastAt = delta, at
    self.candidateInterval, self.candidateSamples = nil, 1
end

function E:Learn(delta, at)
    if not self.candidateAmount then seed(self, delta, at); return end
    if delta ~= self.candidateAmount then
        self:ClearModel("energy gain amount changed"); seed(self, delta, at); return
    end
    local gap = at - (self.candidateLastAt or at)
    if gap <= 0 or self.candidateInterval
        and math.abs(gap - self.candidateInterval)
            > tolerance(self.candidateInterval) then
        self:ClearModel("energy gain cadence changed"); seed(self, delta, at); return
    end
    self.candidateInterval = math.max(self.candidateInterval or 0, gap)
    self.candidateLastAt = at
    self.candidateSamples = (self.candidateSamples or 1) + 1
    if self.candidateSamples >= MIN_GAINS then
        self.verifiedAmount = self.candidateAmount
        self.verifiedObservedInterval = self.candidateInterval
        self.verifiedInterval = self.candidateInterval
            + tolerance(self.candidateInterval)
        self.verifiedSamples = self.candidateSamples
        self.phaseAt, self.phaseSource = at, "observed player energy tick"
    end
end

function E:Observe(guid, energy, maximum, at, exactEvent, powerType)
    energy, maximum, at = numeric(energy), numeric(maximum), numeric(at) or now()
    powerType = tonumber(powerType)
    if powerType ~= ENERGY then
        if self.powerType == ENERGY then
            self:ModifierChanged("player power type changed")
        end
        self.powerType = powerType
        return nil
    end
    if self.powerType and self.powerType ~= powerType then
        self:ModifierChanged("player power type changed")
    end
    self.powerType = powerType
    if guid == nil or not energy or not maximum or maximum <= 0 or not at then
        self:ModifierChanged("energy observation unavailable"); return nil
    end
    if guid ~= self.guid then self:IdentityChanged(guid) end
    if self.lastMaximum and maximum ~= self.lastMaximum then
        self:ModifierChanged("maximum energy changed")
    end
    local prior = self.lastEnergy
    self.lastEnergy, self.lastMaximum, self.lastObservedAt = energy, maximum, at
    if energy >= maximum then
        self:ClearCandidate("energy cap obscured passive gains")
        self.phaseAt, self.phaseSource = nil, "energy cap erased tick phase"
        return self:Snapshot(guid, energy, maximum, at)
    end
    if prior == nil then return self:Snapshot(guid, energy, maximum, at) end
    local delta = energy - prior
    if delta < 0 then
        self.lastSpendAt = at
        if self.verifiedAmount and not self.phaseAt then
            self.phaseAt, self.phaseSource = at,
                "lower bound after observed energy spend"
        end
    elseif delta > 0 then
        local recentSpend = self.lastSpendAt and at - self.lastSpendAt >= 0
            and at - self.lastSpendAt <= SPEND_WINDOW
        if not exactEvent or self:RecentEnergize(guid, at) or recentSpend then
            self:ClearModel("positive energy gain was not a clean passive tick")
        else self:Learn(delta, at) end
    end
    return self:Snapshot(guid, energy, maximum, at)
end

function E:Snapshot(guid, energy, maximum, at)
    at = numeric(at) or now()
    if not self.verifiedAmount or not self.verifiedInterval
        or guid == nil or guid ~= self.guid or not at
        or tonumber(maximum) ~= self.lastMaximum then return nil end
    local phaseKnown = self.externalEnergizeAvailable
        and self.phaseAt ~= nil and tonumber(energy) < tonumber(maximum)
    local nextIn
    if phaseKnown then
        local age = math.max(0, at - self.phaseAt)
        if age >= self.verifiedInterval then
            self.phaseAt, self.phaseSource = nil,
                "expected energy tick was not observed"
            phaseKnown = false
        else nextIn = self.verifiedInterval - age end
    end
    return { verified = true, resourceType = ENERGY,
        amount = self.verifiedAmount, interval = self.verifiedInterval,
        observedInterval = self.verifiedObservedInterval,
        samples = self.verifiedSamples, phaseKnown = phaseKnown,
        nextIn = nextIn, phaseSource = self.phaseSource,
        externalEnergizeExcluded = self.externalEnergizeAvailable and true or false,
        source = "live player energy tick envelope" }
end

E:ResetSession()
