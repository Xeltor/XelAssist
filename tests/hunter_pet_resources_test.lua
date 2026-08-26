table.getn = table.getn or function(value)
    local count = 0
    while value[count + 1] ~= nil do count = count + 1 end
    return count
end

XelAssist = { Game = { Pets = {} } }
local now = 0
GetTime = function() return now end
dofile("Game/Pets/FocusEvidence.lua")
dofile("Game/Pets/FocusEvents.lua")
dofile("Game/Pets/Resources.lua")
local E = XelAssist.Game.Pets.FocusEvidence
local F = XelAssist.Game.Pets.FocusEvents
local R = XelAssist.Game.Pets.Resources

local hunterGuid, otherGuid = {}, {}
local function observe(focus, at, isEvent, maximum, guid, ownerClass)
    now = at
    return E:Observe(guid or hunterGuid, focus, maximum or 100, at,
        isEvent and true or false, ownerClass or "HUNTER")
end

E:ResetSession()
E:SetEnergizeEvidenceAvailable(true)
assert(observe(10, 0, false) == nil)
assert(observe(33, 4, true) == nil)
assert(observe(56, 8, true) == nil,
    "two gains are not enough to execute an inferred focus clock")
local learned = observe(79, 12, true)
assert(learned and learned.verified and learned.amount == 23
    and learned.observedInterval == 4 and learned.interval == 4.8
    and learned.nextIn == 4.8 and learned.samples == 3,
    "live cadence must gain a not-before jitter envelope")
assert(learned.externalEnergizeExcluded,
    "executable clocks must report active energize attribution")
assert(E:Status().executable and E:Status().phaseKnown,
    "diagnostic state must agree with the executable graph clock")

local lifecycle = { resourceRegen = learned }
local actor = { ownerClass = "HUNTER", guid = hunterGuid,
    resource = 10, resourceMax = 100, resourceExact = true }
R:Attach(actor, lifecycle)
assert(actor.resourceType == 2 and actor.resourceRegenKnown)
assert(math.abs(R:TimeUntil(actor, 55) - 9.6) < 0.001)
assert(R:AdvanceActor(actor, 4.799) == 0 and actor.resource == 10,
    "focus must not arrive before the conservative tick boundary")
assert(R:AdvanceActor(actor, 0.002) == 23 and actor.resource == 33)

local splitA = { ownerClass = "HUNTER", guid = hunterGuid,
    resource = 10, resourceMax = 100 }
local splitB = { ownerClass = "HUNTER", guid = hunterGuid,
    resource = 10, resourceMax = 100 }
R:Attach(splitA, lifecycle); R:Attach(splitB, lifecycle)
R:AdvanceActor(splitA, 2.4); R:AdvanceActor(splitA, 2.4)
R:AdvanceActor(splitB, 4.8)
assert(splitA.resource == 33 and splitB.resource == 33
    and splitA.resourceRegen.nextIn == splitB.resourceRegen.nextIn,
    "projection must be invariant to transition segmentation")
assert(lifecycle.resourceRegen.nextIn == 4.8,
    "actor projection must not mutate observed lifecycle evidence")

local capped = { ownerClass = "HUNTER", guid = hunterGuid,
    resource = 90, resourceMax = 100 }
R:Attach(capped, lifecycle)
assert(R:AdvanceActor(capped, 4.8) == 10 and capped.resource == 100)
assert(not capped.resourceRegen.phaseKnown and capped.resourceRegen.nextIn == nil)
local paid, spent = R:SpendActor(capped, 30)
assert(paid and spent == 30 and capped.resource == 70
    and capped.resourceRegen.phaseKnown
    and capped.resourceRegen.nextIn == 4.8,
    "spending after cap must re-anchor a full conservative interval")
R:AdvanceActor(capped, 4.799); assert(capped.resource == 70)
R:AdvanceActor(capped, 0.002); assert(capped.resource == 93)
paid, spent = R:SpendActor(capped, 94)
assert(not paid and spent == 0 and capped.resource == 93,
    "an unaffordable spend must be atomic")

local warlock = { ownerClass = "WARLOCK", guid = hunterGuid,
    resource = 10, resourceMax = 100, resourceType = 2,
    resourceRegen = R:CopyClock(learned) }
assert(R:AdvanceActor(warlock, 100) == 0 and warlock.resource == 10)
local wrongSource = { ownerClass = "HUNTER", guid = otherGuid,
    resource = 10, resourceMax = 100 }
R:Attach(wrongSource, lifecycle)
assert(not wrongSource.resourceRegenKnown and wrongSource.resourceRegen == nil)

assert(not E:ObserveEnergize(otherGuid, 2, 12.1))
assert(E:Snapshot(hunterGuid, 79, 100, 12.1).phaseKnown)
assert(not E:ObserveEnergize(hunterGuid, 0, 12.1))
assert(E:ObserveEnergize(hunterGuid, 2, 12.1)
    and E:Snapshot(hunterGuid, 79, 100, 12.1) == nil,
    "an attributed energize must discard an ordering-contaminated model")
observe(89, 12.2, true)
observe(20, 13, true)
assert(E:Snapshot(hunterGuid, 20, 100, 13) == nil,
    "a later spend must not reactivate cadence contaminated by a late event")
observe(43, 17, true); observe(66, 21, true)
local recovered = observe(89, 25, true)
assert(recovered and recovered.amount == 23 and recovered.phaseKnown,
    "three later clean ticks must recover the discarded model")

