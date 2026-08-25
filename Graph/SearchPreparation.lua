-- Bridges action discovery into a sliced, sealed root observation without
-- adding capture mechanics to the search state machine itself.
XelAssist.Graph.SearchPreparation = {}
local P = XelAssist.Graph.SearchPreparation

local function fail(session, reason)
    session.plan, session.fallback = nil, false
    session.reason = reason or "root observation unavailable"
    session.status, session.phase = "complete", "done"
    return true
end

function P:Begin(session, actions)
    session.actions = actions
    local root = XelAssist.Graph.RootObservation
    if not root then
        session.prepareStage, session.phase = 1, "prepare"
        return false
    end
    session.rootObservation = root:Begin(
        session.state, actions, session.observedAt)
    if not session.rootObservation then
        return fail(session, "root observation could not begin")
    end
    session.phase = "observe"
    return false
end

function P:Advance(session)
    local root, observed = XelAssist.Graph.RootObservation,
        session.rootObservation
    if not (root and observed) then
        return fail(session, "root observation unavailable")
    end
    local complete, reason = root:Step(observed)
    if reason then return fail(session, reason) end
    if not complete then return false end
    local sealed
    sealed, reason = root:Seal(observed)
    if not sealed then return fail(session, reason) end
    local actions, status = root:Actions(session.state)
    if status ~= "known" or type(actions) ~= "table" then
        return fail(session, "root action catalog unavailable")
    end
    session.actions = actions
    session.prepareStage, session.phase = 1, "prepare"
    return true
end
