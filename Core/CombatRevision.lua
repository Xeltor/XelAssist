-- Bounded combat-state revision tokens for frame-sliced graph evaluation.
-- This primitive records change only; consumers decide whether a hard change
-- cancels work and whether a soft-domain change needs live validation.
XelAssist.Core = XelAssist.Core or {}
XelAssist.Core.CombatRevision = {}
local R = XelAssist.Core.CombatRevision

R.MAX_COUNTER = 2147483647
R.DOMAINS = {
    "health",
    "resource",
    "readiness",
    "aura",
    "cast",
    "pet",
    "threat",
    "engaged",
    "inventory",
}

local knownDomains = {}
local domainIndex
for domainIndex = 1, table.getn(R.DOMAINS) do
    knownDomains[R.DOMAINS[domainIndex]] = true
end

local function bounded(value)
    value = tonumber(value)
    if value == nil or value < 0 then return 0 end
    value = math.floor(value)
    if value > R.MAX_COUNTER then return R.MAX_COUNTER end
    return value
end

local function advance(value)
    value = bounded(value)
    if value >= R.MAX_COUNTER then return 0 end
    return value + 1
end

local function copyCounters(source)
    local out, index, domain = {}, nil, nil
    source = type(source) == "table" and source or {}
    for index = 1, table.getn(R.DOMAINS) do
        domain = R.DOMAINS[index]
        out[domain] = bounded(source[domain])
    end
    return out
end

local function validCounter(value)
    return type(value) == "number" and value >= 0
        and value <= R.MAX_COUNTER and math.floor(value) == value
end

local function validHardToken(token)
    return type(token) == "table" and validCounter(token.hardEpoch)
end

local function validSoftToken(token)
    if type(token) ~= "table"
        or type(token.softCounters) ~= "table" then return false end
    local index, domain
    for index = 1, table.getn(R.DOMAINS) do
        domain = R.DOMAINS[index]
        if not validCounter(token.softCounters[domain]) then return false end
    end
    return true
end

function R:Reset()
    self.hardEpoch = 0
    self.softCounters = {}
    self.lastHardReason = nil
    self.lastSoftReasons = {}
    local index
    for index = 1, table.getn(self.DOMAINS) do
        self.softCounters[self.DOMAINS[index]] = 0
    end
    return true
end

function R:Snapshot()
    return {
        hardEpoch = bounded(self.hardEpoch),
        softCounters = copyCounters(self.softCounters),
    }
end

function R:Hard(reason)
    self.hardEpoch = advance(self.hardEpoch)
    self.lastHardReason = type(reason) == "string" and reason or nil
    return self.hardEpoch
end

function R:Touch(domain, reason)
    if type(domain) ~= "string" or not knownDomains[domain] then
        return nil, "unknown combat revision domain"
    end
    self.softCounters = type(self.softCounters) == "table"
        and self.softCounters or {}
    self.softCounters[domain] = advance(self.softCounters[domain])
    self.lastSoftReasons = type(self.lastSoftReasons) == "table"
        and self.lastSoftReasons or {}
    self.lastSoftReasons[domain] = type(reason) == "string" and reason or nil
    return self.softCounters[domain], nil
end

function R:HardChanged(token)
    if not validHardToken(token) then return true end
    return bounded(token.hardEpoch) ~= bounded(self.hardEpoch)
end

function R:ChangedDomains(token)
    local changed, index, domain = {}, nil, nil
    if not validSoftToken(token) then
        for index = 1, table.getn(self.DOMAINS) do
            changed[index] = self.DOMAINS[index]
        end
        return changed
    end
    local current = type(self.softCounters) == "table"
        and self.softCounters or {}
    for index = 1, table.getn(self.DOMAINS) do
        domain = self.DOMAINS[index]
        if bounded(token.softCounters[domain]) ~= bounded(current[domain]) then
            table.insert(changed, domain)
        end
    end
    return changed
end

function R:AnyChanged(token)
    if self:HardChanged(token) then return true end
    local changed = self:ChangedDomains(token)
    return table.getn(changed) > 0
end

R:Reset()
