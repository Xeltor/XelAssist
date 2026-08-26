XelAssist = { Game = {}, Graph = {} }
table.getn = table.getn or function(value)
    local count = 0
    while value[count + 1] ~= nil do count = count + 1 end
    return count
end

local units = { target = "enemy-guid", party1 = "party-guid",
    player = "player-guid", pet = "pet-guid", raid1 = "raid-guid" }
local identityCalls, guidCalls = {}, {}
local raceUnit, raceAtCall, raceGuid, booleanOnly = nil, nil, nil, false
local function currentGuid(unit)
    if unit == raceUnit and (identityCalls[unit] or 0) >= raceAtCall then
        return raceGuid
    end
    return units[unit]
end
UnitExists = function(unit)
    identityCalls[unit] = (identityCalls[unit] or 0) + 1
    local guid = currentGuid(unit)
    if booleanOnly then return guid ~= nil end
    return guid ~= nil, guid
end
UnitGUID = function(unit)
    guidCalls[unit] = (guidCalls[unit] or 0) + 1
    return currentGuid(unit)
end

local definitions = {
    [4987] = { relation = "friendly",
        types = { "poison", "disease", "magic" } },
    [527] = { relation = "polymorphic", types = { "magic" } },
    [19801] = { relation = "hostile", types = { "enrage" } },
    [998] = { relation = "polymorphic", types = { "magic" },
        recipientExact = false },
    [999] = { incomplete = true, relation = "polymorphic",
        types = { "magic" } },
    [1000] = { relation = "polymorphic",
        types = { "magic", "magic", "magic", "magic", "magic",
            "magic", "magic", "magic", "magic" } },
    [1001] = { relation = "polymorphic", types = { "magic" }, passive = true },
    [1002] = { relation = "hostile", types = { "magic" }, kind = "damage" },
    [1003] = { relation = "unknown", types = { "magic" } },
}
local semanticCalls, decodeCalls = 0, 0
XelAssist.Game.SpellSemantics = {}
local function semanticDescriptor(spellId, resolution)
    local definition = definitions[spellId]
    if not definition then return { available = false, complete = false,
        admissible = false, reasons = { "spell record unavailable" }, atoms = {} } end
    local unresolved = definition.relation == "polymorphic" and not resolution
    local relation = definition.relation == "polymorphic" and resolution
        and resolution.targetRelation or definition.relation
    local atoms, index = {}, nil
    for index = 1, table.getn(definition.types) do
        table.insert(atoms, { kind = definition.kind or "dispel",
            dispelType = definition.types[index],
            recipient = { present = true,
                exact = definition.recipientExact ~= false and not unresolved,
                primary = { relation = relation, resolved = not unresolved } } })
    end
    local incomplete = definition.incomplete or unresolved
    return { available = true, complete = not incomplete,
        admissible = not incomplete, passive = definition.passive,
        reasons = definition.incomplete and { "fixture incomplete" }
            or unresolved and { "recipient unresolved" } or {}, atoms = atoms }
end
function XelAssist.Game.SpellSemantics:Decode(spellId)
    decodeCalls = decodeCalls + 1
    return semanticDescriptor(spellId)
end
function XelAssist.Game.SpellSemantics:Resolve(spellId, resolution)
    semanticCalls = semanticCalls + 1
    return semanticDescriptor(spellId, resolution)
end

local auras, auraCalls, lastAuraUnit, lastAuraFilter = {}, 0, nil, nil
XelAssist.Game.Encounter = {}
function XelAssist.Game.Encounter:Auras(unit, filter)
    auraCalls, lastAuraUnit, lastAuraFilter = auraCalls + 1, unit, filter
    local row = auras[unit .. ":" .. filter]
    if row == "unavailable" then return { available = false, list = {} } end
    return { available = true, list = row or {} }
end

dofile("Graph/DispelDecision.lua")
local Decision = XelAssist.Graph.DispelDecision
assert(Decision.Evaluate == nil,
    "search code must consume frozen captures instead of live evaluation")
