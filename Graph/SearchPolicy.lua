-- Bounded, automatic graph horizon. Visible HUD rows are presentation policy;
-- they do not shorten the combat search that chooses the current action.
XelAssist.Graph.SearchPolicy = {}
local P = XelAssist.Graph.SearchPolicy

P.MAX_STATES = 128
P.MAX_MS = 6
P.WIDTH = 4
P.MAX_DECISIONS = 8
P.MAX_SECONDS = 12
P.DISCOUNT_SECONDS = 4.5

function P:Depth()
    -- graphDepth is retained only as a standalone/test compatibility override.
    -- Runtime migrates the user-facing setting to visibleSteps and clears it.
    local depth = tonumber(XelAssistCharDB.graphDepth) or self.MAX_DECISIONS
    return math.max(1, math.min(self.MAX_DECISIONS, math.floor(depth)))
end

function P:BudgetReached(started, counter)
    return counter.count >= self.MAX_STATES
        or (GetTime() - started) * 1000 > self.MAX_MS
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
