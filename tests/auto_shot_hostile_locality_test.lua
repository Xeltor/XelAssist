XelAssist = { Combat = {}, Graph = {} }
table.getn = table.getn or function(value)
    local count = 0
    while value[count + 1] ~= nil do count = count + 1 end
    return count
end

local function copy(value, seen)
    if type(value) ~= "table" then return value end
    seen = seen or {}
    if seen[value] then return seen[value] end
    local out, key, entry = {}, nil, nil
    seen[value] = out
    for key, entry in pairs(value) do
        -- Opaque identity tables are used as map keys and values. Test records
        -- mark them so a graph copy preserves exact equality.
        if type(entry) == "table" and entry.opaque then out[key] = entry
        else out[key] = copy(entry, seen) end
    end
    return out
end

local syncs = 0
XelAssist.Graph.State = {
    Copy = function(_, state) return copy(state) end,
    SyncSelectedHostile = function(_, state)
        syncs = syncs + 1
        local key = state.hostiles.selectedKey
        local record = state.hostiles.byKey[key]
        state.targetGUID = record.guid
        state.targetHealth = record.health or 0
        state.targetHealthExact = record.healthExact == true
        state.hostile = record.dead ~= true
        return state
    end,
}
XelAssist.Graph.State.RefreshHostileRecord = function(self, state, key)
    if state.targetContextKey == nil and key == state.hostiles.selectedKey then
        return self:SyncSelectedHostile(state)
    end
    return state
end
XelAssist.Graph.Effects = {
    StateAtImpact = function(_, state) return XelAssist.Graph.State:Copy(state) end,
    Decision = function() return 1, 1 end,
}
dofile("Combat/AutoShotRange.lua")

local guidA, guidB, guidC, guidDead, guidMissing =
    { opaque = true }, { opaque = true }, { opaque = true },
    { opaque = true }, { opaque = true }
local keyA, keyB, keyC, keyDead =
    { opaque = true }, { opaque = true }, { opaque = true }, { opaque = true }

local records = {
    [keyA] = { key = keyA, guid = guidA, unit = "prior",
        selected = false, dead = false, health = 100, healthMax = 100,
        healthExact = true },
    [keyB] = { key = keyB, guid = guidB, unit = "target",
        selected = true, dead = false, health = 200, healthMax = 200,
        healthExact = true },
    [keyC] = { key = keyC, guid = guidC, unit = "unknown",
        selected = false, dead = false, health = 0, healthMax = 0,
        healthExact = false },
    [keyDead] = { key = keyDead, guid = guidDead, unit = "dead",
        selected = false, dead = true, health = 0, healthMax = 100,
        healthExact = true },
}

local function stateWith(shots)
    return { hostile = true, targetGUID = guidB, targetHealth = 200,
        targetHealthExact = true, targetDistance = 20,
        targetLineOfSight = true, time = 0,
        hostiles = { order = { keyA, keyB, keyC, keyDead },
            byKey = records, selectedKey = keyB, total = 4, capped = false },
        autoShot = { active = false, projectable = false,
            rangeChecked = true, rangeVerdict = true,
            rangeIdentityVerified = true, rangeTargetGuid = guidB,
            rangeSpellId = 75,
            targetGuid = guidB, projectileDistance = 20,
            projectileDistanceKind = "center", projectileSpeed = 40,
            ammoKnown = true, ammoCount = 10, inFlight = shots },
        inventory = { ammo = { known = true, count = 10 } } }
end

dofile("Graph/AutoShotUncertainty.lua")
dofile("Graph/AutoShotEffects.lua")
local A = XelAssist.Graph.AutoShotEffects

