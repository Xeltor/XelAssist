XelAssist = { Game = {}, Combat = {} }
table.getn = table.getn or function(value) return #value end

local ARRAY_FIELDS = {
    "effect", "effectDieSides", "effectBaseDice", "effectDicePerLevel",
    "effectRealPointsPerLevel", "effectBasePoints", "effectMechanic",
    "effectImplicitTargetA", "effectImplicitTargetB", "effectRadiusIndex",
    "effectApplyAuraName", "effectAmplitude", "effectMultipleValue",
    "effectChainTarget", "effectItemType", "effectMiscValue",
    "effectTriggerSpell", "effectPointsPerComboPoint",
}

local function triple(a, b, c) return { a or 0, b or 0, c or 0 } end
local function record(values)
    local out, index, field = {}, nil, nil
    for index = 1, table.getn(ARRAY_FIELDS) do
        field = ARRAY_FIELDS[index]
        out[field] = triple()
    end
    for field, value in pairs(values or {}) do out[field] = value end
    if out.school == nil then out.school = 1 end
    if out.powerType == nil then out.powerType = 0 end
    if out.attributes == nil then out.attributes = 0 end
    if out.attributesEx == nil then out.attributesEx = 0 end
    return out
end

local records = {
    -- One representative installed-client signature for every playable class.
    [355] = record({ effect = triple(114, 6),
        effectApplyAuraName = triple(0, 11),
        effectImplicitTargetA = triple(6, 6) }), -- Warrior: Taunt
    [4987] = record({ effect = triple(38, 38, 38),
        effectImplicitTargetA = triple(21, 21, 21),
        effectMiscValue = triple(4, 3, 1) }), -- Paladin: Cleanse
    [19801] = record({ effect = triple(38),
        effectImplicitTargetA = triple(6),
        effectMiscValue = triple(9) }), -- Hunter: Tranquilizing Shot
    [13750] = record({ effect = triple(6),
        effectApplyAuraName = triple(110),
        effectImplicitTargetA = triple(1), effectBasePoints = triple(99),
        effectMiscValue = triple(3) }), -- Rogue: Adrenaline Rush
    [527] = record({ effect = triple(38),
        effectImplicitTargetA = triple(25),
        effectMiscValue = triple(1) }), -- Priest: Dispel Magic
    [3599] = record({ effect = triple(87),
        effectImplicitTargetA = triple(44),
        effectMiscValue = triple(2523) }), -- Shaman: Searing Totem
    [12051] = record({ effect = triple(6, 6),
        effectApplyAuraName = triple(110, 134),
        effectImplicitTargetA = triple(1, 1),
        attributesEx = 4 }), -- Mage: Evocation
    [18220] = record({ effect = triple(8),
        effectImplicitTargetA = triple(5), effectMiscValue = triple(0),
        effectMultipleValue = triple(1) }), -- Warlock: Dark Pact
    [768] = record({ effect = triple(6, 6, 6),
        effectApplyAuraName = triple(36, 77, 23),
        effectImplicitTargetA = triple(1, 1, 1),
        effectMiscValue = triple(1) }), -- Druid: Cat Form

    [133] = record({ effect = triple(2, 6),
        effectApplyAuraName = triple(0, 3),
        effectImplicitTargetA = triple(6, 6), school = 2 }), -- Fireball
    [8936] = record({ effect = triple(10, 6),
        effectApplyAuraName = triple(0, 8),
        effectImplicitTargetA = triple(21, 21) }), -- Regrowth
    [2687] = record({ effect = triple(30, 64, 2),
        effectImplicitTargetA = triple(1, 1, 1),
        effectMiscValue = triple(1, 0, 0),
        effectTriggerSpell = triple(0, 29131, 0),
        effectBasePoints = triple(99, 0, 9) }), -- Bloodrage
    [29131] = record({ effect = triple(6),
        effectApplyAuraName = triple(24),
        effectImplicitTargetA = triple(1), effectMiscValue = triple(1) }),
    [29130] = record({ effect = triple(32),
        effectImplicitTargetA = triple(1),
        effectTriggerSpell = triple(29131) }),
}

local reads = {}
GetSpellRecField = function(spellId, field, copied)
    reads[spellId] = (reads[spellId] or 0) + 1
    local found, value = records[spellId], records[spellId] and records[spellId][field]
    if type(value) == "table" then
        assert(copied == 1, "all DBC arrays must request an owned copy")
    end
    return value
