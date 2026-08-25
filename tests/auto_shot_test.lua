XelAssist = { Game = {}, Combat = {} }
table.getn = table.getn or function(value)
    local count = 0
    while value[count + 1] ~= nil do count = count + 1 end
    return count
end

local clock = 10
local playerGuid, targetGuid = {}, {}
local activeRepeat, ammo = false, 20
local slotAvailable, tooltipSlot = false, nil
local registered = {}

GetTime = function() return clock end
UnitClass = function() return "Hunter", "HUNTER" end
UnitExists = function(unit)
    if unit == "player" then return true, playerGuid end
    if unit == "target" then return true, targetGuid end
    return false, nil
end
UnitRangedDamage = function() return 2.5 end
IsAutoRepeatAction = function(slot) return slot == 7 and activeRepeat end
GetActionTexture = function(slot)
    if slotAvailable and (slot == 7 or slot == 8 or slot == 9) then return "icon" end
    return nil
end
GetActionText = function(slot) return slot == 8 and "macro" or nil end
IsEquippedAction = function(slot) return slot == 9 end
GetAmmo = function() return 2516, ammo end
SpellInfo = function(id) return id == 75 and "Auto Shot" or "Other" end
getglobal = function()
    return { GetText = function()
        if tooltipSlot == 7 or tooltipSlot == 8 or tooltipSlot == 9 then
            return "Auto Shot"
        end
        return "Other"
    end }
end
CreateFrame = function(kind)
    if kind == "GameTooltip" then
        return {
            ClearLines = function() tooltipSlot = nil end,
            SetOwner = function() end,
            SetAction = function(_, slot) tooltipSlot = slot end,
        }
    end
    return {
        RegisterEvent = function(_, name) registered[name] = true end,
        SetScript = function(self, name, callback) self[name] = callback end,
    }
end
XelAssist.Game.Capabilities = { RangedDamage = function() return 55 end,
    Distance = function() return 20 end }

dofile("Combat/AutoShot.lua")
dofile("Combat/AutoShotProjection.lua")
local A = XelAssist.Combat.AutoShot

assert(registered.UNIT_CASTEVENT and registered.PLAYER_TARGET_CHANGED
    and registered.START_AUTOREPEAT_SPELL and registered.STOP_AUTOREPEAT_SPELL,
    "exact launch and stock autorepeat lifecycle events must be registered")
local unknown = A:Snapshot()
local canStart, reason = A:CanStart(unknown)
assert(unknown.stateUncertain and not canStart
    and reason == "Auto Shot state uncertain",
    "a UI reload without direct repeat evidence must never assume the toggle is off")
slotAvailable = true
A:OnEvent("ACTIONBAR_SLOT_CHANGED")
local idle = A:Snapshot()
local slots = A:DiscoverSlots()
assert(idle.supported and idle.knownInactive and not idle.active
    and idle.rangedSpeed == 2.5 and slots[1] == 7 and slots[2] == nil,
    "only an exact native, non-macro, non-equipped Auto Shot slot may prove inactivity")
canStart, reason = A:CanStart(idle)
assert(canStart and reason == nil, "an idle Hunter with ammo and a target may start Auto Shot")

A:Submitted(targetGuid)
local pending = A:Snapshot()
assert(not pending.active and pending.stateUncertain
    and pending.activeSource == "start submitted",
    "a submitted start must remain pending rather than project invented shots")
canStart, reason = A:CanStart(pending)
assert(not canStart and reason == "Auto Shot state uncertain",
    "repeated taps must not toggle a pending Auto Shot off")

clock = 10.2
activeRepeat = true
A:UnitCast(playerGuid, targetGuid, "CAST", 75)
local launched = A:Snapshot()
assert(launched.active and launched.lastLaunchAt == 10.2,
    "an exact launch must confirm the repeat and establish ranged phase")
assert(table.getn(launched.inFlight) == 1
    and launched.inFlight[1].targetGuid == targetGuid
    and launched.inFlight[1].spellId == 75
    and launched.inFlight[1].power == 55
    and launched.inFlight[1].delivery == 1
    and math.abs(launched.inFlight[1].remaining - 0.5) < 0.0001,
    "an exact launch must expose its fixed target, outcome and remaining flight")
assert(launched.nextLaunchIn > 2.49 and launched.nextLaunchIn < 2.51,
    "CAST, not START, must establish ranged phase")
