-- Bounded character/session evidence for normal-cast pushback. Octo's exact
-- SPELL_DELAYED_SELF increment is learned without importing an upstream
-- formula; regime changes retire the evidence before it can cross characters,
-- talents, equipment, levels, or forms.
XelAssist.Game.Player = XelAssist.Game.Player or {}
XelAssist.Game.Player.PushbackEvidence = {}
local P = XelAssist.Game.Player.PushbackEvidence

P.MAX_SAMPLES = 8
P.MAX_DELAY_MS = 2000

local function playerGuid()
    if type(UnitExists) ~= "function" then return nil end
    local ok, exists, guid = pcall(UnitExists, "player")
    return ok and exists and guid or nil
end

local function copy(source)
    local out, key, value = {}, nil, nil
    for key, value in pairs(source or {}) do out[key] = value end
    return out
end

function P:Invalidate(reason)
    self.samples, self.totalDelay = {}, 0
    self.minimumDelay, self.maximumDelay = nil, nil
    self.generation = (self.generation or 0) + 1
    self.lastReason = reason or "pushback regime changed"
end

function P:Observe(casterGuid, delayMs)
    local guid = playerGuid()
    local delay = tonumber(delayMs)
    if not guid or casterGuid ~= guid or not delay or delay ~= delay
        or delay <= 0 or delay > self.MAX_DELAY_MS then return false end
    delay = delay / 1000
    table.insert(self.samples, delay)
    self.totalDelay = self.totalDelay + delay
    while table.getn(self.samples) > self.MAX_SAMPLES do
        self.totalDelay = self.totalDelay - table.remove(self.samples, 1)
    end
    self.minimumDelay = self.samples[1]
    self.maximumDelay = self.samples[1]
    local i
    for i = 2, table.getn(self.samples) do
        self.minimumDelay = math.min(self.minimumDelay, self.samples[i])
        self.maximumDelay = math.max(self.maximumDelay, self.samples[i])
    end
    self.lastReason = "observed exact Octo normal-cast delay"
    return true
end

function P:ObserveDelay(runtime, casterGuid, delayMs)
    local accepted = runtime and runtime:Delay(casterGuid, delayMs)
    if accepted then self:Observe(casterGuid, delayMs) end
    return accepted and true or false
end

function P:RegimeEvent(name, unit)
    if name == "SPELLS_CHANGED" or name == "CHARACTER_POINTS_CHANGED"
        or name == "PLAYER_LEVEL_UP"
        or name == "UNIT_INVENTORY_CHANGED" and unit == "player"
        or name == "UPDATE_SHAPESHIFT_FORM"
        or name == "UPDATE_SHAPESHIFT_FORMS" then
        self:Invalidate("player pushback regime changed")
        return true
    end
    return false
end

function P:Snapshot()
    local count = table.getn(self.samples)
    if count <= 0 then return nil end
    return copy({ available = true, estimated = true,
        meanDelay = self.totalDelay / count,
        minimumDelay = self.minimumDelay,
        maximumDelay = self.maximumDelay, samples = count,
        generation = self.generation or 0,
        source = "exact SPELL_DELAYED_SELF character/session samples" })
end

function P:Status()
    local out = self:Snapshot() or { available = false }
    out.lastReason = self.lastReason
    return out
end

P.generation = 0
P:Invalidate("initial state")
