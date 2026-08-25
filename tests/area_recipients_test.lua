XelAssist = { Graph = {} }
table.getn = table.getn or function(value)
    local count = 0
    while value[count + 1] ~= nil do count = count + 1 end
    return count
end

local keyA, keyB, keyC, keyD, keyE = {}, {}, {}, {}, {}
local pairCalls = {}
local pairDistances = { b = 5, c = 6, d = 12 }
UnitXP = function(operation, from, to)
    assert(operation == "distanceBetween" and from == "target",
        "pairwise resolution must use only the selected observed unit")
    table.insert(pairCalls, to)
    return pairDistances[to]
end

local function record(key, unit, distance, engaged, selected)
    local encounter
    if engaged ~= nil then encounter = { inCombat = engaged } end
    return { key = key, unit = unit, selected = selected, dead = false,
        engaged = engaged,
        geometry = { player = { distance = distance,
            source = "player snapshot" },
            pet = { distance = distance and distance + 3,
                source = "pet snapshot" } },
        encounter = encounter }
end

local records = {
    [keyA] = record(keyA, "target", 3, true, true),
    [keyB] = record(keyB, "b", 8, true, false),
    [keyC] = record(keyC, "c", 5, false, false),
    [keyD] = record(keyD, "d", 20, true, false),
    [keyE] = record(keyE, "e", nil, true, false),
}
local state = { hostiles = { order = { keyA, keyB, keyC, keyD, keyE },
    byKey = records, selectedKey = keyA, total = 5, capped = false,
    discoveryComplete = true } }

local casterArea = { available = true, effects = {
    { index = 2, effect = 2, relation = "hostile", shape = "area",
        center = "caster", radius = 10, radiusKnown = true },
} }

dofile("Graph/AreaRecipients.lua")
local A = XelAssist.Graph.AreaRecipients

local caster = A:Resolve(state, { actor = "player", facts = {} }, casterArea)
local group = caster.groups[1]
assert(group.effectIndex == 2 and group.topology == casterArea.effects[1],
    "recipient groups must retain their exact DBC effect topology")
assert(table.getn(group.order) == 2 and group.order[1] == keyA
    and group.order[2] == keyB and group.byKey[keyA] == records[keyA]
    and group.byKey[keyB] == records[keyB],
    "caster circles must credit only in-radius selected and engaged records")
assert(table.getn(group.secondaryOrder) == 1
    and group.secondaryOrder[1] == keyB,
    "the selected primary must not masquerade as secondary area damage")
assert(table.getn(caster.collateral) == 1
    and caster.collateral[1].key == keyC
    and not group.byKey[keyC],
    "visible unengaged hostiles must be reported as collateral, not free damage")
assert(table.getn(pairCalls) == 0,
    "caster-centered circles must not query target-pair geometry")
assert(caster.additionalUnknown,
    "a missing observed caster distance must remain explicit")

records[keyC].engaged = nil
records[keyC].encounter = { inCombat = true }
records[keyC].victim = { available = true, targetsPlayer = false,
    targetsPet = false }
local unrelated = A:Resolve(state, { actor = "player", facts = {} }, casterArea)
assert(table.getn(unrelated.groups[1].order) == 2
    and table.getn(unrelated.collateral) == 1
    and unrelated.collateral[1].key == keyC
    and unrelated.collateral[1].uncertain,
    "generic NPC combat or victim availability must not imply engagement with us")
records[keyC].engaged = false
records[keyC].victim = nil

local petCaster = A:Resolve(state, { actor = "player",
    facts = { damageActor = "pet" } }, casterArea)
assert(table.getn(petCaster.groups[1].order) == 1
    and petCaster.groups[1].order[1] == keyA,
    "effect actor facts must select pet-centered snapshot geometry")
assert(table.getn(petCaster.collateral) == 1
    and petCaster.collateral[1].key == keyC,
    "pet-centered collateral must remain separate too")
local petAction = A:Resolve(state, { actor = "pet", facts = {} }, casterArea)
local petEffect = A:Resolve(state, { actor = "player",
    facts = { effectActor = "pet" } }, casterArea)
assert(table.getn(petAction.groups[1].order) == 1
    and table.getn(petEffect.groups[1].order) == 1,
    "pet action and effect actors must both use pet-centered geometry")

records[keyB].geometry.selected = { distance = 4,
    source = "selected-pair snapshot" }
records[keyC].geometry.selected = { distance = 6,
    source = "selected-pair snapshot" }
records[keyD].geometry.selected = { distance = 12,
    source = "selected-pair snapshot" }
records[keyE].geometry.selected = { distance = nil,
    source = "pair unavailable" }
