XelAssistUI = {}
local UI = XelAssistUI
local FALLBACK_ICON = "Interface\\Icons\\INV_Misc_QuestionMark"

local function iconFor(action)
    if action and action.texture then return action.texture end
    local slot = action and XelAssistCapabilities:SpellSlot(action.name)
    return slot and GetSpellTexture(slot, BOOKTYPE_SPELL) or FALLBACK_ICON
end

local function actionName(action)
    if not action then return "" end
    local highest = XelAssistCapabilities:SpellRank(action.name)
    if action.rank and action.rank < highest then return action.name .. " · R" .. action.rank end
    return action.name
end

local function classColor()
    local _, class = UnitClass("player")
    local c = RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
    if c then return c.r, c.g, c.b end
    return 0.25, 0.72, 1
end

local function emptyCopy(reason)
    if reason and string.find(reason, "Dependencies missing:") == 1 then return "Setup required", reason
    elseif reason == "Select a target or injured ally" then return "Choose a target", "Select an enemy or an injured ally"
    elseif reason == "Move into range" then return "Move into range", "Target is too far away"
    elseif reason == "Move farther away" then return "Move farther away", "Target is inside the action's minimum range"
    elseif reason == "Finish moving" then return "Finish moving", "Useful actions currently require a cast"
    elseif reason == "Not enough resources" then return "Recover resources", "No useful affordable action is ready"
    elseif reason == "Waiting for cooldown" then return "Wait", "Useful actions are still cooling down"
    elseif reason == "No worthwhile action" then return "Hold", "No action improves the current state"
    elseif reason == "Evaluation paused" then return "Holding safely", "Graph data could not be evaluated"
    else return "Holding safely", reason or "No action queued" end
end

local function updateCooldown(button, action)
    local cooldown = button.cooldown
    if not cooldown or not CooldownFrame_SetTimer then return end
    CooldownFrame_SetTimer(cooldown, 0, 0, 0)
    if action and action.executor == "item" then
        if GetItemIdCooldown and action.itemId then
            local ok, info = pcall(GetItemIdCooldown, action.itemId)
            if ok and type(info) == "table" then
                local start, duration = info.individualStartS, (info.individualDurationMs or 0) / 1000
                if (info.categoryRemainingMs or 0) > (info.individualRemainingMs or 0) then
                    start, duration = info.categoryStartS, (info.categoryDurationMs or 0) / 1000
                end
                if start and duration > 0 then CooldownFrame_SetTimer(cooldown, start, duration, 1) end
                return
            end
        end
        if GetContainerItemCooldown and action.bag and action.bagSlot then
            local start, duration, enabled = GetContainerItemCooldown(action.bag, action.bagSlot)
            if start and duration then CooldownFrame_SetTimer(cooldown, start, duration, enabled or 1) end
        end
        return
    end
    local slot = action and XelAssistCapabilities:SpellSlot(action.name)
    if not slot then return end
    local start, duration, enabled = GetSpellCooldown(slot, BOOKTYPE_SPELL)
    if start and duration then CooldownFrame_SetTimer(cooldown, start, duration, enabled or 1) end
end

function UI:SavePosition()
    if not self.frame then return end
    local point, _, relativePoint, x, y = self.frame:GetPoint()
    XelAssistDB.ui.position = { point = point, relativePoint = relativePoint, x = x, y = y }
end

function UI:ResetPosition()
    if not self.frame then return end
    self.frame:ClearAllPoints()
    self.frame:SetPoint("CENTER", UIParent, "CENTER", 0, -180)
    self:SavePosition()
end

function UI:SetScale(value)
    local scale = tonumber(value) or 1
    if scale < 0.7 then scale = 0.7 end
    if scale > 1.5 then scale = 1.5 end
    XelAssistDB.ui.scale = scale
    if self.frame then
        local old = self.frame:GetScale() or 1
        local point, _, relativePoint, x, y = self.frame:GetPoint()
        self.frame:SetScale(scale)
        if old > 0 and point then
            self.frame:ClearAllPoints()
            self.frame:SetPoint(point, UIParent, relativePoint, (x or 0) * old / scale,
                (y or 0) * old / scale)
            self:SavePosition()
        end
    end
end

