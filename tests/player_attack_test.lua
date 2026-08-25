XelAssist = { Game = {} }

local clock, liveAutoAttack, attackCalls = 10, 0, 0
GetTime = function() return clock end
GetCurrentCastingInfo = function()
    return 0, 0, 0, 0, 0, 0, liveAutoAttack
end
AttackTarget = function() attackCalls = attackCalls + 1 end

dofile("Game/PlayerAttack.lua")
local A = XelAssist.Game.PlayerAttack

local inactive = A:Snapshot()
local allowed, reason = A:CanStart(inactive)
assert(inactive.supported and inactive.activeKnown
    and inactive.active == false and not inactive.pending
    and allowed and reason == nil,
    "an exact inactive Nampower state must admit player Attack")

local targetGuid = {}
local started
started, reason = A:Start(targetGuid)
assert(started and reason == nil and attackCalls == 1,
    "player Attack must dispatch exactly once from proven inactivity")
local pending = A:Snapshot()
allowed, reason = A:CanStart(pending)
assert(pending.pending and pending.pendingTargetGuid == targetGuid
    and not allowed and reason == "player Attack start pending",
    "the submission latch must hold while the client state settles")
started, reason = A:Start(targetGuid)
assert(not started and reason == "player Attack start pending"
    and attackCalls == 1,
    "a repeated input must not toggle a pending Attack off")

clock = 1
local rewound = A:Snapshot()
assert(not rewound.pending and rewound.activeKnown and not rewound.active,
    "a combat-clock reset must retire a latch from the prior world timeline")
clock = 10.1
A:Start(targetGuid)

clock, liveAutoAttack = clock + 0.1, 1
local active = A:Snapshot()
allowed, reason = A:CanStart(active)
assert(active.activeKnown and active.active and not active.pending
    and attackCalls == 2
    and not allowed and reason == "player Attack already active",
    "the exact active state must retire the latch and block another press")
started, reason = A:Start(targetGuid)
assert(not started and attackCalls == 2,
    "an active Attack must never reach AttackTarget again")

clock, liveAutoAttack = clock + 1, nil
local unknown = A:Snapshot()
allowed, reason = A:CanStart(unknown)
assert(not unknown.activeKnown and unknown.active == nil
    and not allowed and reason == "player Attack state uncertain",
    "unknown Nampower state must hold rather than guess inactivity")

liveAutoAttack = 0
AttackTarget = nil
local unavailable = A:Snapshot()
allowed, reason = A:CanStart(unavailable)
assert(unavailable.activeKnown and unavailable.active == false
    and not allowed and reason == "player Attack command unavailable",
    "missing AttackTarget must not fall back to a toggle spell cast")

print("ok: exact player Attack state, submission latch and idempotent dispatch")
