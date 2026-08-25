-- Short release hysteresis for noisy movement and geometry edges. Blocking
-- evidence applies immediately; a recovered edge must remain positive briefly
-- before it can re-admit an action.
XelAssist.Game.SpatialEvidence = {}
local S = XelAssist.Game.SpatialEvidence

local SETTLE_SECONDS = 0.15

local function clock()
    return type(GetTime) == "function" and GetTime() or 0
end

local function blocked(record, rawBlocked, at)
    if rawBlocked == true then
        record.blocked, record.releaseAt = true, nil
        return true
    end
    if rawBlocked == nil then return record.blocked and true or nil end
    if record.blocked then
        record.releaseAt = record.releaseAt or at + SETTLE_SECONDS
        if at < record.releaseAt then return true end
    end
    record.blocked, record.releaseAt = false, nil
    return false
end

local function available(record, raw, at)
    local result = blocked(record,
        raw == nil and nil or raw == false, at)
    if result == nil then return nil end
    return not result
end

function S:Reset()
    self.targetGuid, self.lineOfSight, self.behind = nil, {}, {}
    self.movement, self.rangeTarget, self.ranges = {}, nil, {}
end

function S:Snapshot(targetGuid, moving, lineOfSight, behind)
    if self.targetGuid ~= targetGuid then
        self.targetGuid, self.lineOfSight, self.behind = targetGuid, {}, {}
    end
    local at = clock()
    return blocked(self.movement, moving == nil and nil or moving == true, at),
        available(self.lineOfSight, lineOfSight, at),
        available(self.behind, behind, at)
end

local function actionRecord(ranges, action)
    local name = action and action.name or ""
    local byRank = ranges[name]
    if not byRank then byRank = {}; ranges[name] = byRank end
    local rank = tonumber(action and action.rank) or 0
    if not byRank[rank] then byRank[rank] = {} end
    return byRank[rank]
end

function S:Range(action, targetGuid, verdict)
    if self.rangeTarget ~= targetGuid then
        self.rangeTarget, self.ranges = targetGuid, {}
    end
    return available(actionRecord(self.ranges, action), verdict, clock())
end

S:Reset()
