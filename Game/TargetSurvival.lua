-- Session-only hostile health trends. Opaque unit identities are table keys
-- only; no identity or name is persisted, printed, or copied into evidence.
XelAssist.Game.TargetSurvival = {
    MAX_TARGETS = 16, WINDOW = 8, MAX_GAP = 1.5,
    MIN_SPAN = 1, MIN_SAMPLES = 3, histories = {}, historyCount = 0,
}
local S = XelAssist.Game.TargetSurvival

local function unavailable(reason, samples, span, loss)
    return { available = false, reason = reason,
        samples = samples or 0, observedFor = span or 0,
        observedLoss = loss or 0,
        source = "exact hostile health trend" }
end

local function newHistory(maximum, now, health)
    return { maximum = maximum, lastSeen = now,
        samples = { { at = now, health = health } } }
end

local function removeHistory(owner, guid)
    if owner.histories[guid] then
        owner.histories[guid] = nil
        owner.historyCount = math.max(0, owner.historyCount - 1)
    end
end

local function evictOldest(owner, keep)
    if owner.historyCount < owner.MAX_TARGETS then return end
    local oldestKey, oldestAt, key, history = nil, nil, nil, nil
    for key, history in pairs(owner.histories) do
        if key ~= keep and (oldestAt == nil
            or (tonumber(history.lastSeen) or 0) < oldestAt) then
            oldestKey, oldestAt = key, tonumber(history.lastSeen) or 0
        end
    end
    if oldestKey ~= nil then removeHistory(owner, oldestKey) end
end

local function resetHistory(owner, guid, maximum, now, health)
    if not owner.histories[guid] then
        evictOldest(owner, guid)
        owner.historyCount = owner.historyCount + 1
    end
    local history = newHistory(maximum, now, health)
    owner.histories[guid] = history
    return history
end

local function prune(history, now, window)
    local cutoff = now - window
    while table.getn(history.samples) > 2
        and history.samples[2].at <= cutoff do
        table.remove(history.samples, 1)
    end
end

local function appendSample(history, now, health)
    local samples = history.samples
    local latest = samples[table.getn(samples)]
    if latest and now <= latest.at then
        latest.at, latest.health = now, health
        return
    end
    table.insert(samples, { at = now, health = health })
    if table.getn(samples) > 48 then table.remove(samples, 1) end
end

local function estimate(history, health)
    local samples = history.samples
    local count = table.getn(samples)
    local first, last = samples[1], samples[count]
    local span = first and last and math.max(0, last.at - first.at) or 0
    local loss = first and last and math.max(0, first.health - last.health) or 0
    local minimumLoss = math.max(1, (tonumber(history.maximum) or 0) * 0.02)
    if count < S.MIN_SAMPLES or span < S.MIN_SPAN then
        return unavailable("health trend still learning", count, span, loss)
    end
    if loss < minimumLoss then
        return unavailable("no sustained health loss observed", count, span, loss)
    end
    local rate = loss / span
    if rate <= 0 then
        return unavailable("health loss rate unavailable", count, span, loss)
    end
    local timeToDie = math.max(0, health) / rate
    local lossFraction = history.maximum > 0 and loss / history.maximum or 0
    local confidence = span >= 3 and count >= 6 and lossFraction >= 0.10
        and "observed" or "limited samples"
    local lowerFactor = confidence == "observed" and 0.75 or 0.50
    local upperFactor = confidence == "observed" and 1.35 or 1.75
    return { available = true, incomingDps = rate, timeToDie = timeToDie,
        lowerTimeToDie = timeToDie * lowerFactor,
        upperTimeToDie = timeToDie * upperFactor,
        confidence = confidence, samples = count, observedFor = span,
        observedLoss = loss, source = "exact hostile health trend" }
end

function S:Observe(guid, health, maximum, exact, now)
    now = tonumber(now) or (GetTime and GetTime()) or 0
    health, maximum = tonumber(health), tonumber(maximum)
    if guid == nil or exact ~= true or health == nil or maximum == nil
        or maximum <= 0 or health < 0 then
        if guid ~= nil then removeHistory(self, guid) end
        return unavailable("exact hostile health unavailable")
    end
    local history = self.histories[guid]
    if not history then
        resetHistory(self, guid, maximum, now, health)
        return unavailable("health trend still learning", 1, 0, 0)
    end
    local samples = history.samples
    local latest = samples[table.getn(samples)]
    local gap = latest and now - latest.at or 0
    local maximumChanged = math.abs((tonumber(history.maximum) or 0) - maximum) > 0.5
    local healReset = latest and health > latest.health
        and health - latest.health >= math.max(5, maximum * 0.08)
    if gap < 0 or gap > self.MAX_GAP or maximumChanged or healReset then
        resetHistory(self, guid, maximum, now, health)
        local reason = maximumChanged and "maximum health changed"
            or healReset and "large heal reset health trend"
            or "observation gap reset health trend"
        return unavailable(reason, 1, 0, 0)
    end
    history.lastSeen, history.maximum = now, maximum
    appendSample(history, now, health)
    prune(history, now, self.WINDOW)
    return estimate(history, health)
end

function S:Reset()
    self.histories, self.historyCount = {}, 0
end
