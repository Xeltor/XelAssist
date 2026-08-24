XelAssist.UI.Settings = {}
local Config = XelAssist.UI.Settings

local function label(parent, text, template)
    local fs = parent:CreateFontString(nil, "OVERLAY", template or "GameFontNormal")
    fs:SetText(text)
    return fs
end

local function makeButton(parent, text, width, onClick)
    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    button:SetWidth(width); button:SetHeight(22); button:SetText(text)
    button:SetScript("OnClick", onClick)
    return button
end

local function storeFor(scope)
    if scope == "toggle" then return XelAssistCharDB.toggles end
    if scope == "character" then return XelAssistCharDB end
    return XelAssistDB.ui
end

local function makeCheck(parent, text, key, scope)
    local check = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    check:SetWidth(24); check:SetHeight(24)
    check.text = label(parent, text, "GameFontHighlightSmall")
    check.text:SetPoint("LEFT", check, "RIGHT", 2, 0)
    check:SetScript("OnClick", function()
        local store = storeFor(scope)
        store[key] = this:GetChecked() and true or false
        if key == "locked" and XelAssist.UI.HUD.frame then
            if store[key] then XelAssist.UI.HUD.frame.move:Hide() else XelAssist.UI.HUD.frame.move:Show() end
        elseif key == "shown" and XelAssist.UI.HUD.frame then
            if store[key] then XelAssist.UI.HUD.frame:Show() else XelAssist.UI.HUD.frame:Hide() end
        elseif key == "minimap" and XelAssist.UI.Minimap then
            XelAssist.UI.Minimap:SetVisible(store[key])
        end
        XelAssist.UI.HUD:Refresh(true)
    end)
    check.Refresh = function()
        local store = storeFor(scope)
        check:SetChecked(store[key] and true or false)
    end
    return check
end

