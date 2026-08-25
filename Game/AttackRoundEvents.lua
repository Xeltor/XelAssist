-- Stock pet-state boundaries that invalidate resolved swing phase. Exact
-- attack rounds themselves are routed by Core/Runtime from Nampower.
XelAssist.Game.AttackRoundEvents = {}
local E = XelAssist.Game.AttackRoundEvents
local Rounds = XelAssist.Game.AttackRounds

local EVENTS = {
    "PLAYER_ENTERING_WORLD", "PLAYER_PET_CHANGED", "UNIT_PET",
    "PET_ATTACK_START", "PET_ATTACK_STOP", "UNIT_TARGET",
    "UNIT_ATTACK_SPEED", "UNIT_ATTACK", "UNIT_AURA", "UNIT_LEVEL",
    "PLAYER_CONTROL_LOST", "PLAYER_CONTROL_GAINED",
}

local function petEventUnit(unit)
    return unit == nil or unit == "pet"
end

function E:OnEvent(eventName, unit)
    if eventName == "PET_ATTACK_START" then
        Rounds:AttackStateChanged(true)
    elseif eventName == "PET_ATTACK_STOP" then
        Rounds:AttackStateChanged(false)
    elseif eventName == "PLAYER_ENTERING_WORLD" then
        Rounds:RegimeChanged("world transition")
    elseif eventName == "PLAYER_PET_CHANGED"
        or eventName == "UNIT_PET" and (unit == nil or unit == "player") then
        Rounds:RegimeChanged("companion identity event")
    elseif eventName == "PLAYER_CONTROL_LOST"
        or eventName == "PLAYER_CONTROL_GAINED" then
        Rounds:RegimeChanged("player control regime changed")
    elseif eventName == "UNIT_TARGET" and petEventUnit(unit) then
        Rounds:RegimeChanged("companion target changed")
    elseif (eventName == "UNIT_ATTACK_SPEED" or eventName == "UNIT_ATTACK"
        or eventName == "UNIT_AURA" or eventName == "UNIT_LEVEL")
        and petEventUnit(unit) then
        Rounds:RegimeChanged("companion attack regime changed")
    else return false end
    return true
end

function E:RegisterEvents()
    if self.eventFrame or type(CreateFrame) ~= "function" then return false end
    local frame = CreateFrame("Frame")
    local index
    for index = 1, table.getn(EVENTS) do
        pcall(frame.RegisterEvent, frame, EVENTS[index])
    end
    frame:SetScript("OnEvent", function() E:OnEvent(event, arg1) end)
    self.eventFrame = frame
    return true
end

E:RegisterEvents()