end

dofile("Game/SpellTopology.lua")
dofile("Game/SpellSemantics.lua")
local Semantics = XelAssist.Game.SpellSemantics

local function atoms(descriptor, kind)
    local found, index = {}, nil
    for index = 1, table.getn(descriptor.atoms or {}) do
        if descriptor.atoms[index].kind == kind then
            table.insert(found, descriptor.atoms[index])
        end
    end
    return found
end

local function hasReason(descriptor, pattern)
    local index
    for index = 1, table.getn(descriptor.reasons or {}) do
        if string.find(descriptor.reasons[index], pattern) then return true end
    end
    return false
end

local warrior = Semantics:Decode(355)
assert(warrior.complete and table.getn(warrior.effects) == 3
    and table.getn(atoms(warrior, "taunt")) == 2,
    "Warrior Taunt must compose its direct and aura taunt mechanics")

local paladin = Semantics:Decode(4987)
local cleanses = atoms(paladin, "dispel")
assert(paladin.complete and table.getn(cleanses) == 3
    and cleanses[1].dispelType == "poison"
    and cleanses[2].dispelType == "disease"
    and cleanses[3].dispelType == "magic",
    "Paladin Cleanse must preserve all three dispel effects")

local hunter = Semantics:Decode(19801)
assert(hunter.complete and atoms(hunter, "dispel")[1].dispelType == "enrage",
    "Hunter Tranquilizing Shot must remain an enrage dispel")

local rogue = Semantics:Decode(13750)
assert(rogue.complete and atoms(rogue, "aura")[1].aura == 110
    and atoms(rogue, "aura")[1].semantic == "fixtureWhitelistedRaw",
    "Adrenaline Rush aura 110 must be admitted only as verified raw metadata")

local priest = Semantics:Decode(527)
assert(not priest.complete and table.getn(atoms(priest, "dispel")) == 1
    and atoms(priest, "dispel")[1].recipient.primary.relation == "polymorphic"
    and atoms(priest, "dispel")[1].recipient.primary.resolved == false,
    "polymorphic Priest Dispel Magic must wait for actor target context")
local resolvedPriest = Semantics:Resolve(527, { targetRelation = "hostile" })
assert(resolvedPriest.complete
    and atoms(resolvedPriest, "dispel")[1].recipient.primary.relation == "hostile"
    and not priest.complete,
    "actor context must resolve a fresh descriptor without mutating Decode")
local secondResolution = Semantics:Resolve(resolvedPriest,
    { targetRelation = "hostile" })
resolvedPriest.complete = false
resolvedPriest.effects[1].recipient.primary.relation = "mutated"
resolvedPriest.atoms[1].kind = "mutated"
assert(secondResolution.complete
    and secondResolution.effects[1].recipient.primary.relation == "hostile"
    and secondResolution.atoms[1].kind == "dispel",
    "Resolve calls must never share descriptor, recipient, or atom tables")

local shaman = Semantics:Decode(3599)
assert(shaman.complete and atoms(shaman, "summon")[1].summonType == "totemSlot1"
    and atoms(shaman, "summon")[1].recipient.primary.center == "casterFrontLeft",
    "Searing Totem must preserve its totem slot and deployable location")

local mage = Semantics:Decode(12051)
assert(mage.complete and mage.channel and table.getn(atoms(mage, "aura")) == 2,
    "Evocation must preserve both raw verified auras and its channel flag")

local warlock = Semantics:Decode(18220)
assert(warlock.complete and atoms(warlock, "resourceLoss")[1].resource == "mana"
    and atoms(warlock, "resourceLoss")[1].recipient.primary.relation == "pet"
    and atoms(warlock, "resourceGain")[1].recipient.primary.relation == "self",
    "Dark Pact must compose pet mana loss and caster mana gain")

local druid = Semantics:Decode(768)
assert(not druid.complete and table.getn(atoms(druid, "shapeshift")) == 1
    and atoms(druid, "shapeshift")[1].form == 1,
    "Cat Form must retain its exact form atom while unresolved auras fail closed")

local fireball = Semantics:Decode(133)
assert(fireball.complete and table.getn(atoms(fireball, "damage")) == 2
    and atoms(fireball, "damage")[1].delivery == "direct"
    and atoms(fireball, "damage")[2].delivery == "periodic",
    "direct and periodic Fireball damage must remain composable atoms")
