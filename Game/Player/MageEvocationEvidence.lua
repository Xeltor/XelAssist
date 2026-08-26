-- Session-only, character-specific Evocation evidence. One uninterrupted,
-- uncapped channel teaches a conservative delivered-mana envelope. Any other
-- aura, equipment, talent, level, identity, or energize boundary retires it.
XelAssist.Game.Player = XelAssist.Game.Player or {}
XelAssist.Game.Player.MageEvocationEvidence = {}
local E = XelAssist.Game.Player.MageEvocationEvidence

E.SPELL_ID = 12051
E.MIN_SAMPLES = 3
E.MIN_COMPLETION = 7.5
E.MAX_INTERVAL = 3

local function finite(value)
    value = tonumber(value)
    return value and value == value and value > -1e308 and value < 1e308
        and value or nil
end

local function copy(source)
    local out, key, value = {}, nil, nil
    for key, value in pairs(source or {}) do out[key] = value end
    return out
end

function E:ClearActive(reason)
    self.active, self.startedAt = false, nil
    self.lastMana, self.lastGainAt = nil, nil
    self.minimumGain, self.maximumInterval = nil, nil
    self.samples, self.contaminated = 0, false
    self.activeReason = reason
end

function E:Invalidate(reason)
    self.profile = nil
    self.generation = (self.generation or 0) + 1
    self.lastReason = reason
    self:ClearActive(reason)
end

function E:Start(mana, maximum, at)
    mana, maximum, at = finite(mana), finite(maximum), finite(at)
    if not mana or not maximum or maximum <= 0 or not at then
        self:Invalidate("Evocation start state unavailable")
        return false
    end
    self.profile = nil
    self.active, self.startedAt = true, at
    self.lastMana, self.maximum = mana, maximum
    self.lastGainAt, self.minimumGain, self.maximumInterval = nil, nil, nil
    self.samples, self.contaminated = 0, false
    return true
end

function E:Contaminate(reason)
    if self.active then
        self.contaminated = true
        self.activeReason = reason
    else self:Invalidate(reason) end
end

function E:Observe(mana, maximum, at)
    if not self.active then return false end
    mana, maximum, at = finite(mana), finite(maximum), finite(at)
    if not mana or not maximum or maximum ~= self.maximum or not at
        or at < self.startedAt then
        self:Contaminate("Evocation mana observation changed regime")
        return false
    end
    local prior = self.lastMana
    self.lastMana = mana
    if not prior or mana == prior then return false end
    local delta = mana - prior
    if delta <= 0 or mana >= maximum then
        self:Contaminate(delta <= 0 and "Evocation had a negative mana edge"
            or "Evocation reached the obscuring mana cap")
        return false
    end
    if self.lastGainAt then
        local interval = at - self.lastGainAt
        if interval <= 0 or interval > self.MAX_INTERVAL then
            self:Contaminate("Evocation tick cadence was not bounded")
            return false
        end
        self.maximumInterval = math.max(self.maximumInterval or 0, interval)
    end
    self.lastGainAt = at
    self.minimumGain = math.min(self.minimumGain or delta, delta)
    self.samples = self.samples + 1
    return true
end

function E:Finish(at)
    at = finite(at)
    local elapsed = at and self.startedAt and at - self.startedAt or nil
    local valid = self.active and not self.contaminated and elapsed
        and elapsed >= self.MIN_COMPLETION and self.samples >= self.MIN_SAMPLES
        and self.minimumGain and self.minimumGain > 0
        and self.maximumInterval and self.maximumInterval > 0
    if valid then
        local ticks = math.floor((elapsed - 0.001) / self.maximumInterval)
        if ticks >= 1 then
            self.profile = { exact = true, spellId = self.SPELL_ID,
                minimumGain = self.minimumGain,
                maximumInterval = self.maximumInterval,
                minimumTicks = ticks, resourceGain = ticks * self.minimumGain,
                observedDuration = elapsed, samples = self.samples,
                generation = self.generation or 0,
                source = "completed Octo Evocation mana-event envelope" }
        end
    end
    if not self.profile then
        self.lastReason = self.activeReason
            or "Evocation channel did not produce complete evidence"
    end
    self:ClearActive(self.profile and "Evocation profile learned"
        or self.lastReason)
    return self.profile ~= nil
end

function E:AuraChanged(active, mana, maximum, at)
    if active == nil then
        self:Invalidate("Evocation aura identity unavailable")
        return false
    end
    if active and not self.active then return self:Start(mana, maximum, at) end
    if active and self.active then
        self:Contaminate("another player aura changed during Evocation")
        return false
    end
    if not active and self.active then return self:Finish(at) end
    if self.profile then self:Invalidate("player aura regime changed") end
    return false
end

function E:Snapshot()
    return self.profile and copy(self.profile) or nil
end

function E:Status()
    local out = self:Snapshot() or {}
    out.active, out.activeSamples = self.active and true or false,
        self.samples or 0
    out.lastReason = self.lastReason or self.activeReason
    return out
end

E.generation = 0
E:ClearActive("initial state")
