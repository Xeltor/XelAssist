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
}

GetSpellRecField = function(spellId, field, copy)
    assert(copy == 1, "topology arrays must be copied from Nampower")
    return records[spellId] and records[spellId][field] or nil
end

dofile("Game/SpellTopology.lua")

local area = XelAssist.Game.SpellTopology:Facts(100)
assert(area.available and area.area and table.getn(area.hostile) == 1
    and area.hostile[1].shape == "area"
    and area.hostile[1].center == "caster"
    and area.hostile[1].radius == 10
    and area.hostile[1].radiusKnown,
    "caster-centered hostile area topology must retain exact patched DBC radius")

local chain = XelAssist.Game.SpellTopology:Facts(200)
assert(chain.chain and chain.hostile[1].shape == "chain"
    and chain.hostile[1].center == "target"
    and chain.hostile[1].maxTargets == 3,
    "a chained hostile effect must not remain a single-target spell")

local friendly = XelAssist.Game.SpellTopology:Facts(300)
assert(friendly.chain and table.getn(friendly.friendly) == 1
    and friendly.friendly[1].relation == "friendly"
    and friendly.friendly[1].maxTargets == 4
    and friendly.radiusUnknown,
    "friendly chains and unknown patched radius indices must remain explicit")

local missingRadius = XelAssist.Game.SpellTopology:Facts(400)
assert(missingRadius.area and missingRadius.radiusUnknown
    and missingRadius.hostile[1].radiusKnown == false,
    "an area effect with no mapped positive radius must remain unknown")

local ground = XelAssist.Game.SpellTopology:Facts(450)
assert(ground.area and ground.hostile[1].shape == "ground"
    and ground.hostile[1].center == "dynamicObject",
    "dynamic-object effects must not masquerade as target-centered circles")

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
