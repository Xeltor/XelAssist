XelAssist = { Game = { Player = {}, SpellSemantics = {} } }
table.getn = table.getn or function(value)
    local count = 0
    while value[count + 1] ~= nil do count = count + 1 end
    return count
end

local playerClass = "SHAMAN"
UnitClass = function() return "Localized class", playerClass end
GetSpellName = function()
    error("Shaman action discovery must not inspect localized spell names")
end

local definitions = {
    [3599] = { complete = true, types = { "totemSlot1" } },
    [1535] = { complete = true, types = { "totemSlot1" } },
    [8071] = { complete = true, types = { "totemSlot2" } },
    [5394] = { complete = true, types = { "totemSlot3" } },
    [8512] = { complete = true, types = { "totemSlot4" } },
    [9001] = { complete = true,
        types = { "totemSlot1", "totemSlot2" } },
    [9002] = { complete = true, types = { "generic" } },
    [9003] = { complete = false, types = { "totemSlot3" },
        reason = "trigger unresolved" },
    [9004] = { complete = true, types = { "totemSlot2" } },
}
local semanticCalls, durationCalls = {}, {}
function XelAssist.Game.SpellSemantics:Resolve(spellId)
    semanticCalls[spellId] = (semanticCalls[spellId] or 0) + 1
    local row = definitions[spellId]
    if not row then return { complete = false, admissible = false,
        reasons = { "spell record unavailable" }, atoms = {} } end
    local atoms, index = {}, nil
    for index = 1, table.getn(row.types) do
        table.insert(atoms, { kind = "summon",
            summonType = row.types[index] })
    end
    return { complete = row.complete, admissible = row.complete,
        reasons = row.complete and {} or { row.reason }, atoms = atoms }
end

local durations = { [3599] = 30000, [1535] = 5000, [8071] = 300000,
    [5394] = 60000, [8512] = 120000, [9001] = 5000,
    [9002] = 5000, [9003] = 45000 }
GetSpellDuration = function(spellId)
    durationCalls[spellId] = (durationCalls[spellId] or 0) + 1
    if durations[spellId] == nil then error("duration unavailable") end
    return durations[spellId]
end

dofile("Game/Player/TotemState.lua")
dofile("Game/Player/ShamanActions.lua")
local Actions = XelAssist.Game.Player.ShamanActions

local expected = {
    [3599] = { slot = 1, element = "fire", duration = 30 },
    [8071] = { slot = 2, element = "earth", duration = 300 },
    [5394] = { slot = 3, element = "water", duration = 60 },
    [8512] = { slot = 4, element = "air", duration = 120 },
}
local spellId, row, facts, reason, handled
for spellId, row in pairs(expected) do
    facts, reason, handled = Actions:InferKnowledge(spellId)
    assert(facts and reason == nil and handled
        and facts.inferred and facts.kind == "totem" and facts.kindExact
        and facts.self and facts.fixedTarget == "player"
        and facts.totemPlacementOrigin == "player"
        and facts.totemPlacementOriginExact
        and facts.totemSlot == row.slot
        and facts.totemElement == row.element
        and facts.totemElementExact
        and facts.totemReplacementSlot == row.slot
        and facts.totemReplacementExact
        and facts.totemReplacementFamily
            == "shamanTotemSlot" .. tostring(row.slot)
        and facts.totemReplacementFamilyExact
        and facts.totemLifetime == row.duration
        and facts.totemLifetimeExact
        and facts.exclusiveFamily == nil,
        "installed slotted summon and duration evidence must seal lifecycle")
    assert(facts.shamanRepresentation == Actions.LIFECYCLE_ONLY
        and facts.shamanRepresentationExact
        and facts.shamanLifecycleRepresented
        and facts.shamanEffectRepresented == false
        and facts.shamanRangeRepresented == false
        and facts.shamanRecipientsRepresented == false
        and facts.requiresShamanTotemState
        and facts.requiresExactTotemDownstream,
        "totem discovery must expose lifecycle separately from unknown effects")
end

local sameSlot = Actions:InferKnowledge(1535)
assert(sameSlot and sameSlot.totemSlot == 1
    and sameSlot.totemReplacementFamily == "shamanTotemSlot1"
    and sameSlot.totemLifetime == 5
    and sameSlot.priority == nil and sameSlot.utility == nil,
    "distinct spells in one semantic slot must replace that slot without order")

local forbidden = { "priority", "score", "utility", "damage", "healing",
    "threat", "role", "preferred", "order", "pulse", "radius",
    "recipients", "recipientRelation", "exclusiveFamily" }
local index, field
facts = Actions:InferKnowledge(3599)
for index = 1, table.getn(forbidden) do
    field = forbidden[index]
    assert(facts[field] == nil,
        "totem discovery must not infer " .. field)
end

