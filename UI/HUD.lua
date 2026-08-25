XelAssist.UI.HUD = {}
local UI = XelAssist.UI.HUD
local Theme = XelAssist.UI.Theme
local setFittedText = Theme.SetFittedText
local FALLBACK_ICON = "Interface\\Icons\\INV_Misc_QuestionMark"
local BASE_HEIGHT = 76
local STEP_HEIGHT = 24

local function iconFor(action)
    if action and action.texture then return action.texture end
    local slot = action and XelAssist.Game.Capabilities:SpellSlot(action.name)
    return slot and GetSpellTexture(slot, BOOKTYPE_SPELL) or FALLBACK_ICON
end

local function actionName(action)
    if not action then return "" end
    local highest = XelAssist.Game.Capabilities:SpellRank(action.name)
    if action.rank and action.rank < highest then return action.name .. " · R" .. action.rank end
    return action.name
end

local function actorCopy(action)
    local actor = action and action.actor or "player"
    if actor == "pet" then return "Companion" end
    if actor == "player" then return "You" end
    return tostring(action and action.actorName or actor)
end
local function targetCopy(target, targetRef)
    if target == "player" then return "Self" end
    if target == "pet" then return "Companion" end
    -- Resolve a live name only after the mutable token still matches the exact
    -- snapshot identity; otherwise use a role label and never render the GUID.
    if targetRef and XelAssist.Game.Capabilities:SameUnitRef(targetRef)
        and UnitName then
        local ok, name = pcall(UnitName, targetRef.unit)
        if ok and name and name ~= "" then return name end
    end
    if not target or target == "target" then return "Target" end
    if type(target) == "string" and string.find(target, "party", 1, true) == 1 then return "Party " .. string.sub(target, 6) end
    if type(target) == "string" and string.find(target, "raid", 1, true) == 1 then return "Raid " .. string.sub(target, 5) end
    local relation = targetRef and targetRef.relation
    if relation == "ally" or relation == "friendly" then return "Ally" end
    if relation == "self" or relation == "player" then return "Self" end
    if relation == "pet" or relation == "controlled" then return "Companion" end
    return "Target"
end
local function routeCopy(action, target, targetRef)
    if action and action.facts and action.facts.ground then
        return actorCopy(action) .. " -> Ground placement"
    end
    return actorCopy(action) .. " -> " .. targetCopy(target, targetRef)
end
local function timeCopy(value)
    value = math.max(0, tonumber(value) or 0)
    if value <= 0.05 then return "NOW" end
    if value < 10 then return string.format("+%.1fs", value) end
    return "+" .. math.floor(value + 0.5) .. "s"
end

local function resistanceOpen(resistance)
    if not resistance then return false end
    if resistance.unknown or resistance.penetrationUnknown then return true end
    local i
    for i = 1, table.getn(resistance.components or {}) do
        local component = resistance.components[i]
        if component.unknown or component.penetrationUnknown then return true end
    end
    return false
end

local function certaintyCopy(plan, candidate)
    local resistance = candidate and candidate.resistance or plan and plan.resistance
    if (plan and plan.confidence == "partial data")
        or (candidate and candidate.confidence == "partial data")
        or (candidate and candidate.unknowns and table.getn(candidate.unknowns) > 0)
        or resistanceOpen(resistance) then
        return "OPEN", 1, 0.70, 0.26
    end
    if (candidate and candidate.estimated)
        or (plan and plan.confidence == "estimated") then
        return "EST", 0.95, 0.73, 0.34
    end
    if candidate and candidate.confidence ~= "client data" then
        return "MODEL", 0.58, 0.72, 0.88
    end
    return "LIVE", 0.48, 0.82, 0.69
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
    local slot = action and XelAssist.Game.Capabilities:SpellSlot(action.name)
    if not slot then return end
    local start, duration, enabled = GetSpellCooldown(slot, BOOKTYPE_SPELL)
    if start and duration then CooldownFrame_SetTimer(cooldown, start, duration, enabled or 1) end
end

local function roundedPercent(value)
    return math.floor((tonumber(value) or 1) * 100 + 0.5)
end

