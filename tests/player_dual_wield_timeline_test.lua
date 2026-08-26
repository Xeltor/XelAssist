XelAssist = { Combat = {}, Graph = {} }
table.getn = table.getn or function(value)
    local count = 0
    while value and value[count + 1] ~= nil do count = count + 1 end
    return count
end

XelAssist.Graph.State = { RefreshHostileRecord = function() end }
XelAssist.Graph.Effects = {
    Decision = function(_, estimate)
        return estimate and estimate.multiplier or 1
    end,
}
XelAssist.Graph.CompanionTargets = {
    Hostiles = function(_, state) return state.hostiles end,
    ForGuid = function(_, state, guid)
        local hostiles = state.hostiles
        local key = hostiles and hostiles.byGuid and hostiles.byGuid[guid]
        return key, key and hostiles.byKey[key]
    end,
    ProvenDead = function(_, record)
        return not record or record.dead == true
            or record.healthExact and record.health <= 0
    end,
    Resolve = function(_, state, entry)
        if state.hostiles or state.targetGUID ~= entry.targetGuid
            or state.targetHealthExact and state.targetHealth <= 0 then
            return nil
        end
        return state, nil, nil, true
    end,
}
local rageAwards = 0
XelAssist.Graph.PlayerRage = { GainFromWhite = function()
    rageAwards = rageAwards + 1
end }
XelAssist.Graph.PlayerThreat = { Add = function() end }
XelAssist.Combat.Resistance = {
    Estimate = function() return { multiplier = 1 } end,
}

GetTime = function() error("dual-wield graph performed a live read") end
UnitExists = GetTime
UnitDamage = GetTime
UnitAttackSpeed = GetTime

dofile("Graph/PlayerSwings.lua")
dofile("Graph/PlayerOffhandSwings.lua")
dofile("Graph/PlayerSwingTimeline.lua")

local Timeline = XelAssist.Graph.PlayerSwingTimeline
local targetGuid = {}

local function state(mainDue, offhandDue, health)
    return { time = 0, hostile = true, targetGUID = targetGuid,
        targetHealth = health or 200, targetHealthExact = true,
        targetDistance = 3, targetDistanceKind = "hitbox",
        playerAttack = { active = true, activeKnown = true,
            onSwing = { occupied = false },
            attackRound = { projectable = true, phaseKnown = true,
                verified = true, targetGuid = targetGuid,
                nextSwingIn = mainDue, interval = 2, power = 60,
                normalDamageKnown = true, phaseSource = "exact main" },
            offhandAttackRound = { projectable = true,
                phaseKnown = true, verified = true,
                targetGuid = targetGuid, nextSwingIn = offhandDue,
                interval = 1.5, power = 20,
                normalDamageKnown = true, phaseSource = "exact off" } } }
end

local function candidate(window)
    return { action = { actor = "player", facts = {} }, wait = 0,
        cast = 0, downtime = window }
end

local converged = state(0.5, 0.55)
local events = Timeline:Events(converged, candidate(1))
assert(table.getn(events) == 2
    and events[1].kind == "playerMainSwing"
    and math.abs(events[1].offset - 0.5) < 0.0001
    and events[2].kind == "playerOffhandSwing"
    and math.abs(events[2].offset - 0.7) < 0.0001,
    "a main-hand round must delay a converging off-hand round to 0.2s")
assert(math.abs(converged.playerAttack.attackRound.nextSwingIn - 1.5)
        < 0.0001
    and math.abs(converged.playerAttack.offhandAttackRound.nextSwingIn - 1.2)
        < 0.0001,
    "the clamp must shift the off-hand's following causal clock")

local offFirst = state(0.55, 0.5)
events = Timeline:Events(offFirst, candidate(1))
assert(events[1].kind == "playerOffhandSwing"
    and math.abs(events[1].offset - 0.5) < 0.0001
    and events[2].kind == "playerMainSwing"
    and math.abs(events[2].offset - 0.7) < 0.0001,
    "the cross-hand guard must work symmetrically when off-hand fires first")

