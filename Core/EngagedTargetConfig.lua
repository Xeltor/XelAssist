-- Character policy initialization and slash-command boundary for optional
-- GUID-directed casts at enemies already proven part of the active fight.
XelAssist.Core.EngagedTargetConfig = {}
local C = XelAssist.Core.EngagedTargetConfig

function C:Initialize()
    if XelAssistCharDB.toggles.engagedTargets == nil then
        XelAssistCharDB.toggles.engagedTargets = false
    end
    XelAssistCharDB.schema = 5
end

function C:Command(command)
    if command ~= "engaged" and command ~= "engagedtargets" then
        return false
    end
    local current = XelAssistCharDB.toggles.engagedTargets
    XelAssistCharDB.toggles.engagedTargets = not current
    DEFAULT_CHAT_FRAME:AddMessage("XelAssist: engaged enemy casts "
        .. (not current and "enabled" or "disabled") .. ".", 0.35, 0.85, 1)
    if XelAssist.UI and XelAssist.UI.HUD then
        XelAssist.UI.HUD:RequestRefresh(true)
    end
    return true
end
