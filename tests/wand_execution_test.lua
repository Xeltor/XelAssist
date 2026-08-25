XelAssist = { Combat = {}, Core = {} }

local active, pending, targetGuid = false, false, "hostile-a"
local castCount, submittedGuid = 0, nil
local resistanceAction, resistanceGuid, resistanceTooltip, rememberedUnit

UnitExists = function(unit)
    return unit == "target", unit == "target" and targetGuid or nil
end

XelAssist.Combat.Wand = {
    Snapshot = function()
        return { active = active, activeKnown = true, pending = pending,
            currentTargetGuid = targetGuid }
    end,
    CanStart = function(_, snapshot)
        if snapshot.active then return false, "wand already active" end
        if snapshot.pending then return false, "wand start pending" end
        return true, nil
    end,
    Submitted = function(_, guid)
        submittedGuid = guid
        pending = true
        return true
    end,
}
XelAssist.Combat.Resistance = {
    RememberUnit = function(_, unit) rememberedUnit = unit end,
    Submitted = function(_, action, guid, tooltip)
        resistanceAction, resistanceGuid, resistanceTooltip = action, guid, tooltip
    end,
}
CastSpellByName = function(name)
    assert(name == "Shoot", "the exact recommended action must be dispatched")
    castCount = castCount + 1
end

dofile("Core/WandExecution.lua")
local W = XelAssist.Core.WandExecution

local guid, reason = W:Validate("hostile-b")
assert(guid == nil and reason == "target changed",
    "a changed target must stop the repeat toggle at the final boundary")

local dispatched
dispatched, reason, guid = W:Dispatch("Shoot", "hostile-a")
assert(dispatched and reason == nil and guid == "hostile-a" and castCount == 1,
    "a proven inactive wand may be started exactly once")
local shoot = { name = "Shoot", spellId = 5019,
    facts = { wandRepeat = true, dynamicSchool = "equippedWand" } }
local shootTooltip = { directDamage = 25 }
assert(W:Submitted(guid, shoot, shootTooltip)
    and submittedGuid == "hostile-a" and pending,
    "successful dispatch must arm the runtime submission latch")
assert(resistanceAction == shoot and resistanceGuid == "hostile-a"
    and resistanceTooltip == shootTooltip and rememberedUnit == "target",
    "wand submission must seed only its exact dynamic resistance context")

dispatched, reason = W:Dispatch("Shoot", "hostile-a")
assert(not dispatched and reason == "wand start pending" and castCount == 1,
    "macro tapping during event delay must not toggle Shoot a second time")

pending, active = false, true
dispatched, reason = W:Dispatch("Shoot", "hostile-a")
assert(not dispatched and reason == "wand already active" and castCount == 1,
    "an active wand must never be cancelled by the recommendation macro")

print("ok: idempotent final wand dispatch boundary")
