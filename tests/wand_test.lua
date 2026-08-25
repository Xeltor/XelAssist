XelAssist = { Combat = {} }

local clock, targetGuid = 10, "hostile-a"
local targetExists, targetHostile, targetDead = true, true, false
local activeRepeat, repeatFailure = false, false
local shootSlot, tooltipSlot, textureQueries = 3, nil, 0
local registered = {}

local function count(values)
    local total = 0
    while values[total + 1] ~= nil do total = total + 1 end
    return total
end

GetTime = function() return clock end
UnitExists = function(unit)
    if unit == "target" then return targetExists, targetGuid end
    return false, nil
end
UnitGUID = function(unit) return unit == "target" and targetGuid or nil end
UnitCanAttack = function(_, unit) return unit == "target" and targetHostile end
UnitIsDead = function(unit) return unit == "target" and targetDead end
SpellInfo = function(id) return id == 5019 and "Shoot" or "Other" end
UnitRangedDamage = function() return 2.1, 12, 18, 0, 0, 1 end
GetActionTexture = function(slot)
    textureQueries = textureQueries + 1
    if slot == shootSlot or slot == 4 or slot == 5 then return "icon" end
    return nil
end
GetActionText = function(slot) return slot == 4 and "Shoot macro" or nil end
IsEquippedAction = function(slot) return slot == 5 end
IsAutoRepeatAction = function(slot)
    if repeatFailure then error("repeat unavailable") end
    return slot == shootSlot and activeRepeat
end
getglobal = function()
    return { GetText = function()
        if tooltipSlot == shootSlot or tooltipSlot == 4 or tooltipSlot == 5 then
            return "Shoot"
        end
        return "Other"
    end }
end
CreateFrame = function(kind)
    if kind == "GameTooltip" then
        return { ClearLines = function() tooltipSlot = nil end,
            SetOwner = function() end,
            SetAction = function(_, slot) tooltipSlot = slot end }
    end
    return { RegisterEvent = function(_, name) registered[name] = true end,
        SetScript = function(self, name, callback) self[name] = callback end }
end

dofile("Combat/Wand.lua")
local W = XelAssist.Combat.Wand

assert(registered.START_AUTOREPEAT_SPELL and registered.STOP_AUTOREPEAT_SPELL
    and registered.ACTIONBAR_SLOT_CHANGED and registered.PLAYER_TARGET_CHANGED,
    "wand observation must follow the native repeat and action-bar lifecycle")

local idle = W:Snapshot()
local slots, scanKnown = W:DiscoverSlots()
assert(scanKnown and count(slots) == 1 and slots[1] == 3,
    "only an exact native non-macro, non-item Shoot action may be observed")
assert(idle.state == "inactive" and idle.activeKnown and not idle.active
    and idle.currentTargetGuid == targetGuid,
    "a queried native Shoot slot must prove exact inactivity and bind the hostile")
assert(idle.rangedSpeedKnown and idle.rangedSpeed == 2.1
    and idle.rangedDamageKnown and idle.rangedMinDamage == 12
    and idle.rangedMaxDamage == 18 and idle.rangedDamage == 15,
    "live ranged speed and damage must be exposed without invented fallbacks")
local firstScanQueries = textureQueries
W:Snapshot()
assert(textureQueries == firstScanQueries,
    "ordinary snapshots must reuse the cached concrete Shoot slots")

local allowed, reason = W:CanStart(idle)
assert(allowed and reason == nil, "an exact idle wand and hostile may start")
local submitted, submittedReason = W:Submitted(targetGuid)
assert(submitted and submittedReason == nil, "a verified wand start must latch")
local pendingUntil = W.pendingUntil
clock = 10.2
submitted, submittedReason = W:Submitted(targetGuid)
assert(submitted and submittedReason == "wand start already pending"
    and W.pendingUntil == pendingUntil,
    "repeated submissions must be idempotent and must not extend the latch")
local pending = W:Snapshot()
allowed, reason = W:CanStart(pending)
assert(pending.pending and pending.pendingTargetGuid == targetGuid
    and not allowed and reason == "wand start pending",
    "the event-delay window must block a second toggle press")

activeRepeat = true
local active = W:Snapshot()
assert(active.state == "active" and active.active and active.activeKnown
    and active.targetGuid == targetGuid and not active.pending,
    "the live repeat indicator must confirm activity, bind its target and clear the latch")
allowed, reason = W:CanStart(active)
assert(not allowed and reason == "wand already active",
    "an active wand must never be toggled by another start")

activeRepeat = false
targetHostile = false
local friendly = W:Snapshot()
allowed, reason = W:CanStart(friendly)
assert(not allowed and reason == "hostile target identity unavailable",
    "Shoot must not start without a current attackable target identity")
targetHostile = true

repeatFailure = true
local unknown = W:Snapshot()
allowed, reason = W:CanStart(unknown)
assert(unknown.state == "unknown" and not unknown.activeKnown
    and not allowed and reason == "wand state uncertain",
    "a failed repeat query must stay unknown instead of assuming inactivity")
repeatFailure = false

shootSlot = 6
W:OnEvent("ACTIONBAR_SLOT_CHANGED")
slots = W:DiscoverSlots()
assert(count(slots) == 1 and slots[1] == 6
    and textureQueries > firstScanQueries,
    "action-bar invalidation must refresh the cached Shoot slot")

shootSlot = nil
W:Invalidate()
unknown = W:Snapshot()
allowed, reason = W:CanStart(unknown)
assert(unknown.state == "unknown" and not allowed
    and reason == "wand state uncertain",
    "absence of a concrete Shoot slot cannot prove that the toggle is off")

shootSlot = 3
W:Invalidate()
clock = 20
assert(W:Submitted(targetGuid))
clock = 21.49
assert(W:Snapshot().pending, "the submission latch must survive event delay")
clock = 21.51
local expired = W:Snapshot()
assert(not expired.pending and W:CanStart(expired),
    "an unconfirmed submission must recover after its bounded timeout")

UnitRangedDamage = function() error("unavailable") end
local noStats = W:Snapshot()
assert(not noStats.rangedSpeedKnown and not noStats.rangedDamageKnown
    and noStats.rangedSpeed == nil and noStats.rangedDamage == nil,
    "failed live weapon APIs must remain explicitly unknown")

W:Submitted(targetGuid)
W:Reset()
assert(W.pendingUntil == nil and W.repeatSlots == nil,
    "Reset must clear both the submission latch and scan cache")

print("ok: exact wand auto-repeat observation, target binding and start latch")