-- Cap obscures candidates but must not destroy a previously verified cadence.
observe(100, 29, true)
local capClock = E:Snapshot(hunterGuid, 100, 100, 29)
assert(capClock and not capClock.phaseKnown)
observe(40, 30, true)
local afterSpend = E:Snapshot(hunterGuid, 40, 100, 30)
assert(afterSpend and afterSpend.phaseKnown and afterSpend.nextIn == 4.8)
local afterCapTick = observe(63, 34, true)
assert(afterCapTick and afterCapTick.verified and afterCapTick.phaseKnown,
    "first clean post-cap tick must preserve the verified regime")

E:ModifierChanged("talent points changed")
assert(E:Snapshot(hunterGuid, 63, 100, 34) == nil)
observe(63, 35, false); observe(86, 39, true)
observe(30, 40, true); observe(53, 44, true)
assert(E:Snapshot(hunterGuid, 53, 100, 44) == nil,
    "a nearby spend must exclude a coalesced positive delta")

E:ResetSession()
E:SetEnergizeEvidenceAvailable(false)
observe(5, 0, false); observe(22, 3, true); observe(39, 6, true)
local unattributed = observe(56, 9, true)
assert(unattributed and unattributed.amount == 17
    and unattributed.observedInterval == 3 and unattributed.interval == 3.6
    and not unattributed.externalEnergizeExcluded
    and not unattributed.phaseKnown,
    "UNIT_FOCUS may diagnose cadence without attribution but cannot execute it")
assert(E:Status().verified and not E:Status().executable
    and not E:Status().phaseKnown,
    "diagnostics must not describe an unattributed phase as executable")
local dormant = { ownerClass = "HUNTER", guid = hunterGuid,
    resource = 0, resourceMax = 100 }
R:Attach(dormant, { resourceRegen = unattributed })
assert(R:TimeUntil(dormant, 17) == nil
    and R:AdvanceActor(dormant, 20) == 0,
    "unattributed cadence must remain graph-dormant")

observe(56, 10, false, 120)
assert(E:Snapshot(hunterGuid, 56, 120, 10) == nil)
observe(10, 11, false, 100, otherGuid)
assert(E:Snapshot(hunterGuid, 10, 100, 11) == nil)
assert(E:Observe(otherGuid, 10, 100, 12, false, "WARLOCK") == nil
    and E.guid == nil)

local registeredEvents, registeredNames = 0, {}
local registrationFrame = { RegisterEvent = function(_, name)
    registeredEvents = registeredEvents + 1
    registeredNames[name] = true
end }
GetNampowerVersion = function() return 4, 4, 9 end
assert(not F:RegisterEnergizeEvents(registrationFrame) and registeredEvents == 0)
local control, energize = F:RegisterRuntimeEvents(registrationFrame)
assert(control and not energize and registeredEvents == 4
    and registeredNames.PLAYER_CONTROL_LOST
    and registeredNames.PLAYER_CONTROL_GAINED
    and registeredNames.UNIT_AURA)
registeredEvents = 0
GetNampowerVersion = function() return 4, 5, 0 end
assert(F:RegisterEnergizeEvents(registrationFrame) and registeredEvents == 3
    and E.externalEnergizeAvailable)
E.guid, E.lastFocus, E.lastFocusMax = hunterGuid, 10, 100
E.verifiedAmount, E.verifiedInterval, E.verifiedSamples = 23, 4.8, 3
E.phaseAt = 16
assert(F:OnRuntimeEvent("PLAYER_CONTROL_GAINED")
    and E:Snapshot(hunterGuid, 10, 100, 16) == nil)
E.guid, E.lastFocus, E.lastFocusMax = hunterGuid, 10, 100
E.verifiedAmount, E.verifiedInterval, E.phaseAt = 23, 4.8, 16
assert(F:OnRuntimeEvent("UNIT_AURA", "pet")
    and E:Snapshot(hunterGuid, 10, 100, 16) == nil,
    "pet aura regime changes must invalidate temporary focus modifiers")

dofile("Game/Pets/Effects.lua")
local effectActor = { ownerClass = "HUNTER", guid = hunterGuid,
    resource = 10, resourceMax = 100 }
R:Attach(effectActor, lifecycle)
XelAssist.Game.Pets.Effects:Advance({ actors = { pet = effectActor } }, 4.8)
assert(effectActor.resource == 33)

XelAssist.Graph = { State = {}, Effects = {}, HostileEffects = {},
    ReadinessEffects = {}, EventAuras = {} }
dofile("Graph/CompanionResources.lua")
dofile("Graph/ActionConsumption.lua")
dofile("Graph/DotProjection.lua")
dofile("Graph/FriendlyActionEffects.lua")
dofile("Graph/ActionEffects.lua")
local chosenActor = { ownerClass = "HUNTER", guid = hunterGuid,
    resource = 100, resourceMax = 100 }
R:Attach(chosenActor, { resourceRegen = {
    verified = true, resourceType = 2, amount = 23, interval = 4.8,
    phaseKnown = false, sourceGuid = hunterGuid,
    externalEnergizeExcluded = true } })
assert(XelAssist.Graph.ActionEffects:Consume(
    { actors = { pet = chosenActor } },
    { action = { actor = "pet", executor = "petAbility", facts = {} },
        cost = 20, costKnown = true }) ~= false)
assert(chosenActor.resource == 80 and chosenActor.resourceRegen.phaseKnown
    and chosenActor.resourceRegen.nextIn == 4.8)

print("ok: attributed Hunter focus learning, conservative timing and graph clocks")