local inferred, inferReason = Decision:InferKnowledge(527)
assert(inferred and inferReason == nil and inferred.kind == "dispel"
    and inferred.inferred and inferred.dbcDispel
    and inferred.requiresDispelCapture and inferred.dispelPolymorphic
    and inferred.semanticDispelTypes[1] == "magic" and semanticCalls == 0,
    "unresolved polymorphic recipients must not hide a proven dispel mechanic")
local fixedDispel = Decision:InferKnowledge(4987)
assert(fixedDispel and not fixedDispel.dispelPolymorphic
    and table.getn(fixedDispel.semanticDispelTypes) == 3,
    "fixed-recipient dispels must use the same name-independent discovery seam")
assert(Decision:InferKnowledge(1001) == nil
    and Decision:InferKnowledge(1002) == nil
    and Decision:InferKnowledge(1003) == nil
    and Decision:InferKnowledge(123456) == nil,
    "passive, non-dispel, unknown-recipient and absent records must not infer actions")
local function action(spellId)
    return { name = "fixture", spellId = spellId,
        actor = "player", facts = { kind = "dispel" } }
end

local state, descriptors
local function reset()
    identityCalls, guidCalls = {}, {}
    raceUnit, raceAtCall, raceGuid, booleanOnly = nil, nil, nil, false
    semanticCalls, decodeCalls = 0, 0
    auraCalls, lastAuraUnit, lastAuraFilter = 0, nil, nil
    auras = {}
    local records = {
        enemy = { unit = "target", guid = "enemy-guid", selected = true },
        party = { unit = "party1", guid = "party-guid", relation = "party" },
        player = { unit = "player", guid = "player-guid", relation = "self" },
        pet = { unit = "pet", guid = "pet-guid", relation = "pet" },
        raid = { unit = "raid1", guid = "raid-guid", relation = "raid" },
    }
    descriptors = {
        target = { unit = "target", guid = "enemy-guid", key = "enemy-key",
            relation = "hostile", source = "selected", record = records.enemy },
        party = { unit = "party1", guid = "party-guid", key = "party-key",
            relation = "ally", source = "party", record = records.party },
        player = { unit = "player", guid = "player-guid", key = "player-key",
            relation = "self", source = "self", record = records.player },
        pet = { unit = "pet", guid = "pet-guid", key = "pet-key",
            relation = "pet", source = "controlled", record = records.pet },
        raid = { unit = "raid1", guid = "raid-guid", key = "raid-key",
            relation = "ally", source = "raid", record = records.raid },
    }
    state = { time = 0, targetGUID = "enemy-guid",
        hostiles = { order = { "enemy-key" }, selectedKey = "enemy-key",
            byKey = { ["enemy-key"] = records.enemy } },
        friendlies = {
            order = { "party-key", "player-key", "pet-key", "raid-key" },
            byKey = { ["party-key"] = records.party,
                ["player-key"] = records.player,
                ["pet-key"] = records.pet,
                ["raid-key"] = records.raid } } }
end

reset()
auras["party1:HARMFUL"] = {
    { name = "Poison", spellId = 101, dispelType = "Poison", remaining = 8 },
    { name = "Disease", spellId = 102, dispelType = "Disease", remaining = 5 },
    { name = "Magic", spellId = 103, dispelType = "Magic", remaining = 3 },
}
local cleanse, reason = Decision:Capture(action(4987), state, descriptors.party)
assert(cleanse and reason == nil and cleanse.filter == "HARMFUL"
    and lastAuraUnit == "party1" and lastAuraFilter == "HARMFUL"
    and cleanse.exactRelation == "party" and table.getn(cleanse.effects) == 3
    and cleanse.effects[1].dispelType == "poison"
    and cleanse.effects[2].dispelType == "disease"
    and cleanse.effects[3].dispelType == "magic",
    "Cleanse must retain each exact supported harmful aura type")
assert(Decision:Apply(state, cleanse)
    and state.dispelProjection["party-guid"].magic.removedLowerBound == 1,
    "projection must record only the guaranteed per-type removal")
