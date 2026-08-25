XelAssist = { Game = {} }
local now = 10
GetTime = function() return now end
dofile("Game/SpatialEvidence.lua")
local Spatial = XelAssist.Game.SpatialEvidence

local moving, sight, behind = Spatial:Snapshot("enemy-a", false, true, true)
assert(not moving and sight and behind,
    "initial positive geometry must be usable without artificial delay")

moving, sight, behind = Spatial:Snapshot("enemy-a", true, false, false)
assert(moving and sight == false and behind == false,
    "blocking movement and geometry evidence must apply immediately")
now = 10.05
moving, sight, behind = Spatial:Snapshot("enemy-a", false, true, true)
assert(moving and sight == false and behind == false,
    "a recovered edge must remain blocked during its settle window")
now = 10.21
moving, sight, behind = Spatial:Snapshot("enemy-a", false, true, true)
assert(not moving and sight and behind,
    "stable recovered evidence must become available")

local action = { name = "Backstab", rank = 1 }
assert(Spatial:Range(action, "enemy-a", true) == true)
assert(Spatial:Range(action, "enemy-a", false) == false)
now = 10.25
assert(Spatial:Range(action, "enemy-a", true) == false,
    "an out-of-range edge must not oscillate immediately back to usable")
now = 10.41
assert(Spatial:Range(action, "enemy-a", true) == true)
assert(Spatial:Range(action, "enemy-b", true) == true,
    "a new opaque target identity must start with its own evidence")

print("ok: movement and spatial release hysteresis")
