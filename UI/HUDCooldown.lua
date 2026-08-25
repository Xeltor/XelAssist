-- Cooldown overlays are stateful widgets. Reapplying the same timer clears and
-- restarts the animation on Vanilla clients, so only material timer changes
-- are written to the frame.
XelAssist.UI.HUDCooldown = {}
local C = XelAssist.UI.HUDCooldown

local function apply(button, start, duration, enabled)
    start, duration = tonumber(start) or 0, tonumber(duration) or 0
    enabled = tonumber(enabled) or 0
    if duration <= 0 then start, duration, enabled = 0, 0, 0 end
    if button.xelCooldownStart == start
        and button.xelCooldownDuration == duration
        and button.xelCooldownEnabled == enabled then return false end
    button.xelCooldownStart, button.xelCooldownDuration = start, duration
    button.xelCooldownEnabled = enabled
    CooldownFrame_SetTimer(button.cooldown, start, duration, enabled)
    return true
end

function C:Update(button, action)
    if not (button and button.cooldown and CooldownFrame_SetTimer) then return false end
    if action and action.executor == "item" then
        if GetItemIdCooldown and action.itemId then
            local ok, info = pcall(GetItemIdCooldown, action.itemId)
            if ok and type(info) == "table" then
                local start = info.individualStartS
                local duration = (info.individualDurationMs or 0) / 1000
                if (info.categoryRemainingMs or 0)
                    > (info.individualRemainingMs or 0) then
                    start = info.categoryStartS
                    duration = (info.categoryDurationMs or 0) / 1000
                end
                return apply(button, start, duration, duration > 0 and 1 or 0)
            end
        end
        if GetContainerItemCooldown and action.bag and action.bagSlot then
            return apply(button,
                GetContainerItemCooldown(action.bag, action.bagSlot))
        end
        return apply(button, 0, 0, 0)
    end
    local slot = action and XelAssist.Game.Capabilities:SpellSlot(action.name)
    if not slot then return apply(button, 0, 0, 0) end
    return apply(button, GetSpellCooldown(slot, BOOKTYPE_SPELL))
end
