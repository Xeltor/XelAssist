XelAssist = { Game = {} }
table.getn = table.getn or function(value) return #value end

local records = {
    [100] = {
        effect = { 2, 0, 0 },
        effectImplicitTargetA = { 15, 0, 0 },
        effectImplicitTargetB = { 0, 0, 0 },
        effectRadiusIndex = { 13, 0, 0 },
        effectChainTarget = { 0, 0, 0 },
    },
    [200] = {
        effect = { 2, 0, 0 },
        effectImplicitTargetA = { 6, 0, 0 },
        effectImplicitTargetB = { 0, 0, 0 },
        effectRadiusIndex = { 0, 0, 0 },
        effectChainTarget = { 3, 0, 0 },
    },
    [300] = {
        effect = { 10, 0, 0 },
        effectImplicitTargetA = { 45, 0, 0 },
        effectImplicitTargetB = { 0, 0, 0 },
        effectRadiusIndex = { 99, 0, 0 },
        effectChainTarget = { 4, 0, 0 },
    },
    [400] = {
        effect = { 2, 0, 0 },
        effectImplicitTargetA = { 15, 0, 0 },
        effectImplicitTargetB = { 0, 0, 0 },
        effectRadiusIndex = { 0, 0, 0 },
        effectChainTarget = { 0, 0, 0 },
    },
    [450] = {
        effect = { 2, 0, 0 },
        effectImplicitTargetA = { 28, 0, 0 },
        effectImplicitTargetB = { 0, 0, 0 },
        effectRadiusIndex = { 13, 0, 0 },
        effectChainTarget = { 0, 0, 0 },
    },
    [460] = {
        effect = { 2, 10, 0 },
        effectImplicitTargetA = { 25, 7, 0 },
        effectImplicitTargetB = { 21, 8, 0 },
        effectRadiusIndex = { 0, 13, 0 },
        effectChainTarget = { 0, 0, 0 },
    },
    [470] = {
        effect = { 2, 2, 2 },
        effectImplicitTargetA = { 32, 23, 51 },
        effectImplicitTargetB = { 0, 0, 0 },
        effectRadiusIndex = { 0, 0, 13 },
        effectChainTarget = { 0, 0, 0 },
    },
}

-- Frozen 0.8.27 collapsed projection. Rich enum metadata must not change any
-- recommendation-facing relation, shape, or center until a consumer opts in.
local legacyProjection = {
    [1] = "self|single|caster", [2] = "hostile|single|caster",
    [3] = "friendly|single|caster", [5] = "pet|single|caster",
    [6] = "hostile|single|target", [7] = "unknown|area|caster",
    [8] = "unknown|area|target", [15] = "hostile|area|caster",
    [16] = "hostile|area|target", [20] = "party|area|caster",
    [21] = "friendly|single|target", [24] = "hostile|cone|caster",
    [25] = "unknown|single|target", [27] = "friendly|single|caster",
    [28] = "hostile|ground|dynamicObject",
    [29] = "friendly|ground|dynamicObject",
    [30] = "friendly|area|caster", [31] = "friendly|area|target",
    [33] = "party|area|caster", [34] = "party|area|target",
    [35] = "party|single|target", [36] = "hostile|area|caster",
    [37] = "friendly|area|target", [45] = "friendly|chain|target",
    [54] = "hostile|cone|caster", [56] = "raid|area|caster",
    [57] = "raid|single|target", [58] = "raid|single|caster",
    [59] = "friendly|cone|caster",
}
local code
for code = 0, 63 do
    records[1000 + code] = {
        effect = { 2, 0, 0 },
        effectImplicitTargetA = { code, 0, 0 },
        effectImplicitTargetB = { 0, 0, 0 },
        effectRadiusIndex = { 0, 0, 0 },
        effectChainTarget = { 0, 0, 0 },
    }
end

local dbcReads = 0
GetSpellRecField = function(spellId, field, copy)
    dbcReads = dbcReads + 1
    assert(copy == 1, "topology arrays must be copied from Nampower")
    return records[spellId] and records[spellId][field] or nil
end

dofile("Game/SpellTopology.lua")
local T = XelAssist.Game.SpellTopology

local legacyEffectFields = { index = true, effect = true, implicitA = true,
    implicitB = true, relation = true, shape = true, center = true,
    radiusIndex = true, radius = true, radiusKnown = true, maxTargets = true }
local function assertCompact(record)
    assert(record.targetA == nil and record.targetB == nil,
        "rich descriptors must not enter graph-copied topology facts")
    local key
    for key in pairs(record) do
        assert(legacyEffectFields[key],
            "topology facts must retain the compact 0.8.27 effect shape")
    end
end

local area = T:Facts(100)
assert(area.available and area.area and table.getn(area.hostile) == 1
    and area.hostile[1].shape == "area"
    and area.hostile[1].center == "caster"
    and area.hostile[1].radius == 10
    and area.hostile[1].radiusKnown,
    "caster-centered hostile area topology must retain exact patched DBC radius")

local chain = T:Facts(200)
assert(chain.chain and chain.hostile[1].shape == "chain"
    and chain.hostile[1].center == "target"
    and chain.hostile[1].maxTargets == 3
    and T:Describe(chain.hostile[1].implicitA).shape == "single",
    "a chained hostile effect must not remain a single-target spell")

local friendly = T:Facts(300)
assert(friendly.chain and table.getn(friendly.friendly) == 1
    and friendly.friendly[1].relation == "friendly"
    and friendly.friendly[1].maxTargets == 4
    and friendly.radiusUnknown,
    "friendly chains and unknown patched radius indices must remain explicit")

local missingRadius = T:Facts(400)
assert(missingRadius.area and missingRadius.radiusUnknown
    and missingRadius.hostile[1].radiusKnown == false,
    "an area effect with no mapped positive radius must remain unknown")

