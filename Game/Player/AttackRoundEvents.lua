-- Stock player-state boundaries that invalidate an exact main-hand phase.
-- Exact rounds themselves are routed separately from Nampower combat events.
XelAssist.Game.Player.AttackRoundEvents = {}
local E = XelAssist.Game.Player.AttackRoundEvents
local Rounds = XelAssist.Game.Player.AttackRounds
local Offhand = XelAssist.Game.Player.OffhandAttackRounds

local EVENTS = {
    "PLAYER_ENTERING_WORLD", "PLAYER_TARGET_CHANGED",
    "PLAYER_ENTER_COMBAT", "PLAYER_LEAVE_COMBAT",
    "UNIT_ATTACK_SPEED", "UNIT_INVENTORY_CHANGED",
    "UPDATE_SHAPESHIFT_FORM", "UPDATE_SHAPESHIFT_FORMS",
    "PLAYER_CONTROL_LOST", "PLAYER_CONTROL_GAINED",
}

local function playerUnit(unit)
    return unit == nil or unit == "player"
end

function E:OnEvent(eventName, unit)
    if eventName == "PLAYER_ENTERING_WORLD" then
        Rounds:RegimeChanged("world transition")
        if Offhand then Offhand:RegimeChanged("world transition") end
    elseif eventName == "PLAYER_TARGET_CHANGED" then
        Rounds:TargetChanged()
        if Offhand then Offhand:TargetChanged() end
    elseif eventName == "PLAYER_ENTER_COMBAT" then
        Rounds:AttackStateChanged(true)
        if Offhand then Offhand:AttackStateChanged(true) end
    elseif eventName == "PLAYER_LEAVE_COMBAT" then
        Rounds:AttackStateChanged(false)
        if Offhand then Offhand:AttackStateChanged(false) end
    elseif eventName == "UNIT_ATTACK_SPEED" and playerUnit(unit) then
        Rounds:SpeedChanged()
        if Offhand then Offhand:SpeedChanged() end
    elseif eventName == "UNIT_INVENTORY_CHANGED" and playerUnit(unit) then
        Rounds:EquipmentChanged()
        if Offhand then Offhand:EquipmentChanged() end
    elseif eventName == "UPDATE_SHAPESHIFT_FORM"
        or eventName == "UPDATE_SHAPESHIFT_FORMS" then
        Rounds:FormChanged()
        if Offhand then Offhand:FormChanged() end
    elseif eventName == "PLAYER_CONTROL_LOST"
        or eventName == "PLAYER_CONTROL_GAINED" then
        Rounds:ControlChanged()
        if Offhand then Offhand:ControlChanged() end
    else return false end
    return true
end

function E:RegisterEvents()
    if self.eventFrame or type(CreateFrame) ~= "function" then return false end
    local frame, index = CreateFrame("Frame"), nil
    for index = 1, table.getn(EVENTS) do
        pcall(frame.RegisterEvent, frame, EVENTS[index])
    end
    frame:SetScript("OnEvent", function() E:OnEvent(event, arg1) end)
    self.eventFrame = frame
    return true
end

E:RegisterEvents()
