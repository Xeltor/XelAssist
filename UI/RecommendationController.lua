-- Frame-sliced graph production and atomic publication. Physical input only
-- consumes a finished snapshot; it never performs or restarts graph work.
XelAssist.UI.RecommendationController = {}
local Controller = XelAssist.UI.RecommendationController
local Stability = XelAssist.UI.RecommendationStability
local RecommendationSnapshot = XelAssist.Core.RecommendationSnapshot
local POLL_SECONDS = 0.35

local function selectedMode(owner, mode)
    return mode or owner.requestedMode or XelAssist.mode
end

local function dependencyError()
    if XelAssist and XelAssist.executionEnabled == false then
        return "Dependencies missing: "
            .. table.concat(XelAssist.missing or {}, ", ")
    end
    return nil
end

local function validatePlan(plan, err)
    local publication = XelAssist.Core and XelAssist.Core.PublicationGuard
    if plan and plan.liveSnapshot == true and publication
        and publication.Validate then
        local valid, reason = publication:Validate(plan)
        if not valid then
            return nil, "State changed during evaluation: "
                .. tostring(reason or "live evidence changed"), true
        end
    end
    local reach = XelAssist.Core and XelAssist.Core.ExecutionReach
    if plan and plan.liveSnapshot == true and plan.action
        and plan.action.executor ~= "instruction"
        and reach and reach.Validate then
        local valid, reason = reach:Validate(plan,
            plan.castTarget or plan.target)
        if not valid then
            return nil, "State changed during evaluation: "
                .. tostring(reason or "live evidence changed"), true
        end
    end
    return plan, err, false
end

function Controller:CancelActive(owner, reason)
    local active = owner.activeEvaluation
    if not active then return false end
    if XelAssist.Graph and XelAssist.Graph.CancelEvaluation then
        pcall(XelAssist.Graph.CancelEvaluation,
            XelAssist.Graph, active.session, reason)
    end
    owner.activeEvaluation = nil
    return true
end

function Controller:Invalidate(owner, reason, mode)
    self:CancelActive(owner, reason)
    RecommendationSnapshot:Invalidate(reason)
    owner.refreshRequested, owner.forceRequested = true, true
    if mode then owner.requestedMode = mode end
    owner.elapsed = POLL_SECONDS
    if owner.SetUpdating then owner:SetUpdating(reason) end
end

function Controller:MarkTargetDirty(owner)
    self:Invalidate(owner, "target changed")
    owner.targetDirty = true
end

function Controller:RequestRefresh(owner, force, mode)
    if force then
        self:Invalidate(owner, "state refresh requested", mode)
        return
    end
    owner.refreshRequested = true
    if mode then owner.requestedMode = mode end
    owner.elapsed = POLL_SECONDS
end

function Controller:EnsureEvaluation(owner, mode)
    local selected = selectedMode(owner, mode)
    local active = owner.activeEvaluation
    if active and active.mode == selected then return false end
    local pendingMode = selectedMode(owner, owner.requestedMode)
    if owner.refreshRequested and pendingMode == selected then return false end
    local publishedMode = RecommendationSnapshot.mode
    if (active and active.mode ~= selected)
        or (publishedMode and publishedMode ~= selected) then
        self:Invalidate(owner, "recommendation mode changed", selected)
    else
        owner.requestedMode = selected
        owner.refreshRequested = true
        owner.elapsed = POLL_SECONDS
    end
    return true
end

function Controller:ClearExecutionMode(owner)
    owner.requestedMode = nil
end

local function selectPublication(owner, ticket, plan, err, force)
    if not RecommendationSnapshot:IsTicketCurrent(ticket, ticket.mode) then
        return nil, nil, false, false
    end
    local changed
    if Stability then
        plan, err, changed = Stability:Select(owner, plan, err, force)
    else changed = true end
    local generation = RecommendationSnapshot:PublishIfCurrent(
        ticket, plan, ticket.mode, err)
    return plan, err, changed, generation ~= nil
end

function Controller:Commit(owner, active, plan, err)
    if not RecommendationSnapshot:IsTicketCurrent(
        active.ticket, active.mode) then return false end
    local retry
    plan, err, retry = validatePlan(plan, err)
    if retry then
        self:Invalidate(owner, err, active.mode)
        return false
    end
    local selected, selectedError, changed, published = selectPublication(
        owner, active.ticket, plan, err, active.force)
    if not published then return false end
    if owner.Render then owner:Render(selected, selectedError, changed) end
    return true
end

