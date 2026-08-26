XelAssist = { Game = {}, Combat = {}, Graph = {}, UI = {} }
table.getn = table.getn or function(value)
    local count = 0
    while value[count + 1] ~= nil do count = count + 1 end
    return count
end

local units = {}
UnitExists = function(unit)
    local record = units[unit]
    if record then return true, record.guid end
    return false, nil
end
UnitCanAssist = function(_, unit)
    local record = units[unit]
    return record and record.assist and true or false
end
UnitCanAttack = function(_, unit)
    local record = units[unit]
    return record and record.hostile and true or false
end
UnitIsDead = function(unit)
    local record = units[unit]
    return record and record.dead and true or false
end
UnitIsPlayer = function(unit)
    local record = units[unit]
    return record and record.player ~= false and true or false
end
UnitIsUnit = function(first, second)
    local a, b = units[first], units[second]
    return a and b and a.guid and a.guid == b.guid and true or false
end
UnitHealth = function(unit) return units[unit] and units[unit].health or 0 end
UnitHealthMax = function(unit) return units[unit] and units[unit].healthMax or 0 end
UnitName = function() error("friendly snapshots must not collect unit names") end

XelAssist.Game.Capabilities = {
    Health = function(_, unit)
        local record = units[unit]
        return record.health, record.healthMax, record.exact
    end,
    Distance = function(_, unit)
        local record = units[unit]
        return record.distance, record.distance and "test" or nil
    end,
    Geometry = function(_, _, unit)
        local record = units[unit]
        return { lineOfSight = record.lineOfSight }
    end,
}

local auraCalls = {}
XelAssist.Game.Encounter = {
    Auras = function(_, unit, filter)
        assert(filter == "HELPFUL", "friendlies must request only helpful aura state")
        auraCalls[unit] = (auraCalls[unit] or 0) + 1
        if unit == "party4" then
            local renew = { name = "Renew", remaining = 8, mine = true }
            return { available = true, list = { renew }, byName = { Renew = renew } }
        end
        if unit == "party2" then
            local stale = { name = "Stale", remaining = 99 }
            return { available = false, list = { stale }, byName = { Stale = stale } }
        end
        return { available = false, list = {}, byName = {} }
    end,
}

dofile("Game/Friendlies.lua")

local function unit(guid, health, maximum, assist, extra)
    local out = { guid = guid, health = health, healthMax = maximum,
        assist = assist, exact = true, distance = 20, lineOfSight = true }
    local key, value
    for key, value in pairs(extra or {}) do out[key] = value end
    return out
end

units = {
    player = unit("player-guid", 1000, 1000, true, { distance = 0 }),
    pet = unit("pet-guid", 1000, 1000, true),
    party1 = unit("ally-1", 600, 1000, true),
    party2 = unit("ally-2", 300, 1000, true),
    party3 = unit("ally-3", 850, 1000, true),
    party4 = unit("ally-4", 950, 1000, true),
    party5 = unit("ally-5", 1, 1000, true, { dead = true }),
    party6 = unit("ally-6", 1, 1000, false),
    mouseover = unit("ally-4", 950, 1000, true),
    target = unit("enemy-guid", 5000, 5000, false, { hostile = true }),
    targettarget = unit("ally-3", 850, 1000, true),
}
local actors = {
    player = { unit = "player", guid = "player-guid" },
    pet = { unit = "pet", guid = "pet-guid" },
    allies = {
        { unit = "party1", guid = "ally-1" },
        { unit = "party2", guid = "ally-2" },
        { unit = "party3", guid = "ally-3" },
        { unit = "party4", guid = "ally-4" },
        { unit = "party5", guid = "ally-5", dead = true },
        { unit = "party6", guid = "ally-6" },
    },
}

local snapshot = XelAssist.Game.Friendlies:Snapshot(actors)
assert(snapshot.total == 6 and snapshot.capped,
    "player, pet and four eligible allies should dedupe to six before the cap")
assert(table.getn(snapshot.order) == XelAssist.Game.Friendlies.MAX_TARGETS,
    "friendly target expansion must remain capped at three")
assert(snapshot.order[1] == "g:ally-4", "mouseover must be retained first")
assert(snapshot.order[2] == "g:ally-3", "the hostile target's victim must be retained second")
assert(snapshot.order[3] == "g:ally-2", "largest missing-health fraction must win next")
local mouseover = snapshot.byKey["g:ally-4"]
assert(mouseover and mouseover.unit == "party4" and mouseover.source == "party")
assert(mouseover.relation == "party" and mouseover.explicit == 2)
assert(snapshot.byUnit.mouseover == mouseover.key and snapshot.byUnit.party4 == mouseover.key,
    "GUID aliases must resolve to one canonical record")
assert(mouseover.targetRef.key == mouseover.key and mouseover.targetRef.unit == "party4"
    and mouseover.targetRef.guid == "ally-4" and mouseover.targetRef.relation == "ally"
    and mouseover.targetRef.source == "party" and mouseover.targetRef.priority == 1)
