XelAssistUI = {}
local UI = XelAssistUI
local FALLBACK_ICON = "Interface\\Icons\\INV_Misc_QuestionMark"

local function iconFor(name)
    local slot = name and XelAssistCapabilities:SpellSlot(name)
    return slot and GetSpellTexture(slot, BOOKTYPE_SPELL) or FALLBACK_ICON
end

local function setAction(button, action)
    if action then button.icon:SetTexture(iconFor(action[1])); button.name:SetText(action[1])
    else button.icon:SetTexture(FALLBACK_ICON); button.name:SetText("Hold") end
end

function UI:Build()
    if self.frame then return end
    local f = CreateFrame("Frame", "XelAssistFrame", UIParent)
    f:SetWidth(300); f:SetHeight(106); f:SetPoint("CENTER", UIParent, "CENTER", 0, -180)
    f:SetMovable(true); f:EnableMouse(true); f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function() this:StartMoving() end)
    f:SetScript("OnDragStop", function() this:StopMovingOrSizing() end)

    local main = CreateFrame("Button", "XelAssistActionButton", f, "ActionButtonTemplate")
    main:SetWidth(64); main:SetHeight(64); main:SetPoint("LEFT", f, "LEFT", 8, 0)
    main.icon = getglobal("XelAssistActionButtonIcon") or main:CreateTexture(nil, "ARTWORK")
    main.icon:SetAllPoints(main)
    main.name = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    main.name:SetPoint("TOPLEFT", main, "TOPRIGHT", 9, -2); main.name:SetWidth(190); main.name:SetJustifyH("LEFT")
    main.reason = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    main.reason:SetPoint("TOPLEFT", main.name, "BOTTOMLEFT", 0, -4); main.reason:SetWidth(190); main.reason:SetJustifyH("LEFT")
    main.binding = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    main.binding:SetPoint("TOPRIGHT", main, "TOPRIGHT", -2, -2)
    main:SetScript("OnClick", function() XelAssist:Execute() end)
    main:SetScript("OnEnter", function()
        GameTooltip:SetOwner(this, "ANCHOR_RIGHT"); GameTooltip:SetText("XelAssist smart execute")
        GameTooltip:AddLine(UI.lastReason or "Previewing...", 1, 1, 1); GameTooltip:Show()
    end)
    main:SetScript("OnLeave", function() GameTooltip:Hide() end)
    f.main = main

    local i
    f.follow = {}
    for i = 1, 2 do
        local b = CreateFrame("Button", nil, f, "ActionButtonTemplate")
        b:SetWidth(28); b:SetHeight(28); b:SetPoint("BOTTOMLEFT", main, "BOTTOMRIGHT", 8 + (i - 1) * 98, 0)
        b.icon = b:CreateTexture(nil, "ARTWORK"); b.icon:SetAllPoints(b)
        b.name = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        b.name:SetPoint("LEFT", b, "RIGHT", 4, 0); b.name:SetWidth(65); b.name:SetJustifyH("LEFT")
        f.follow[i] = b
    end
    f:SetScript("OnUpdate", function()
        UI.elapsed = (UI.elapsed or 0) + (arg1 or 0)
        if UI.elapsed >= 0.20 then UI.elapsed = 0; UI:Refresh(false) end
    end)
    self.frame = f
    self:Refresh(true)
end

function UI:Refresh(force)
    if not self.frame then return end
    local plan, err = XelAssistGraph:Evaluate(XelAssist.mode, true)
    if plan then
        setAction(self.frame.main, plan.action)
        self.frame.main.reason:SetText(plan.reason .. " · " .. plan.confidence .. " confidence")
        self.lastReason = plan.action[1] .. " — " .. plan.reason
        local i
        for i = 1, 2 do setAction(self.frame.follow[i], plan.follow[i]) end
    else
        setAction(self.frame.main, nil); self.frame.main.reason:SetText(err or "fallback")
        setAction(self.frame.follow[1], nil); setAction(self.frame.follow[2], nil)
        self.lastReason = err
    end
    local key = GetBindingKey("XELASSIST_EXECUTE")
    self.frame.main.binding:SetText(key or "")
end
