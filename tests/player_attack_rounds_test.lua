if not table.getn then
    table.getn = function(value)
        local count = 0
        while value[count + 1] ~= nil do count = count + 1 end
        return count
    end
end

XelAssist = { Game = { Player = {} } }

local clock = 0
local playerGuid, otherPlayerGuid = {}, {}
local targetGuid, otherTargetGuid = {}, {}
local currentPlayer, currentTarget = playerGuid, targetGuid
local liveAttackSpeed, liveOffhandSpeed = 2, 1.5
local rawFields = {
    baseAttackTime = 2000,
    minDamage = 18,
    maxDamage = 28,
}

GetTime = function() return clock end
UnitExists = function(unit)
    if unit == "player" and currentPlayer then return true, currentPlayer end
    if unit == "target" and currentTarget then return true, currentTarget end
    return false, nil
end
UnitAttackSpeed = function(unit)
    assert(unit == "player")
    return liveAttackSpeed, liveOffhandSpeed
end
UnitDamage = function(unit)
    assert(unit == "player")
    return 40, 60, 0, 0, 5, -2, 1.1
end
GetUnitField = function(unit, field)
    assert(unit == "player")
    return rawFields[field]
end

local eventFrame
CreateFrame = function()
    local frame = { registered = {} }
    function frame:RegisterEvent(name) self.registered[name] = true end
    function frame:SetScript(name, handler)
        assert(name == "OnEvent")
        self.handler = handler
    end
    eventFrame = frame
    return frame
end

dofile("Game/Player/AttackRounds.lua")
local A = XelAssist.Game.Player.AttackRounds

local active = { active = true, activeKnown = true }
local exactMiss = { actor = "player", hand = "main", hitInfo = 16,
    outcome = "miss", evidence = "ordinary-miss", exactDelivery = true }
local exactHit = { actor = "player", hand = "main", hitInfo = 40,
    outcome = "hit", evidence = "hit", exactDelivery = true }

local function close(actual, expected, message)
    assert(type(actual) == "number" and math.abs(actual - expected) < 0.0001,
        message .. ": expected " .. tostring(expected)
            .. ", got " .. tostring(actual))
end

local waiting = A:Snapshot(active)
assert(not waiting.phaseKnown and not waiting.projectable,
    "live Attack state and speed must not invent a player swing phase")

clock = 9
assert(not A:Observe(playerGuid, targetGuid,
        { actor = "pet", hand = "main", hitInfo = 0,
            evidence = "hit", exactDelivery = true }, clock)
    and not A:Observe(playerGuid, targetGuid,
        { actor = "player", hand = "off", hitInfo = 4,
            evidence = "hit", exactDelivery = true }, clock)
    and not A:Observe(playerGuid, targetGuid,
        { actor = "player", hand = "main", hitInfo = 65536,
            evidence = "hit", exactDelivery = true }, clock)
    and not A:Observe(playerGuid, targetGuid,
        { actor = "player", hand = "main", hitInfo = 0,
            evidence = "hit", exactDelivery = false }, clock)
    and not A:Observe(otherPlayerGuid, targetGuid, exactHit, clock)
    and not A:Observe(playerGuid, nil, exactHit, clock)
    and not A:Status().phaseKnown,
    "pet, off-hand, NOACTION, inexact, wrong-caster and targetless packets must be ignored")

clock = 10
assert(A:Observe(playerGuid, targetGuid, exactMiss, clock),
    "an exact ordinary main-hand miss must anchor player phase")
clock = 10.5
local projected = A:Snapshot(active)
assert(projected.projectable and projected.phaseKnown and projected.phaseExact
    and projected.verified and projected.targetGuid == targetGuid
    and projected.lastRoundKind == "ordinary-main-hand"
    and projected.phaseSource == "resolved Nampower player attack round",
    "the exact ordinary result must expose a target-pinned phase snapshot")
close(projected.interval, 2.05, "trusted player interval changed")
close(projected.nextSwingIn, 1.55, "trusted player deadline changed")
close(projected.minimum, 40, "displayed player minimum damage changed")
close(projected.maximum, 60, "displayed player maximum damage changed")
close(projected.power, 50, "displayed player average damage changed")
assert(projected.normalDamageKnown and not projected.damageKnown
    and not projected.outcomeMagnitudeKnown,
    "damage descriptors must not invent the next white-swing outcome")

local attached = { active = true, activeKnown = true }
assert(A:Attach(attached) == attached and attached.attackRound.projectable
    and attached.attackRound.targetGuid == targetGuid,
    "Attach must match Game.PlayerAttack's snapshot contract")

