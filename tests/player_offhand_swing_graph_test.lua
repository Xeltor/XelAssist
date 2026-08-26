XelAssist = { Game = { Player = {} }, Combat = {}, Graph = {} }
table.getn = table.getn or function(value)
    local count = 0
    while value[count + 1] ~= nil do count = count + 1 end
    return count
end

local refreshed, rageGained = 0, 0
XelAssist.Graph.State = {
    RefreshHostileRecord = function() refreshed = refreshed + 1 end,
}
XelAssist.Graph.Effects = {
    Decision = function(_, estimate)
        return estimate and estimate.multiplier or 1
    end,
}
XelAssist.Graph.CompanionTargets = {
    Hostiles = function(_, state) return state.hostiles end,
    ForGuid = function(_, state, guid)
        local hostiles = state.hostiles
        if not hostiles then return nil, nil end
        local key = hostiles.byGuid and hostiles.byGuid[guid]
        return key, key and hostiles.byKey[key] or nil
    end,
    ProvenDead = function(_, record)
        return not record or record.dead == true
            or record.healthExact and record.health <= 0
    end,
    Resolve = function(self, state, entry)
        if entry.targetLocal then
            local key, record = self:ForGuid(state, entry.targetGuid)
            if key ~= entry.targetKey or self:ProvenDead(record) then return nil end
            return state, key, record, true
        end
        if state.hostiles or state.targetGUID ~= entry.targetGuid
            or state.targetHealthExact and state.targetHealth <= 0 then
            return nil
        end
        return state, nil, nil, true
    end,
}
XelAssist.Graph.PlayerRage = {
    GainFromWhite = function(_, _, damage)
        rageGained = rageGained + damage
    end,
}
XelAssist.Graph.PlayerThreat = {
    Add = function(_, record, _, actor, amount)
        assert(actor == "player")
        record.projectedOffhandThreat =
            (record.projectedOffhandThreat or 0) + amount
    end,
}
XelAssist.Combat.Resistance = {
    Estimate = function(_, action, target, tooltip)
        assert(action.facts.whiteAttack and action.facts.weaponHand == "off"
            and action.facts.usesWeaponSkill
            and target == "target" and tooltip.school == 0,
            "off-hand events must use the exact off-hand white table")
        return { multiplier = 0.5 }
    end,
}

-- Search must remain independent of every mutable live API.
GetTime = function() error("off-hand graph search performed a live read") end
UnitDamage = GetTime
UnitAttackSpeed = GetTime
UnitExists = GetTime
GetUnitField = GetTime

dofile("Graph/PlayerOffhandSwings.lua")
local Swings = XelAssist.Graph.PlayerOffhandSwings
local targetGuid = {}

local function state()
    return { time = 0, targetGUID = targetGuid, targetHealth = 100,
        targetHealthExact = true, hostile = true,
        targetDistance = 3, targetDistanceKind = "hitbox",
        playerAttack = { active = true, activeKnown = true,
            onSwing = { occupied = true, marker = "main-hand only" },
            offhandAttackRound = { hand = "off", projectable = true,
                phaseKnown = true, verified = true,
                normalDamageKnown = true, targetGuid = targetGuid,
                nextSwingIn = 0.5, interval = 1.5, power = 20,
                phaseSource = "test exact off-hand round" } } }
end

local candidate = { action = { actor = "player", facts = {} },
    wait = 0, cast = 0, downtime = 3.2 }
local current = state()
local events = Swings:Events(current, candidate)
assert(table.getn(events) == 2
    and events[1].kind == "playerOffhandSwing"
    and events[1].offset == 0.5 and events[2].offset == 2
    and math.abs(current.playerAttack.offhandAttackRound.nextSwingIn - 0.3)
        < 0.0001,
    "the exact off-hand phase must schedule an independent bounded lane")
assert(Swings:CanChange(current),
    "an active exact off-hand lane must invalidate no-ambient-damage shortcuts")