function UI:Build()
    if self.frame then return end
    local r, g, b = classColor()
    local f = CreateFrame("Frame", "XelAssistFrame", UIParent)
    f:SetWidth(246); f:SetHeight(76)
    f:SetBackdrop({ bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", tile = true,
        tileSize = 16, edgeSize = 10,
        insets = { left = 3, right = 3, top = 3, bottom = 3 } })
    f:SetBackdropColor(0.025, 0.035, 0.055, 0.94)
    f:SetBackdropBorderColor(0.22, 0.25, 0.31, 1)
    f:SetFrameStrata("MEDIUM")

    local pos = XelAssistDB.ui.position
    if pos then f:SetPoint(pos.point or "CENTER", UIParent, pos.relativePoint or "CENTER", pos.x or 0, pos.y or -180)
    else f:SetPoint("CENTER", UIParent, "CENTER", 0, -180) end
    f:SetScale(XelAssistDB.ui.scale or 1)

    local stripe = f:CreateTexture(nil, "ARTWORK")
    stripe:SetWidth(3); stripe:SetPoint("TOPLEFT", f, "TOPLEFT", 4, -5); stripe:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 4, 5)
    stripe:SetTexture(r, g, b, 1)

    local actorBar = f:CreateTexture(nil, "ARTWORK")
    actorBar:SetHeight(2); actorBar:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 7, 4)
    actorBar:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -7, 4)
    actorBar:SetTexture(0.62, 0.38, 0.86, 1); actorBar:Hide()
    f.actorBar = actorBar

    local eyebrow = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    eyebrow:SetPoint("TOPLEFT", f, "TOPLEFT", 69, -8)
    eyebrow:SetText("XELASSIST  ·  SMART")
    eyebrow:SetTextColor(r, g, b)
    f.eyebrow = eyebrow

    local main = CreateFrame("Button", "XelAssistActionButton", f, "ActionButtonTemplate")
    main:SetWidth(52); main:SetHeight(52); main:SetPoint("LEFT", f, "LEFT", 12, -4)
    main.icon = getglobal("XelAssistActionButtonIcon") or main:CreateTexture(nil, "ARTWORK")
    main.icon:SetAllPoints(main)
    main.cooldown = getglobal("XelAssistActionButtonCooldown")
    main.binding = f:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmallGray")
    main.binding:SetPoint("TOPRIGHT", main, "TOPRIGHT", -2, -2)
    main.count = f:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
    main.count:SetPoint("BOTTOMRIGHT", main, "BOTTOMRIGHT", -2, 2)
    main:SetScript("OnClick", function() XelAssist:Execute() end)
    main:SetScript("OnEnter", function()
        GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
        GameTooltip:SetText("Execute recommendation")
        if UI.lastPlan and UI.lastPlan.actor == "pet" then
            GameTooltip:AddLine("Actor: active companion", 0.72, 0.52, 0.92)
        end
        GameTooltip:AddLine(UI.lastReason or "No recommendation yet", 1, 1, 1)
        local plan = UI.lastPlan
        if plan then
            GameTooltip:AddLine(string.format("Downtime %.1fs · threat %d", plan.downtime or 0,
                math.floor(plan.threat or 0)), 0.72, 0.75, 0.82)
            local observed = plan.observed or {}
            if observed.distance then
                GameTooltip:AddLine(string.format("Range evidence %.1f yd · %s", observed.distance,
                    observed.distanceKind or "unknown"), 0.72, 0.75, 0.82)
            end
            GameTooltip:AddLine(string.format("Graph %d states · %.2fms", plan.expanded or 0,
                plan.elapsed or 0), 0.55, 0.58, 0.64)
            if observed.talentPoints then
                GameTooltip:AddLine(string.format("Talent-adjusted client facts · %d points", observed.talentPoints),
                    0.55, 0.58, 0.64)
            end
        end
        GameTooltip:Show()
    end)
    main:SetScript("OnLeave", function() GameTooltip:Hide() end)
    f.main = main

    local name = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    name:SetPoint("TOPLEFT", f, "TOPLEFT", 69, -25); name:SetWidth(132); name:SetJustifyH("LEFT")
    f.name = name
    local reason = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    reason:SetPoint("TOPLEFT", name, "BOTTOMLEFT", 0, -3); reason:SetWidth(150); reason:SetJustifyH("LEFT")
    reason:SetTextColor(0.68, 0.71, 0.76)
    f.reason = reason

    local move = CreateFrame("Button", nil, f)
    move:SetWidth(34); move:SetHeight(15); move:SetPoint("TOPRIGHT", f, "TOPRIGHT", -8, -6)
    move.text = move:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    move.text:SetAllPoints(move); move.text:SetText("DRAG"); move.text:SetTextColor(0.48, 0.52, 0.58)
    move:RegisterForDrag("LeftButton")
    move:SetScript("OnDragStart", function()
        if not XelAssistDB.ui.locked then f:StartMoving() end
    end)
    move:SetScript("OnDragStop", function() f:StopMovingOrSizing(); UI:SavePosition() end)
    move:SetScript("OnEnter", function()
        GameTooltip:SetOwner(this, "ANCHOR_TOP"); GameTooltip:SetText("Drag to move")
        GameTooltip:AddLine("Lock position in XelAssist settings", 1, 1, 1); GameTooltip:Show()
    end)
    move:SetScript("OnLeave", function() GameTooltip:Hide() end)
    f:SetMovable(true)
    f:EnableMouse(true)
    f.move = move
    if XelAssistDB.ui.locked then move:Hide() end

    local config = CreateFrame("Button", nil, f)
    config:SetWidth(28); config:SetHeight(15); config:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -8, 7)
    config.text = config:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    config.text:SetAllPoints(config); config.text:SetText("CFG"); config.text:SetTextColor(0.48, 0.52, 0.58)
    config:SetScript("OnClick", function() XelAssistConfig:Toggle() end)
    config:SetScript("OnEnter", function() this.text:SetTextColor(r, g, b) end)
    config:SetScript("OnLeave", function() this.text:SetTextColor(0.48, 0.52, 0.58) end)
    f.config = config

    f.follow = {}
    local i
    for i = 1, 4 do
        local pip = CreateFrame("Frame", nil, f)
        pip:SetWidth(18); pip:SetHeight(18)
        pip:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 69 + ((i - 1) * 23), 7)
        pip.icon = pip:CreateTexture(nil, "ARTWORK"); pip.icon:SetAllPoints(pip)
        pip.border = pip:CreateTexture(nil, "OVERLAY"); pip.border:SetAllPoints(pip)
        pip.border:SetTexture("Interface\\Buttons\\UI-Quickslot2")
        pip.step = pip:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmallGray")
        pip.step:SetPoint("BOTTOMRIGHT", pip, "BOTTOMRIGHT", 1, -1); pip.step:SetText(i + 1)
        pip:EnableMouse(true)
        pip:Hide(); f.follow[i] = pip
    end

    f:SetScript("OnUpdate", function()
        UI.elapsed = (UI.elapsed or 0) + (arg1 or 0)
        if UI.elapsed >= 0.10 then UI.elapsed = 0; UI:Refresh(false) end
    end)
    self.frame = f
    if XelAssistDB.ui.shown == false then f:Hide() else f:Show() end
    self:Refresh(true)