-- Selecting another unit invalidates rather than temporarily hiding phase. A
-- later selection of the old target must not resurrect the prior deadline.
currentTarget = otherTargetGuid
local redirected = A:Snapshot(active)
assert(not redirected.projectable
    and redirected.reason == "player attack target changed"
    and not A:Status().phaseKnown,
    "selected-target changes must destroy target-pinned certainty")
currentTarget = targetGuid
assert(not A:Snapshot(active).projectable,
    "returning to the old target must await another exact round")

clock = 12
assert(A:Observe(playerGuid, targetGuid, exactHit, clock))
liveAttackSpeed = 2.1
local changedSpeed = A:Snapshot(active)
assert(not changedSpeed.projectable
    and changedSpeed.reason == "player attack speed changed",
    "a live speed mismatch must destroy the old deadline")
liveAttackSpeed = 2
assert(not A:Snapshot(active).projectable,
    "restoring an old speed must not resurrect its old phase")

clock = 14
assert(A:Observe(playerGuid, targetGuid, exactHit, clock))
local stopped = A:Snapshot({ active = false, activeKnown = true })
assert(not stopped.projectable and stopped.reason == "player attack stopped"
    and not A:Snapshot(active).projectable,
    "an exact inactive Attack state must permanently retire the phase")

-- On-swing GO is a timing anchor only with generic on-swing classification,
-- exact ownership, and a nonzero generation identity.
clock = 20
assert(not A:ObserveOnSwingGo(playerGuid, targetGuid,
        { exact = true, attemptId = "700" }, clock)
    and not A:ObserveOnSwingGo(playerGuid, targetGuid,
        { exact = true, onNextSwing = true, attemptId = "0" }, clock)
    and not A:ObserveOnSwingGo(playerGuid, targetGuid,
        { exact = true, onNextSwing = true, attemptId = "700",
            actor = "pet" }, clock)
    and not A:ObserveOnSwingGo(playerGuid, targetGuid,
        { exact = true, onNextSwing = true, attemptId = "700",
            hand = "off" }, clock)
    and not A:ObserveOnSwingGo(playerGuid, targetGuid,
        { exact = true, onNextSwing = true, attemptId = "700",
            targetGuid = otherTargetGuid }, clock),
    "unclassified, identityless, pet and off-hand GO evidence must be rejected")
local onSwing = { exact = true, attemptId = "700",
    tooltip = { onNextSwing = true }, outcome = "raptor-strike-go" }
assert(A:ObserveOnSwingGo(playerGuid, targetGuid, onSwing, clock),
    "an exactly owned, DBC-classified on-swing GO must re-anchor main-hand phase")
clock = 20.25
local afterGo = A:Snapshot(active)
assert(afterGo.projectable and afterGo.lastRoundKind == "on-swing-main-hand"
    and afterGo.phaseSource == "exact owned on-swing SPELL_GO",
    "on-swing GO must expose timing without masquerading as ordinary white evidence")
close(afterGo.nextSwingIn, 1.8, "on-swing GO deadline changed")
assert(not A:ObserveOnSwingGo(playerGuid, targetGuid, onSwing, 20.5),
    "a duplicate exact attempt must never re-anchor the same swing")
A:Reset("duplicate boundary")
assert(not A:ObserveOnSwingGo(playerGuid, targetGuid, onSwing, 21),
    "attempt tombstones must survive ordinary phase invalidation")

clock = 22
local accepted = { phase = "accepted", attemptId = "701",
    action = { facts = { onNextSwing = true } } }
assert(A:ObserveOnSwingGo(playerGuid, targetGuid, accepted, clock),
    "an accepted exact owner record must be sufficient GO evidence")
local generation = A:Snapshot(active).generation
clock = 24
assert(A:Observe(playerGuid, targetGuid, exactMiss, clock)
    and A:Snapshot(active).generation > generation,
    "every exact main-hand round must advance the exposed swing generation")
assert(not A:Observe(playerGuid, targetGuid, exactHit, 23),
    "out-of-order round evidence must not rewind the current phase")

clock = 26.05
local overdue = A:Snapshot(active)
assert(not overdue.projectable
    and overdue.reason == "swing deadline passed without a resolved round",
    "a missed exact round must expire rather than roll phase forward")
clock = 24.5
assert(not A:Snapshot(active).projectable,
    "clock rewind after expiry must not resurrect discarded phase")

-- Raw Nampower speed is diagnostic until three clean exact intervals prove
-- that it describes the effective player cadence.
local stockUnitAttackSpeed, stockUnitDamage = UnitAttackSpeed, UnitDamage
UnitAttackSpeed, UnitDamage = nil, nil
A:Reset("raw descriptor test")
clock = 30
assert(A:Observe(playerGuid, targetGuid, exactMiss, clock))
clock = 32
assert(A:Observe(playerGuid, targetGuid, exactMiss, clock))
clock = 34
assert(A:Observe(playerGuid, targetGuid, exactMiss, clock))
assert(not A:Status().verified and A:Status().samples == 2,
    "two raw intervals must remain unverified")