local source = stateWith({
    { targetGuid = guidA, power = 40, delivery = 0.4,
        rawPower = 100, spellId = 75, remaining = 0.1 },
    { targetGuid = guidA, power = 25, delivery = 0.25,
        rawPower = 100, spellId = 75, remaining = 2 },
    { targetGuid = guidC, power = 30, delivery = 0.3,
        rawPower = 100, spellId = 75, remaining = 2 },
    { targetGuid = guidDead, power = 90, remaining = 2 },
    { targetGuid = guidMissing, power = 90, remaining = 2 },
})
local out = XelAssist.Graph.State:Copy(source)
local candidate = { wait = 0, cast = 0, occupancy = 1, downtime = 1 }
local timeline = A:CreateTimeline(out, source, candidate)
assert(timeline and table.getn(timeline.events) == 5,
    "off-selected carried shots must still open one bounded projectile timeline")
local i
for i = 1, table.getn(timeline.events) do
    if timeline.events[i].offset <= timeline.windowEnd then
        A:ApplyTimelineEvent(out, timeline, timeline.events[i])
    end
end
A:FinishTimeline(out, timeline)

assert(out.hostiles.byKey[keyA].health == 60,
    "an in-flight shot must resolve against its exact launch target after retargeting")
assert(out.hostiles.byKey[keyA].projectedThreat.player == 40
    and out.hostiles.byKey[keyA].threat.playerDelta == 40,
    "Auto Shot threat must accrue from actual damage on its launch target")
assert(out.hostiles.byKey[keyB].health == 200 and out.targetHealth == 200,
    "a prior-target projectile must never damage the currently selected mirror")
assert(syncs == 0,
    "changing an off-selected hostile must not resync selected compatibility fields")
assert(out.autoShot.impacts == 1
    and out.autoShot.impactOffsets[1] == 0.1,
    "the carried launch-time power must resolve exactly once without recomputation")
assert(table.getn(out.autoShot.inFlight) == 2
    and out.autoShot.inFlight[1].targetGuid == guidA
    and out.autoShot.inFlight[1].power == 25
    and out.autoShot.inFlight[1].delivery == 0.25
    and out.autoShot.inFlight[2].targetGuid == guidC,
    "known living and unknown-health targets must retain fixed in-flight outcomes")
assert(out.autoShot.inFlight[1].remaining == 1
    and out.autoShot.inFlight[2].remaining == 1,
    "retained projectile clocks must advance without changing target identity")

local selectedSource = stateWith({
    { targetGuid = guidB, power = 50, delivery = 1,
        rawPower = 50, spellId = 75, remaining = 0.1 },
})
local selectedOut = XelAssist.Graph.State:Copy(selectedSource)
local selectedTimeline = A:CreateTimeline(
    selectedOut, selectedSource, candidate)
A:ApplyTimelineEvent(selectedOut, selectedTimeline,
    selectedTimeline.events[1])
assert(selectedOut.hostiles.byKey[keyB].health == 150
    and selectedOut.targetHealth == 150 and syncs == 1
    and selectedOut.hostiles.byKey[keyB].projectedThreat.player == 50,
    "only an impact that changes the selected record may sync its mirror")

local lethalSource = stateWith({
    { targetGuid = guidA, power = 150, delivery = 1,
        rawPower = 150, spellId = 75, remaining = 0.1 },
})
local lethalOut = XelAssist.Graph.State:Copy(lethalSource)
local lethalTimeline = A:CreateTimeline(lethalOut, lethalSource, candidate)
A:ApplyTimelineEvent(lethalOut, lethalTimeline, lethalTimeline.events[1])
assert(lethalOut.hostiles.byKey[keyA].health == 0
    and lethalOut.hostiles.byKey[keyA].projectedThreat.player == 100,
    "Auto Shot overkill must create threat only for health-capped damage")

XelAssist.Combat.AutoShot = {
    Project = function(_, observed)
        local projected = {}
        for key, entry in pairs(observed) do projected[key] = entry end
        projected.launches, projected.launchOffsets = 1, { 0 }
        projected.impactOffset, projected.windowEnd = 0, 0.25
        return projected
    end,
}
local offSelected = stateWith({})
offSelected.autoShot.active, offSelected.autoShot.projectable = true, true
offSelected.autoShot.targetGuid, offSelected.autoShot.shotDamage = guidA, 80
assert(A:Project(offSelected, candidate) == nil,
    "new launches must not follow an Auto Shot target that is no longer selected")

