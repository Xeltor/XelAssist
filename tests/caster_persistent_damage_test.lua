-- Installed Octowow Spell.dbc shapes for direct impacts with damage tails.
-- Production classification uses only these mechanical fields; spell names
-- below are readable test labels and are never available to the classifier.
table.getn = table.getn or function(values)
    local count = 0
    while values and values[count + 1] ~= nil do count = count + 1 end
    return count
end

local function row(family, school, effects, auras, targets, amplitudes,
    attributes, attributesEx, targetB, chains)
    return { spellFamilyName = family, school = school,
        spellFamilyFlags = 0,
        attributes = attributes or 0x10000, attributesEx = attributesEx or 0,
        effect = effects, effectApplyAuraName = auras,
        effectImplicitTargetA = targets,
        effectImplicitTargetB = targetB or { 0, 0, 0 },
        effectAmplitude = amplitudes,
        effectChainTarget = chains or { 0, 0, 0 } }
end

local records = {
    -- Family 3 exact impact tails: Fireball, Pyroblast, Frostfire Bolt.
    [133] = row(3, 2, { 2, 6, 0 }, { 0, 3, 0 }, { 6, 6, 0 },
        { 0, 2000, 0 }),
    [11366] = row(3, 2, { 2, 6, 0 }, { 0, 3, 0 }, { 6, 6, 0 },
        { 0, 3000, 0 }),
    [45400] = row(3, 4, { 2, 6, 0 }, { 0, 3, 0 }, { 6, 6, 0 },
        { 0, 2000, 0 }),
    -- Family 5/6 exact primary DoTs: Immolate and Holy Fire.
    [348] = row(5, 2, { 6, 2, 0 }, { 3, 0, 0 }, { 6, 6, 0 },
        { 3000, 0, 0 }),
    [14914] = row(6, 1, { 2, 6, 0 }, { 0, 3, 0 }, { 6, 6, 0 },
        { 0, 2000, 0 }),

    -- Exact rejection fixtures from the same installed client shape families.
    [2120] = row(3, 2, { 2, 27, 0 }, { 0, 3, 0 }, { 16, 28, 0 },
        { 0, 2000, 0 }, nil, 0x10000088), -- Flamestrike area
    [5740] = row(5, 2, { 27, 0, 0 }, { 3, 0, 0 }, { 28, 0, 0 },
        { 1000, 0, 0 }, nil, 0x1000008c), -- Rain of Fire channel/area
    [689] = row(5, 5, { 6, 0, 0 }, { 53, 0, 0 }, { 6, 0, 0 },
        { 1000, 0, 0 }, nil, 0x4004), -- Drain Life channel/leech
    [2944] = row(6, 5, { 6, 0, 0 }, { 53, 0, 0 }, { 6, 0, 0 },
        { 3000, 0, 0 }), -- Devouring Plague non-channel leech
    [172] = row(5, 5, { 6, 0, 0 }, { 3, 0, 0 }, { 6, 0, 0 },
        { 3000, 0, 0 }), -- Corruption pure periodic
    [45915] = row(5, 5, { 2, 6, 0 }, { 0, 3, 0 }, { 24, 24, 0 },
        { 0, 3000, 0 }), -- Carrion Swarm cone
    [60001] = row(3, 2, { 2, 6, 10 }, { 0, 3, 0 }, { 6, 6, 6 },
        { 0, 2000, 0 }), -- unowned extra effect
    [60002] = row(3, 2, { 2, 6, 0 }, { 0, 3, 0 }, { 6, 6, 0 },
        { 0, 2000, 0 }, 0x40), -- passive
    [60003] = row(3, 2, { 2, 6, 0 }, { 0, 3, 0 }, { 6, 6, 0 },
        { 0, 2000, 0 }, nil, 0x4), -- channel
    [60004] = row(7, 2, { 2, 6, 0 }, { 0, 3, 0 }, { 6, 6, 0 },
        { 0, 2000, 0 }), -- another class family
    [60005] = row(3, 2, { 2, 6, 0 }, { 0, 3, 0 }, { 6, 6, 0 },
        { 0, 3000, 0 }), -- non-integral duration/cadence
    [60006] = row(3, 2, { 2, 6, 0 }, { 0, 3, 3 }, { 6, 6, 0 },
        { 0, 2000, 0 }), -- residue in an unused effect slot
    [60007] = row(3, 2, { 2, 6, 0 }, { 0, 3, 0 }, { 6, 6, 0 },
        { 0, 2000, 0 }), -- topology without a lifecycle family flag
}
records[133].spellFamilyFlags = 0x40000001
records[11366].spellFamilyFlags = 0x40400000
records[45400].spellFamilyFlags = 0x40000021
records[348].spellFamilyFlags = 0x4
records[14914].spellFamilyFlags = 0x100000