function Config:Build()
    if self.frame then return end
    local f = CreateFrame("Frame", "XelAssistConfigFrame", UIParent)
    f:SetWidth(360); f:SetHeight(570); f:SetPoint("CENTER", UIParent, "CENTER", 0, 20)
    f:SetFrameStrata("DIALOG"); f:EnableMouse(true); f:SetMovable(true)
    f:SetBackdrop({ bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border", tile = true,
        tileSize = 32, edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 } })

    local title = label(f, "XelAssist", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", f, "TOPLEFT", 22, -20)
    local subtitle = label(f, "Character decisions · global display", "GameFontHighlightSmall")
    subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -5)
    subtitle:SetTextColor(0.7, 0.72, 0.76)

    local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", f, "TOPRIGHT", -4, -4)

    local modes = { { "Smart", "smart" }, { "Single", "single" },
        { "Area", "aoe" }, { "Support", "support" } }
    local i
    f.modes = {}
    for i = 1, table.getn(modes) do
        local entry = modes[i]
        local button = makeButton(f, entry[1], 75, function() XelAssist:SetMode(this.mode); Config:Refresh() end)
        button:SetPoint("TOPLEFT", f, "TOPLEFT", 22 + ((i - 1) * 79), -67)
        button.mode = entry[2]
        f.modes[i] = button
    end

    local risk = label(f, "This character · optional actions", "GameFontNormal")
    risk:SetPoint("TOPLEFT", f, "TOPLEFT", 22, -108)
    local riskHelp = label(f, "Off by default. Enable only what one press may spend.", "GameFontHighlightSmall")
    riskHelp:SetPoint("TOPLEFT", risk, "BOTTOMLEFT", 0, -4)
    riskHelp:SetTextColor(0.62, 0.65, 0.7)

    f.cooldowns = makeCheck(f, "Major cooldowns", "cooldowns", "toggle")
    f.cooldowns:SetPoint("TOPLEFT", f, "TOPLEFT", 20, -143)
    f.reagents = makeCheck(f, "Reagent abilities", "reagents", "toggle")
    f.reagents:SetPoint("TOPLEFT", f, "TOPLEFT", 188, -143)

    f.aoe = makeCheck(f, "Allow area actions in Smart", "allowAoe", "character")
    f.aoe:SetPoint("TOPLEFT", f, "TOPLEFT", 20, -173)
    f.consumables = makeCheck(f, "Use consumables", "consumables", "toggle")
    f.consumables:SetPoint("TOPLEFT", f, "TOPLEFT", 188, -173)

    local companion = label(f, "This character · companion", "GameFontNormal")
    companion:SetPoint("TOPLEFT", f, "TOPLEFT", 22, -207)
    f.petActions = makeCheck(f, "Use companion actions", "petActions", "toggle")
    f.petActions:SetPoint("TOPLEFT", f, "TOPLEFT", 20, -226)
    f.petControl = makeCheck(f, "Allow crowd control", "petControl", "toggle")
    f.petControl:SetPoint("TOPLEFT", f, "TOPLEFT", 188, -226)
    local petThreat = label(f, "Companion threat", "GameFontHighlightSmall")
    petThreat:SetPoint("TOPLEFT", f, "TOPLEFT", 22, -260)
    local threatModes = { { "Auto", "auto" }, { "Tank", "tank" }, { "Avoid", "avoid" } }
    f.petThreats = {}
    for i = 1, table.getn(threatModes) do
        local entry = threatModes[i]
        local button = makeButton(f, entry[1], 96, function()
            XelAssistCharDB.petThreat = this.petThreat; Config:Refresh(); XelAssist.UI.HUD:Refresh(true)
        end)
        button:SetPoint("TOPLEFT", f, "TOPLEFT", 22 + ((i - 1) * 101), -276)
        button.petThreat = entry[2]; f.petThreats[i] = button
    end

    local role = label(f, "Character role", "GameFontNormal")
    role:SetPoint("TOPLEFT", f, "TOPLEFT", 22, -313)
    local roles = { { "Auto", "auto" }, { "Tank", "tank" }, { "Damage", "damage" }, { "Healer", "healer" } }
    f.roles = {}
    for i = 1, table.getn(roles) do
        local entry = roles[i]
        local button = makeButton(f, entry[1], 75, function()
            XelAssistCharDB.role = this.role; Config:Refresh(); XelAssist.UI.HUD:Refresh(true)
        end)
        button:SetPoint("TOPLEFT", f, "TOPLEFT", 22 + ((i - 1) * 79), -334)
        button.role = entry[2]; f.roles[i] = button
    end

    local display = label(f, "All characters · display", "GameFontNormal")
    display:SetPoint("TOPLEFT", f, "TOPLEFT", 22, -377)
    f.locked = makeCheck(f, "Lock position", "locked", "global")
    f.locked:SetPoint("TOPLEFT", f, "TOPLEFT", 20, -398)
    f.shown = makeCheck(f, "Show recommendations", "shown", "global")
    f.shown:SetPoint("TOPLEFT", f, "TOPLEFT", 188, -398)
    f.minimap = makeCheck(f, "Show minimap button", "minimap", "global")
    f.minimap:SetPoint("TOPLEFT", f, "TOPLEFT", 20, -426)

    local slider = CreateFrame("Slider", "XelAssistScaleSlider", f, "OptionsSliderTemplate")
    slider:SetWidth(125); slider:SetHeight(16); slider:SetPoint("TOPLEFT", f, "TOPLEFT", 185, -430)
    slider:SetMinMaxValues(0.7, 1.5); slider:SetValueStep(0.1)
    getglobal(slider:GetName() .. "Low"):SetText("70%")
    getglobal(slider:GetName() .. "High"):SetText("150%")
    getglobal(slider:GetName() .. "Text"):SetText("Recommendation size")
    slider:SetScript("OnValueChanged", function() XelAssist.UI.HUD:SetScale(this:GetValue()) end)
    f.slider = slider

    local depth = CreateFrame("Slider", "XelAssistDepthSlider", f, "OptionsSliderTemplate")
    depth:SetWidth(125); depth:SetHeight(16); depth:SetPoint("TOPLEFT", f, "TOPLEFT", 25, -474)
    depth:SetMinMaxValues(1, 5); depth:SetValueStep(1)
    getglobal(depth:GetName() .. "Low"):SetText("1")
    getglobal(depth:GetName() .. "High"):SetText("5")
    getglobal(depth:GetName() .. "Text"):SetText("Visible action steps")
    depth:SetScript("OnValueChanged", function()
        XelAssistCharDB.graphDepth = math.floor(this:GetValue() + 0.5)
        XelAssist.UI.HUD:Refresh(true)
    end)
    f.depth = depth

    local macroLabel = label(f, "Macro command", "GameFontNormalSmall")
    macroLabel:SetPoint("TOPLEFT", f, "TOPLEFT", 185, -471)
    local macro = CreateFrame("EditBox", nil, f, "InputBoxTemplate")
    macro:SetWidth(125); macro:SetHeight(20); macro:SetPoint("TOPLEFT", macroLabel, "BOTTOMLEFT", 4, -4)
    macro:SetAutoFocus(false); macro:SetText("/xa")
    macro:SetScript("OnEscapePressed", function() this:ClearFocus() end)
    macro:SetScript("OnEditFocusGained", function() this:HighlightText() end)
    f.macro = macro

    local reset = makeButton(f, "Reset position", 105, function() XelAssist.UI.HUD:ResetPosition() end)
    reset:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 20, 20)
    f:SetScript("OnShow", function() Config:Refresh() end)
    self.frame = f
    f:Hide()
end

function Config:Refresh()
    if not self.frame then return end
    local f = self.frame
    local i
    for i = 1, table.getn(f.modes) do
        local selected = f.modes[i].mode == XelAssist.mode
        f.modes[i]:SetButtonState(selected and "PUSHED" or "NORMAL", selected)
    end
    for i = 1, table.getn(f.roles) do
        local selected = f.roles[i].role == (XelAssistCharDB.role or "auto")
        f.roles[i]:SetButtonState(selected and "PUSHED" or "NORMAL", selected)
    end
    for i = 1, table.getn(f.petThreats) do
        local selected = f.petThreats[i].petThreat == (XelAssistCharDB.petThreat or "auto")
        f.petThreats[i]:SetButtonState(selected and "PUSHED" or "NORMAL", selected)
    end
    f.cooldowns.Refresh(); f.reagents.Refresh(); f.consumables.Refresh(); f.petActions.Refresh(); f.petControl.Refresh()
    f.aoe.Refresh(); f.locked.Refresh(); f.shown.Refresh(); f.minimap.Refresh()
    f.slider:SetValue(XelAssistDB.ui.scale or 1)
    f.depth:SetValue(XelAssistCharDB.graphDepth or 3)
end

function Config:Toggle()
    self:Build()
    if self.frame:IsShown() then self.frame:Hide() else self.frame:Show() end
end