assert(mouseover.priority == 1 and mouseover.kind == "test" and mouseover.distanceKind == "test")
assert(mouseover.auras.available and mouseover.auras.Renew.remaining == 8)
assert(not mouseover.absorbs.available,
    "helpful aura visibility must not claim that absorb amounts are known")
assert(snapshot.byKey["g:ally-3"].targetedByCurrentEnemy)
assert(not snapshot.byKey["g:ally-2"].targetedByCurrentEnemy)
assert(not snapshot.byKey["g:ally-2"].auras.available
    and snapshot.byKey["g:ally-2"].auras.Stale == nil,
    "unavailable aura observations must remain unknown, not stale known state")
assert(auraCalls.party4 == 1 and auraCalls.party3 == 1 and auraCalls.party2 == 1
    and auraCalls.player == nil,
    "aura collection should run only for retained records")

local repeated = XelAssist.Game.Friendlies:Snapshot(actors)
local i
for i = 1, table.getn(snapshot.order) do
    assert(repeated.order[i] == snapshot.order[i], "friendly cap ordering must be deterministic")
end

local copy = XelAssist.Game.Friendlies:Copy(snapshot)
copy.byKey["g:ally-4"].health = 1
copy.byKey["g:ally-4"].targetRef.unit = "changed"
copy.byKey["g:ally-4"].auras.Renew.remaining = 1
copy.byKey["g:ally-4"].absorbs.Shield = { amount = 10 }
copy.byKey["g:ally-4"].aliases.mouseover = nil
assert(mouseover.health == 950 and mouseover.targetRef.unit == "party4")
assert(mouseover.auras.Renew.remaining == 8 and mouseover.absorbs.Shield == nil)
assert(mouseover.aliases.mouseover, "Copy must not retain nested aliases to the source snapshot")

local stringRecord = { key = "g:ally-guid", guid = "ally-guid",
    unit = "party1", health = 400, healthMax = 500,
    auras = { Renew = { remaining = 8 } }, absorbs = {},
    targetRef = { unit = "party1", guid = "ally-guid",
        relation = "ally", source = "party" } }
local stringSnapshot = { order = { "g:ally-guid" },
    byKey = { ["g:ally-guid"] = stringRecord },
    byUnit = { party1 = "g:ally-guid" }, primaryKey = "g:ally-guid" }
local stringCopy = XelAssist.Game.Friendlies:Copy(stringSnapshot)
local stringCopiedRecord = stringCopy.byKey["g:ally-guid"]
stringCopiedRecord.health = 1
stringCopiedRecord.auras.Renew.remaining = 1
assert(stringCopiedRecord ~= stringRecord
    and stringCopiedRecord.auras ~= stringRecord.auras
    and stringRecord.health == 400 and stringRecord.auras.Renew.remaining == 8,
    "a byKey string ending in guid must not make its mutable record atomic")

units = {
    player = unit("player-guid", 1000, 1000, true, { distance = 0 }),
    pet = unit("pet-guid", 700, 1000, true),
    mouseover = unit("pet-guid", 700, 1000, true, { player = false }),
}
local petSnapshot = XelAssist.Game.Friendlies:Snapshot({
    player = { unit = "player", guid = "player-guid" },
    pet = { unit = "pet", guid = "pet-guid" }, allies = {},
})
assert(petSnapshot.total == 2 and not petSnapshot.capped)
assert(petSnapshot.order[1] == "g:pet-guid", "the controlled pet must remain targetable")
local pet = petSnapshot.byKey["g:pet-guid"]
assert(pet and pet.unit == "pet" and pet.relation == "pet" and pet.source == "controlled")
assert(pet.targetRef.relation == "pet" and pet.targetRef.source == "controlled")
assert(pet.explicit == 0 and petSnapshot.byUnit.mouseover == nil
    and petSnapshot.byUnit.pet == pet.key,
    "an NPC mouseover must not create or reprioritize a buff target")

units = {
    player = unit("player-guid", 1000, 1000, true, { distance = 0 }),
    mouseover = unit("friendly-npc", 500, 1000, true, { player = false }),
}
local npcMouseover = XelAssist.Game.Friendlies:Snapshot({
    player = { unit = "player", guid = "player-guid" }, allies = {},
})
assert(npcMouseover.total == 1 and npcMouseover.byUnit.mouseover == nil,
    "friendly NPC mouseovers must not enter healing or buff expansion")

units = {
    player = unit("player-guid", 1000, 1000, true, { distance = 0 }),
    party1 = unit("ally-1", 100, 1000, true),
    target = unit("external-guid", 990, 1000, true),
}
local selected = XelAssist.Game.Friendlies:Snapshot({
    player = { unit = "player", guid = "player-guid" },
    allies = { { unit = "party1", guid = "ally-1" } },
})
assert(selected.order[1] == "g:external-guid",
    "a friendly selected target must precede health-based ranking")
