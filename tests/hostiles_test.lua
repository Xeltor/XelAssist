XelAssist = { Game = {}, Combat = {}, Graph = {}, UI = {} }
table.getn = table.getn or function(value)
    local count = 0
    while value[count + 1] ~= nil do count = count + 1 end
    return count
end

local now, units = 100, {}
GetTime = function() return now end
UnitExists = function(unit)
    local record = units[unit]
    if record then return true, record.guid end
    return false, nil
end
UnitCanAttack = function(_, unit)
    local record = units[unit]
    return record and record.hostile and true or false
end
UnitIsDead = function(unit)
    local record = units[unit]
    return record and record.dead and true or false
end
UnitIsUnit = function(first, second)
    local a, b = units[first], units[second]
    return a and b and a.guid ~= nil and a.guid == b.guid and true or false
end
UnitHealth = function(unit) return units[unit] and units[unit].health or 0 end
UnitHealthMax = function(unit) return units[unit] and units[unit].healthMax or 0 end
UnitName = function() error("hostile snapshots must not collect unit names") end
IsInInstance = function() return true, "party" end
GetRealZoneText = function() return "Test Depths" end
GetSubZoneText = function() return "Combat Room" end
GetMinimapZoneText = function() return "Combat Room" end
local raidCount, partyCount = 0, 4
GetNumRaidMembers = function() return raidCount end
GetNumPartyMembers = function() return partyCount end

local function unit(guid, hostile, extra)
    local out = { guid = guid, hostile = hostile, health = 1000,
        healthMax = 2000, exact = true, distance = 20,
        petDistance = 4, lineOfSight = true, behind = false }
    local key, value
    for key, value in pairs(extra or {}) do out[key] = value end
    return out
end

local enemyA, enemyB, enemyC = "enemy-a", "enemy-b", {}
local enemyD, enemyE, enemyF = "enemy-d", "enemy-e", "enemy-f"
units = {
    player = unit("player-guid", false), pet = unit("pet-guid", false),
    party1 = unit("ally-1", false), party2 = unit("ally-2", false),
    target = unit(enemyA, true, { health = 700, distance = 8,
        selectedDistance = 0 }),
    mouseover = unit(enemyB, true, { exact = false, distance = 31,
        selectedDistance = 9, lineOfSight = nil }),
    pettarget = unit(enemyC, true, { distance = 6, petDistance = 3,
        selectedDistance = 7 }),
    party1target = unit(enemyC, true, { distance = 22 }),
    party2target = unit(enemyD, true),
    party3target = unit(enemyE, true),
    party4target = unit(enemyF, true),
    targettarget = unit("player-guid", false),
    mouseovertarget = unit("ally-1", false),
    pettargettarget = unit("pet-guid", false),
    party2targettarget = unit("ally-2", false),
}
units.mouseover.lineOfSight = nil

XelAssist.Game.Capabilities = {
    Health = function(_, token)
        local record = units[token]
        return record.health, record.healthMax, record.exact
    end,
    Distance = function(_, token)
        local record = units[token]
        return record.distance, record.distance and "test-hitbox" or nil
    end,
    Geometry = function(_, from, token)
        local record = units[token]
        return { lineOfSight = record.lineOfSight, behind = record.behind,
            source = from == "pet" and "pet-test" or "player-test" }
    end,
}
XelAssist.Game.Actors = {
    Distance = function(_, from, token)
        local record = units[token]
        if from == "target" then
            return record.selectedDistance,
                record.selectedDistance and "selected-hitbox" or nil
        end
        assert(from == "pet")
        return record.petDistance, record.petDistance and "pet-hitbox" or nil
    end,
}

local auraCalls = {}
XelAssist.Game.Encounter = {
    Unit = function(_, token, relation)
        local record = units[token]
        return { unit = token, guid = record.guid, relation = relation,
            level = token == "target" and 63 or 61,
            creatureId = token == "target" and 9001 or 9002 }
    end,
    Auras = function(_, token, filter)
        auraCalls[token] = (auraCalls[token] or 0) + 1
        if filter == "HARMFUL" then
            local aura = { name = "Observed Dot", spellId = 99,
                remaining = 7, mine = true }
            return { available = true, list = { aura },
                byName = { [aura.name] = aura } }
        end
        if token == "mouseover" then
            return { available = false, list = {}, byName = {} }
        end
        return { available = true, list = {}, byName = {} }
    end,
}
XelAssist.Combat.Resistance = { Snapshot = function()
    error("Game.Hostiles must not interpret resistance evidence")
end }
XelAssist.Combat.TargetModifiers = { Active = function()
    error("Game.Hostiles must not project target modifiers")
end }
UnitCastingInfo = function()
    error("unverified retail cast APIs must not be called on the 1.12 client")
end
UnitChannelInfo = UnitCastingInfo
XelAssist.targetCastGUID, XelAssist.targetCastUntil = enemyA, 104

dofile("Game/Hostiles.lua")
local H = XelAssist.Game.Hostiles
local snapshot = H:Snapshot()
assert(H.MAX_TARGETS == 5 and snapshot.total == 6 and snapshot.capped
    and table.getn(snapshot.order) == 5 and not snapshot.discoveryComplete
    and snapshot.additionalUnknown,
    "observable hostile expansion must be GUID-deduplicated and capped")
assert(snapshot.order[1] == enemyA and snapshot.order[2] == enemyB
    and snapshot.order[3] == enemyC and snapshot.order[4] == enemyD
    and snapshot.order[5] == enemyE and not snapshot.byKey[enemyF],
    "hostile priority must be selected, mouseover, companion, then group targets")