local regrowth = Semantics:Decode(8936)
assert(regrowth.complete and table.getn(atoms(regrowth, "healing")) == 2
    and atoms(regrowth, "healing")[1].delivery == "direct"
    and atoms(regrowth, "healing")[2].delivery == "periodic",
    "direct and periodic Regrowth healing must remain composable atoms")

local bloodrage = Semantics:Decode(2687)
assert(bloodrage.complete and table.getn(atoms(bloodrage, "resourceGain")) == 2
    and table.getn(atoms(bloodrage, "trigger")) == 1
    and table.getn(atoms(bloodrage, "damage")) == 1
    and atoms(bloodrage, "trigger")[1].childComplete
    and atoms(bloodrage, "resourceGain")[2].triggeredBySpellId == 29131,
    "Bloodrage must preserve its direct, immediate child, and self-damage effects")
local missile = Semantics:Decode(29130)
assert(missile.complete and atoms(missile, "trigger")[1].childComplete
    and atoms(missile, "resourceGain")[1].triggeredBySpellId == 29131,
    "trigger-missile opcode 32 must use the same guarded immediate-child path")

-- Cached raw arrays must be detached from Nampower's table and stable until an
-- explicit generation invalidation.
local cached = Semantics:Decode(133)
records[133].effect[1] = 200
assert(Semantics:Decode(133) ~= cached and Semantics:Decode(133).effects[1].opcode == 2,
    "cached descriptors must not alias mutable API arrays")
Semantics:Invalidate()
assert(not Semantics:Decode(133).complete,
    "explicit invalidation must expose a changed client record")
records[133].effect[1] = 2
Semantics:Invalidate()
local isolated = Semantics:Decode(133)
isolated.complete = false
isolated.effects[1].opcode = 200
isolated.effects[1].recipient.primary.relation = "mutated"
isolated.atoms[1].kind = "mutated"
local isolatedAgain = Semantics:Decode(133)
assert(isolatedAgain.complete and isolatedAgain.effects[1].opcode == 2
    and isolatedAgain.effects[1].recipient.primary.relation == "hostile"
    and isolatedAgain.atoms[1].kind == "damage"
    and isolatedAgain.raw == nil and isolatedAgain.arrays == nil,
    "Decode must return an isolated compact tree without raw array bundles")

records[30000] = record({ effect = triple(64),
    effectImplicitTargetA = triple(1), effectTriggerSpell = triple(30001) })
records[30001] = record({ effect = triple(64),
    effectImplicitTargetA = triple(1), effectTriggerSpell = triple(30000) })
local cycle = Semantics:Decode(30000)
assert(not cycle.complete and hasReason(cycle, "trigger cycle"),
    "immediate trigger cycles must fail closed")

local id
for id = 31000, 31005 do
    records[id] = record({ effect = triple(64),
        effectImplicitTargetA = triple(1), effectTriggerSpell = triple(id + 1) })
end
records[31006] = record({ effect = triple(30),
    effectImplicitTargetA = triple(1), effectMiscValue = triple(1) })
Semantics:Invalidate()
local deep = Semantics:Decode(31000)
assert(not deep.complete and hasReason(deep, "trigger depth exceeded"),
    "trigger traversal must enforce a fixed depth guard")

local nextId, layer, index = 32001, { 32000 }, nil
local depth
for depth = 1, 3 do
    local following = {}
    for index = 1, table.getn(layer) do
        records[layer[index]] = record({ effect = triple(64, 64, 64),
            effectImplicitTargetA = triple(1, 1, 1),
            effectTriggerSpell = triple(nextId, nextId + 1, nextId + 2) })
        table.insert(following, nextId); table.insert(following, nextId + 1)
        table.insert(following, nextId + 2); nextId = nextId + 3
    end
    layer = following
end
for index = 1, table.getn(layer) do
    records[layer[index]] = record({ effect = triple(30),
        effectImplicitTargetA = triple(1), effectMiscValue = triple(1) })
end
Semantics:Invalidate()
local wide = Semantics:Decode(32000)
assert(not wide.complete and hasReason(wide, "node budget exceeded"),
    "trigger traversal must enforce one shared node guard")

records[33000] = record({ effect = triple(64),
    effectImplicitTargetA = triple(1), effectTriggerSpell = triple(33999) })