clock = 12.6
A:UnitCast(playerGuid, targetGuid, "CAST", 999)
local instantFloor = A:Snapshot()
assert(instantFloor.nextLaunchIn > 0.49 and instantFloor.nextLaunchIn < 0.51,
    "a live instant generic spell must apply the 500 ms resume floor")
assert(A:CanonicalSpellId(1583) == 75 and A:CanonicalSpellId(52637) == 52636,
    "client wrapper IDs must canonicalize to their direct Auto Shot spell")

clock = 13
local bar = A:Snapshot()
assert(bar.active and bar.actionSlot == 7 and bar.activeSource == "action bar repeat")
canStart, reason = A:CanStart(bar)
assert(not canStart, "a live repeat indicator is an absolute no-toggle guard")

activeRepeat = false
clock = 20
local stale = A:Snapshot()
assert(not stale.active, "stale launch evidence must eventually permit recovery")

clock = 21
local priorTarget = targetGuid
A:Submitted(priorTarget)
activeRepeat = true
A:OnEvent("START_AUTOREPEAT_SPELL")
targetGuid = {}
A:OnEvent("PLAYER_TARGET_CHANGED")
local changed = A:Snapshot()
assert(changed.active and changed.projectable,
    "a valid hostile retarget must retain and retarget the active repeat")
canStart, reason = A:CanStart(changed)
assert(not canStart and reason == "Auto Shot already active",
    "retargeting must never turn an uncertain repeat into another toggle press")

clock = 23
assert(A:Snapshot().active,
    "combat exit or elapsed time must not silently clear an active repeat")
activeRepeat = false
A:OnEvent("STOP_AUTOREPEAT_SPELL")
assert(A:Snapshot().knownInactive,
    "the stock stop event must prove the repeat inactive")

A:Reset(true)
clock = 30
priorTarget = targetGuid
A:Submitted(priorTarget)
targetGuid = {}
A:OnEvent("PLAYER_TARGET_CHANGED")
clock = 40
changed = A:Snapshot()
assert(not changed.active and changed.knownInactive,
    "an exact inactive slot must reject an unacknowledged start after timeout")

slotAvailable = false
A:OnEvent("ACTIONBAR_SLOT_CHANGED")
A:Reset(true)
clock = 41
A:Submitted(targetGuid)
clock = 43
changed = A:Snapshot()
assert(not changed.active and changed.stateUncertain,
    "an unacknowledged start without current state evidence must become unknown")
clock = 44
A:Reset(true)
A:Submitted(targetGuid)
A:OnEvent("START_AUTOREPEAT_SPELL")
changed = A:Snapshot()
assert(changed.active and changed.projectable,
    "a correlated stock start event must confirm the requested Auto Shot")
A:Reset(true)
slotAvailable = true
A:OnEvent("ACTIONBAR_SLOT_CHANGED")

ammo = 0
canStart, reason = A:CanStart(A:Snapshot())
assert(not canStart and reason == "ammunition")

ammo = 3
local phase = {
    active = true, targetGuid = targetGuid, nextLaunchIn = 0.4,
    rangedSpeed = 2.5, ammoKnown = true, ammoCount = 3, projectable = true,
}
local projected = A:Project(phase, { wait = 0.5, cast = 1.5, occupancy = 3.0 })
assert(projected.launches == 2 and projected.ammoCount == 1,
    "blocked cast time must advance the timer before the 500 ms resume floor")
assert(projected.launchesBeforeImpact == 1
    and projected.launchesAfterImpact == 1,
    "launch offsets must distinguish shots before and after action impact")
assert(projected.nextLaunchIn > 1.89 and projected.nextLaunchIn < 1.91,
    "projected phase must retain the remaining interval")

projected = A:Project(phase, { wait = 0, cast = 3.0, occupancy = 3.0 })
assert(projected.launches == 0 and projected.nextLaunchIn == 0.5
    and not projected.blocked,
    "a completed cast must expose the server's 500 ms post-blocker floor")

projected = A:Project(phase,
    { wait = 2, cast = 0, occupancy = 0 },
    { playerCasting = true, castRemaining = 2 })
assert(projected.launches == 0 and projected.nextLaunchIn == 0.5,
    "the current live cast must advance the timer, then expose the resume floor")

