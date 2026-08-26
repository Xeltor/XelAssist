-- Small immutable projections returned by Timeline's read-only pre-action
-- pass. This keeps mechanic-specific consumers from retaining or mutating the
-- deep copied timeline state.
XelAssist.Graph.TimelineProbe = {}
local P = XelAssist.Graph.TimelineProbe
local State = XelAssist.Graph.State

function P:Channel(state, candidate)
    local facts = candidate and candidate.action and candidate.action.facts or {}
    if facts.channelContinuation ~= true then return nil end
    local out = { targetGUID = state.targetGUID,
        targetHealth = state.targetHealth,
        targetHealthExact = state.targetHealthExact == true,
        targetAlive = state.hostile ~= false,
        health = state.health, healthMax = state.healthMax,
        resource = state.resource, resourceMax = state.resourceMax,
        playerResourceExact = state.playerResourceExact == true }
    if candidate.targetRelation ~= "hostile" and candidate.targetKey ~= nil
        and State and type(State.FriendlyByKey) == "function" then
        local record = State:FriendlyByKey(state, candidate.targetKey)
        local exact = record and record.healthExact
        if exact == nil and record then exact = record.exact end
        out.friendlyKey = candidate.targetKey
        out.friendlyGUID = record and record.guid
        out.friendlyHealth = record and record.health
        out.friendlyHealthMax = record and record.healthMax
        out.friendlyHealthExact = exact == true
        out.friendlyDead = record and (record.dead == true
            or record.projectedDefeated == true) or false
    end
    return out
end
