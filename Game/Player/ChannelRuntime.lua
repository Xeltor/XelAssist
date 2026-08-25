-- Compatibility ownership for the player's active cast/channel event record.
-- Native GetCastInfo remains authoritative; this bounded record supplies spell
-- and target identity plus a fallback when the detailed API is unavailable.
XelAssist.Game.Player.ChannelRuntime = {}
local C = XelAssist.Game.Player.ChannelRuntime

function C:Start(spellId, targetGUID, durationMs, channel)
    XelAssist.playerCastUntil = GetTime()
        + math.max(0, tonumber(durationMs) or 1500) / 1000
    XelAssist.playerCastName = SpellInfo and SpellInfo(spellId) or nil
    XelAssist.playerCastSpellId = spellId
    XelAssist.playerCastTargetGUID = targetGUID
    XelAssist.playerCastChannel = channel and true or false
end

function C:Clear()
    XelAssist.playerCastUntil, XelAssist.playerCastName = nil, nil
    XelAssist.playerCastSpellId, XelAssist.playerCastTargetGUID = nil, nil
    XelAssist.playerCastChannel = nil
end