clock = 36
assert(A:Observe(playerGuid, targetGuid, exactMiss, clock))
clock = 36.5
local raw = A:Snapshot(active)
assert(raw.projectable and raw.verified and raw.samples == 3
    and raw.minimum == 18 and raw.maximum == 28
    and not raw.normalDamageKnown,
    "three clean raw intervals may prove cadence without inventing complete damage")

-- Unequal weapon speeds periodically collide. The server may delay this hand
-- by roughly 0.2s, but one delayed delivery is not a new recurring cadence.
clock = 38.2
assert(A:Observe(playerGuid, targetGuid, exactHit, clock)
    and math.abs(A.record.observedInterval - 2.2) < 0.0001
    and math.abs(A.record.interval - 2.05) < 0.0001,
    "one raw cross-hand collision must not inflate the learned main cadence")
clock = 40.2
assert(A:Observe(playerGuid, targetGuid, exactHit, clock)
    and math.abs(A.record.interval - 2.05) < 0.0001,
    "a later clean raw round must retain the non-inflated cadence")
UnitAttackSpeed, UnitDamage = stockUnitAttackSpeed, stockUnitDamage

A:Reset("trusted unequal-speed collision test")
clock = 37
assert(A:Observe(playerGuid, targetGuid, exactHit, clock))
clock = 39.2
assert(A:Observe(playerGuid, targetGuid, exactHit, clock)
    and math.abs(A.record.observedInterval - 2.2) < 0.0001
    and math.abs(A.record.interval - 2.05) < 0.0001,
    "trusted UnitAttackSpeed must survive a delayed cross-hand collision")
clock = 41.2
assert(A:Observe(playerGuid, targetGuid, exactHit, clock)
    and math.abs(A.record.interval - 2.05) < 0.0001,
    "trusted main cadence must not remain inflated after the collision")
A:Reset("collision regression complete")

dofile("Game/Player/AttackRoundEvents.lua")
local E = XelAssist.Game.Player.AttackRoundEvents
assert(eventFrame and eventFrame.registered.PLAYER_ENTER_COMBAT
    and eventFrame.registered.PLAYER_LEAVE_COMBAT
    and eventFrame.registered.UNIT_ATTACK_SPEED
    and eventFrame.registered.UNIT_INVENTORY_CHANGED
    and eventFrame.registered.UPDATE_SHAPESHIFT_FORM
    and eventFrame.registered.UPDATE_SHAPESHIFT_FORMS
    and eventFrame.registered.PLAYER_CONTROL_LOST
    and eventFrame.registered.PLAYER_CONTROL_GAINED,
    "all speed, equipment, form, control and attack-state boundaries must register")

local function seed(at)
    currentPlayer, currentTarget, liveAttackSpeed = playerGuid, targetGuid, 2
    clock = at
    assert(A:Observe(playerGuid, targetGuid, exactHit, clock))
    assert(A.record ~= nil)
end

seed(40)
assert(not E:OnEvent("UNIT_ATTACK_SPEED", "pet") and A.record,
    "another unit's speed event must not invalidate player evidence")
assert(E:OnEvent("UNIT_ATTACK_SPEED", "player") and not A.record
    and A.lastResetReason == "player attack speed changed")
seed(41)
assert(E:OnEvent("UNIT_INVENTORY_CHANGED", "player") and not A.record
    and A.lastResetReason == "player weapon changed")
seed(42)
assert(E:OnEvent("UPDATE_SHAPESHIFT_FORM") and not A.record
    and A.lastResetReason == "player form changed")
seed(43)
assert(E:OnEvent("PLAYER_CONTROL_LOST") and not A.record
    and A.lastResetReason == "player control regime changed")
seed(44)
assert(E:OnEvent("PLAYER_LEAVE_COMBAT") and not A.record
    and A.lastResetReason == "player attack stopped")
seed(45)
assert(E:OnEvent("PLAYER_TARGET_CHANGED") and not A.record
    and A.lastResetReason == "player attack target changed")
seed(46)
assert(E:OnEvent("PLAYER_ENTER_COMBAT") and not A.record
    and A.lastResetReason == "player attack started; awaiting round")

local status = A:Status()
local key, value
for key, value in pairs(status) do
    assert(not string.find(string.lower(tostring(key)), "guid", 1, true),
        "privacy-safe status must not expose a GUID field")
    assert(value ~= playerGuid and value ~= targetGuid
        and value ~= otherTargetGuid,
        "privacy-safe status must not expose a GUID value")
end

print("ok: exact target-pinned player attack rounds and reset boundaries")
