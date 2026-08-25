XelAssist.UI.RecommendationController = {}
local Controller = XelAssist.UI.RecommendationController
local Stability = XelAssist.UI.RecommendationStability
local RecommendationSnapshot = XelAssist.Core.RecommendationSnapshot
local POLL_SECONDS = 0.35

function Controller:MarkTargetDirty(owner)
    if Stability then Stability:Reset(owner) end
    RecommendationSnapshot:Invalidate("target changed")
    owner.targetDirty = true
    owner.elapsed = 0
end

function Controller:RequestRefresh(owner, force, mode)
    owner.refreshRequested = true
    if force then owner.forceRequested = true end
    if mode then owner.requestedMode = mode end
    owner.elapsed = POLL_SECONDS
end

function Controller:ClearExecutionMode(owner)
    owner.requestedMode = nil
end

function Controller:Bind(owner)
    -- The producer must remain alive when the presentation frame is hidden.
    local driver = CreateFrame("Frame", "XelAssistHUDDriver", UIParent)
    driver:RegisterEvent("PLAYER_TARGET_CHANGED")
    driver:SetScript("OnEvent", function()
        if event == "PLAYER_TARGET_CHANGED" then owner:MarkTargetDirty() end
    end)
    driver:SetScript("OnUpdate", function()
        if owner.targetDirty then
            owner.targetDirty = nil
            owner.elapsed = 0
            return
        end
        owner.elapsed = (owner.elapsed or 0) + (arg1 or 0)
        if owner.elapsed >= POLL_SECONDS or owner.refreshRequested then
            local force = owner.forceRequested and true or false
            local mode = owner.requestedMode
            owner.elapsed, owner.refreshRequested, owner.forceRequested = 0, nil, nil
            owner:Refresh(force, mode)
        end
    end)
    owner.driver = driver
    return driver
end

function Controller:Evaluate(owner, force, evaluationMode)
    local plan, err
    local selected = evaluationMode or XelAssist.mode
    local observedAt = GetTime()
    if XelAssist and XelAssist.executionEnabled == false then
        err = "Dependencies missing: " .. table.concat(XelAssist.missing or {}, ", ")
    else
        local ok
        ok, plan, err = pcall(function()
            return XelAssist.Graph:Evaluate(selected, true, observedAt)
        end)
        if not ok then
            if XelAssist and XelAssist.RecordError then XelAssist:RecordError(plan) end
            plan, err = nil, "Evaluation paused"
        end
    end
    local reach = XelAssist.Core and XelAssist.Core.ExecutionReach
    if plan and plan.liveSnapshot == true and plan.action
        and plan.action.executor ~= "instruction"
        and reach and reach.Validate then
        local valid, reason = reach:Validate(plan,
            plan.castTarget or plan.target)
        if not valid then
            plan = nil
            err = "State changed during evaluation: "
                .. tostring(reason or "live evidence changed")
        end
    end
    RecommendationSnapshot:Publish(plan, selected, err)
    local changed
    if Stability then
        plan, err, changed = Stability:Select(owner, plan, err, force)
    else changed = true end
    return plan, err, changed
end
