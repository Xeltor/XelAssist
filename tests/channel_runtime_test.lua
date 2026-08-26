XelAssist = { Game = { Player = {} } }

local now = 10
GetTime = function() return now end
UnitExists = function(unit)
    if unit == "player" then return true, "player-guid" end
    return false
end
SpellInfo = function(spellId) return "Spell " .. tostring(spellId) end

dofile("Game/Player/ChannelRuntime.lua")
local runtime = XelAssist.Game.Player.ChannelRuntime

runtime:Start(116, "enemy-a", 2500, false)
assert(runtime:Delay("player-guid", 500)
    and math.abs(XelAssist.playerCastUntil - 13) < 0.001,
    "exact normal-cast pushback must extend fallback occupancy")
assert(not runtime:Delay("other-guid", 500)
    and math.abs(XelAssist.playerCastUntil - 13) < 0.001,
    "another caster must not move player cast timing")

runtime:Start(5143, "enemy-a", 5000, true)
assert(not runtime:Delay("player-guid", 500)
    and math.abs(XelAssist.playerCastUntil - 15) < 0.001,
    "normal pushback evidence must never extend a channel")
now = 11
assert(runtime:UpdateChannel(5143, "enemy-a", 3200)
    and math.abs(XelAssist.playerCastUntil - 14.2) < 0.001,
    "exact channel update must re-anchor fallback remaining time")
assert(not runtime:UpdateChannel(5143, "enemy-b", 1000)
    and math.abs(XelAssist.playerCastUntil - 14.2) < 0.001,
    "a mutated channel target must fail closed")
assert(not runtime:UpdateChannel(9999, "enemy-a", 1000),
    "a stale channel spell must fail closed")
assert(runtime:UpdateChannel(5143, "enemy-a", 0)
    and not XelAssist.playerCastUntil and not XelAssist.playerCastChannel,
    "an exact zero-remaining update must clear channel occupancy")

print("channel runtime tests passed")