local ground = T:Facts(450)
assert(ground.area and ground.hostile[1].shape == "ground"
    and ground.hostile[1].center == "dynamicObject",
    "dynamic-object effects must not masquerade as target-centered circles")
local groundTarget = T:Describe(ground.effects[1].implicitA)
assert(groundTarget.kind == "unit" and groundTarget.shape == "area"
    and groundTarget.destination == "dynamicObject"
    and groundTarget.deployable,
    "dynamic-object recipient sets must expose their deployable destination")

local separate = T:Facts(460)
local polymorphic = separate.effects[1]
local polymorphicA = T:Describe(polymorphic.implicitA)
local polymorphicB = T:Describe(polymorphic.implicitB)
assert(polymorphic.implicitA == 25 and polymorphic.implicitB == 21
    and polymorphicA ~= polymorphicB
    and polymorphicA.code == 25
    and polymorphicA.name == "TARGET_UNIT"
    and polymorphicA.relation == "polymorphic"
    and polymorphicA.shape == "single"
    and polymorphicA.resolved == false
    and polymorphicB.relation == "friendly",
    "implicit A/B must remain separate and target 25 must stay polymorphic")
assert(polymorphic.relation == "friendly"
    and polymorphic.shape == "single"
    and table.getn(separate.friendly) == 1,
    "richer A/B metadata must preserve legacy friendly aggregation")

local scripted = separate.effects[2]
local scriptedA = T:Describe(scripted.implicitA)
local scriptedB = T:Describe(scripted.implicitB)
assert(scriptedA.code == 7 and scriptedA.scripted
    and scriptedA.resolved == false
    and scriptedA.relation == "unknown"
    and scriptedA.shape == "area"
    and scriptedA.destination == "source"
    and scriptedB.code == 8 and scriptedB.scripted
    and scriptedB.resolved == false
    and scriptedB.relation == "unknown"
    and scriptedB.shape == "area"
    and scriptedB.destination == "destination",
    "scripted source/destination target enums must remain unresolved")
assert(scripted.relation == "unknown" and scripted.shape == "area"
    and scripted.center == "caster",
    "scripted descriptors must not alter the legacy collapsed projection")

local destinations = T:Facts(470)
local minion = T:Describe(destinations.effects[1].implicitA)
local object = T:Describe(destinations.effects[2].implicitA)
local objectArea = T:Describe(destinations.effects[3].implicitA)
assert(minion.kind == "location" and minion.shape == "location"
    and minion.relation == "none" and minion.deployable
    and object.kind == "object" and object.shape == "single"
    and objectArea.kind == "object" and objectArea.shape == "area"
    and objectArea.scripted and objectArea.resolved == false,
    "location, object, and deployable destinations must remain non-unit")

local readsBeforeDescribe = dbcReads
for code = 0, 63 do
    local descriptor = T:Describe(code)
    assert(descriptor.code == code and descriptor.name
        and descriptor.kind and descriptor.relation and descriptor.shape
        and descriptor.center and descriptor.resolved ~= nil
        and descriptor.scripted ~= nil and descriptor.legacy == nil
        and descriptor.legacyCenter == nil and descriptor.legacyShape == nil
        and descriptor.legacyRelation == nil,
        "every locally verified Nampower target enum needs an exact descriptor")
end
assert(dbcReads == readsBeforeDescribe,
    "static target description must never call the client DBC API")

for code = 0, 63 do
    local effect = T:Facts(1000 + code).effects[1]
    local signature = effect.relation .. "|" .. effect.shape
        .. "|" .. effect.center
    assert(signature == (legacyProjection[code] or "unknown|unknown|unknown"),
        "rich target metadata must not change the 0.8.27 collapsed projection")
    assertCompact(effect)
end

local function target(code)
    return T:Describe(code)
end
assert(target(1).relation == "self" and target(1).kind == "unit"
    and target(5).relation == "pet" and target(5).kind == "unit"
    and target(6).relation == "hostile" and target(6).shape == "single"
    and target(21).relation == "friendly" and target(21).shape == "single"
    and target(20).relation == "party" and target(20).shape == "area"
    and target(56).relation == "raid" and target(56).shape == "area"
    and target(45).relation == "friendly" and target(45).shape == "chain"
    and target(15).relation == "hostile" and target(15).shape == "area",
    "unit descriptors must distinguish recipient relation and selection shape")

local isolated = T:Describe(25)
isolated.relation = "mutated"
assert(T:Describe(25).relation == "polymorphic",
    "Describe must return a fresh module-owned descriptor copy")

assertCompact(area.effects[1])
assertCompact(chain.effects[1])
assertCompact(friendly.effects[1])
assertCompact(ground.effects[1])
assertCompact(separate.effects[1])
assertCompact(separate.effects[2])
assertCompact(destinations.effects[1])
assertCompact(destinations.effects[2])
assertCompact(destinations.effects[3])

local cached = XelAssist.Game.SpellTopology:Facts(100)
records[100].effectRadiusIndex[1] = 8
assert(cached == XelAssist.Game.SpellTopology:Facts(100)
    and cached.hostile[1].radius == 10,
    "topology facts must be stable within one spellbook cache generation")
XelAssist.Game.SpellTopology:Invalidate()
assert(XelAssist.Game.SpellTopology:Facts(100).hostile[1].radius == 5,
    "explicit invalidation must refresh client DBC topology")

GetSpellRecField = nil
XelAssist.Game.SpellTopology:Invalidate()
assert(not XelAssist.Game.SpellTopology:Facts(500).available,
    "missing Nampower topology must remain unavailable")

print("ok: DBC recipient topology, radius, chains and explicit unknowns")