local function addResistanceLines(plan, compact)
    local resistance = plan and plan.resistance
    if not resistance then return end
    local scored = resistance.decisionMultiplier or resistance.multiplier or 1
    if resistance.unknown then
        GameTooltip:AddLine("Resistance: " .. (resistance.source or "unknown"), 1, 0.72, 0.28)
        if resistance.landChance then
            GameTooltip:AddLine(string.format("Delivery %.0f%% · landed-hit value unknown",
                resistance.landChance * 100), 0.82, 0.7, 0.42)
        end
        if math.abs(scored - (resistance.multiplier or 1)) > 0.001 then
            GameTooltip:AddLine("Graph-scored factor " .. roundedPercent(scored)
                .. "% · uncertainty reserve", 0.82, 0.7, 0.42)
        end
    else
        local base = resistance.multiplier or 1
        local label = resistance.schoolName or "Damage"
        if math.abs(scored - base) > 0.001 then
            GameTooltip:AddLine(label .. ": " .. roundedPercent(base)
                .. "% expected output", 0.62, 0.82, 1)
            GameTooltip:AddLine("Graph-scored factor " .. roundedPercent(scored)
                .. "% · vulnerability/uncertainty included", 0.72, 0.75, 0.82)
        else
            GameTooltip:AddLine(label .. ": " .. roundedPercent(base)
                .. "% expected output", 0.62, 0.82, 1)
        end
        if not compact then
            GameTooltip:AddLine((resistance.source or "modeled") .. " · "
                .. (resistance.confidence or "unknown confidence")
                .. ((resistance.samples or 0) > 0 and " · " .. resistance.samples .. " samples" or ""),
                0.55, 0.58, 0.64)
        end
        if resistance.landChance and resistance.mitigationOnLand and not compact
            and (resistance.landChance < 0.995 or resistance.mitigationOnLand < 0.995) then
            GameTooltip:AddLine(string.format("Land %.0f%% · landed-hit value %.0f%%",
                resistance.landChance * 100, resistance.mitigationOnLand * 100),
                0.72, 0.75, 0.82)
        end
        if resistance.raw ~= nil and not compact then
            local penetration = resistance.penetrationUnknown and "penetration unknown"
                or "penetration " .. math.floor((resistance.penetration or 0) + 0.5)
            GameTooltip:AddLine("Target value " .. math.floor(resistance.raw + 0.5)
                .. " · " .. penetration, 0.55, 0.58, 0.64)
        end
    end
    if resistance.components and not compact then
        local totalWeight, i = 0, nil
        for i = 1, table.getn(resistance.components) do
            totalWeight = totalWeight
                + math.max(0, tonumber(resistance.components[i].componentWeight) or 0)
        end
        for i = 1, table.getn(resistance.components) do
            local component = resistance.components[i]
            local label = component.componentPhase == "direct" and "Direct"
                or component.componentPhase == "periodic" and "Periodic"
                or component.schoolName or "Component"
            local base = component.multiplier or 1
            local weight = tonumber(component.componentWeight) or 0
            local componentScored = weight > 0 and component.decisionWeight
                and component.decisionWeight / weight or base
            local detail = label .. " " .. roundedPercent(base) .. "%"
            if totalWeight > 0 then
                detail = detail .. " · "
                    .. math.floor(weight * 100 / totalWeight + 0.5) .. "% share"
            end
            if math.abs(componentScored - base) > 0.001 then
                detail = detail .. " -> " .. roundedPercent(componentScored) .. "% scored"
            end
            if component.unknown then detail = detail .. " · uncertain" end
            if component.penetrationUnknown and component.school and component.school > 0 then
                detail = detail .. " · pen ?"
            end
            GameTooltip:AddLine(detail, component.unknown and 1 or 0.72,
                component.unknown and 0.72 or 0.75, component.unknown and 0.28 or 0.82)
        end
    end
end

local function showPredictionTooltip()
    local pip = this
    GameTooltip:SetOwner(pip, "ANCHOR_TOP")
    if pip.placeholder == true then
        GameTooltip:SetText("Future step " .. pip.stepIndex)
        GameTooltip:AddLine(pip.placeholderReason, 0.78, 0.80, 0.84)
        GameTooltip:AddLine("The rail stays visible because Settings requests look-ahead.",
            0.55, 0.58, 0.64)
    else
        GameTooltip:SetText(actionName(pip.action))
        local candidate = pip.candidate
        GameTooltip:AddLine(candidate and candidate.reason
            or "Predicted future action", 0.75, 0.78, 0.84)
        if candidate then
            GameTooltip:AddLine(pip.route:GetText() .. " · " .. pip.time:GetText(),
                0.64, 0.69, 0.76)
            local wait = math.max(0, tonumber(candidate.wait) or 0)
            local occupied = tonumber(candidate.occupancy)
                or math.max(0, (tonumber(candidate.downtime) or 0) - wait)
            GameTooltip:AddLine(string.format(
                "Predicted step %d · %.1fs wait · %.1fs occupied",
                pip.stepIndex, wait, occupied), 0.55, 0.58, 0.64)
            addResistanceLines(candidate, true)
        end
    end
    GameTooltip:Show()