local durations = { [133] = 4000, [11366] = 12000, [45400] = 8000,
    [348] = 15000, [14914] = 10000, [2120] = 8000, [5740] = 8000,
    [689] = 5000, [2944] = 24000, [172] = 12000, [45915] = 12000,
    [60001] = 8000, [60002] = 8000, [60003] = 8000,
    [60004] = 8000, [60005] = 8000, [60006] = 8000,
    [60007] = 8000 }

local dbcReads, durationReads = 0, 0
function GetSpellRecField(spellId, field, copied)
    dbcReads = dbcReads + 1
    local record = records[spellId]
    if not record then return nil end
    local value = record[field]
    if copied and type(value) == "table" then
        return { value[1], value[2], value[3] }
    end
    return value
end
function GetSpellDuration(spellId)
    durationReads = durationReads + 1
    return durations[spellId]
end

XelAssist = { Combat = {}, Game = {}, Graph = {} }
dofile("Game/Caster/PersistentDamage.lua")
local Facts = XelAssist.Game.Caster.PersistentDamage

local explicit = { kind = "damage", ranged = true, typedSentinel = "kept" }
local fireball = assert(Facts:Refine(133, explicit))
assert(fireball ~= explicit and fireball.kind == "damage"
    and fireball.ranged and fireball.typedSentinel == "kept"
    and fireball.repeatablePersistentDamage
    and fireball.persistentDamageDuration == 4
    and fireball.persistentDamageInterval == 2
    and fireball.persistentDamageTicks == 2,
    "an exact Mage impact tail must refine a copied damage fact set")
assert(explicit.repeatablePersistentDamage == nil
    and explicit.dbcDirectPeriodic == nil,
    "root knowledge must remain immutable during DBC refinement")

local pyro = assert(Facts:Refine(11366))
local frostfire = assert(Facts:Refine(45400))
assert(pyro.kind == "damage" and pyro.inferred
    and pyro.persistentDamageTicks == 4
    and frostfire.kind == "damage" and frostfire.inferred
    and frostfire.persistentDamageTicks == 4,
    "localized unknown Mage ranks must be inferred from exact family shape")

local immolate = assert(Facts:Refine(348))
local holyFire = assert(Facts:Refine(14914, { kind = "dot", ranged = true }))
assert(immolate.kind == "dot" and immolate.inferred
    and not immolate.repeatablePersistentDamage
    and holyFire.kind == "dot" and holyFire.ranged
    and not holyFire.repeatablePersistentDamage,
    "Warlock and Priest primary DoTs must retain ordinary application guards")
assert(Facts:Refine(348, { kind = "heal" }) == nil,
    "an existing unrelated mechanic must remain authoritative")

local rejected = { 2120, 5740, 689, 2944, 172, 45915,
    60001, 60002, 60003, 60004, 60005, 60006 }
local i
for i = 1, table.getn(rejected) do
    assert(Facts:Refine(rejected[i]) == nil,
        "unsupported exact fixture " .. tostring(rejected[i]) .. " must fail closed")
end
assert(Facts:Refine(60007) == nil,
    "unknown topology without a lifecycle family flag must fail closed")
local knownPatch = assert(Facts:Refine(60007, { kind = "damage" }))
assert(knownPatch.repeatablePersistentDamage,
    "an explicit known damage lifecycle may refine exact patch topology")