local bothHeld = state(0, 0)
bothHeld.playerAttack.attackRound.readyHeld = true
bothHeld.playerAttack.offhandAttackRound.readyHeld = true
events = Timeline:Events(bothHeld, candidate(0.5))
assert(table.getn(events) == 2
    and events[1].kind == "playerMainSwing"
    and math.abs(events[1].offset - 0.05) < 0.0001
    and events[2].kind == "playerOffhandSwing"
    and math.abs(events[2].offset - 0.25) < 0.0001,
    "two held rounds must re-enter melee on one clamped causal clock")

local heldAndNear = state(0, 0.15)
heldAndNear.playerAttack.attackRound.readyHeld = true
events = Timeline:Events(heldAndNear, candidate(0.5))
assert(table.getn(events) == 2
    and events[1].kind == "playerMainSwing"
    and math.abs(events[1].offset - 0.05) < 0.0001
    and events[2].kind == "playerOffhandSwing"
    and math.abs(events[2].offset - 0.25) < 0.0001,
    "a held hand must delay the other hand when its deadline is within 0.2s")

local boundary = state(0.5, 0.7)
events = Timeline:Events(boundary, candidate(1))
assert(math.abs(events[1].offset - 0.5) < 0.0001
    and math.abs(events[2].offset - 0.7) < 0.0001,
    "a round already exactly 0.2s apart must not be delayed")

local beyond = state(0.9, 1.05)
events = Timeline:Events(beyond, candidate(1))
assert(table.getn(events) == 1 and events[1].kind == "playerMainSwing"
    and math.abs(beyond.playerAttack.offhandAttackRound.nextSwingIn - 0.1)
        < 0.0001,
    "a near-due round just outside the window must retain the server delay")

local lethal = state(0.5, 0.55, 50)
events = Timeline:Events(lethal, candidate(1))
assert(XelAssist.Graph.PlayerSwings:Apply(lethal, events[1])
    and lethal.targetHealth == 0 and lethal.hostile == false,
    "the first causal hand must be able to defeat the target")
assert(not XelAssist.Graph.PlayerOffhandSwings:Apply(lethal, events[2])
    and lethal.targetHealth == 0,
    "a later clamped hand must not damage or reward rage after lethal impact")

local heldLethal, awardsBefore = state(0, 0, 50), rageAwards
heldLethal.playerAttack.attackRound.readyHeld = true
heldLethal.playerAttack.offhandAttackRound.readyHeld = true
events = Timeline:Events(heldLethal, candidate(0.5))
assert(XelAssist.Graph.PlayerSwings:Apply(heldLethal, events[1])
    and not XelAssist.Graph.PlayerOffhandSwings:Apply(heldLethal, events[2])
    and heldLethal.targetHealth == 0 and rageAwards == awardsBefore + 1,
    "a lethal held first hand must suppress later damage and rage rewards")

local unrelated = state(0.5, 0.55)
unrelated.playerAttack.offhandAttackRound.targetGuid = {}
events = Timeline:Events(unrelated, candidate(1))
assert(table.getn(events) == 1
    and events[1].kind == "playerMainSwing"
    and math.abs(events[1].offset - 0.5) < 0.0001,
    "unrelated target-pinned evidence must never emit or cross-couple")

local crowded = state(0.5, 0.55)
events = Timeline:Events(crowded, candidate(15))
local capCount, priorKind, priorOffset, index = 0, nil, nil, nil
for index = 1, table.getn(events) do
    local entry = events[index]
    if entry.kind == "playerSwingTimelineCap" then
        capCount = capCount + 1
        assert(entry.combined and index == table.getn(events),
            "one combined cap must terminate the known dual-wield prefix")
    elseif priorKind and priorKind ~= entry.kind then
        assert(entry.offset - priorOffset >= 0.2 - 0.0001,
            "the crowded known prefix must preserve every cross-hand clamp")
    end
    if entry.kind == "playerMainSwing"
        or entry.kind == "playerOffhandSwing" then
        priorKind, priorOffset = entry.kind, entry.offset
    end
end
assert(capCount == 1
    and crowded.playerAttack.attackRound.projectable == false
    and crowded.playerAttack.offhandAttackRound.projectable == false,
    "a lane event cap must fail the shared future closed without reverting")

print("ok: one causal dual-wield player swing timeline")
