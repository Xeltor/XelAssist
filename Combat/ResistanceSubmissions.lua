-- Transient combat-event correlation for resistance observations.
--
-- SuperWoW identities are opaque values and may be tables. Keep them as
-- nested table keys; never serialize or concatenate them for correlation.
XelAssist.Combat.ResistanceSubmissions = {}
local S = XelAssist.Combat.ResistanceSubmissions

local PENDING_RETENTION = 30

local function now()
    return GetTime and GetTime() or 0
end

local function recentRetention(record)
    return math.max(4, math.min(60, (tonumber(record.duration) or 0) + 2))
end

function S:New(owner)
    local ledger = { owner = owner, keyIndex = {} }
    setmetatable(ledger, { __index = self })
    return ledger
end

-- Tests and runtime reset paths may replace the exposed tables. Resetting the
-- private index at that same boundary avoids retaining opaque identities from
-- a discarded combat session.
function S:Tables()
    local owner = self.owner
    if type(owner.submissions) ~= "table" then owner.submissions = {} end
    if type(owner.recentSubmissions) ~= "table" then owner.recentSubmissions = {} end
    if self.pending ~= owner.submissions or self.recent ~= owner.recentSubmissions then
        self.pending = owner.submissions
        self.recent = owner.recentSubmissions
        self.keyIndex = {}
    end
    return self.pending, self.recent
end

function S:Key(targetGuid, casterGuid, spellId, create)
    self:Tables()
    if targetGuid == nil or casterGuid == nil or spellId == nil then return nil end
    local byCaster = self.keyIndex[targetGuid]
    if not byCaster then
        if not create then return nil end
        byCaster = {}
        self.keyIndex[targetGuid] = byCaster
    end
    local bySpell = byCaster[casterGuid]
    if not bySpell then
        if not create then return nil end
        bySpell = {}
        byCaster[casterGuid] = bySpell
    end
    local key = bySpell[spellId]
    if not key and create then
        key = {}
        bySpell[spellId] = key
    end
    return key
end

function S:Release(targetGuid, casterGuid, spellId, key)
    local pending, recent = self:Tables()
    if not key or pending[key] or recent[key] then return end
    local byCaster = self.keyIndex[targetGuid]
    local bySpell = byCaster and byCaster[casterGuid]
    if not bySpell or bySpell[spellId] ~= key then return end
    bySpell[spellId] = nil
    if not next(bySpell) then byCaster[casterGuid] = nil end
    if not next(byCaster) then self.keyIndex[targetGuid] = nil end
end

function S:Sweep()
    local pending, recent = self:Tables()
    local at, expired, key, record = now(), {}, nil, nil
    for key, record in pairs(pending) do
        if at - (record.at or 0) > PENDING_RETENTION then
            table.insert(expired, { entries = pending, key = key, record = record })
        end
    end
    for key, record in pairs(recent) do
        if at - (record.consumedAt or record.at or 0) > recentRetention(record) then
            table.insert(expired, { entries = recent, key = key, record = record })
        end
    end
    local i
    for i = 1, table.getn(expired) do
        local entry = expired[i]
        entry.entries[entry.key] = nil
        self:Release(entry.record.targetGuid, entry.record.casterGuid,
            entry.record.spellId, entry.key)
    end
    return table.getn(expired)
end

function S:Put(targetGuid, casterGuid, spellId, record)
    local pending = self:Tables()
    local key = self:Key(targetGuid, casterGuid, spellId, true)
    if not key or type(record) ~= "table" then return nil end
    record.targetGuid, record.casterGuid, record.spellId = targetGuid, casterGuid, spellId
    pending[key] = record
    return record
end

function S:Get(targetGuid, casterGuid, spellId)
    self:Sweep()
    local pending = self:Tables()
    local key = self:Key(targetGuid, casterGuid, spellId)
    local record = key and pending[key]
    if record and now() - (record.at or 0) <= PENDING_RETENTION then return record end
    if key then
        pending[key] = nil
        self:Release(targetGuid, casterGuid, spellId, key)
    end
    return nil
end

function S:Take(targetGuid, casterGuid, spellId, force)
    local key = self:Key(targetGuid, casterGuid, spellId)
    local record = self:Get(targetGuid, casterGuid, spellId)
    if record and (force or now() >= (record.readyAt or record.at or 0)) then
        local pending, recent = self:Tables()
        pending[key] = nil
        record.consumedAt = now()
        recent[key] = record
        return record
    end
    return nil
end

function S:Recent(targetGuid, casterGuid, spellId)
    self:Sweep()
    local _, recent = self:Tables()
    local key = self:Key(targetGuid, casterGuid, spellId)
    local record = key and recent[key]
    if record and now() - (record.consumedAt or record.at or 0) <= recentRetention(record) then
        return record
    end
    if key then
        recent[key] = nil
        self:Release(targetGuid, casterGuid, spellId, key)
    end
    return nil
end

function S:ForgetRecent(targetGuid, casterGuid, spellId)
    local _, recent = self:Tables()
    local key = self:Key(targetGuid, casterGuid, spellId)
    if not key then return nil end
    local record = recent[key]
    recent[key] = nil
    self:Release(targetGuid, casterGuid, spellId, key)
    return record
end

function S:Cancel(spellId, casterGuid, targetGuid)
    local pending = self:Tables()
    local matches, key, record = {}, nil, nil
    for key, record in pairs(pending) do
        if (not spellId or tonumber(record.spellId) == tonumber(spellId))
            and (not casterGuid or record.casterGuid == casterGuid)
            and (not targetGuid or record.targetGuid == targetGuid) then
            table.insert(matches, { key = key, record = record })
        end
    end
    local i
    for i = 1, table.getn(matches) do
        local entry = matches[i]
        pending[entry.key] = nil
        self:Release(entry.record.targetGuid, entry.record.casterGuid,
            entry.record.spellId, entry.key)
    end
    return table.getn(matches)
end