local targetArea = { available = true, effects = {
    { index = 1, effect = 2, relation = "hostile", shape = "area",
        center = "target", radius = 7, radiusKnown = true },
} }
local target = A:Resolve(state, { facts = {} }, targetArea)
assert(table.getn(target.groups[1].order) == 2
    and target.groups[1].order[1] == keyA
    and target.groups[1].order[2] == keyB,
    "target circles must use selected-pair snapshot geometry in stable order")
assert(target.groups[1].evidenceByKey[keyB].distanceSource
        == "selected-pair snapshot" and table.getn(pairCalls) == 0,
    "snapshot pair geometry must avoid volatile live queries")
assert(target.additionalUnknown and table.getn(target.collateral) == 1,
    "unknown pair geometry and proven collateral must stay visible")

records[keyB].geometry.selected = nil
local fallback = A:Resolve(state, { facts = {} }, targetArea)
assert(fallback.groups[1].byKey[keyB] == records[keyB]
    and fallback.groups[1].evidenceByKey[keyB].distanceSource
        == "live UnitXP fallback" and pairCalls[1] == "b"
    and fallback.additionalUnknown,
    "bounded UnitXP fallback must be marked and preserve opaque recipient keys")
records[keyB].geometry.selected = { distance = 4 }

local unknownRadius = { available = true, effects = {
    { index = 1, relation = "hostile", shape = "area",
        center = "target", radiusKnown = false },
} }
local radius = A:Resolve(state, { facts = {} }, unknownRadius)
assert(table.getn(radius.groups[1].order) == 1
    and radius.groups[1].order[1] == keyA
    and table.getn(radius.groups[1].secondaryOrder) == 0
    and radius.additionalUnknown,
    "unknown area radius may retain its proven center but never secondaries")

local unsupported = { available = true, effects = {
    { index = 1, relation = "hostile", shape = "cone", center = "caster",
        radius = 10, radiusKnown = true },
    { index = 2, relation = "hostile", shape = "chain", center = "target",
        maxTargets = 3 },
    { index = 3, relation = "hostile", shape = "ground",
        center = "dynamicObject", radius = 10, radiusKnown = true },
} }
local special = A:Resolve(state, { facts = {} }, unsupported)
assert(table.getn(special.groups) == 3
    and table.getn(special.groups[1].order) == 0
    and table.getn(special.groups[2].order) == 1
    and special.groups[2].order[1] == keyA
    and table.getn(special.groups[2].secondaryOrder) == 0
    and table.getn(special.groups[3].order) == 0
    and special.additionalUnknown,
    "cones, chain jumps and dynamic objects must receive no secondary credit")

local cappedState = { hostiles = { order = state.hostiles.order,
    byKey = records, selectedKey = keyA, total = 9, capped = true,
    discoveryComplete = false, additionalUnknown = true } }
local capped = A:Resolve(cappedState, { facts = {} }, casterArea)
assert(table.getn(capped.groups[1].order) == 1
    and capped.groups[1].order[1] == keyA
    and table.getn(capped.groups[1].withheld) == 1
    and capped.groups[1].withheld[1].key == keyB
    and capped.additionalUnknown,
    "capped discovery must withhold even geometrically visible secondaries")
assert(table.getn(capped.collateral) == 1
    and capped.collateral[1].key == keyC,
    "known collateral remains reportable when discovery is incomplete")

local boundedState = { hostiles = { order = state.hostiles.order,
    byKey = records, selectedKey = keyA, total = 5, capped = false,
    discoveryComplete = false, additionalUnknown = true } }
local bounded = A:Resolve(boundedState, { facts = {} }, casterArea)
assert(table.getn(bounded.groups[1].order) == 1
    and bounded.groups[1].order[1] == keyA
    and table.getn(bounded.groups[1].withheld) == 1
    and bounded.groups[1].withheld[1].key == keyB
    and bounded.additionalUnknown,
    "bounded unit-token discovery must never imply an exhaustive AoE roster")

local implicitUnknown = { available = true, effects = {
    { index = 1, relation = "unknown", shape = "area",
        center = "caster", radius = 10, radiusKnown = true },
} }
local implicit = A:Resolve(state, { facts = {} }, implicitUnknown)
assert(table.getn(implicit.groups) == 1
    and table.getn(implicit.groups[1].order) == 0
    and implicit.additionalUnknown,
    "unknown implicit recipient relations must remain empty and explicit")

local fallbackTopology = A:Resolve(state,
    { facts = { topology = targetArea } })
assert(fallbackTopology.groups[1].order[1] == keyA,
    "action facts may provide topology when the explicit argument is absent")
local unavailable = A:Resolve(state, { facts = {} })
assert(table.getn(unavailable.groups) == 0 and unavailable.additionalUnknown
    and table.getn(unavailable.unknowns) == 1,
    "missing DBC topology must produce one stable explicit unknown")

print("ok: bounded per-effect hostile area recipients and collateral")