local readsBeforeCache, durationsBeforeCache = dbcReads, durationReads
GetSpellRecField = function() error("recognized shape reread DBC") end
GetSpellDuration = function() error("recognized shape reread duration") end
local cached = assert(Facts:Refine(133, { kind = "damage" }))
assert(cached.persistentDamageTicks == 2 and dbcReads == readsBeforeCache
    and durationReads == durationsBeforeCache,
    "a recognized root shape must be copied from its sealed cache")

local power = { dbcEffectDirectDamage = 40,
    dbcEffectPeriodicDamage = 8, duration = 4 }
assert(Facts:ApplyPower({ facts = fireball }, power)
    and power.average == 48 and power.dbcEffectAverage == 48
    and power.dbcEffectComplete and power.directDamage == 40
    and power.periodicDamage == 8 and power.periodicInterval == 2
    and power.persistentDamage.exact
    and power.persistentDamage.ticks == 2,
    "root power sealing must preserve both impact and complete tail")
assert(not Facts:ApplyPower({ facts = fireball }, {
        dbcEffectDirectDamage = 40, dbcEffectPeriodicDamage = 8,
        duration = 6 }),
    "a duration mismatch must not fabricate a persistent damage contract")
local ordinaryDotPower = { dbcEffectDirectDamage = 10,
    dbcEffectPeriodicDamage = 40, duration = 15,
    average = 50, damageTotalSource = "tooltip" }
assert(not Facts:ApplyPower({ facts = immolate }, ordinaryDotPower)
    and ordinaryDotPower.average == 50
    and ordinaryDotPower.damageTotalSource == "tooltip"
    and ordinaryDotPower.persistentDamage == nil,
    "primary DoTs must retain the existing generic tooltip/DBC power policy")

-- Every remaining method runs after the root boundary. Any API read is a hard
-- test failure, including reads hidden behind an apparently harmless helper.
GetSpellRecField = function() error("DBC read during graph search") end
GetSpellDuration = function() error("duration read during graph search") end
GetTime = function() error("time read during graph search") end
UnitHealth = function() error("unit read during graph search") end

local sawPeriodicSurvival = false
XelAssist.Graph.Effects = {}
function XelAssist.Graph.Effects:PhaseFactor(_, phase)
    if phase == "direct" then return 0.8 end
    return 0.5
end
function XelAssist.Graph.Effects:OverWindow()
    return 0.5
end
XelAssist.Graph.SurvivalPressure = {}
function XelAssist.Graph.SurvivalPressure:Adjust(context)
    assert(context.kind == "dot",
        "persistent survival must use the shared periodic envelope")
    sawPeriodicSurvival = true
    context.dotPeriodicExpectedPower = context.dotPeriodicExpectedPower * 0.5
    context.expectedPower = context.persistentDirectExpectedPower
        + context.dotPeriodicExpectedPower
    context.survival = { decisionFactor = 0.75, periodicFactor = 0.5 }
end
XelAssist.Graph.HostileEffects = {}
function XelAssist.Graph.HostileEffects:ApplySelectedDamage(state, amount)
    if state.targetHealthExact ~= true then return false, nil end
    local dealt = math.min(state.targetHealth, math.max(0, amount))
    state.targetHealth = state.targetHealth - dealt
    return true, dealt
end
XelAssist.Graph.EventAuras = {}
function XelAssist.Graph.EventAuras:ReplaceStateAura(_, _, delivery, prior)
    if prior and delivery < 1 then return { prior } end
    return nil
end
dofile("Game/SpellTiming.lua")
dofile("Graph/CasterPersistentDamage.lua")
local Graph = XelAssist.Graph.CasterPersistentDamage

local action = { name = "localized display text", spellId = 133,
    actor = "player", facts = fireball }
local tooltip = { school = 2, duration = 4,
    cast = 2,
    persistentDamage = { exact = true, direct = 40, periodic = 60,
        duration = 4, interval = 2, ticks = 2,
        source = "sealed test evidence" } }
local state = { role = "damage", time = 0, auras = {}, targetAuras = {},
    targetHealth = 50, targetHealthExact = true }
local context = { action = action, facts = action.facts, kind = "damage",
    tooltip = tooltip, target = "target", state = state,
    power = 100, expectedPower = 100, effectDelivery = 0.8,
    resistance = { decisionMultiplier = 1 }, wait = 0, cast = 2,
    downtime = 2, cost = 30 }
