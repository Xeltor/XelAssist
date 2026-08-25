-- Public action-graph facade. SearchSession owns the explicit table-cursor
-- continuation so the same deterministic graph can run synchronously or in
-- short frame slices without publishing partial recommendations.
-- Its legacy budget invariants remain level > 2, level >= 2, and budgetLimited.
local G = XelAssist.Graph
local State = G.State
local SearchSession = G.SearchSession

function G:ActiveTargetModifiers(encounter, targetResistance)
    return State:ActiveTargetModifiers(encounter, targetResistance)
end

function G:Snapshot(mode)
    return State:Snapshot(mode)
end

function G:BeginEvaluation(mode, preview, observedAt)
    return SearchSession:Begin(mode, preview, observedAt)
end

function G:ResumeEvaluation(session, sliceMs)
    return SearchSession:Resume(session, sliceMs)
end

function G:CancelEvaluation(session)
    return SearchSession:Cancel(session)
end

function G:Evaluate(mode, preview, observedAt)
    local session = self:BeginEvaluation(mode, preview, observedAt)
    local complete, plan, reason, fallback = false, nil, nil, false
    while not complete do
        -- Zero disables cooperative yielding but retains the same active CPU
        -- and state budgets, preserving the legacy synchronous API exactly.
        complete, plan, reason, fallback = self:ResumeEvaluation(session, 0)
    end
    return plan, reason, fallback
end
