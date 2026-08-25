-- Runtime evidence bridge for Hunter focus learning. Standard control/aura
-- boundaries remain available without Nampower; detailed energize attribution
-- is enabled only when the installed DLL proves registration support.
XelAssist.Game.Pets.FocusEvents = {}
local F = XelAssist.Game.Pets.FocusEvents
local Evidence = XelAssist.Game.Pets.FocusEvidence

local function clockNow()
    if type(GetTime) ~= "function" then return nil end
    local ok, value = pcall(GetTime)
    if ok and type(value) == "number" then return value end
    return nil
end

function F:EnergizeRegistrationSupported()
    if type(GetNampowerVersion) ~= "function" then return false end
    local ok, major, minor = pcall(GetNampowerVersion)
    major, minor = tonumber(major), tonumber(minor)
    if not ok or not major or not minor then return false end
    return major > 4 or major == 4 and minor >= 5
end

function F:RegisterEnergizeEvents(frame)
    if not self:EnergizeRegistrationSupported()
        or not (frame and type(frame.RegisterEvent) == "function") then
        Evidence:SetEnergizeEvidenceAvailable(false)
        return false
    end
    local names = { "SPELL_ENERGIZE_BY_SELF", "SPELL_ENERGIZE_BY_OTHER",
        "SPELL_ENERGIZE_ON_SELF" }
    local registered, i = true, nil
    for i = 1, table.getn(names) do
        local ok = pcall(frame.RegisterEvent, frame, names[i])
        registered = registered and ok
    end
    Evidence:SetEnergizeEvidenceAvailable(registered)
    return registered
end

function F:RegisterRuntimeEvents(frame)
    if not (frame and type(frame.RegisterEvent) == "function") then
        Evidence.controlRegimeEventsAvailable = false
        return false, false
    end
    local names = { "CHARACTER_POINTS_CHANGED", "PLAYER_CONTROL_LOST",
        "PLAYER_CONTROL_GAINED", "UNIT_AURA" }
    local registered, i = true, nil
    for i = 1, table.getn(names) do
        local ok = pcall(frame.RegisterEvent, frame, names[i])
        registered = registered and ok
    end
    Evidence.controlRegimeEventsAvailable = registered
    return registered, self:RegisterEnergizeEvents(frame)
end

function F:OnRuntimeEvent(eventName, unit, powerType)
    if eventName == "CHARACTER_POINTS_CHANGED"
        or eventName == "PLAYER_CONTROL_LOST"
        or eventName == "PLAYER_CONTROL_GAINED" then
        local reason = eventName == "CHARACTER_POINTS_CHANGED"
            and "talent points changed" or "player control regime changed"
        Evidence:ModifierChanged(reason)
        return true
    end
    if eventName == "UNIT_AURA" then
        if unit ~= "pet" and unit ~= Evidence.guid then return false end
        Evidence:ModifierChanged("pet aura regime changed")
        return true
    end
    if eventName == "SPELL_ENERGIZE_BY_SELF"
        or eventName == "SPELL_ENERGIZE_BY_OTHER"
        or eventName == "SPELL_ENERGIZE_ON_SELF" then
        return Evidence:ObserveEnergize(unit, powerType, clockNow())
    end
    return false
end

function F:RegisterEvents()
    if self.eventFrame or type(CreateFrame) ~= "function" then return false end
    local frame = CreateFrame("Frame")
    self:RegisterRuntimeEvents(frame)
    frame:SetScript("OnEvent", function()
        F:OnRuntimeEvent(event, arg1, arg4)
    end)
    self.eventFrame = frame
    return true
end

F:RegisterEvents()