end

function UI:Refresh(force)
    if not self.frame then return end
    local plan, err
    if XelAssist and XelAssist.executionEnabled == false then
        err = "Dependencies missing: " .. table.concat(XelAssist.missing or {}, ", ")
    else
        local ok
        ok, plan, err = pcall(function() return XelAssistGraph:Evaluate(XelAssist.mode, true) end)
        if not ok then
            if XelAssist and XelAssist.RecordError then XelAssist:RecordError(plan) end
            plan, err = nil, "Evaluation paused"
        end
    end
    local f = self.frame
    if plan then
        self.lastPlan = plan
        local action = plan.action
        local petAction = (action.actor or "player") == "pet"
        f.eyebrow:SetText((petAction and "COMPANION" or string.upper(XelAssist.mode or "smart"))
            .. "  ·  " .. string.upper(XelAssistCharDB.role or "auto"))
        if petAction then f.actorBar:Show() else f.actorBar:Hide() end
        f.main.icon:SetTexture(iconFor(action))
        f.name:SetText(actionName(action)); f.reason:SetText(plan.reason .. " · " .. plan.confidence)
        updateCooldown(f.main, action)
        f.main.count:SetText(action.executor == "item" and tostring(action.count or "") or "")
        self.lastReason = actionName(action) .. " — " .. plan.reason
        local i
        for i = 1, 4 do
            local follow = plan.follow[i]
            local pip = f.follow[i]
            if follow and i < (XelAssistCharDB.graphDepth or 3) then
                pip.icon:SetTexture(iconFor(follow)); pip:Show()
                if follow.actor == "pet" then pip.border:SetVertexColor(0.72, 0.48, 0.92)
                else pip.border:SetVertexColor(1, 1, 1) end
                pip:SetScript("OnEnter", function()
                    GameTooltip:SetOwner(this, "ANCHOR_TOP")
                    GameTooltip:SetText(actionName(this.action))
                    local candidate = this.candidate
                    GameTooltip:AddLine(candidate and candidate.reason or "Predicted future action", 0.75, 0.78, 0.84)
                    if candidate then
                        GameTooltip:AddLine(string.format("Predicted step %d · %.1fs downtime", this.stepIndex,
                            candidate.downtime or 0), 0.55, 0.58, 0.64)
                    end
                    GameTooltip:Show()
                end)
                pip:SetScript("OnLeave", function() GameTooltip:Hide() end)
                pip.action = follow
                pip.candidate = plan.path and plan.path[i + 1] or nil
                pip.stepIndex = i + 1
            else pip.action = nil; pip.candidate = nil; pip:Hide() end
        end
    else
        f.eyebrow:SetText(string.upper(XelAssist.mode or "smart") .. "  ·  "
            .. string.upper(XelAssistCharDB.role or "auto"))
        f.actorBar:Hide()
        local title, detail = emptyCopy(err)
        f.main.icon:SetTexture(FALLBACK_ICON)
        f.main.count:SetText("")
        updateCooldown(f.main, nil)
        f.name:SetText(title); f.reason:SetText(detail)
        local i
        for i = 1, 4 do f.follow[i]:Hide() end
        self.lastReason = title .. " — " .. detail
        self.lastPlan = nil
    end
    local key = GetBindingKey("XELASSIST_EXECUTE")
    f.main.binding:SetText(key or "")
end
