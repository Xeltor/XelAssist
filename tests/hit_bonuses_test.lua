XelAssist = { Game = {} }
local now, calls = 10, 0
GetTime = function() return now end
C_PlayerInfo = { GetEquippedHitBonuses = function()
    calls = calls + 1
    return 2, 3, 4, 17
end }

dofile("Game/HitBonuses.lua")
local H = XelAssist.Game.HitBonuses
local observed = H:Snapshot()
assert(observed.melee == 2 and observed.ranged == 3 and observed.spell == 4
    and observed.equipped == 17 and observed.equipmentKnown
    and not observed.totalKnown and observed.gap == "talent and aura +hit",
    "the exact equipped hit aggregate must stay separate from unresolved character hit")
H:Snapshot()
assert(calls == 1, "same-snapshot equipped hit reads must be cached")

H:Invalidate()
C_PlayerInfo.GetEquippedHitBonuses = function() return nil end
observed = H:Snapshot()
assert(not observed.equipmentKnown and observed.melee == 0
    and observed.gap == "equipment, talent and aura +hit",
    "an unavailable native aggregate must not become a partial hit total")

print("ok: exact equipped hit capability and conservative total gap")