function Controller:Begin(owner, force, mode)
    local selected = selectedMode(owner, mode)
    local observedAt = GetTime()
    local active = { mode = selected, force = force and true or false,
        observedAt = observedAt,
        ticket = RecommendationSnapshot:Ticket(selected, observedAt) }
    local err = dependencyError()
    if err then
        self:Commit(owner, active, nil, err)
        return false
    end
    local ok, session = pcall(function()
        return XelAssist.Graph:BeginEvaluation(selected, true, observedAt)
    end)
    if not ok then
        if XelAssist and XelAssist.RecordError then XelAssist:RecordError(session) end
        self:Commit(owner, active, nil, "Evaluation paused")
        return false
    end
    active.session = session
    owner.activeEvaluation = active
    return true
end

function Controller:Resume(owner)
    local active = owner.activeEvaluation
    if not active then return false end
    local ok, complete, plan, err = pcall(function()
        return XelAssist.Graph:ResumeEvaluation(active.session)
    end)
    if not ok then
        if XelAssist and XelAssist.RecordError then XelAssist:RecordError(complete) end
        complete, plan, err = true, nil, "Evaluation paused"
    end
    if not complete then return true end
    owner.activeEvaluation = nil
    if active.session and active.session.cancelled then return false end
    if active.session and active.session.stale then
        owner.refreshRequested, owner.elapsed = true, POLL_SECONDS
        if owner.SetUpdating then
            owner:SetUpdating(err or "combat state changed; recalculating")
        end
        return false
    end
    local snapshotAt = active.session and active.session.snapshotAt
        or active.observedAt
    active.observedAt = snapshotAt
    if active.ticket then active.ticket.observedAt = snapshotAt end
    local age = GetTime() - (tonumber(active.observedAt) or 0)
    if age < 0 or age > RecommendationSnapshot.MAX_AGE then
        self:Invalidate(owner,
            "evaluation expired before publication", active.mode)
        return false
    end
    self:Commit(owner, active, plan, err)
    return false
end

function Controller:Tick(owner, elapsed)
    owner.elapsed = (owner.elapsed or 0) + (tonumber(elapsed) or 0)
    if owner.targetDirty then
        -- The target event already invalidated execution. Begin its replacement
        -- on this next frame without imposing the old 0.35-second blank delay.
        owner.targetDirty = nil
        owner.refreshRequested = true
        owner.elapsed = POLL_SECONDS
    end
    if owner.activeEvaluation then
        self:Resume(owner)
        return
    end
    if owner.elapsed < POLL_SECONDS and not owner.refreshRequested then return end
    local force = owner.forceRequested and true or false
    local mode = owner.requestedMode
    owner.elapsed, owner.refreshRequested, owner.forceRequested = 0, nil, nil
    self:Begin(owner, force, mode)
end

function Controller:Bind(owner)
    -- The producer must remain alive when the presentation frame is hidden.
    local driver = CreateFrame("Frame", "XelAssistHUDDriver", UIParent)
    driver:RegisterEvent("PLAYER_TARGET_CHANGED")
    driver:SetScript("OnEvent", function()
        if event == "PLAYER_TARGET_CHANGED" then owner:MarkTargetDirty() end
    end)
    driver:SetScript("OnUpdate", function()
        Controller:Tick(owner, arg1 or 0)
    end)
    owner.driver = driver
    return driver
end

-- Synchronous compatibility for standalone tests and explicit diagnostic
-- callers. Runtime production uses Begin/Resume exclusively through Tick.
function Controller:Evaluate(owner, force, evaluationMode)
    self:CancelActive(owner, "synchronous diagnostic evaluation")
    owner.refreshRequested, owner.forceRequested = nil, nil
    local selected = selectedMode(owner, evaluationMode)
    if force then RecommendationSnapshot:Invalidate("synchronous refresh") end
    local observedAt = GetTime()
    local active = { mode = selected, force = force and true or false,
        observedAt = observedAt,
        ticket = RecommendationSnapshot:Ticket(selected, observedAt) }
    local plan, err
    err = dependencyError()
    if not err then
        local ok
        ok, plan, err = pcall(function()
            return XelAssist.Graph:Evaluate(selected, true, observedAt)
        end)
        if not ok then
            if XelAssist and XelAssist.RecordError then XelAssist:RecordError(plan) end
            plan, err = nil, "Evaluation paused"
        end
    end
    plan, err = validatePlan(plan, err)
    local selectedPlan, selectedError, changed = selectPublication(
        owner, active.ticket, plan, err, active.force)
    return selectedPlan, selectedError, changed
end
