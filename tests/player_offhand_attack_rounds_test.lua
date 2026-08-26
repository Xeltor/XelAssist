XelAssist = { Game = { Player = {} } }
table.getn = table.getn or function(values)
    local count = 0
    while values[count + 1] ~= nil do count = count + 1 end
    return count
end

local playerGuid, targetGuid, otherGuid = {}, {}, {}
local clock, selected = 10, targetGuid
local mainSpeed, offSpeed = 2.4, 1.6
local stockSpeed, stockDamage = true, true

GetTime = function() return clock end
UnitExists = function(unit)
    if unit == "player" then return true, playerGuid end
    if unit == "target" and selected then return true, selected end
    return false, nil
end
UnitAttackSpeed = function(unit)
    assert(unit == "player")
    if not stockSpeed then error("stock speed disabled") end
    return mainSpeed, offSpeed
end
UnitDamage = function(unit)
    assert(unit == "player")
    if not stockDamage then error("stock damage disabled") end
    return 20, 30, 7, 11, 5, -2, 1.1
end
GetUnitField = function(unit, field)
    assert(unit == "player")
    local values = { offhandAttackTime = offSpeed and offSpeed * 1000,
        minOffhandDamage = 7, maxOffhandDamage = 11 }
    return values[field]
end

dofile("Game/Player/OffhandAttackRounds.lua")
local Rounds = XelAssist.Game.Player.OffhandAttackRounds
local active = { active = true, activeKnown = true }
local offHit = { actor = "player", hand = "off", exactDelivery = true,
    evidence = "hit", hitInfo = 4, outcome = "hit" }
local offMiss = { actor = "player", hand = "off", exactDelivery = true,
    evidence = "ordinary-miss", hitInfo = 4, outcome = "miss" }

assert(not Rounds:Observe(playerGuid, targetGuid,
        { actor = "player", hand = "main", exactDelivery = true,
            evidence = "hit", hitInfo = 0 }, clock)
    and not Rounds:Observe(playerGuid, targetGuid,
        { actor = "pet", hand = "off", exactDelivery = true,
            evidence = "hit", hitInfo = 4 }, clock)
    and not Rounds:Observe(playerGuid, targetGuid,
        { actor = "player", hand = "off", exactDelivery = false,
            evidence = "hit", hitInfo = 4 }, clock)
    and not Rounds:Observe(playerGuid, targetGuid,
        { actor = "player", hand = "off", exactDelivery = true,
            evidence = nil, hitInfo = 4 }, clock)
    and not Rounds:Observe(playerGuid, targetGuid,
        { actor = "player", hand = "off", exactDelivery = true,
            evidence = "hit", hitInfo = 65540 }, clock)
    and not Rounds:Observe(otherGuid, targetGuid, offHit, clock)
    and not Rounds:Observe(playerGuid, nil, offHit, clock),
    "only an exact ordinary player off-hand packet may anchor the lane")

assert(Rounds:Observe(playerGuid, targetGuid, offHit, clock),
    "an exact LEFTSWING result must anchor off-hand phase")
clock = 10.25
local snapshot = Rounds:Snapshot(active)
assert(snapshot.projectable and snapshot.phaseKnown and snapshot.phaseExact
    and snapshot.verified and snapshot.hand == "off"
    and snapshot.speed == 1.6
    and math.abs(snapshot.interval - 1.65) < 0.0001
    and math.abs(snapshot.nextSwingIn - 1.4) < 0.0001
    and snapshot.minimum == 7 and snapshot.maximum == 11
    and snapshot.power == 9 and snapshot.normalDamageKnown,
    "trusted stock speed and damage must expose one exact off-hand clock")
local attached = {}
attached.active, attached.activeKnown = true, true
assert(Rounds:Attach(attached) == attached
    and attached.offhandAttackRound.projectable
    and attached.offhandAttackRound.targetGuid == targetGuid,
    "the player Attack snapshot must accept the independent off-hand lane")

clock = 11.6
assert(Rounds:Observe(playerGuid, targetGuid, offMiss, clock),
    "a resolved ordinary miss is still an exact completed round")
local generation = Rounds:Snapshot(active).generation
assert(generation == 2
    and math.abs(Rounds.record.observedInterval - 1.6) < 0.0001,
    "each exact off-hand outcome must advance only this lane")