local selectedTarget = selected.byKey["g:external-guid"]
assert(selectedTarget.unit == "target" and selectedTarget.explicit == 1
    and selectedTarget.source == "selected" and selectedTarget.relation == "external")
assert(selectedTarget.targetRef.relation == "ally"
    and selectedTarget.targetRef.source == "selected")

local opaquePlayer, opaqueAlly = {}, {}
units = {
    player = unit(opaquePlayer, 200, 1000, true, { distance = 0 }),
    party1 = unit(opaquePlayer, 200, 1000, true),
    party2 = unit(opaqueAlly, 900, 1000, true),
}
local opaque = XelAssist.Game.Friendlies:Snapshot({
    player = { unit = "player", guid = opaquePlayer },
    allies = {
        { unit = "party1", guid = opaquePlayer },
        { unit = "party2", guid = opaqueAlly },
    },
})
assert(opaque.total == 2 and opaque.byUnit.player == opaquePlayer
    and opaque.byUnit.party1 == opaquePlayer and opaque.byKey[opaquePlayer],
    "opaque GUID aliases must remain exact canonical table keys")
local opaqueCopy = XelAssist.Game.Friendlies:Copy(opaque)
assert(opaqueCopy.order[1] == opaquePlayer
    and opaqueCopy.byKey[opaqueCopy.order[1]]
    and opaqueCopy.byUnit.player == opaquePlayer
    and opaqueCopy.byKey[opaquePlayer].guid == opaquePlayer
    and opaqueCopy.byKey[opaquePlayer].targetRef.guid == opaquePlayer,
    "Copy must preserve opaque GUID identity across every canonical index")
local opaqueSourceRecord = opaque.byKey[opaquePlayer]
local opaqueCopiedRecord = opaqueCopy.byKey[opaquePlayer]
opaqueCopiedRecord.health = 1
opaqueCopiedRecord.targetRef.unit = "changed"
assert(opaqueCopiedRecord ~= opaqueSourceRecord
    and opaqueSourceRecord.health == 200
    and opaqueSourceRecord.targetRef.unit == "player",
    "opaque table identities must remain atomic while their records stay isolated")

UnitBuff = function(unitName, index)
    if unitName == "party1" and index == 1 then
        return "buff-texture", 1, 1459
    end
    return nil
end
SpellInfo = function(id) if id == 1459 then return "Arcane Intellect" end end
units = {
    player = unit("player-guid", 1000, 1000, true, { distance = 0 }),
    party1 = unit("ally-1", 500, 1000, true),
}
local fallback = XelAssist.Game.Friendlies:Snapshot({
    player = { unit = "player", guid = "player-guid" },
    allies = { { unit = "party1", guid = "ally-1" } },
})
local fallbackAlly = fallback.byKey["g:ally-1"]
assert(fallbackAlly.auras.available
    and fallbackAlly.auras["Arcane Intellect"].spellId == 1459,
    "SuperWoW UnitBuff fallback must preserve a live friendly aura in future graph copies")
local fallbackCopy = XelAssist.Game.Friendlies:Copy(fallback)
assert(fallbackCopy.byKey["g:ally-1"].auras["Arcane Intellect"],
    "a fallback friendly aura must remain known after a projected transition")

XelAssist.Game.Actors = { Actions = function()
    return { { name = "Arcane Intellect", actor = "player",
        facts = { kind = "buff" } } }
end }
XelAssist.Game.Encounter.Auras = function(_, unitName)
    local active = unitName ~= "party4"
    local aura = active and { name = "Arcane Intellect" } or nil
    return { available = true, list = aura and { aura } or {},
        byName = aura and { [aura.name] = aura } or {} }
end
units = {
    player = unit("player-guid", 1000, 1000, true, { distance = 0 }),
    party1 = unit("ally-1", 1000, 1000, true),
    party2 = unit("ally-2", 1000, 1000, true),
    party3 = unit("ally-3", 1000, 1000, true),
    party4 = unit("ally-4", 1000, 1000, true),
}
local buffSnapshot = XelAssist.Game.Friendlies:Snapshot({
    player = { unit = "player", guid = "player-guid" },
    allies = {
        { unit = "party1", guid = "ally-1" },
        { unit = "party2", guid = "ally-2" },
        { unit = "party3", guid = "ally-3" },
        { unit = "party4", guid = "ally-4" },
    },
})
local buffKeys = buffSnapshot.byAction["Arcane Intellect"]
assert(table.getn(buffSnapshot.order) == 3 and buffKeys[1] == "g:ally-4"
    and buffSnapshot.byKey["g:ally-4"],
    "an action-specific lane must retain an unbuffed ally outside the healing cap")
assert(XelAssist.Game.Friendlies:TargetKeys(buffSnapshot,
    { name = "Arcane Intellect", facts = { kind = "buff" } }) == buffKeys,
    "buff target expansion must consume its bounded action-specific lane")

print("ok: canonical capped friendlies, pet targeting, aura uncertainty and deep copies")