end

function UI:SavePosition()
    if not self.frame then return end
    local point, _, relativePoint, x, y = self.frame:GetPoint()
    XelAssistDB.ui.position = { point = point, relativePoint = relativePoint, x = x, y = y,
        height = self.frameHeight or BASE_HEIGHT }
end

function UI:ResetPosition()
    if not self.frame then return end
    self.frame:ClearAllPoints()
    self.frame:SetPoint("TOP", UIParent, "CENTER", 0, -180)
    self:SavePosition()
end

function UI:SetVisiblePredictions(count)
    if not self.frame then return end
    self.visiblePredictions = math.max(0, math.min(4, tonumber(count) or 0))
end

function UI:MarkTargetDirty()
    self.targetDirty = true
    self.elapsed = 0
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
    local r, g, b = Theme:ClassColor()
    local f = CreateFrame("Frame", "XelAssistFrame", UIParent)
    local pos = XelAssistDB.ui.position
    self.frameHeight = BASE_HEIGHT
    f:SetWidth(372); f:SetHeight(BASE_HEIGHT)
    Theme:ApplyInstrumentBackdrop(f)
    f:SetFrameStrata("MEDIUM")
    if f.SetClampedToScreen then f:SetClampedToScreen(true) end

    if pos then f:SetPoint(pos.point or "CENTER", UIParent, pos.relativePoint or "CENTER", pos.x or 0, pos.y or -180)
    else f:SetPoint("TOP", UIParent, "CENTER", 0, -180) end
    f:SetScale(XelAssistDB.ui.scale or 1)

    f.classStripe = Theme:AddClassStripe(f)

    local actorBar = f:CreateTexture(nil, "ARTWORK")
    actorBar:SetHeight(2); actorBar:SetPoint("TOPLEFT", f, "TOPLEFT", 7, -72)
    actorBar:SetPoint("TOPRIGHT", f, "TOPRIGHT", -7, -72)
    actorBar:SetTexture(0.62, 0.38, 0.86, 1); actorBar:Hide()
    f.actorBar = actorBar

    local route = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    route:SetPoint("TOPLEFT", f, "TOPLEFT", 69, -8)
    route:SetWidth(210); route:SetHeight(12); route:SetJustifyH("LEFT")
    if route.SetNonSpaceWrap then route:SetNonSpaceWrap(false) end
    route:SetText("You -> Target")
    route:SetTextColor(r, g, b)
    f.route, f.eyebrow = route, route

    local status = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    status:SetPoint("TOPRIGHT", f, "TOPRIGHT", -8, -8)
    status:SetWidth(80); status:SetJustifyH("RIGHT")
    status:SetText("HOLD")
    status:SetTextColor(0.60, 0.64, 0.70)
    f.status = status

    local main = CreateFrame("Button", "XelAssistActionButton", f)
    main:SetWidth(52); main:SetHeight(52); main:SetPoint("TOPLEFT", f, "TOPLEFT", 12, -12)
    main.icon, main.iconFrame, main.cooldown = Theme:CreateActionIcon(main, 52, true)
    main.iconFrame:SetPoint("CENTER", main, "CENTER", 0, 0)
    main:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square")
    main.step = main:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmallGray")
    main.step:SetPoint("TOPLEFT", main, "TOPLEFT", 2, -2); main.step:SetText("01")
    main.binding = f:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmallGray")
    main.binding:SetPoint("TOPRIGHT", main, "TOPRIGHT", -2, -2)
    main.count = f:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
    main.count:SetPoint("BOTTOMRIGHT", main, "BOTTOMRIGHT", -2, 2)
    main:SetScript("OnClick", function() XelAssist:Execute() end)
    main:SetScript("OnEnter", function()
        GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
        local plan = UI.lastPlan
        if not plan then
            GameTooltip:SetText("No executable recommendation")
            GameTooltip:AddLine(UI.lastReason or "The graph is holding safely", 0.78, 0.80, 0.84)
        else
            GameTooltip:SetText("Execute recommendation")
            GameTooltip:AddLine("Re-evaluates now and performs one action.", 0.72, 0.82, 1)
            GameTooltip:AddLine(routeCopy(plan.action, plan.target),
                plan.actor == "pet" and 0.72 or 0.82,
                plan.actor == "pet" and 0.52 or 0.84,
                plan.actor == "pet" and 0.92 or 0.88)
            GameTooltip:AddLine(UI.lastReason or "No recommendation yet", 1, 1, 1)
            GameTooltip:AddLine(string.format("Downtime %.1fs · threat %d", plan.downtime or 0,
                math.floor(plan.threat or 0)), 0.72, 0.75, 0.82)
            local resistance = plan.resistance
            if resistance then addResistanceLines(plan, false) end
            local observed = plan.observed or {}
            if observed.distance then
                GameTooltip:AddLine(string.format("Range evidence %.1f yd · %s", observed.distance,
                    observed.distanceKind or "unknown"), 0.72, 0.75, 0.82)
            end
            GameTooltip:AddLine(string.format("Graph %d states · %.2fms%s", plan.expanded or 0,
                plan.elapsed or 0, plan.budgetLimited and " · runway limited" or ""), 0.55, 0.58, 0.64)
            if observed.talentPoints then
                GameTooltip:AddLine(string.format("Talent-adjusted client facts · %d points", observed.talentPoints),
                    0.55, 0.58, 0.64)
            end
            if plan.unknowns and table.getn(plan.unknowns) > 0 then
                GameTooltip:AddLine("Unknown: " .. table.concat(plan.unknowns, ", "), 1, 0.72, 0.28)
            end
            GameTooltip:AddLine("Mode " .. string.upper(XelAssist.mode or "smart") .. " · role "
                .. string.upper(XelAssistCharDB.role or "auto"), 0.55, 0.58, 0.64)
        end
        GameTooltip:Show()
    end)
    main:SetScript("OnLeave", function() GameTooltip:Hide() end)
    f.main = main

    local name = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    name:SetPoint("TOPLEFT", f, "TOPLEFT", 69, -25); name:SetWidth(286); name:SetHeight(14)
    name:SetJustifyH("LEFT")
    if name.SetNonSpaceWrap then name:SetNonSpaceWrap(false) end
    f.name = name
    local reason = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    reason:SetPoint("TOPLEFT", name, "BOTTOMLEFT", 0, -3); reason:SetWidth(225); reason:SetHeight(12)
    reason:SetJustifyH("LEFT")
    if reason.SetNonSpaceWrap then reason:SetNonSpaceWrap(false) end
    reason:SetTextColor(0.68, 0.71, 0.76)
    f.reason = reason

    local move = CreateFrame("Button", nil, f)
    move:SetWidth(34); move:SetHeight(15); move:SetPoint("TOPRIGHT", f, "TOPRIGHT", -42, -54)
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
    config:SetWidth(28); config:SetHeight(15); config:SetPoint("TOPRIGHT", f, "TOPRIGHT", -8, -54)
    config.text = config:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    config.text:SetAllPoints(config); config.text:SetText("CFG"); config.text:SetTextColor(0.48, 0.52, 0.58)
    config:SetScript("OnClick", function() XelAssist.UI.Settings:Toggle() end)
    config:SetScript("OnEnter", function() this.text:SetTextColor(r, g, b) end)
    config:SetScript("OnLeave", function() this.text:SetTextColor(0.48, 0.52, 0.58) end)
    f.config = config

    f.follow = {}
    local i
    for i = 1, 4 do
        local pip = CreateFrame("Frame", nil, f)
        pip:SetWidth(360); pip:SetHeight(STEP_HEIGHT)
        pip:SetPoint("TOPLEFT", f, "TOPLEFT", 6, -(BASE_HEIGHT + ((i - 1) * STEP_HEIGHT)))
        pip.background = pip:CreateTexture(nil, "BACKGROUND")
        pip.background:SetAllPoints(pip)
        pip.background:SetTexture(0.055, 0.075, 0.105, i == 1 and 0.92 or 0.72)
        pip.rail = pip:CreateTexture(nil, "ARTWORK")
        pip.rail:SetWidth(2); pip.rail:SetPoint("TOPLEFT", pip, "TOPLEFT", 13, 0)
        pip.rail:SetPoint("BOTTOMLEFT", pip, "BOTTOMLEFT", 13, 0)
        pip.rail:SetTexture(r, g, b, 0.58)
        pip.icon, pip.iconFrame = Theme:CreateActionIcon(pip, 20, false)
        pip.iconFrame:SetPoint("LEFT", pip, "LEFT", 24, 0)
        pip.step = pip:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmallGray")
        pip.step:SetPoint("LEFT", pip, "LEFT", 1, 0); pip.step:SetWidth(19)
        pip.step:SetJustifyH("CENTER"); pip.step:SetText(string.format("%02d", i + 1))
        pip.route = pip:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        pip.route:SetPoint("LEFT", pip, "LEFT", 49, 0); pip.route:SetWidth(112)
        pip.route:SetHeight(12); pip.route:SetJustifyH("LEFT")
        if pip.route.SetNonSpaceWrap then pip.route:SetNonSpaceWrap(false) end
        pip.route:SetTextColor(0.64, 0.69, 0.76)
        pip.name = pip:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        pip.name:SetPoint("LEFT", pip, "LEFT", 164, 0); pip.name:SetWidth(112)
        pip.name:SetHeight(12); pip.name:SetJustifyH("LEFT")
        if pip.name.SetNonSpaceWrap then pip.name:SetNonSpaceWrap(false) end
        pip.name:SetTextColor(0.90, 0.93, 0.96)
        pip.time = pip:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmallGray")
        pip.time:SetPoint("LEFT", pip, "LEFT", 278, 0); pip.time:SetWidth(41)
        pip.time:SetJustifyH("RIGHT")
        pip.certainty = pip:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        pip.certainty:SetPoint("RIGHT", pip, "RIGHT", -2, 0); pip.certainty:SetWidth(37)
        pip.certainty:SetJustifyH("RIGHT")
        pip:EnableMouse(true)
        pip:SetScript("OnEnter", showPredictionTooltip)
        pip:SetScript("OnLeave", function() GameTooltip:Hide() end)
        pip:Hide(); f.follow[i] = pip
    end

    local driver = CreateFrame("Frame", "XelAssistHUDDriver", f)
    driver:RegisterEvent("PLAYER_TARGET_CHANGED")
    driver:SetScript("OnEvent", function()
        if event == "PLAYER_TARGET_CHANGED" then UI:MarkTargetDirty() end
    end)
    driver:SetScript("OnUpdate", function()
        if UI.targetDirty then
            UI.targetDirty = nil
            UI.elapsed = 0
            return
        end
        UI.elapsed = (UI.elapsed or 0) + (arg1 or 0)
        if UI.elapsed >= 0.10 then UI.elapsed = 0; UI:Refresh(false) end
    end)
    self.driver = driver
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
        ok, plan, err = pcall(function() return XelAssist.Graph:Evaluate(XelAssist.mode, true) end)
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
        local classR, classG, classB = Theme:ClassColor()
        setFittedText(f.route, routeCopy(action, plan.target, plan.targetRef), 210)
        f.route:SetTextColor(petAction and 0.72 or classR,
            petAction and 0.48 or classG, petAction and 0.92 or classB)
        local certainty, cr, cg, cb = certaintyCopy(plan, nil)
        local first = plan.path and plan.path[1]
        f.status:SetText(timeCopy(first and first.actionStart or plan.wait) .. " · " .. certainty)
        f.status:SetTextColor(cr, cg, cb)
        if petAction then f.actorBar:Show() else f.actorBar:Hide() end
        f.main.icon:SetTexture(iconFor(action))
        Theme:SetIconActor(f.main.iconFrame, petAction and "pet" or "player")
        if f.main.icon.SetDesaturated then f.main.icon:SetDesaturated(false) end
        f.main:SetAlpha(1); f.main:Enable()
        setFittedText(f.name, actionName(action), 286)
        setFittedText(f.reason, plan.reason .. " · " .. plan.confidence, 225)
        updateCooldown(f.main, action)
        f.main.count:SetText(action.executor == "item" and tostring(action.count or "") or "")
        self.lastReason = actionName(action) .. " — " .. plan.reason
        local i, visible, placeholderShown = nil, 0, false
        local requested = math.max(0, math.min(4,
            (tonumber(XelAssistCharDB.graphDepth) or 1) - 1))
        local pathTime = math.max(0, tonumber(plan.downtime) or 0)
        for i = 1, 4 do
            local follow = plan.follow and plan.follow[i]
            local pip = f.follow[i]
            if follow and i <= requested and not placeholderShown then
                pip.icon:SetTexture(iconFor(follow)); pip:Show()
                if pip.icon.SetDesaturated then pip.icon:SetDesaturated(false) end
                visible = visible + 1
                Theme:SetIconActor(pip.iconFrame, follow.actor or "player")
                pip.action = follow
                pip.candidate = plan.path and plan.path[i + 1] or nil
                pip.placeholder = nil
                pip.stepIndex = i + 1
                setFittedText(pip.route,
                    routeCopy(follow, pip.candidate and pip.candidate.target,
                        pip.candidate and pip.candidate.targetRef), 112)
                pip.route:SetTextColor(follow.actor == "pet" and 0.72 or 0.64,
                    follow.actor == "pet" and 0.48 or 0.69,
                    follow.actor == "pet" and 0.92 or 0.76)
                setFittedText(pip.name, actionName(follow), 112)
                local start = pip.candidate and tonumber(pip.candidate.actionStart) or pathTime
                pip.time:SetText(timeCopy(start))
                local label, rr, rg, rb = certaintyCopy(nil, pip.candidate)
                pip.certainty:SetText(label); pip.certainty:SetTextColor(rr, rg, rb)
                if pip.candidate then
                    pathTime = math.max(pathTime, start or pathTime)
                        + math.max(0, tonumber(pip.candidate.downtime) or 0)
                end
            elseif i <= requested and not placeholderShown then
                placeholderShown = true; visible = visible + 1
                pip.action = nil; pip.candidate = nil; pip.placeholder = true
                pip.stepIndex = i + 1
                pip.placeholderReason = plan.budgetLimited
                    and "The graph's safe look-ahead budget ended before this step."
                    or "The current graph has no reliable continuation for this step."
                pip.icon:SetTexture(FALLBACK_ICON)
                if pip.icon.SetDesaturated then pip.icon:SetDesaturated(true) end
                Theme:SetIconActor(pip.iconFrame, "placeholder")
                pip.route:SetText("GRAPH HORIZON")
                pip.route:SetTextColor(0.48, 0.52, 0.58)
                setFittedText(pip.name, plan.budgetLimited and "Look-ahead limit"
                    or "No reliable next step", 112)
                pip.time:SetText("--")
                pip.certainty:SetText("OPEN"); pip.certainty:SetTextColor(0.95, 0.73, 0.34)
                pip:Show()
            else
                pip.action = nil; pip.candidate = nil; pip.placeholder = nil
                pip.route:SetText(""); pip.name:SetText(""); pip.time:SetText("")
                pip.certainty:SetText(""); pip:Hide()
            end
        end
        self:SetVisiblePredictions(visible)
    else
        f.route:SetText(string.upper(XelAssist.mode or "smart") .. " · "
            .. string.upper(XelAssistCharDB.role or "auto"))
        f.route:SetTextColor(0.60, 0.64, 0.70)
        f.status:SetText("HOLD"); f.status:SetTextColor(0.95, 0.73, 0.34)
        f.actorBar:Hide()
        local title, detail = emptyCopy(err)
        f.main.icon:SetTexture(FALLBACK_ICON)
        Theme:SetIconActor(f.main.iconFrame, "placeholder")
        if f.main.icon.SetDesaturated then f.main.icon:SetDesaturated(true) end
        f.main:SetAlpha(0.52); f.main:Disable()
        f.main.count:SetText("")
        updateCooldown(f.main, nil)
        setFittedText(f.name, title, 286); setFittedText(f.reason, detail, 225)
        local i
        for i = 1, 4 do
            f.follow[i].action = nil; f.follow[i].candidate = nil
            f.follow[i].placeholder = nil
            f.follow[i].route:SetText(""); f.follow[i].name:SetText("")
            f.follow[i].time:SetText(""); f.follow[i].certainty:SetText("")
            f.follow[i]:Hide()
        end
        self:SetVisiblePredictions(0)
        self.lastReason = title .. " — " .. detail
        self.lastPlan = nil
    end
    local key = GetBindingKey("XELASSIST_EXECUTE")
    f.main.binding:SetText(key or "")
end
