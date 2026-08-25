-- Bridges exact normal-queue ownership into graph reservation lifecycle state.
XelAssist.Core.PlayerQueueEvents = {}
local E = XelAssist.Core.PlayerQueueEvents
local PlayerNormalQueue = XelAssist.Core.PlayerNormalQueue

local function markDropped(lifecycle, at)
    if not lifecycle then return end
    lifecycle.state, lifecycle.droppedAt, lifecycle.failureAt,
        lifecycle.lastAt = "dropped", at, at, at
end

function E:Allows(spellId, matched)
    if matched then return true end
    local current = PlayerNormalQueue:Current()
    return not current or tonumber(current.spellId) ~= tonumber(spellId)
end

function E:Handle(owner, queueCode, spellId)
    queueCode = tonumber(queueCode)
    local record, disposition = PlayerNormalQueue:QueueEvent(queueCode, spellId)
    local playerGuid = owner:PlayerGUID()
    if queueCode == 0 or queueCode == 2 or queueCode == 4 then
        owner:TouchPendingSpell(spellId, "queued", 2, playerGuid)
    elseif queueCode == 3 and disposition == "prior-generation-pop" then
        owner:TouchPendingSpell(spellId, "queued", 2, playerGuid,
            record and record.targetGuid)
    elseif queueCode == 3 and record and record.owner == "xelassist"
        and record.phase == "dropped" then
        local droppedSpell = record.spellId or spellId
        owner:ClearPendingBySpell(droppedSpell, playerGuid, record.targetGuid)
        local at = GetTime()
        markDropped(owner:Lifecycle(droppedSpell, playerGuid,
            record.targetGuid, false), at)
        if record.targetGuid ~= nil then
            markDropped(owner:Lifecycle(
                droppedSpell, playerGuid, nil, false), at)
        end
    elseif queueCode == 3 then
        local lifecycle = owner:Lifecycle(spellId, playerGuid, nil)
        if lifecycle then
            lifecycle.state, lifecycle.poppedAt, lifecycle.lastAt =
                "popped", GetTime(), GetTime()
        end
    end
    return record, disposition
end
