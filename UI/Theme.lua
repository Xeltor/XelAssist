XelAssist.UI.Theme = {}
local Theme = XelAssist.UI.Theme

Theme.colors = {
    void = { 0.025, 0.035, 0.055, 0.96 },
    gunmetal = { 0.22, 0.25, 0.31, 1 },
    quiet = { 0.10, 0.13, 0.18, 0.82 },
    evidence = { 0.95, 0.73, 0.34, 1 },
    companion = { 0.72, 0.48, 0.92, 1 },
}

function Theme:ClassColor()
    local _, class = UnitClass("player")
    local color = RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
    if color then return color.r, color.g, color.b end
    return 0.25, 0.72, 1
end

function Theme:ApplyInstrumentBackdrop(frame)
    frame:SetBackdrop({ bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", tile = true,
        tileSize = 16, edgeSize = 10,
        insets = { left = 3, right = 3, top = 3, bottom = 3 } })
    local void, metal = self.colors.void, self.colors.gunmetal
    frame:SetBackdropColor(void[1], void[2], void[3], void[4])
    frame:SetBackdropBorderColor(metal[1], metal[2], metal[3], metal[4])
    frame.instrumentStyle = true
end

function Theme:AddClassStripe(frame)
    local r, g, b = self:ClassColor()
    local stripe = frame:CreateTexture(nil, "ARTWORK")
    stripe:SetWidth(3)
    stripe:SetPoint("TOPLEFT", frame, "TOPLEFT", 4, -5)
    stripe:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 4, 5)
    stripe:SetTexture(r, g, b, 1)
    return stripe
end

function Theme:AddSectionRail(frame, y)
    local rail = frame:CreateTexture(nil, "ARTWORK")
    rail:SetHeight(1)
    rail:SetPoint("TOPLEFT", frame, "TOPLEFT", 22, y)
    rail:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -22, y)
    local quiet = self.colors.quiet
    rail:SetTexture(quiet[1], quiet[2], quiet[3], quiet[4])
    return rail
end

function Theme:CreateActionIcon(owner, size, withCooldown)
    local plate = owner:CreateTexture(nil, "BORDER")
    plate:SetWidth(size); plate:SetHeight(size)
    local icon = owner:CreateTexture(nil, "ARTWORK")
    icon:SetWidth(size - 2); icon:SetHeight(size - 2)
    icon:SetPoint("CENTER", plate, "CENTER", 0, 0)
    local cooldown
    if withCooldown then
        cooldown = CreateFrame("Cooldown", nil, owner, "CooldownFrameTemplate")
        cooldown:SetWidth(size - 2); cooldown:SetHeight(size - 2)
        cooldown:SetPoint("CENTER", owner, "CENTER", 0, 0)
    end
    return icon, plate, cooldown
end

function Theme:SetIconActor(plate, actor)
    if actor == "pet" then
        local color = self.colors.companion
        plate:SetTexture(color[1], color[2], color[3], color[4])
    elseif actor == "placeholder" then
        local color = self.colors.gunmetal
        plate:SetTexture(color[1], color[2], color[3], color[4])
    else
        local r, g, b = self:ClassColor()
        plate:SetTexture(r, g, b, 1)
    end
end

local function trimLastCharacter(value)
    local index = string.len(value)
    while index > 0 do
        local byte = string.byte(value, index)
        index = index - 1
        if byte < 128 or byte >= 192 then break end
    end
    return string.sub(value, 1, index)
end

function Theme.SetFittedText(fontString, value, maxWidth)
    value = tostring(value or "")
    fontString:SetText(value)
    if not fontString.GetStringWidth then return end
    local ok, width = pcall(fontString.GetStringWidth, fontString)
    if not ok or type(width) ~= "number" then return end
    local fitted = value
    while width > maxWidth and fitted ~= "" do
        fitted = trimLastCharacter(fitted)
        fontString:SetText(fitted .. "..")
        ok, width = pcall(fontString.GetStringWidth, fontString)
        if not ok or type(width) ~= "number" then return end
    end
end