assert(Graph:Prepare(context)
    and context.dotRawDirectPower == 40
    and context.dotRawPeriodicPower == 60
    and context.persistentDirectExpectedPower == 32
    and context.dotPeriodicExpectedPower == 24
    and context.expectedPower == 56,
    "impact and tail must retain separate resistance consequences")
assert(Graph:AdjustSurvival(context) and sawPeriodicSurvival
    and context.kind == "damage"
    and context.persistentDirectExpectedPower == 32
    and context.dotPeriodicExpectedPower == 12
    and context.expectedPower == 44,
    "shared target survival must trim only the tail and restore damage kind")
assert(Graph:Score(context, 50)
    and context.persistentMarginalPower == 44
    and context.reason == "adds impact and lasting damage",
    "a fresh impact tail must earn only its delivered consequences")
assert(context.reason ~= "finishes with the direct impact",
    "later ticks must never claim an immediate lethal impact")

state.auras[action.name] = { mine = true, spellId = 133,
    remaining = 3, duration = 4, applicationProbability = 1 }
assert(Graph:Blocker(action, state, nil, tooltip) == nil,
    "an own same-rank tail must not block another repeatable impact")
assert(Graph:Score(context, 50)
    and context.persistentMarginalPower == 32
    and context.effectivePower == 32
    and context.reason == "recasts for its direct impact",
    "refreshing an active tail must value only the provable new impact")

state.auras[action.name].remaining = 1
assert(Graph:Score(context, 50)
    and context.persistentMarginalPower == 44
    and context.reason == "adds impact and lasting damage",
    "a tail expiring before cast impact must not suppress the fresh tail")
state.auras[action.name].remaining = 3

state.auras[action.name].spellId = 143
local blocker, handled = Graph:Blocker(action, state, nil, tooltip)
assert(blocker == "persistent tail rank unknown" and handled,
    "a mismatched tail rank must fail closed")
state.auras[action.name].spellId = 133
state.auras[action.name].applicationProbability = 0.5
blocker, handled = Graph:Blocker(action, state, nil, tooltip)
assert(blocker == "persistent tail state unknown" and handled,
    "an uncertain replacement branch must fail closed")
state.auras[action.name] = nil
state.targetAuras[action.name] = { mine = false, spellId = 133,
    remaining = 4, duration = 4 }
assert(Graph:Blocker(action, state, nil, tooltip) == nil,
    "another caster's same display aura must not block our impact")
state.targetAuras[action.name] = nil
blocker, handled = Graph:Blocker(action, state, nil, {})
assert(blocker == "persistent damage evidence unavailable" and handled,
    "a claimed action without sealed power evidence must fail closed")

local candidate = { action = action, tooltip = tooltip, target = "target",
    targetRelation = "hostile", power = 56,
    dotRawPeriodicPower = 60, dotPeriodicExpectedPower = 24,
    effectDelivery = 0.8, occupancy = 2, cast = 2,
    survival = { periodicFactor = 0.5 } }
local out = { targetHealth = 100, targetHealthExact = true, auras = {} }
local transition = {}
assert(Graph:Apply(out, candidate, transition)
    and out.targetHealth == 68 and transition.appliedHostileDamage == 32,
    "the chosen edge must apply only its immediate impact")
local aura = assert(out.auras[action.name])
assert(aura.spellId == 133 and aura.remaining == 4
    and aura.periodicRate == 6 and aura.periodicRawRate == 7.5
    and aura.periodicInterval == 2 and aura.periodicNextIn == 2
    and aura.periodicThreatActor == "player"
    and aura.repeatablePersistentDamage,
    "the tail must become a causal tick clock instead of front-loaded damage")

candidate.occupancy, candidate.cast = 3, 0
out = { targetHealth = 100, targetHealthExact = true, auras = {} }
transition = {}
assert(Graph:Apply(out, candidate, transition)
    and out.targetHealth == 56
    and math.abs(out.auras[action.name].remaining - 1) < 0.0001
    and math.abs(out.auras[action.name].periodicNextIn - 1) < 0.0001,
    "only completed cadence ticks during occupancy may land immediately")

print("ok: caster impact tails use exact sealed DBC consequences")