assert(Swings:Apply(current, events[1]) and current.targetHealth == 90
    and rageGained == 10,
    "the first off-hand event must apply expected delivered damage once")
assert(current.playerAttack.onSwing.marker == "main-hand only",
    "an off-hand event must never consume the main-hand replacement slot")
assert(Swings:Apply(current, events[2]) and current.targetHealth == 80
    and rageGained == 20,
    "later off-hand rounds must remain causal and independent")

local changed = state()
local changedEvents = Swings:Events(changed,
    { action = candidate.action, wait = 0, cast = 0, downtime = 1 })
changed.playerAttack.offhandAttackRound.targetGuid = {}
assert(not Swings:Apply(changed, changedEvents[1])
    and changed.targetHealth == 100,
    "target identity changes must retire a captured off-hand event")

local hostile = state()
local key = {}
local record = { key = key, guid = targetGuid, health = 50,
    healthExact = true, geometry = { player = {
        distance = 3, distanceKind = "combat reach" } } }
hostile.hostiles = { order = { key }, byKey = { [key] = record },
    byGuid = { [targetGuid] = key } }
local hostileEvents = Swings:Events(hostile,
    { action = candidate.action, wait = 0, cast = 0, downtime = 1 })
assert(table.getn(hostileEvents) == 1
    and hostileEvents[1].targetKey == key
    and hostileEvents[1].targetLocal,
    "engaged-hostile events must retain their exact record identity")
assert(Swings:Apply(hostile, hostileEvents[1])
    and record.health == 40 and record.projectedOffhandThreat == 10
    and refreshed == 1,
    "off-hand damage and threat must update only the captured hostile")

local unknownPower = state()
unknownPower.playerAttack.offhandAttackRound.normalDamageKnown = false
local unknownEvents = Swings:Events(unknownPower,
    { action = candidate.action, wait = 0, cast = 0, downtime = 1 })
assert(Swings:Apply(unknownPower, unknownEvents[1])
    and not unknownPower.targetHealthExact
    and unknownPower.playerOffhandDamageUnknown,
    "unknown magnitude must poison exact health instead of inventing damage")

local outOfRange = state()
outOfRange.targetDistance = 7
local rangeEvents = Swings:Events(outOfRange,
    { action = candidate.action, wait = 0, cast = 0, downtime = 1 })
assert(table.getn(rangeEvents) == 0
    and outOfRange.playerAttack.offhandAttackRound.readyHeld,
    "an out-of-range off-hand deadline must hold without phantom damage")
outOfRange.targetDistance = 3
rangeEvents = Swings:Events(outOfRange,
    { action = candidate.action, wait = 0, cast = 0, downtime = 0.1 })
assert(table.getn(rangeEvents) == 1 and rangeEvents[1].offset == 0.05,
    "a held off-hand round may resume only after exact melee range returns")

local casting = state()
casting.playerCasting, casting.castRemaining = true, 1
local castEvents = Swings:Events(casting,
    { action = candidate.action, wait = 0, cast = 0, downtime = 1.1 })
assert(table.getn(castEvents) == 1
    and math.abs(castEvents[1].offset - 1.05) < 0.0001,
    "an existing cast lock must defer rather than erase the off-hand round")

local capped = state()
capped.playerAttack.offhandAttackRound.nextSwingIn = 0.05
capped.playerAttack.offhandAttackRound.interval = 0.1
local capCandidate = { action = candidate.action, wait = 0,
    cast = 0, downtime = 2 }
local capEvents = Swings:Events(capped, capCandidate)
assert(table.getn(capEvents) == 9
    and capEvents[9].kind == "playerOffhandTimelineCap"
    and not capped.playerAttack.offhandAttackRound.projectable
    and not capped.playerAttack.offhandAttackRound.phaseKnown
    and capCandidate.playerOffhandUnknowns[1]
        == "player off-hand swing timeline cap",
    "the off-hand lane must fail closed at its fixed event budget")

print("ok: bounded causal player off-hand graph lane")