projected = A:Project({ active = true, targetGuid = targetGuid,
    nextLaunchIn = 0.5, rangedSpeed = 1, ammoKnown = true,
    ammoCount = 3, projectable = true },
    { action = { actor = "pet" }, wait = 0, cast = 2, occupancy = 2 })
assert(projected.launches == 2,
    "a companion cast must not freeze the Hunter's independent ranged phase")

projected = A:Project({
    active = true, targetGuid = targetGuid, nextLaunchIn = 0.2,
    rangedSpeed = 1, ammoKnown = true, ammoCount = 1, projectable = true,
}, { wait = 0, cast = 0, occupancy = 2 })
assert(projected.launches == 1 and projected.ammoCount == 0 and not projected.active,
    "projected launches consume ammunition and stop at zero")

projected = A:Project({ active = true, targetGuid = targetGuid,
    nextLaunchIn = 0.2, rangedSpeed = 2.5, ammoKnown = true,
    ammoCount = 3, projectable = true },
    { action = { actor = "player", facts = { kind = "damage" } },
        wait = 0, cast = 0, occupancy = 1.5 })
assert(projected.launches == 1
    and math.abs(projected.launchOffsets[1] - 0.5) < 0.0001,
    "an instant generic spell must floor a nearly-ready shot to 500 ms")
projected = A:Project({ active = true, targetGuid = targetGuid,
    nextLaunchIn = 0.8, rangedSpeed = 2.5, ammoKnown = true,
    ammoCount = 3, projectable = true },
    { action = { actor = "player", facts = { kind = "damage" } },
        wait = 0, cast = 0, occupancy = 1.5 })
assert(projected.launches == 1
    and math.abs(projected.launchOffsets[1] - 0.8) < 0.0001,
    "the GCD itself must not block a shot already beyond the resume floor")

A:Reset(true)
ammo = 3
local moving = A:Snapshot({ hostile = true, moving = true,
    distance = 20, lineOfSight = true })
canStart, reason = A:CanStart(moving)
assert(canStart and reason == nil,
    "the server permits an inactive Auto Shot toggle to start while moving")
local channeling = A:Snapshot({ hostile = true, channeling = true,
    casting = false, distance = 20, lineOfSight = true })
canStart, reason = A:CanStart(channeling)
assert(canStart and reason == nil,
    "an inactive Auto Shot may be armed during a channel even though launches wait")

phase.blocked = false
phase.nextLaunchIn = 0.5
projected = A:Project(phase, { wait = 0, cast = 0, occupancy = 2 },
    { moving = true })
assert(projected.launches == 0 and projected.nextLaunchIn == 0
    and projected.blocked,
    "movement must advance the timer without launching or clearing the repeat")
projected = A:Project(projected, { wait = 0, cast = 0, occupancy = 1 },
    { moving = false })
assert(projected.launches == 1 and not projected.blocked,
    "resuming after a depleted blocked timer must launch after the 500 ms floor")

A:Reset(true)
clock, activeRepeat = 50, true
XelAssist.Graph = { AutoShotEffects = { CaptureLaunch = function()
    return 44, 0.8
end } }
A:UnitCast(playerGuid, targetGuid, "CAST", 75)
local fixedFlight = A:Snapshot()
assert(fixedFlight.inFlight[1].power == 44
    and fixedFlight.inFlight[1].delivery == 0.8,
    "an available graph outcome must be fixed into the live launch ledger")
activeRepeat = false
A:OnEvent("STOP_AUTOREPEAT_SPELL")
assert(not A:Snapshot().active and table.getn(A:Snapshot().inFlight) == 1,
    "stopping the repeat must not erase an arrow already in flight")
clock = 50.6
assert(table.getn(A:Snapshot().inFlight) == 0,
    "a completed projectile must expire from the session ledger")
clock = 60
local i
for i = 1, 10 do
    clock = clock + 0.01
    A:UnitCast(playerGuid, targetGuid, "CAST", 75)
end
assert(table.getn(A:Snapshot().inFlight) == 8,
    "the live launch ledger must remain bounded")
A:Reset(true)
assert(table.getn(A:InFlight()) == 0,
    "an explicit session reset must clear carried projectiles")

print("ok: Auto Shot idempotency, stock lifecycle, phase floor, identity and ammo")