Semantics:Invalidate()
assert(not Semantics:Decode(33000).complete,
    "a missing immediate child spell must fail closed")

records[34000] = record({ effect = triple(6),
    effectApplyAuraName = triple(23), effectImplicitTargetA = triple(1),
    effectTriggerSpell = triple(29131) })
Semantics:Invalidate(); reads[29131] = 0
local periodicTrigger = Semantics:Decode(34000)
assert(not periodicTrigger.complete and reads[29131] == 0,
    "periodic aura triggers must not recurse as immediate effects")

records[35000] = record({ effect = triple(3), effectImplicitTargetA = triple(6) })
records[35001] = record({ effect = triple(77), effectImplicitTargetA = triple(6) })
records[35002] = record({ effect = triple(200), effectImplicitTargetA = triple(6) })
records[35003] = record({ effect = triple(6), effectApplyAuraName = triple(200),
    effectImplicitTargetA = triple(6) })
records[35004] = record({ effect = triple(2), effectImplicitTargetA = triple(250) })
records[35005] = record({ effect = triple(2), effectImplicitTargetA = triple(6) })
records[35005].effectAmplitude = nil
records[35006] = record({ effect = triple(6),
    effectApplyAuraName = triple(110), effectImplicitTargetA = triple(1) })
Semantics:Invalidate()
for _, id in ipairs({ 35000, 35001, 35002, 35003, 35004, 35005, 35006 }) do
    local unknown = Semantics:Decode(id)
    assert(unknown.available and not unknown.complete and table.getn(unknown.effects) == 3,
        "unknown, scripted, custom, recipient, and incomplete evidence must fail closed")
end

records[36002] = record({ effect = triple(132),
    effectApplyAuraName = triple(13), effectImplicitTargetA = triple(56) })
Semantics:Invalidate()
local raidAura = Semantics:Decode(36002)
assert(raidAura.complete and atoms(raidAura, "auraCarrier")[1].carrier == "raidArea"
    and atoms(raidAura, "modifier")[1].modifier == "damageDone",
    "backported effect 132 must remain an exact raid-area aura carrier")
reads[133] = 0
local inferred, reason, descriptor = Semantics:InferAction({ spellId = 133,
    facts = { kind = "damage" } })
assert(inferred == nil and string.find(reason, "authoritative")
    and descriptor == nil and reads[133] == 0,
    "explicit Combat.Knowledge must win without reading generic DBC evidence")
inferred, reason, descriptor = Semantics:InferAction({ spellId = 133,
    facts = { inferred = true } })
assert(inferred == nil and string.find(reason, "no registered consumer")
    and descriptor.complete,
    "load-only semantics must not enter action inference without atom consumers")
local out = { untouched = true }
local applied = Semantics:Apply({ spellId = 133, facts = { inferred = true } }, out)
assert(not applied and out.untouched and next(out) == "untouched",
    "the unwired Apply boundary must not mutate recommendation facts")

records[36001] = record({ effect = triple(30), attributes = 64,
    effectImplicitTargetA = triple(1), effectMiscValue = triple(1) })
Semantics:Invalidate()
local passive = Semantics:Decode(36001)
inferred, reason = Semantics:InferAction({ spellId = 36001,
    facts = { inferred = true } })
assert(passive.complete and passive.passive and inferred == nil
    and reason == "passive spell",
    "passive DBC evidence must never enter generic action inference")

Semantics:Invalidate(); reads[133] = 0
Semantics:Decode(133)
local positiveReads = reads[133]
Semantics:Decode(133)
assert(positiveReads > 0 and reads[133] == positiveReads,
    "positive spell rows must use both raw and descriptor caches")
Semantics:Invalidate(); Semantics:Decode(133)
assert(reads[133] > positiveReads,
    "positive spell rows must reread only after explicit invalidation")

Semantics:Invalidate(); reads[36000] = 0
local unavailable = Semantics:Decode(36000)
local negativeReads = reads[36000]
Semantics:Decode(36000)
assert(not unavailable.available and negativeReads > 0
    and reads[36000] == negativeReads,
    "missing spell rows must be negative-cached")
Semantics:Invalidate(); Semantics:Decode(36000)
assert(reads[36000] > negativeReads,
    "negative spell rows must reread only after explicit invalidation")

print("ok: cached DBC spell descriptors, nine-class atoms and guarded triggers")
