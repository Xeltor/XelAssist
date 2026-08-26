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
-- Leave enough room for one indivisible scoring/transition call after the
-- checkpoint. Live Mage evidence showed a nominal 3 ms budget reaching
-- 4.25 ms; 1.75 ms keeps the measured whole Resume below the 3.23 ms frame
-- ceiling without shortening the aggregate search.
P.SLICE_MS = 1.75

-- GetTime is updated at the frame boundary on the 1.12 client. A synchronous
-- graph search therefore sees a frozen value and cannot enforce a millisecond
-- budget with it. debugprofilestop is the client-owned intra-frame clock; the
-- fallback keeps standalone tests and reduced API environments deterministic.
function P:ClockMilliseconds()
    if type(debugprofilestop) == "function" then
        local value = debugprofilestop()
        if type(value) == "number" then return value end
    end
    if type(GetTime) == "function" then return GetTime() * 1000 end
    return 0
end

function P:ElapsedMilliseconds(started)
    -- A resumable evaluation stores only CPU time accumulated while it was
    -- actively running. Its per-resume clock is cleared before control is
    -- returned to the frame, so inter-frame idle never consumes the graph's
    -- existing millisecond budget.
    if type(started) == "table" and started.xelSearchSession then
        local elapsed = math.max(0, tonumber(started.activeMs) or 0)
        if started.budgetResumeStarted ~= nil then
            elapsed = elapsed + math.max(0, self:ClockMilliseconds()
                - (tonumber(started.budgetResumeStarted) or 0))
        end
        return elapsed
    end
    return math.max(0, self:ClockMilliseconds()
        - (tonumber(started) or 0))
end

function P:SliceReached(started, sliceMs)
    local limit = tonumber(sliceMs)
    return limit ~= nil and limit > 0
        and self:ElapsedMilliseconds(started) >= limit
end

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
        or self:ElapsedMilliseconds(started) > (counter.maxMs or self.MIN_MS)
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