local selectedLaunch = stateWith({})
selectedLaunch.autoShot.active, selectedLaunch.autoShot.projectable = true, true
selectedLaunch.autoShot.targetGuid, selectedLaunch.autoShot.shotDamage = guidB, 80
local launchOut = XelAssist.Graph.State:Copy(selectedLaunch)
local launchTimeline = A:CreateTimeline(launchOut, selectedLaunch, candidate)
assert(launchTimeline and launchTimeline.shots[1].targetGuid == guidB,
    "a newly planned projectile must carry the exact selected identity")
launchOut.hostiles.selectedKey = keyA
launchOut.targetGUID = guidA
assert(not A:ApplyTimelineEvent(launchOut, launchTimeline,
        launchTimeline.events[1]) and launchOut.autoShot.ammoCount == 10,
    "a selection change before launch must cancel the stale planned projectile")

XelAssist.Combat.AutoShot = nil
local legacy = stateWith({
    { targetGuid = guidA, power = 50, remaining = 0.1 },
})
legacy.hostiles = nil
local legacyHealth, legacyImpacts = A:HealthBeforeImpact(legacy,
    { wait = 1, cast = 0, occupancy = 1, downtime = 2 })
assert(legacyHealth == 200 and legacyImpacts == 0,
    "a legacy prior-target projectile must retain selected-mirror isolation")
legacy.autoShot.inFlight[1].targetGuid = guidB
legacyHealth, legacyImpacts = A:HealthBeforeImpact(legacy,
    { wait = 1, cast = 0, occupancy = 1, downtime = 2 })
assert(legacyHealth == 150 and legacyImpacts == 1,
    "states without hostile records must preserve current-target behavior")

records[keyA].health, records[keyA].healthExact = 100, true
records[keyA].threat = { playerDelta = 0 }
local uncertain = stateWith({})
uncertain.autoShot.unknownInFlight = { { targetGuid = guidA, spellId = 75,
    power = 40, timingUnknown = true } }
local uncertainOut = XelAssist.Graph.State:Copy(uncertain)
local uncertainTimeline = A:CreateTimeline(uncertainOut, uncertain, candidate)
assert(uncertainTimeline
    and uncertainOut.hostiles.byKey[keyA].healthExact == false
    and uncertainOut.hostiles.byKey[keyA].autoShotImpactTimingUnknown
    and uncertainOut.hostiles.byKey[keyA].threat.playerDeltaExact == false,
    "an observed arrow with unknown timing must invalidate only its target's health and threat")
A:FinishTimeline(uncertainOut, uncertainTimeline)
assert(table.getn(uncertainOut.autoShot.unknownInFlight) == 1
    and uncertainOut.autoShot.unknownInFlight[1].targetGuid == guidA,
    "unknown projectile evidence must persist across graph windows")
uncertain.autoShot.unknownInFlight[1].targetGuid = guidB
assert(A:HealthBeforeImpact(uncertain, candidate) == nil,
    "unknown impact ordering on the selected target must withhold exact health")

local globalUncertain = stateWith({})
globalUncertain.autoShot.flightOverflowGlobal = true
local globalOut = XelAssist.Graph.State:Copy(globalUncertain)
local globalTimeline = A:CreateTimeline(globalOut, globalUncertain, candidate)
assert(globalTimeline and not globalOut.hostiles.byKey[keyA].healthExact
    and not globalOut.hostiles.byKey[keyB].healthExact
    and globalOut.hostiles.byKey[keyDead].healthExact,
    "global projectile overflow must invalidate every living bounded hostile, never proven dead records")

print("ok: hostile-local Auto Shot routing and conservative projectile retention")