state.time, state.dispelProjection = 2, nil
identityCalls, semanticCalls, auraCalls = {}, 0, 0
raceUnit, raceAtCall, raceGuid = "party1", 1, "replacement-guid"
assert(Decision:Apply(state, cleanse)
    and state.dispelProjection["party-guid"].poison.removedLowerBound == 1
    and semanticCalls == 0 and auraCalls == 0
    and (identityCalls.party1 or 0) == 0,
    "future search must consume a frozen capture without mutable live reads")

reset()
auras["target:HELPFUL"] = {
    { name = "Enemy Magic", spellId = 201, dispelType = "Magic", remaining = 9 } }
cleanse, reason = Decision:Capture(action(4987), state, descriptors.target)
assert(cleanse == nil and reason == "spell cannot dispel this recipient",
    "friendly-only Cleanse must never become an offensive dispel")

reset()
auras["target:HELPFUL"] = {
    { name = "Enrage", spellId = 202, dispelType = "Enrage", remaining = 6 } }
local tranquilize = Decision:Capture(action(19801), state, descriptors.target)
assert(tranquilize and tranquilize.filter == "HELPFUL"
    and tranquilize.effects[1].dispelType == "enrage",
    "hostile enrage removal must inspect helpful auras only")
local invalid = Decision:Capture(action(19801), state, descriptors.party)
assert(invalid == nil, "hostile-only dispels must not target friendlies")

reset()
local friendlyCases = { { "party", "party1", "party" },
    { "player", "player", "self" }, { "pet", "pet", "pet" },
    { "raid", "raid1", "raid" } }
local index
for index = 1, table.getn(friendlyCases) do
    local item = friendlyCases[index]
    auras[item[2] .. ":HARMFUL"] = {
        { name = "Ally Magic", spellId = 300 + index,
            dispelType = "Magic", remaining = 4 } }
    local decision = Decision:Capture(action(527), state, descriptors[item[1]])
    assert(decision and decision.targetRelation == "friendly"
        and decision.exactRelation == item[3] and decision.filter == "HARMFUL",
        "polymorphic dispels must preserve exact friendly relation " .. item[3])
end
auras["target:HELPFUL"] = {
    { name = "Enemy Magic", spellId = 305, dispelType = "Magic", remaining = 4 } }
local priestHostile = Decision:Capture(action(527), state, descriptors.target)
assert(priestHostile and priestHostile.targetRelation == "hostile"
    and priestHostile.exactRelation == "hostile"
    and priestHostile.filter == "HELPFUL",
    "Priest Dispel Magic must resolve independently for hostile recipients")

reset()
auras["party1:HARMFUL"] = {
    { name = "Magic-looking curse", spellId = 401,
        dispelType = "Curse", remaining = 4 },
    { name = "Magic in prose only", spellId = 402, remaining = 4 },
}
local none
none, reason = Decision:Capture(action(527), state, descriptors.party)
assert(none == nil and reason == "nothing eligible to dispel",
    "aura names must never substitute for an exact live dispel type")

reset()
auras["party1:HARMFUL"] = {
    { name = "Protected", spellId = 403, dispelType = "Magic",
        remaining = 4, boss = true },
    { name = "Expired", spellId = 404, dispelType = "Magic", remaining = 0 },
}
none, reason = Decision:Capture(action(527), state, descriptors.party)
assert(none == nil and reason == "nothing eligible to dispel",
    "boss and expired aura evidence must fail closed")

reset()
auras["party1:HARMFUL"] = "unavailable"
none, reason = Decision:Capture(action(527), state, descriptors.party)
assert(none == nil and reason == "aura observation unavailable",
    "missing live aura evidence must fail closed")

reset()
auras["party1:HARMFUL"] = {
    { name = "First", spellId = 501, dispelType = "Magic", remaining = 4 },
    { name = "Second", spellId = 502, dispelType = "Magic", remaining = 4 } }
local ambiguous = Decision:Capture(action(527), state, descriptors.party)
assert(ambiguous and ambiguous.effects[1].count == 2
    and not ambiguous.effects[1].identityKnown
    and ambiguous.effects[1].aura == nil,
    "multiple same-type auras must not fabricate which aura is removed")

