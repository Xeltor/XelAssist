XelAssist = { Game = { Player = {} } }
table.getn = table.getn or function(value)
    local count = 0
    while value and value[count + 1] ~= nil do count = count + 1 end
    return count
end

local function triple(first, second, third)
    return { first or 0, second or 0, third or 0 }
end

local records = {
    [1463] = { spellFamilyName = 3, spellFamilyFlags = 32768,
        powerType = 0, effect = triple(6),
        effectApplyAuraName = triple(97),
        effectImplicitTargetA = triple(1),
        effectImplicitTargetB = triple(),
        effectMultipleValue = triple(2),
        effectMiscValue = triple(1), effectTriggerSpell = triple() },
    [133] = { spellFamilyName = 3, spellFamilyFlags = 1 },
    [9001] = { spellFamilyName = 3, spellFamilyFlags = 32768,
        powerType = 0, effect = triple(6),
        effectApplyAuraName = triple(97),
        effectImplicitTargetA = triple(1),
        effectImplicitTargetB = triple(),
        effectMultipleValue = triple(1),
        effectMiscValue = triple(1), effectTriggerSpell = triple() },
}
local dbcCalls, durationCalls, modifierCalls = 0, 0, 0
local playerClass, modifierFlat, modifierPercent, modifierChanged =
    "MAGE", 0, 0, 0

UnitClass = function() return "Localized", playerClass end
GetSpellName = function()
    error("Mana Shield mechanics must not read localized spell names")
end
GetSpellRecField = function(spellId, field, copied)
    dbcCalls = dbcCalls + 1
    local row = records[spellId]
    if not row or row[field] == nil then error("missing DBC field") end
    if copied and type(row[field]) == "table" then
        return { row[field][1], row[field][2], row[field][3] }
    end
    return row[field]
end
GetSpellDuration = function(spellId)
    durationCalls = durationCalls + 1
    if spellId == 1463 or spellId == 9001 then return 60000 end
    error("duration unavailable")
end
GetSpellModifiers = function(spellId, kind)
    modifierCalls = modifierCalls + 1
    assert(spellId == 1463 and kind == 27,
        "capture must query only this shield's MULTIPLE_VALUE modifier")
    return modifierFlat, modifierPercent, modifierChanged
end

dofile("Game/Player/MageManaShield.lua")
local Shield = XelAssist.Game.Player.MageManaShield

local facts, reason, handled = Shield:InferKnowledge(1463)
assert(facts and reason == nil and handled and facts.kind == "absorb"
    and facts.kindExact and facts.self and facts.fixedTarget == "player"
    and facts.mageManaShield and facts.manaFundedAbsorb
    and facts.requiresMageManaShieldEvidence
    and facts.mageManaShieldEvidence.schoolMask == 1
    and facts.mageManaShieldEvidence.baseManaPerDamage == 2
    and facts.mageManaShieldEvidence.duration == 60,
    "installed topology must identify the physical mana-funded self shield")
assert(facts.priority == nil and facts.score == nil and facts.rotation == nil,
    "mechanics discovery must not encode an action order")

local beforeDBC, beforeDuration = dbcCalls, durationCalls
local second = Shield:InferKnowledge(1463)
assert(second and second ~= facts and dbcCalls == beforeDBC
    and durationCalls == beforeDuration,
    "complete Mana Shield evidence must be cached outside search")
second.mageManaShieldEvidence.schoolMask = 127
local third = Shield:InferKnowledge(1463)
assert(third.mageManaShieldEvidence.schoolMask == 1,
    "caller mutation must not poison cached DBC evidence")

local unknown
unknown, reason, handled = Shield:InferKnowledge(133)
assert(unknown == nil and not handled and reason == "spell is not Mana Shield",
    "another Mage family spell must remain available to generic inference")
unknown, reason, handled = Shield:InferKnowledge(9001)
assert(unknown == nil and handled
    and reason == "Mana Shield DBC topology is incomplete",
    "a claimed family with changed mana ratio must fail closed")

local action = { name = "Localized shield", spellId = 1463,
    facts = facts }
local tooltip = Shield:CaptureFacts(action,
    { cost = 40, duration = 60, average = 120 })
assert(tooltip.manaPerAbsorbedDamage == 2
    and tooltip.manaPerAbsorbedDamageExact
    and tooltip.mageManaShieldSchoolMask == 1
    and modifierCalls == 1,
    "root capture must seal an exact unmodified live mana ratio")

