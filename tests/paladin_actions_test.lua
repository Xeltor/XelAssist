XelAssist = { Game = { Player = {} } }
table.getn = table.getn or function(value)
    local count = 0
    while value[count + 1] ~= nil do count = count + 1 end
    return count
end

local playerClass, dbcCalls = "PALADIN", 0
local records = {
    [20154] = { 10, 134217728 }, -- seal bit 27
    [20375] = { 10, 33554432 },  -- another seal
    [19740] = { 10, 268435458 }, -- blessing bit 28
    [1038] = { 10, 256 },        -- another blessing
    [20271] = { 10, 8388608 },   -- Judgement bit 23
    [25780] = { 10, 1 },         -- Righteous Fury bit 0
    [5000] = { 5, 134217728 },   -- same bit, different class family
    [5001] = { 10, 0 },          -- unrepresented Paladin family member
    [5002] = { 10, 402653184 },  -- conflicting seal and blessing bits
}
UnitClass = function() return "Paladin", playerClass end
GetSpellRecField = function(spellId, field)
    dbcCalls = dbcCalls + 1
    local row = records[spellId]
    if not row then error("missing spell") end
    if field == "spellFamilyName" then return row[1] end
    if field == "spellFamilyFlags" then return row[2] end
    error("unknown field")
end
GetSpellName = function()
    error("Paladin discovery must never inspect localized spell names")
end

dofile("Game/Player/PaladinAuraState.lua")
dofile("Game/Player/PaladinActions.lua")
local Actions = XelAssist.Game.Player.PaladinActions

local seal, reason, handled = Actions:InferKnowledge(20154)
assert(seal and reason == nil and handled
    and seal.inferred and seal.kind == "buff" and seal.kindExact
    and seal.self and seal.fixedTarget == "player"
    and seal.recipientRelation == "self"
    and seal.recipientRelationExact
    and seal.exclusiveFamily == "paladinSeal"
    and seal.exclusiveFamilyExact
    and seal.paladinAura and seal.paladinSeal
    and seal.paladinRepresentation == Actions.LIFECYCLE_ONLY
    and seal.paladinRepresentationExact
    and seal.paladinLifecycleRepresented
    and seal.paladinLifecycleOnly
    and seal.paladinEffectRepresented == false,
    "a seal must infer an exact self-exclusive lifecycle-only buff")

local blessing
blessing, reason, handled = Actions:InferKnowledge(19740)
assert(blessing and reason == nil and handled
    and blessing.kind == "buff" and not blessing.self
    and blessing.fixedTarget == nil
    and blessing.recipientRelation == "friendly"
    and blessing.exclusiveFamily == "paladinBlessingByCaster"
    and blessing.paladinAura and blessing.paladinBlessing
    and blessing.paladinRepresentation == Actions.LIFECYCLE_ONLY
    and blessing.paladinLifecycleRepresented
    and blessing.paladinLifecycleOnly
    and blessing.paladinEffectRepresented == false,
    "a blessing must infer an exact variable-friendly per-caster family")

local judgement
judgement, reason, handled = Actions:InferKnowledge(20271)
assert(judgement and reason == nil and handled
    and judgement.kind == "judgement" and judgement.hostile
    and judgement.recipientRelation == "hostile"
    and judgement.exclusiveFamily == nil
    and judgement.exclusiveFamilyExact
    and judgement.paladinJudgement
    and judgement.requiresExactPaladinDownstreamOutcome
    and judgement.paladinRepresentation
        == Actions.REQUIRES_EXACT_DOWNSTREAM
    and judgement.paladinLifecycleRepresented == false
    and judgement.paladinEffectRepresented == false,
    "Judgement must remain a hostile mechanic requiring exact downstream evidence")

local righteousFury
righteousFury, reason, handled = Actions:InferKnowledge(25780)
assert(righteousFury and reason == nil and handled
    and righteousFury.kind == "buff" and righteousFury.self
    and righteousFury.fixedTarget == "player"
    and righteousFury.recipientRelation == "self"
    and righteousFury.exclusiveFamily == nil
    and righteousFury.paladinAura and righteousFury.paladinRighteousFury
    and righteousFury.paladinRepresentation == Actions.UNREPRESENTED
    and righteousFury.paladinLifecycleRepresented == false
    and righteousFury.paladinEffectRepresented == false,
    "Righteous Fury must be discovered but remain fully unrepresented")

local forbidden = { "priority", "score", "utility", "threat", "damage",
    "healing", "tankOnly", "role", "preferred", "order" }
local index, field
for index = 1, table.getn(forbidden) do
    field = forbidden[index]
    assert(seal[field] == nil and blessing[field] == nil
        and judgement[field] == nil and righteousFury[field] == nil,
        "Paladin inference must not assign " .. field)
end

local representation, represented = Actions:Representation(seal)
assert(representation == Actions.LIFECYCLE_ONLY and not represented
    and not Actions:EffectsRepresented(nil)
    and not Actions:EffectsRepresented({ facts = blessing }),
    "missing and explicit-false downstream representation must fail closed")
local promoted = { facts = { paladinRepresentationExact = true,
    paladinRepresentation = Actions.REQUIRES_EXACT_DOWNSTREAM,
    paladinEffectRepresented = true } }
representation, represented = Actions:Representation(promoted)
assert(representation == Actions.REQUIRES_EXACT_DOWNSTREAM and represented,
    "only an explicit later exact resolver may mark downstream representation")

local unknown
unknown, reason, handled = Actions:InferKnowledge(5000)
assert(unknown == nil and not handled
    and reason == "spell is not an exact Paladin action",
    "another class family must remain outside Paladin discovery")
unknown, reason, handled = Actions:InferKnowledge(5001)
assert(unknown == nil and not handled
    and reason == "spell is not an exact Paladin action",
    "an ordinary Paladin-family spell must remain available to normal discovery")
unknown, reason, handled = Actions:InferKnowledge(5002)
assert(unknown == nil and handled
    and reason == "Paladin DBC exclusive families conflict",
    "conflicting Paladin family evidence must fail closed")

unknown, reason, handled = Actions:InferKnowledge(7777)
assert(unknown == nil and not handled
    and reason == "Paladin DBC family evidence unavailable",
    "missing DBC evidence must not claim an unknown action identity")
records[7777] = { 10, 256 }
local recovered = Actions:InferKnowledge(7777)
assert(recovered and recovered.paladinBlessing,
    "failed observations must not be cached across later exact evidence")

local before = dbcCalls
local cached = Actions:InferKnowledge(20375)
local afterFirst = dbcCalls
local cachedAgain = Actions:InferKnowledge(20375)
assert(cached and cachedAgain and afterFirst == before + 2
    and dbcCalls == afterFirst,
    "exact immutable family classification should be cached by spell ID")
Actions:Invalidate()
Actions:InferKnowledge(20375)
assert(dbcCalls == afterFirst + 2,
    "explicit invalidation must clear the bounded action cache")

playerClass = "SHAMAN"
before = dbcCalls
unknown, reason, handled = Actions:InferKnowledge(20154)
assert(unknown == nil and not handled and dbcCalls == before
    and reason == "player is not an exactly identified Paladin",
    "Paladin discovery must reject another exact player class before DBC reads")

print("ok: exact name-independent Paladin action discovery is fail closed")