reset()
auras["party1:HARMFUL"] = {
    { name = "Magic", spellId = 601, dispelType = "Magic", remaining = 4 } }
raceUnit, raceAtCall, raceGuid = "party1", 1, "replacement-guid"
none, reason = Decision:Capture(action(527), state, descriptors.party)
assert(none == nil and reason == "dispel recipient changed"
    and semanticCalls == 0 and auraCalls == 0,
    "a recipient changed before observation must cancel before semantic or aura reads")

reset()
auras["party1:HARMFUL"] = {
    { name = "Magic", spellId = 602, dispelType = "Magic", remaining = 4 } }
raceUnit, raceAtCall, raceGuid = "party1", 2, "replacement-guid"
none, reason = Decision:Capture(action(527), state, descriptors.party)
assert(none == nil and reason == "dispel recipient changed"
    and semanticCalls == 1 and auraCalls == 1,
    "a recipient changed during aura observation must cancel the decision")

reset()
state.friendlies.byKey["party-key"] = { unit = "party1",
    guid = "party-guid", relation = "party" }
none, reason = Decision:Capture(action(527), state, descriptors.party)
assert(none == nil and reason == "friendly dispel recipient is not retained"
    and (identityCalls.party1 or 0) == 0,
    "a stale friendly descriptor record must fail before mutable live reads")

reset()
state.hostiles.selectedKey = "replacement-key"
state.hostiles.byKey["replacement-key"] = { unit = "target",
    guid = "replacement-guid", selected = true }
none, reason = Decision:Capture(action(527), state, descriptors.target)
assert(none == nil and reason == "offensive dispel requires the selected hostile"
    and (identityCalls.target or 0) == 0,
    "an offensive dispel must not survive a selected-hostile identity race")

reset()
booleanOnly = true
auras["party1:HARMFUL"] = {
    { name = "Magic", spellId = 603, dispelType = "MAGIC", remaining = 4 } }
local fallbackGuid = Decision:Capture(action(527), state, descriptors.party)
assert(fallbackGuid and guidCalls.party1 == 2,
    "UnitGUID must provide exact identity when UnitExists returns only a boolean")

reset()
state.time = 0.01
none, reason = Decision:Capture(action(527), state, descriptors.party)
assert(none == nil and reason == "dispel requires root observation"
    and semanticCalls == 0 and auraCalls == 0
    and (identityCalls.party1 or 0) == 0,
    "future branches must fail before querying mutable live state")

reset()
state.time = nil
none, reason = Decision:Capture(action(527), state, descriptors.party)
assert(none == nil and reason == "dispel requires root observation"
    and semanticCalls == 0 and auraCalls == 0
    and (identityCalls.party1 or 0) == 0,
    "unknown branch time must not be mistaken for root observation")

reset()
none, reason = Decision:Capture(action(998), state, descriptors.party)
assert(none == nil and reason == "spell cannot dispel this recipient",
    "unresolved semantic recipients must fail closed")
none, reason = Decision:Capture(action(999), state, descriptors.party)
assert(none == nil and reason == "fixture incomplete",
    "incomplete installed-client semantics must fail closed")
none, reason = Decision:Capture(action(1000), state, descriptors.party)
assert(none == nil and reason == "dispel semantic budget exceeded",
    "semantic expansion beyond the exact decision budget must fail closed")

reset()
local overflow, auraIndex = {}, nil
for auraIndex = 1, Decision.MAX_AURAS + 1 do
    overflow[auraIndex] = { name = "Magic " .. auraIndex,
        spellId = 700 + auraIndex, dispelType = "Magic", remaining = 4 }
end
auras["party1:HARMFUL"] = overflow
none, reason = Decision:Capture(action(527), state, descriptors.party)
assert(none == nil and reason == "aura observation exceeds decision budget",
    "an oversized aura scan must not fabricate unique or complete evidence")

local invalidState = {}
assert(not Decision:Apply(invalidState, { captured = true, observed = true,
        targetGUID = "party-guid", effects = {} })
    and invalidState.dispelProjection == nil,
    "an incomplete future projection must fail atomically")

print("ok: exact bounded polymorphic dispel decisions")
