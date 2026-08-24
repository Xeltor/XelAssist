XelAssist.UI.Minimap = {}
local MinimapButton = XelAssist.UI.Minimap

function MinimapButton:Build()
    if self.button or not Minimap then return end
    local button = CreateFrame("Button", "XelAssistMinimapButton", Minimap)
    button:SetWidth(30); button:SetHeight(30)
    button:SetPoint("TOPLEFT", Minimap, "TOPLEFT", 0, -4)
    button:SetFrameStrata("MEDIUM"); button:SetFrameLevel(Minimap:GetFrameLevel() + 3)
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

    local border = button:CreateTexture(nil, "OVERLAY")
    border:SetWidth(52); border:SetHeight(52); border:SetPoint("TOPLEFT", button, "TOPLEFT", 0, 0)
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    local icon = button:CreateTexture(nil, "BACKGROUND")
    icon:SetWidth(18); icon:SetHeight(18); icon:SetPoint("CENTER", button, "CENTER", -1, 1)
    icon:SetTexture("Interface\\Icons\\Spell_Holy_MindVision")
    button.icon = icon

    button:SetScript("OnClick", function()
        if arg1 == "RightButton" then XelAssist.UI.Settings:Toggle()
        elseif XelAssist.UI.HUD.frame:IsShown() then
            XelAssist.UI.HUD.frame:Hide(); XelAssistDB.ui.shown = false
        else XelAssist.UI.HUD.frame:Show(); XelAssistDB.ui.shown = true end
    end)
    button:SetScript("OnEnter", function()
        GameTooltip:SetOwner(this, "ANCHOR_LEFT")
        GameTooltip:SetText("XelAssist")
        GameTooltip:AddLine("Left-click: show or hide recommendations", 1, 1, 1)
        GameTooltip:AddLine("Right-click: settings", 1, 1, 1)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function() GameTooltip:Hide() end)
    self.button = button
    self:SetVisible(XelAssistDB.ui.minimap ~= false)
end

function MinimapButton:SetVisible(visible)
    if not self.button then self:Build() end
    if not self.button then return end
    if visible then self.button:Show() else self.button:Hide() end
end