local selected = snapshot.byKey[enemyA]
assert(selected.unit == "target" and selected.source == "selected"
    and selected.selected and selected.executable
    and selected.targetRef.guid == enemyA
    and selected.targetRef.relation == "hostile"
    and selected.targetRef.priority == 1 and snapshot.selectedKey == enemyA,
    "the selected hostile must expose an exact executable action reference")
assert(selected.health == 700 and selected.healthMax == 2000
    and selected.healthExact and selected.healthAvailable,
    "exact hostile health evidence was not preserved")
assert(selected.harmfulAuras.available
    and selected.harmfulAuras.byName["Observed Dot"].remaining == 7
    and selected.helpfulAuras.available and selected.auras == nil,
    "hostile aura polarity and availability evidence were not preserved")
assert(selected.resistance == nil and selected.modifier == nil,
    "raw hostile observation must not own graph resistance/modifier policy")
assert(selected.cast.available and selected.cast.active
    and selected.cast.remaining == 4
    and selected.cast.source == "SuperWoW selected-target cast event",
    "selected-target SuperWoW cast evidence was not correlated by identity")
assert(selected.victim.available and selected.victim.guid == "player-guid"
    and selected.hasPlayerAggro and selected.hasPetAggro == false,
    "the exact hostile victim must drive actor-local aggro evidence")
assert(selected.distance == 8 and selected.distanceKind == "test-hitbox"
    and selected.lineOfSight and selected.behind == false
    and selected.geometry.pet.distance == 4
    and selected.geometry.pet.distanceKind == "pet-hitbox",
    "player and companion geometry evidence was not retained")
assert(selected.selectedDistance == 0
    and selected.geometry.selected.source == "identity",
    "selected-hostile identity geometry must be exact")
assert(selected.encounter.guid == enemyA and selected.encounter.creatureId == 9001,
    "encounter join evidence must remain target-local")
assert(snapshot.location.zone == "Test Depths"
    and snapshot.location.instanceType == "party",
    "raw encounter location evidence was not preserved")

local mouseover = snapshot.byKey[enemyB]
assert(not mouseover.selected and not mouseover.executable
    and mouseover.healthExact == false and mouseover.lineOfSight == nil
    and mouseover.helpfulAuras.available == false
    and not mouseover.cast.available and mouseover.cast.active == nil,
    "off-target evidence must remain non-executable and preserve unknowns")
assert(mouseover.selectedDistance == 9
    and mouseover.selectedDistanceKind == "selected-hitbox",
    "target-centered area geometry must be captured in the live snapshot")
local companionTarget = snapshot.byKey[enemyC]
assert(companionTarget.guid == enemyC and companionTarget.unit == "pettarget"
    and companionTarget.aliases.pettarget
    and companionTarget.aliases.party1target
    and companionTarget.sources.companion and companionTarget.sources.party
    and snapshot.byUnit.pettarget == enemyC
    and snapshot.byUnit.party1target == enemyC,
    "companion/group aliases must resolve to one exact opaque identity")
assert(not companionTarget.cast.available and companionTarget.cast.active == nil
    and companionTarget.cast.remaining == nil,
    "off-target casting must stay unknown without a GUID-keyed event ledger")
assert(companionTarget.victim.targetsPet and companionTarget.hasPetAggro
    and companionTarget.hasPlayerAggro == false,
    "companion aggro must be attached to the hostile it is fighting")
assert(snapshot.byKey[enemyC] and snapshot.byKey[enemyC].guid == enemyC
    and snapshot.order[3] == enemyC,
    "opaque identities must remain exact table keys and ordered values")
assert(auraCalls.party4target == nil,
    "expensive hostile evidence must be collected only after the cap")

local repeated = H:Snapshot()
local i
for i = 1, table.getn(snapshot.order) do
    assert(repeated.order[i] == snapshot.order[i],
        "hostile cap ordering must be deterministic")
end

-- Missing providers and percentage health must stay explicitly incomplete.
XelAssist.Game.Capabilities = {}
XelAssist.Game.Actors = nil
XelAssist.Game.Encounter = nil
UnitCastingInfo, UnitChannelInfo = nil, nil
XelAssist.targetCastGUID, XelAssist.targetCastUntil = nil, nil
partyCount = 0
units = { player = unit("player-guid", false),
    target = unit("unknown-evidence", true, { health = 42, healthMax = 100 }) }
local unknown = H:Snapshot().byKey["unknown-evidence"]
assert(unknown and unknown.healthAvailable and not unknown.healthExact
    and unknown.distance == nil and unknown.lineOfSight == nil
    and not unknown.harmfulAuras.available
    and unknown.resistance == nil and unknown.modifier == nil
    and not unknown.cast.available and unknown.cast.active == nil
    and not unknown.victim.available and unknown.hasPlayerAggro == nil,
    "missing hostile capabilities must remain unknown rather than safe defaults")
local unknownSnapshot = H:Snapshot()
assert(not unknownSnapshot.discoveryComplete and unknownSnapshot.additionalUnknown,
    "an uncapped unit-token snapshot must still not claim exhaustive discovery")

-- A raid roster supersedes party target tokens and remains bounded/deduplicated.
local raidEnemy = {}
raidCount, partyCount = 2, 4
units = {
    player = unit("player-guid", false),
    target = unit(enemyA, true),
    raid1target = unit(raidEnemy, true),
    raid2target = unit(enemyA, true),
    party1target = unit("party-only-enemy", true),
}
local raid = H:Snapshot()
assert(raid.total == 2 and raid.byKey[raidEnemy]
    and raid.byUnit.raid1target == raidEnemy
    and raid.byUnit.raid2target == enemyA
    and raid.byUnit.party1target == nil,
    "raid targets must be observed instead of stale party target tokens")

print("ok: capped identity-safe hostile observation and conservative evidence")
