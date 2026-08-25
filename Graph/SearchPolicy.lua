-- Bounded, automatic graph horizon. Visible HUD rows are presentation policy;
-- they do not shorten the combat search that chooses the current action.
XelAssist.Graph.SearchPolicy = {}
local P = XelAssist.Graph.SearchPolicy

P.MIN_STATES = 256
P.MEDIUM_STATES = 512
P.MAX_STATES = 768
P.MIN_MS = 8
P.MEDIUM_MS = 12
P.MAX_MS = 18
P.WIDTH = 5
P.MAX_DECISIONS = 24
P.MAX_SECONDS = 45
P.DISCOUNT_SECONDS = 4.5

function P:Depth()
    -- graphDepth is retained only as a standalone/test compatibility override.
    -- Runtime migrates the user-facing setting to visibleSteps and clears it.
    local depth = tonumber(XelAssistCharDB.graphDepth) or self.MAX_DECISIONS
    return math.max(1, math.min(self.MAX_DECISIONS, math.floor(depth)))
end

function P:Limits(state)
    local time = tonumber(state and state.time) or 0
    local gcd = math.max(0,
        (tonumber(state and state.playerGcdReadyAt) or time) - time)
    local actor = state and state.actorReadyAt
    local ready = math.max(0,
        (tonumber(actor and actor.player) or time) - time)
    local slack = math.max(gcd, ready)
    -- A running cast/GCD is usable planning time: the player cannot submit a
    -- second normal action yet, so deepen the graph without delaying a ready
    -- button. Keep the immediate lane below half of a 60 FPS frame.
    if state and (state.inCombat == false or slack >= 1) then
        return self.MAX_STATES, self.MAX_MS
    end
    if slack >= 0.35 then return self.MEDIUM_STATES, self.MEDIUM_MS end
    return self.MIN_STATES, self.MIN_MS
end

function P:BudgetReached(started, counter)
    return counter.count >= (counter.maxStates or self.MIN_STATES)
        or (GetTime() - started) * 1000 > (counter.maxMs or self.MIN_MS)
end

function P:WithinHorizon(state, rootTime)
    return math.max(0, (tonumber(state.time) or 0) - rootTime)
        < self.MAX_SECONDS
end

function P:Weight(rootTime, candidate)
    local impact = tonumber(candidate.actionStart) or rootTime
    impact = impact + math.max(0, tonumber(candidate.cast) or 0)
    local elapsed = math.max(0, impact - rootTime)
    return 1 / (1 + elapsed / self.DISCOUNT_SECONDS)
end
