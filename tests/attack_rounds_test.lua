XelAssist = { Game = { Pets = { Effects = {} } } }

local clock = 0
local petGuid = "0xF14000000000BEEF"
local targetGuid = "0xF13000000000CAFE"
local otherTargetGuid = "0xF13000000000DEAD"
local liveAttackSpeed = 2
local rawFields = {
    baseAttackTime = 2000,
    minDamage = 15,
    maxDamage = 25,
}

GetTime = function() return clock end
UnitExists = function(unit)
    if unit == "pet" then return true, petGuid end
    return false, nil
end
UnitAttackSpeed = function(unit)
    assert(unit == "pet")
    return liveAttackSpeed
end
UnitDamage = function(unit)
    assert(unit == "pet")
    return 20, 30, 0, 0, 5, -2, 1.2
end
GetUnitField = function(unit, field)
    assert(unit == "pet")
    return rawFields[field]
end
XelAssist.Game.Pets.Effects.DamageMultiplier = function(_, pet)
    return (tonumber(pet.damagePercentage) or 100) / 100
end

dofile("Game/AttackRounds.lua")
local A = XelAssist.Game.AttackRounds

local function close(actual, expected, message)
    assert(type(actual) == "number" and math.abs(actual - expected) < 0.0001,
        message .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
end

local pet = { guid = petGuid, targetGuid = targetGuid,
    attackActive = true, attackActiveKnown = true, damagePercentage = 125 }
local miss = { actor = "pet", hand = "main", hitInfo = 16, outcome = "miss",
    evidence = "ordinary-miss", exactDelivery = true }

local waiting = A:Snapshot(pet)
assert(not waiting.phaseKnown and not waiting.projectable
    and waiting.reason == "awaiting first resolved companion swing",
    "command state and live stats must not invent a swing before an exact round")

clock = 9
assert(not A:Observe(petGuid, targetGuid,
    { actor = "pet", hitInfo = 65536, outcome = "melee spell packet",
        exactDelivery = false }, clock),
    "NOACTION attack-state packets must not anchor white-swing phase")
assert(not A:Status().phaseKnown,
    "an ignored NOACTION packet must leave the phase empty")
assert(not A:Observe(petGuid, targetGuid,
    { actor = "pet", hitInfo = 0, outcome = "unclassified victim state",
        exactDelivery = false }, clock)
    and not A:Observe(petGuid, targetGuid,
        { actor = "pet", evidence = "hit", exactDelivery = true }, clock)
    and not A:Observe(petGuid, targetGuid,
        { actor = "pet", hand = "off", hitInfo = 4,
            evidence = "hit", exactDelivery = true }, clock)
    and not A:Status().phaseKnown,
    "unclassified or structurally incomplete packets must not anchor phase")

clock = 10
assert(A:Observe(petGuid, targetGuid, miss, clock),
    "an exact ordinary miss is still a resolved attack round")
clock = 10.5
local projected = A:Snapshot(pet)
assert(projected.projectable and projected.phaseKnown and projected.verified
    and A.record.lastOutcome == "miss",
    "a resolved miss must establish the next conservative swing phase")
close(projected.interval, 2.05, "trusted speed must receive the conservative delay")
close(projected.nextSwingIn, 1.55, "projected swing deadline changed")

-- UnitDamage's base envelope is incomplete. Apply its signed physical bonus and
-- multiplier first, then remove the already-observed happiness multiplier so
-- the graph can apply happiness exactly once later.
close(projected.rawMinimum, 27.6, "full minimum damage formula changed")
close(projected.rawMaximum, 39.6, "full maximum damage formula changed")
close(projected.minimum, 22.08, "happiness-normalized minimum changed")
close(projected.maximum, 31.68, "happiness-normalized maximum changed")
close(projected.power, 26.88, "happiness-normalized average power changed")
assert(projected.normalDamageKnown and not projected.damageKnown
    and not projected.outcomeMagnitudeKnown
    and projected.damageSource == "stock pet damage with physical modifiers",
    "normal damage must stay non-executable until the white outcome table is complete")

local wrongTargetPet = { guid = petGuid, targetGuid = otherTargetGuid,
    attackActive = true, attackActiveKnown = true, damagePercentage = 125 }
local wrongTarget = A:Snapshot(wrongTargetPet)
assert(not wrongTarget.projectable
    and wrongTarget.reason == "companion target changed",
    "a resolved round must never project onto another target")

liveAttackSpeed = 2.5
local changedSpeed = A:Snapshot(pet)
assert(not changedSpeed.projectable
    and changedSpeed.reason == "companion attack speed changed",
    "a speed-regime change must invalidate the observed phase")
liveAttackSpeed = 2

clock = 12.05
local overdue = A:Snapshot(pet)
assert(not overdue.projectable
    and overdue.reason == "swing deadline passed without a resolved round"
    and not A:Status().phaseKnown and A:Status().verified,
    "an overdue phase must expire instead of rolling forward indefinitely")

clock = 13
assert(A:Observe(petGuid, targetGuid, miss, clock))
A:AttackStateChanged(false)
assert(not A:Snapshot(pet).projectable and not A:Status().phaseKnown
    and A:Status().lastResetReason == "companion attack stopped",
    "PET_ATTACK_STOP must discard resolved phase")
clock = 14
assert(A:Observe(petGuid, targetGuid, miss, clock))
A:AttackStateChanged(true)
assert(not A:Snapshot(pet).projectable and not A:Status().phaseKnown
    and A:Status().lastResetReason == "companion attack started; awaiting round",
    "PET_ATTACK_START must await a new resolved round rather than anchor phase")

-- Raw Nampower descriptors can diagnose cadence, but the unmodified base speed
-- needs three clean intervals and raw damage cannot become executable because
-- it omits UnitDamage's physical bonuses and multiplier.
UnitAttackSpeed = nil
UnitDamage = nil
A:Reset("raw descriptor test")
clock = 20
assert(A:Observe(petGuid, targetGuid, miss, clock))
assert(not A:Status().verified and A:Status().samples == 0)
clock = 22
assert(A:Observe(petGuid, targetGuid, miss, clock))
assert(not A:Status().verified and A:Status().samples == 1)
clock = 25
assert(A:Observe(petGuid, targetGuid, miss, clock))
assert(not A:Status().verified and A:Status().samples == 0,
    "an unclean raw interval must restart cadence learning")
clock = 27
assert(A:Observe(petGuid, targetGuid, miss, clock))
clock = 29
assert(A:Observe(petGuid, targetGuid, miss, clock))
assert(not A:Status().verified and A:Status().samples == 2,
    "two clean raw intervals must remain diagnostic only")
clock = 31
assert(A:Observe(petGuid, targetGuid, miss, clock))
assert(A:Status().verified and A:Status().samples == 3,
    "three clean raw intervals are required to verify cadence")
clock = 31.5
local rawOnly = A:Snapshot(pet)
assert(rawOnly.rawMinimum == 15 and rawOnly.rawMaximum == 25
    and not rawOnly.normalDamageKnown and rawOnly.projectable
    and not rawOnly.outcomeMagnitudeKnown,
    "verified raw cadence may project a boundary without inventing damage")

local status = A:Status()
local key, value
for key, value in pairs(status) do
    assert(not string.find(string.lower(tostring(key)), "guid", 1, true),
        "privacy-safe status must not expose a GUID field")
    assert(value ~= petGuid and value ~= targetGuid and value ~= otherTargetGuid,
        "privacy-safe status must not expose a GUID value")
end

print("ok: conservative companion attack-round evidence and private diagnostics")