assert(not Rounds:Observe(playerGuid, targetGuid, offHit, 11.5),
    "out-of-order packets must not rewind off-hand phase")

-- With unequal weapon speeds, a main-hand round can delay one off-hand round
-- by about 0.2s. UnitAttackSpeed remains the exact recurring cadence.
clock = 13.4
assert(Rounds:Observe(playerGuid, targetGuid, offHit, clock)
    and math.abs(Rounds.record.observedInterval - 1.8) < 0.0001
    and math.abs(Rounds.record.interval - 1.65) < 0.0001,
    "one trusted cross-hand collision must not inflate off-hand cadence")
clock = 15
assert(Rounds:Observe(playerGuid, targetGuid, offHit, clock)
    and math.abs(Rounds.record.interval - 1.65) < 0.0001,
    "the trusted off-hand cadence must remain exact after the collision")

offSpeed = 1.8
local changed = Rounds:Snapshot(active)
assert(not changed.projectable
    and changed.reason == "player off-hand attack speed changed"
    and Rounds.record == nil,
    "a live off-hand speed change must retire the old deadline")
offSpeed = 1.6
assert(not Rounds:Snapshot(active).projectable,
    "restoring an old speed must not resurrect discarded phase")

clock = 15
assert(Rounds:Observe(playerGuid, targetGuid, offHit, clock))
selected = otherGuid
local retargeted = Rounds:Snapshot(active)
assert(not retargeted.projectable
    and retargeted.reason == "player attack target changed",
    "an off-hand phase must stay pinned to its exact hostile identity")
selected = targetGuid

clock = 20
assert(Rounds:Observe(playerGuid, targetGuid, offHit, clock))
local stopped = Rounds:Snapshot({ active = false, activeKnown = true })
assert(not stopped.projectable and stopped.reason == "player attack stopped",
    "stopping Attack must retire the off-hand phase")

clock = 25
assert(Rounds:Observe(playerGuid, targetGuid, offHit, clock))
clock = 26.65
local overdue = Rounds:Snapshot(active)
assert(not overdue.projectable and overdue.reason
        == "off-hand swing deadline passed without a resolved round",
    "a missed exact deadline must expire instead of rolling forward")

-- Raw Nampower descriptors can prove cadence only after three clean intervals;
-- their magnitude remains intentionally untrusted for graph damage.
UnitAttackSpeed, UnitDamage = nil, nil
stockSpeed, stockDamage = false, false
Rounds:Reset("raw descriptor test")
clock = 30
assert(Rounds:Observe(playerGuid, targetGuid, offHit, clock))
clock = 31.6
assert(Rounds:Observe(playerGuid, targetGuid, offHit, clock))
clock = 33.2
assert(Rounds:Observe(playerGuid, targetGuid, offHit, clock))
assert(not Rounds:Status().verified and Rounds:Status().samples == 2,
    "two raw intervals must not prove an effective off-hand cadence")
clock = 34.8
assert(Rounds:Observe(playerGuid, targetGuid, offHit, clock))
clock = 35
local raw = Rounds:Snapshot(active)
assert(raw.projectable and raw.verified and raw.samples == 3
    and raw.speed == 1.6 and raw.power == 9
    and not raw.normalDamageKnown,
    "three raw intervals may prove phase without inventing damage certainty")

clock = 36.6
assert(Rounds:Observe(playerGuid, targetGuid, offHit, clock)
    and math.abs(Rounds.record.observedInterval - 1.8) < 0.0001
    and math.abs(Rounds.record.interval - 1.65) < 0.0001,
    "one raw cross-hand collision must not poison off-hand cadence")
clock = 38.2
assert(Rounds:Observe(playerGuid, targetGuid, offHit, clock)
    and math.abs(Rounds.record.interval - 1.65) < 0.0001,
    "a clean raw round must retain the non-inflated off-hand cadence")

Rounds:EquipmentChanged()
assert(Rounds.record == nil
    and Rounds.lastResetReason == "player off-hand weapon changed",
    "equipment boundaries must expose an explicit off-hand reset hook")
Rounds:FormChanged()
assert(Rounds.lastResetReason == "player form changed")
Rounds:ControlChanged()
assert(Rounds.lastResetReason == "player control regime changed")

print("ok: exact independent player off-hand phase evidence")
