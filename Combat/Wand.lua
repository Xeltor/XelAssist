-- Exact observation for the client-owned Shoot auto-repeat toggle.  Starting
-- Shoot is an action; subsequent wand bolts are ambient client activity.
-- Never infer that the toggle is inactive when its native action is absent.
XelAssist.Combat.Wand = {}
local W = XelAssist.Combat.Wand

local SHOOT_ID = 5019
local ACTION_SLOTS = 120
local SUBMISSION_GUARD = 1.5
local TIP_NAME = "XelAssistWandScanTooltip"
local actionTip

local function truthy(value)
    return value == true or value == 1
end

local function arrayCount(values)
    local count = 0
    while values[count + 1] ~= nil do count = count + 1 end
    return count
end

local function now()
    if type(GetTime) ~= "function" then return nil end
    local ok, value = pcall(GetTime)
    if ok and type(value) == "number" then return value end
    return nil
end

local function currentHostileGuid()
    if type(UnitExists) ~= "function"
        or type(UnitCanAttack) ~= "function" then return nil end
    local ok, exists, guid = pcall(UnitExists, "target")
    if not ok or not truthy(exists) then return nil end
    if guid == nil and type(UnitGUID) == "function" then
        ok, guid = pcall(UnitGUID, "target")
        if not ok then guid = nil end
    end
    if guid == nil then return nil end
    ok, exists = pcall(UnitCanAttack, "player", "target")
    if not ok or not truthy(exists) then return nil end
    if type(UnitIsDead) == "function" then
        ok, exists = pcall(UnitIsDead, "target")
        if not ok or truthy(exists) then return nil end
    end
    return guid
end

local function expectedName()
    if type(SpellInfo) == "function" then
        local ok, name = pcall(SpellInfo, SHOOT_ID)
        if ok and type(name) == "string" and name ~= "" then return name end
    end
    -- English clients can still be observed without ClassicAPI's SpellInfo.
    -- Other locales safely remain unknown unless SpellInfo supplies the name.
    return "Shoot"
end

local function scanAvailable()
    return type(CreateFrame) == "function" and type(getglobal) == "function"
        and type(GetActionTexture) == "function"
        and type(GetActionText) == "function"
        and type(IsEquippedAction) == "function"
end

local function tooltip()
    if actionTip ~= nil then return actionTip or nil end
    local ok, tip = pcall(CreateFrame, "GameTooltip", TIP_NAME,
        nil, "GameTooltipTemplate")
    if not ok or not tip or type(tip.ClearLines) ~= "function"
        or type(tip.SetAction) ~= "function" then
        actionTip = false
        return nil
    end
    if type(tip.SetOwner) == "function" then
        pcall(tip.SetOwner, tip, UIParent, "ANCHOR_NONE")
    end
    actionTip = tip
    return actionTip
end

local function actionName(slot)
    local ok, value = pcall(GetActionTexture, slot)
    if not ok then return nil, false end
    if value == nil then return nil, true end
    ok, value = pcall(GetActionText, slot)
    if not ok then return nil, false end
    if value ~= nil then return nil, true end
    ok, value = pcall(IsEquippedAction, slot)
    if not ok then return nil, false end
    if truthy(value) then return nil, true end
    local tip = tooltip()
    if not tip then return nil, false end
    ok = pcall(tip.ClearLines, tip)
    if not ok then return nil, false end
    ok = pcall(tip.SetAction, tip, slot)
    if not ok then return nil, false end
    local line
    ok, line = pcall(getglobal, TIP_NAME .. "TextLeft1")
    if not ok then return nil, false end
    if not line or type(line.GetText) ~= "function" then return nil, false end
    ok, value = pcall(line.GetText, line)
    if not ok then return nil, false end
    return value, true
end

function W:DiscoverSlots()
    if self.repeatSlots ~= nil then
        return self.repeatSlots, self.slotScanKnown
    end
    local slots, complete, slot = {}, scanAvailable(), nil
    if complete then
        local shoot = expectedName()
        for slot = 1, ACTION_SLOTS do
            local name, known = actionName(slot)
            if not known then complete = false end
            if known and name == shoot then table.insert(slots, slot) end
        end
    end
    self.repeatSlots, self.slotScanKnown = slots, complete
    return slots, complete
end

function W:LiveState()
    if type(IsAutoRepeatAction) ~= "function" then
        return nil, false, "Shoot repeat API unavailable", nil
    end
    local slots, scanKnown = self:DiscoverSlots()
    if not scanKnown or arrayCount(slots) == 0 then
        return nil, false, "native Shoot action slot unavailable", nil
    end
    local allKnown, i = true, nil
    for i = 1, arrayCount(slots) do
        local ok, active = pcall(IsAutoRepeatAction, slots[i])
        if ok and truthy(active) then
            return true, true, "native Shoot auto-repeat", slots[i]
        end
        if not ok or not (active == false or active == 0 or active == nil) then
            allKnown = false
        end
    end
    if allKnown then return false, true, "native Shoot auto-repeat", nil end
    return nil, false, "Shoot repeat query failed", nil
end

