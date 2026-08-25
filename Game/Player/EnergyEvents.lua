-- Exact player energy-change and energize attribution bridge.
XelAssist.Game.Player.EnergyEvents = {}
local E = XelAssist.Game.Player.EnergyEvents
local Evidence = XelAssist.Game.Player.EnergyEvidence

local function playerIdentity()
    if type(XelAssist.PlayerGUID) == "function" then
        return XelAssist:PlayerGUID()
    end
    if not UnitExists then return nil end
    local exists, guid = UnitExists("player")
    return exists and guid or nil
end

local function observe()
    local guid = playerIdentity()
    return Evidence:Observe(guid, UnitMana("player"), UnitManaMax("player"),
        GetTime(), true, UnitPowerType and UnitPowerType("player") or nil)
end

function E:EnergizeRegistrationSupported()
    if type(GetNampowerVersion) ~= "function" then return false end
    local ok, major, minor = pcall(GetNampowerVersion)
    major, minor = tonumber(major), tonumber(minor)
    return ok and major and minor
        and (major > 4 or major == 4 and minor >= 5) or false
end

function E:OnEvent(eventName, a1, a2, _, a4)
    if eventName == "UNIT_ENERGY" and a1 == "player"
        or eventName == "UNIT_ENERGY_GUID" and tonumber(a2) == 1
            and a1 == playerIdentity() then
        return observe()
    elseif eventName == "SPELL_ENERGIZE_ON_SELF" then
        return Evidence:ObserveEnergize(a1, a4, GetTime())
    elseif eventName == "PLAYER_ENTERING_WORLD" then
        Evidence:ResetSession()
        return true
    elseif eventName == "CHARACTER_POINTS_CHANGED"
        or eventName == "UPDATE_SHAPESHIFT_FORM"
        or eventName == "UNIT_AURA" and a1 == "player" then
        Evidence:ModifierChanged("player energy modifier boundary")
        return true
    end
    return false
end

function E:RegisterEvents()
    if self.frame or type(CreateFrame) ~= "function" then return false end
    local frame = CreateFrame("Frame")
    local names = { "UNIT_ENERGY", "UNIT_ENERGY_GUID", "PLAYER_ENTERING_WORLD",
        "CHARACTER_POINTS_CHANGED", "UPDATE_SHAPESHIFT_FORM", "UNIT_AURA" }
    local i
    for i = 1, table.getn(names) do pcall(frame.RegisterEvent, frame, names[i]) end
    local attributed = false
    if self:EnergizeRegistrationSupported() then
        attributed = pcall(frame.RegisterEvent, frame, "SPELL_ENERGIZE_ON_SELF")
    end
    Evidence:SetEnergizeEvidenceAvailable(attributed)
    frame:SetScript("OnEvent", function()
        E:OnEvent(event, arg1, arg2, arg3, arg4)
    end)
    self.frame = frame
    return true
end

E:RegisterEvents()
