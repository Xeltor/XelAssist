XelAssist = { Game = { Player = {} } }
table.getn = table.getn or function(value) return #value end
UnitExists = function(unit)
    if unit == "player" then return true, "player-guid" end
end
dofile("Game/Player/PushbackEvidence.lua")
local P = XelAssist.Game.Player.PushbackEvidence

assert(not P:Observe("other-guid", 500)
    and not P:Observe("player-guid", 0)
    and not P:Observe("player-guid", 2001),
    "malformed, foreign, and unbounded delay packets must be rejected")
assert(P:Observe("player-guid", 500)
    and P:Observe("player-guid", 750),
    "exact player delay increments must be learned")
local snapshot = P:Snapshot()
assert(snapshot.available and snapshot.samples == 2
    and snapshot.meanDelay == 0.625
    and snapshot.minimumDelay == 0.5
    and snapshot.maximumDelay == 0.75,
    "the bounded delay envelope must preserve exact sample arithmetic")
for i = 1, 10 do assert(P:Observe("player-guid", 400 + i * 10)) end
snapshot = P:Snapshot()
assert(snapshot.samples == P.MAX_SAMPLES and snapshot.minimumDelay == 0.43
    and snapshot.maximumDelay == 0.5,
    "the learner must retain only its newest bounded sample window")
P:Invalidate("talents changed")
assert(P:Snapshot() == nil and P:Status().lastReason == "talents changed",
    "regime invalidation must retire all learned pushback value")

print("ok: exact bounded player pushback evidence")