modifierChanged, modifierPercent = 1, 4294967276
local modified = Shield:CaptureFacts(action,
    { cost = 40, duration = 60, average = 120 })
assert(modified.manaPerAbsorbedDamage == nil
    and modified.manaPerAbsorbedDamageExact == false
    and modified.mageManaShieldCaptureReason
        == "modified Mana Shield mana ratio is unresolved",
    "talent-sensitive unsigned modifiers must not be guessed")
local blocker, claimed = Shield:Blocker(action, {
    resourceType = 0, resource = 200, playerResourceExact = true }, modified)
assert(claimed and blocker == "modified Mana Shield mana ratio is unresolved",
    "unresolved live modifiers must block the exact consequence model")
modifierChanged, modifierPercent = 0, 0

blocker, claimed = Shield:Blocker(action, {
    resourceType = 0, resource = 200, playerResourceExact = true }, tooltip)
assert(claimed and blocker == nil,
    "exact Mage mana state must admit an unmodified shield")
blocker = Shield:Blocker(action, {
    resourceType = 0, resource = 200, playerResourceExact = false }, tooltip)
assert(blocker == "Mana Shield resource evidence unavailable",
    "unknown player mana must fail closed")

local candidate = { action = action, tooltip = tooltip, power = 120,
    cost = 40, effectDelivery = 1 }
local capacity = Shield:EffectiveCapacity(candidate, {
    resourceType = 0, resource = 100, playerResourceReserved = 0,
    playerResourceExact = true })
assert(capacity == 30,
    "capacity must reserve cast mana before pricing future absorption")
local entry = Shield:Entry(candidate)
assert(entry and entry.mageManaShield and entry.amount == 120
    and entry.manaPerDamage == 2 and entry.schoolMask == 1,
    "projection must retain the exact server consumption contract")

local state = { resourceType = 0, resource = 100,
    playerResourceExact = true,
    playerResourceClock = { verified = true, phaseKnown = true, nextIn = 1 },
    actors = { player = { resource = 100 } } }
local absorbs = { shield = entry }
local residual, absorbed, spent, partial, consumed =
    Shield:ConsumeEntry(state, absorbs, "shield", 50, 1, 2)
assert(consumed and residual == 50 and absorbed == 0 and spent == 0
    and not partial and state.resource == 100 and absorbs.shield.amount == 120
    and state.playerResourceClock and state.playerResourceClock.phaseKnown,
    "the physical-only shield must not absorb fire damage")

residual, absorbed, spent, partial, consumed =
    Shield:ConsumeEntry(state, absorbs, "shield", 80, 1, 0)
assert(consumed and residual == 30 and absorbed == 50 and spent == 100
    and not partial and state.resource == 0
    and state.actors.player.resource == 0 and absorbs.shield.amount == 70
    and state.playerResourceClock == nil,
    "physical damage must debit mana and close the unmatched passive phase")

state.resource, state.actors.player.resource = 60, 60
residual, absorbed, spent, partial =
    Shield:ConsumeEntry(state, absorbs, "shield", 20, 0.5, 0)
assert(residual == 0 and absorbed == 10 and spent == 20 and partial
    and state.resource == 40 and absorbs.shield.amount == 60
    and absorbs.shield.applicationProbability == 1,
    "probabilistic hostile casts must preserve the surviving shield branch")

state.playerResourceExact = false
residual, absorbed, spent, partial, consumed =
    Shield:ConsumeEntry(state, absorbs, "shield", 10, 1, 0)
assert(consumed and residual == 10 and absorbed == 0 and spent == 0 and partial,
    "unknown mana must not fabricate prevented damage")

local savedDBC, savedDuration, savedModifiers = GetSpellRecField,
    GetSpellDuration, GetSpellModifiers
GetSpellRecField = function() error("DBC read during graph search") end
GetSpellDuration = function() error("duration read during graph search") end
GetSpellModifiers = function() error("modifier read during graph search") end
state.playerResourceExact, state.resource = true, 20
assert(Shield:Entry(candidate)
    and Shield:EffectiveCapacity(candidate, state) == 0,
    "sealed search helpers must perform no mutable API reads")
GetSpellRecField, GetSpellDuration, GetSpellModifiers =
    savedDBC, savedDuration, savedModifiers

playerClass = "PRIEST"
beforeDBC = dbcCalls
unknown, reason, handled = Shield:InferKnowledge(1463)
assert(unknown == nil and not handled and dbcCalls == beforeDBC,
    "another exact player class must be rejected before DBC access")

print("ok: Mage Mana Shield preserves physical mask and exact mana debit")
