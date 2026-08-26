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

local function playerGuid()
    local exists, guid = UnitExists("player")
    if exists and guid then return guid end
end

-- SPELL_DELAYED_SELF carries one exact delay increment for a normal cast.
-- GetCastInfo is authoritative when available, but its compatibility fallback
-- must move by the same amount or it can publish a future action too early.
function C:Delay(casterGUID, delayMs)
    if casterGUID ~= playerGuid() or XelAssist.playerCastChannel then return false end
    local delay = tonumber(delayMs)
    local now = GetTime()
    if not delay or delay <= 0 or not XelAssist.playerCastUntil
        or XelAssist.playerCastUntil <= now then return false end
    XelAssist.playerCastUntil = XelAssist.playerCastUntil + delay / 1000
    return true
end

-- Nampower reports channel pushback as a new exact remaining time, not as a
-- delay. Keep that distinct from normal casts: vanilla channel pushback
-- shortens the channel rather than extending it.
function C:UpdateChannel(spellId, targetGUID, remainingMs)
    local remaining = tonumber(remainingMs)
    if not remaining or remaining < 0 or not XelAssist.playerCastChannel
        or tonumber(XelAssist.playerCastSpellId) ~= tonumber(spellId) then
        return false
    end
    if XelAssist.playerCastTargetGUID and targetGUID
        and targetGUID ~= "0x0000000000000000"
        and XelAssist.playerCastTargetGUID ~= targetGUID then return false end
    if remaining == 0 then self:Clear(); return true end
    XelAssist.playerCastUntil = GetTime() + remaining / 1000
    if targetGUID and targetGUID ~= "0x0000000000000000" then
        XelAssist.playerCastTargetGUID = targetGUID
    end
    return true
end