function W:RangedStats()
    local stats = { source = "ranged weapon stats unavailable",
        speedKnown = false, damageKnown = false }
    if type(UnitRangedDamage) ~= "function" then return stats end
    local ok, speed, low, high = pcall(UnitRangedDamage, "player")
    if not ok then return stats end
    speed, low, high = tonumber(speed), tonumber(low), tonumber(high)
    if speed and speed > 0 then
        stats.speed, stats.speedKnown = speed, true
    end
    if low and high and low >= 0 and high >= low and high > 0 then
        stats.lowDamage, stats.highDamage = low, high
        stats.averageDamage, stats.damageKnown = (low + high) / 2, true
    end
    if stats.speedKnown or stats.damageKnown then
        stats.source = "live UnitRangedDamage"
    end
    return stats
end

function W:RangedSpeed()
    local stats = self:RangedStats()
    return stats.speed, stats.source, stats.speedKnown
end

function W:RangedDamage()
    local stats = self:RangedStats()
    return stats.averageDamage, stats.lowDamage, stats.highDamage,
        stats.source, stats.damageKnown
end

function W:Snapshot()
    local at = now()
    if self.pendingUntil and at and (at >= self.pendingUntil
        or self.pendingSubmittedAt and at < self.pendingSubmittedAt) then
        self.pendingUntil, self.pendingSubmittedAt = nil, nil
        self.pendingTargetGuid = nil
    end
    local active, activeKnown, source, activeSlot = self:LiveState()
    local targetGuid = currentHostileGuid()
    local pending = self.pendingUntil ~= nil
        and (at == nil or at < self.pendingUntil) and true or false
    if active == true then
        self.pendingUntil, self.pendingSubmittedAt = nil, nil
        self.pendingTargetGuid = nil
        self.activeTargetGuid = targetGuid
        pending = false
    elseif activeKnown and active == false then
        self.activeTargetGuid = nil
    end
    local stats = self:RangedStats()
    local state = activeKnown and (active and "active" or "inactive") or "unknown"
    return { supported = type(IsAutoRepeatAction) == "function"
            and scanAvailable(),
        spellId = SHOOT_ID,
        state = state, active = active, activeKnown = activeKnown,
        source = source, actionSlot = activeSlot,
        currentTargetGuid = targetGuid,
        targetGuid = active and self.activeTargetGuid or nil,
        pending = pending,
        pendingTargetGuid = pending and self.pendingTargetGuid or nil,
        clockKnown = at ~= nil,
        rangedSpeed = stats.speed, rangedSpeedKnown = stats.speedKnown,
        rangedMinDamage = stats.lowDamage,
        rangedMaxDamage = stats.highDamage,
        rangedDamage = stats.averageDamage,
        rangedDamageKnown = stats.damageKnown,
        rangedStatsSource = stats.source }
end

function W:CanStart(snapshot)
    local state = snapshot or self:Snapshot()
    if state.pending then return false, "wand start pending" end
    if state.activeKnown ~= true or state.active == nil then
        return false, "wand state uncertain"
    end
    if state.active then return false, "wand already active" end
    if state.currentTargetGuid == nil then
        return false, "hostile target identity unavailable"
    end
    if not state.clockKnown then return false, "combat clock unavailable" end
    return true, nil
end

function W:Submitted(targetGuid)
    local snapshot = self:Snapshot()
    if snapshot.active then return true, "wand active confirmed" end
    if snapshot.pending then return true, "wand start already pending" end
    local current = snapshot.currentTargetGuid
    targetGuid = targetGuid or current
    if current == nil or targetGuid ~= current then
        return false, "hostile target identity unavailable"
    end
    local submittedAt = now()
    if submittedAt == nil then return false, "combat clock unavailable" end
    self.pendingSubmittedAt = submittedAt
    self.pendingUntil = submittedAt + SUBMISSION_GUARD
    self.pendingTargetGuid = targetGuid
    return true, nil
end

function W:Invalidate()
    self.repeatSlots, self.slotScanKnown = nil, nil
    if actionTip == false then actionTip = nil end
end

function W:Reset()
    self.pendingUntil, self.pendingSubmittedAt = nil, nil
    self.pendingTargetGuid, self.activeTargetGuid = nil, nil
    self:Invalidate()
end

function W:OnEvent(name, unit)
    if name == "PLAYER_ENTERING_WORLD" then self:Reset()
    elseif name == "ACTIONBAR_SLOT_CHANGED"
        or name == "ACTIONBAR_PAGE_CHANGED"
        or name == "UPDATE_BONUS_ACTIONBAR" then self:Invalidate()
    elseif name == "UNIT_INVENTORY_CHANGED" and unit == "player" then
        self:Invalidate()
    elseif name == "START_AUTOREPEAT_SPELL"
        or name == "STOP_AUTOREPEAT_SPELL"
        or name == "PLAYER_TARGET_CHANGED" then self:Snapshot() end
end

W:Reset()

if type(CreateFrame) == "function" then
    local frame = CreateFrame("Frame")
    frame:RegisterEvent("PLAYER_ENTERING_WORLD")
    frame:RegisterEvent("PLAYER_TARGET_CHANGED")
    frame:RegisterEvent("START_AUTOREPEAT_SPELL")
    frame:RegisterEvent("STOP_AUTOREPEAT_SPELL")
    frame:RegisterEvent("ACTIONBAR_SLOT_CHANGED")
    frame:RegisterEvent("ACTIONBAR_PAGE_CHANGED")
    frame:RegisterEvent("UPDATE_BONUS_ACTIONBAR")
    frame:RegisterEvent("UNIT_INVENTORY_CHANGED")
    frame:SetScript("OnEvent", function() W:OnEvent(event, arg1) end)
    W.frame = frame
end