local lifecycle
lifecycle, reason = Actions:Lifecycle({ facts = facts })
assert(lifecycle and reason == nil and lifecycle.exact
    and lifecycle.slot == 1 and lifecycle.element == "fire"
    and lifecycle.duration == 30 and lifecycle.replacementSlot == 1
    and lifecycle.replacementFamily == "shamanTotemSlot1",
    "search must be able to consume immutable captured lifecycle facts")

local representation, represented = Actions:Representation(facts)
assert(representation == Actions.LIFECYCLE_ONLY and not represented
    and not Actions:DownstreamRepresented(nil),
    "lifecycle-only discovery must never stand in for represented value")
local promoted = {}
for field, row in pairs(facts) do promoted[field] = row end
promoted.shamanEffectRepresented = true
assert(not Actions:DownstreamRepresented(promoted),
    "effect evidence alone must not imply range or recipient evidence")
promoted.shamanRangeRepresented = true
assert(not Actions:DownstreamRepresented(promoted),
    "effect and range evidence must not imply eligible recipients")
promoted.shamanRecipientsRepresented = true
representation, represented = Actions:Representation({ facts = promoted })
assert(representation == Actions.LIFECYCLE_ONLY and represented,
    "only three explicit downstream gates may promote represented value")

local oldResolve = XelAssist.Game.SpellSemantics.Resolve
local oldDuration = GetSpellDuration
XelAssist.Game.SpellSemantics.Resolve = function()
    error("graph search must not re-read spell semantics")
end
GetSpellDuration = function()
    error("graph search must not re-read spell duration")
end
lifecycle, reason = Actions:Lifecycle({ facts = facts })
assert(lifecycle and reason == nil and lifecycle.duration == 30,
    "search-safe lifecycle access must perform no installed-data reads")
XelAssist.Game.SpellSemantics.Resolve = oldResolve
GetSpellDuration = oldDuration

local cachedBeforeSemantics = semanticCalls[3599]
local cachedBeforeDuration = durationCalls[3599]
local secondFacts = Actions:InferKnowledge(3599)
assert(secondFacts and secondFacts ~= facts
    and semanticCalls[3599] == cachedBeforeSemantics
    and durationCalls[3599] == cachedBeforeDuration,
    "exact immutable discovery must cache evidence but return fresh facts")
secondFacts.totemElement = "mutated"
local thirdFacts = Actions:InferKnowledge(3599)
assert(thirdFacts.totemElement == "fire",
    "caller mutation must not corrupt cached lifecycle evidence")
Actions:Invalidate()
Actions:InferKnowledge(3599)
assert(semanticCalls[3599] == cachedBeforeSemantics + 1
    and durationCalls[3599] == cachedBeforeDuration + 1,
    "explicit invalidation must clear the bounded discovery cache")

local unknown
unknown, reason, handled = Actions:InferKnowledge(9001)
assert(unknown == nil and handled
    and reason == "totem spell has conflicting elements",
    "conflicting replacement slots must fail closed as a recognized totem")
unknown, reason, handled = Actions:InferKnowledge(9002)
assert(unknown == nil and not handled
    and reason == "spell is not a slotted totem summon",
    "a generic summon must remain outside exact four-slot discovery")
unknown, reason, handled = Actions:InferKnowledge(9003)
assert(unknown == nil and handled and reason == "trigger unresolved",
    "an incomplete descriptor with a slotted atom must stop unsafe fallback")
definitions[9003].complete = true
local recovered = Actions:InferKnowledge(9003)
assert(recovered and recovered.totemSlot == 3,
    "failed semantic observations must not be cached")

unknown, reason, handled = Actions:InferKnowledge(9004)
assert(unknown == nil and handled and reason == "totem duration unavailable",
    "a recognized totem without a positive lifetime must fail closed")
durations[9004] = 90000
recovered = Actions:InferKnowledge(9004)
assert(recovered and recovered.totemLifetime == 90,
    "failed lifetime observations must not be cached")

unknown, reason, handled = Actions:InferKnowledge(999999)
assert(unknown == nil and not handled and reason == "spell record unavailable",
    "missing evidence must not guess that an unrelated spell is a totem")

local damaged = {}
for field, row in pairs(facts) do damaged[field] = row end
damaged.totemReplacementSlot = 2
lifecycle, reason = Actions:Lifecycle(damaged)
assert(lifecycle == nil
    and reason == "exact Shaman totem lifecycle facts unavailable",
    "search must reject inconsistent captured replacement evidence")

playerClass = "MAGE"
local before = semanticCalls[8071]
unknown, reason, handled = Actions:InferKnowledge(8071)
assert(unknown == nil and not handled and semanticCalls[8071] == before
    and reason == "player is not an exactly identified Shaman",
    "another exact class must be rejected before installed-data reads")

print("ok: exact name-independent Shaman totem action discovery is fail closed")
