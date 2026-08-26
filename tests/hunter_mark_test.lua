-- Hunter's Mark is valued only through exact target-local ranged weapon AP.
-- No localized display name, rank priority, or fixed utility enters the model.
table.getn = table.getn or function(value) return #value end
XelAssist = { Game = { Player = {} }, Graph = {} }

local function triple(first, second, third)
    return { first or 0, second or 0, third or 0 }
end

local function markRow(level, cost, base)
    return {
        school = 6, category = 0, castUI = 0, dispel = 1, mechanic = 0,
        attributes = 67174400, attributesEx = 1056, attributesEx2 = 0,
        attributesEx3 = 196609, attributesEx4 = 0,
        stances = 0, stancesNot = 0, targets = 0, targetCreatureType = 0,
        requiresSpellFocus = 0, casterAuraState = 0, targetAuraState = 0,
        castingTimeIndex = 1, recoveryTime = 0, categoryRecoveryTime = 0,
        interruptFlags = 0, auraInterruptFlags = 0,
        channelInterruptFlags = 0, procFlags = 0, procChance = 101,
        procCharges = 0, maxLevel = 0, baseLevel = level,
        spellLevel = level, durationIndex = 4, powerType = 0,
        manaCost = cost, manaCostPerlevel = 0, manaPerSecond = 0,
        manaPerSecondPerLevel = 0, rangeIndex = 6, modalNextSpell = 0,
        stackAmount = 0, equippedItemClass = -1,
        equippedItemSubClassMask = 0, equippedItemInventoryTypeMask = 0,
        manaCostPercentage = 0, startRecoveryCategory = 133,
        startRecoveryTime = 1500, spellFamilyName = 9,
        spellFamilyFlags = 1024, maxAffectedTargets = 0,
        dmgClass = 0, preventionType = 0,
        effect = triple(6, 6), effectDieSides = triple(1, 1),
        effectBaseDice = triple(1, 1), effectDicePerLevel = triple(),
        effectRealPointsPerLevel = triple(),
        effectBasePoints = triple(-1, base), effectMechanic = triple(),
        effectImplicitTargetA = triple(25, 6),
        effectImplicitTargetB = triple(), effectRadiusIndex = triple(),
        effectApplyAuraName = triple(68, 127), effectAmplitude = triple(),
        effectMultipleValue = triple(1), effectChainTarget = triple(),
        effectItemType = triple(), effectMiscValue = triple(),
        effectTriggerSpell = triple(), effectPointsPerComboPoint = triple(),
    }
end

local records = {
    [1130] = markRow(6, 15, 19),
    [14323] = markRow(22, 30, 44),
    [14324] = markRow(40, 45, 74),
    [14325] = markRow(58, 60, 109),
    -- Installed Multi-Shot, Auto Shot, and the 0.5-coefficient Scatter Shot
    -- weapon shape, plus Arcane Shot's direct-school-damage shape that must
    -- not receive target-side RAP.
    [2643] = { dmgClass = 3, effect = triple(121) },
    [75] = { dmgClass = 3, effect = triple(58) },
    [19503] = { dmgClass = 3, effect = triple(31, 6) },
    [3044] = { dmgClass = 3, effect = triple(2, 31) },
}
local durations = { [1130] = 120000, [14323] = 120000,
    [14324] = 120000, [14325] = 120000 }
local reads, class = 0, "HUNTER"

function GetSpellRecField(spellId, field, copied)
    reads = reads + 1
    local value = records[spellId] and records[spellId][field]
    if copied and type(value) == "table" then
        return { value[1], value[2], value[3] }
    end
    return value
end

function GetSpellDuration(spellId)
    reads = reads + 1
    return durations[spellId]
end

function GetSpellRangeData(index)
    reads = reads + 1
    assert(index == 6)
    return 0, 100
end

function UnitClass()
    return "localized class ignored", class
end

function UnitRangedDamage(unit)
    assert(unit == "player")
    reads = reads + 1
    return 2.8, 100, 120, 5, -2, 1.1
end

dofile("Game/Player/HunterMark.lua")
local Runtime = XelAssist.Game.Player.HunterMark
local ids, bonuses, costs = { 1130, 14323, 14324, 14325 },
    { 20, 45, 75, 110 }, { 15, 30, 45, 60 }
local index
for index = 1, table.getn(ids) do
    local found, reason, handled = Runtime:Classify(ids[index])
    assert(found and found.valid and found.exact and handled and reason == nil
        and found.rank == index and found.rangedAttackPowerBonus == bonuses[index]
        and found.cost == costs[index] and found.powerType == 0
        and found.duration == 120 and found.minRange == 0
        and found.maxRange == 100 and found.gcd == 1.5
        and found.cast == 0 and found.school == 6
        and found.markAura == 68 and found.rangedAttackPowerAura == 127
        and found.recipient == "selected-hostile",
        "every installed Mark rank must retain its exact aura-127 consequence")
end
local unrelated, _, handled = Runtime:Classify(99999)
assert(unrelated == nil and not handled,
    "an unrelated numeric identity must remain outside the Mark portfolio")

local inferred, reason
inferred, reason, handled = Runtime:InferKnowledge(1130)
assert(inferred and handled and reason == nil and inferred.kind == "debuff"
    and inferred.kindExact and inferred.hunterMark and inferred.hostile
    and inferred.ranged and inferred.targetLocalRangedAttackPower
    and inferred.requiresExactHunterMarkDownstream
    and inferred.requiresExactUsability and inferred.submissionGuarded
    and inferred.preferred == nil and inferred.order == nil
    and inferred.hunterMarkEvidence.rangedAttackPowerBonus == 20,
    "inference must describe Mark mechanics without an ordered rotation")
class = "ROGUE"
local foreign, _, foreignHandled = Runtime:InferKnowledge(1130)
assert(foreign == nil and not foreignHandled,
    "another class must not claim Hunter action inference")
class = "HUNTER"

local markAction = { name = "localized mark text deliberately ignored",
    spellId = 1130, actor = "player", facts = inferred }
local markFacts = Runtime:CaptureFacts(markAction, { source = "root tooltip" })
assert(markFacts.hunterMark and markFacts.targetLocalRangedAttackPower
    and markFacts.hunterMarkEvidence.rangedAttackPowerBonus == 20
    and markFacts.cost == 15 and markFacts.powerType == 0
    and markFacts.duration == 120 and markFacts.minRange == 0
    and markFacts.maxRange == 100 and markFacts.gcd == 1.5
    and markFacts.cast == 0 and markFacts.school == 6,
    "root facts must consume sealed Mark discovery evidence")

local multiAction = { name = "localized ranged weapon text ignored",
    spellId = 2643, actor = "player", facts = { kind = "damage" } }
local multiFacts = Runtime:CaptureFacts(multiAction, {
    weaponCoefficient = 1, weaponNormalized = true,
    weaponFormulaSource = "OctoWoW VMaNGOS weapon effects" })
assert(multiFacts.hunterRangedWeaponEvidence
    and multiFacts.hunterRangedWeaponEvidence.attackType == "ranged"
    and multiFacts.hunterRangedWeaponEvidence.normalized
    and multiFacts.hunterRangedWeaponEvidence.weaponEffectCount == 1,
    "a ranged normalized weapon effect must expose its exact Mark lane")
local autoAction = { name = "localized repeat text ignored", spellId = 75,
    actor = "player", facts = { kind = "damage" } }
local autoFacts = Runtime:CaptureFacts(autoAction, {
    weaponCoefficient = 1, weaponNormalized = false,
    weaponFormulaSource = "OctoWoW VMaNGOS weapon effects" })
assert(autoFacts.hunterRangedWeaponEvidence
    and not autoFacts.hunterRangedWeaponEvidence.normalized,
    "an ordinary ranged weapon effect must retain current-speed semantics")
local arcaneAction = { name = "localized direct shot text ignored",
    spellId = 3044, actor = "player", facts = { kind = "damage" } }
local arcaneFacts = Runtime:CaptureFacts(arcaneAction, {
    weaponCoefficient = 0.1, weaponNormalized = false,
    weaponFormulaSource = "OctoWoW VMaNGOS weapon effects" })
assert(arcaneFacts.hunterRangedWeaponEvidence == nil,
    "a ranged direct-school-damage spell must not inherit Mark RAP")
local halfAction = { name = "localized coefficient text ignored",
    spellId = 19503, actor = "player", facts = { kind = "damage" } }
local halfFacts = Runtime:CaptureFacts(halfAction, {
    weaponCoefficient = 0.5, weaponNormalized = false,
    weaponFormulaSource = "OctoWoW VMaNGOS weapon effects" })
assert(halfFacts.hunterRangedWeaponEvidence
    and halfFacts.hunterRangedWeaponEvidence.weaponCoefficient == 0.5
    and not halfFacts.hunterRangedWeaponEvidence.normalized,
    "the installed 0.5-coefficient weapon effect must retain both facts")

XelAssist.Graph.State = {
    RefreshHostileRecord = function(_, state, key)
        state.refreshed = (state.refreshed or 0) + 1
        local record = state.hostiles.byKey[key]
        if state.targetGUID == record.guid then
            state.auras = record.projectedAuras
        end
    end,
}
dofile("Graph/HunterMark.lua")
local Graph = XelAssist.Graph.HunterMark

local function record(key, guid, selected)
    return { key = key, guid = guid, selected = selected, dead = false,
        projectedAuras = {}, targetAuras = {},
        harmfulAuras = { available = true, list = {}, byName = {} } }
end

local function state()
    local selected = record("selected-key", "selected-guid", true)
    local other = record("other-key", "other-guid", false)
    local out = { time = 0, targetGUID = selected.guid,
        hostiles = { selectedKey = selected.key,
            order = { selected.key, other.key },
            byKey = { [selected.key] = selected, [other.key] = other } },
        auras = selected.projectedAuras }
    Graph:Attach(out)
    return out
end

local source, observed, incomplete = state(), state(), state()
assert(source.hunterMarkRoot.lane.damageMultiplier == 1.1
    and source.hunterMarkRoot.lane.damageMultiplierUnits == "factor",
    "UnitRangedDamage's sixth return must be sealed as a multiplier factor")
local descriptor = { unit = "target", relation = "hostile",
    source = "selected", key = "selected-key", guid = "selected-guid",
    record = source.hostiles.byKey["selected-key"] }
local offTarget = { unit = "mouseover", relation = "hostile",
    source = "engaged", key = "other-key", guid = "other-guid",
    record = source.hostiles.byKey["other-key"] }

local savedDBC, savedDuration, savedRange, savedClass, savedRanged =
    GetSpellRecField, GetSpellDuration, GetSpellRangeData, UnitClass,
    UnitRangedDamage
GetSpellRecField = function() error("DBC read after root attachment") end
GetSpellDuration = function() error("duration read after root attachment") end
GetSpellRangeData = function() error("range read after root attachment") end
UnitClass = function() error("class read after root attachment") end
UnitRangedDamage = function() error("ranged stat read after root attachment") end

local blocker, exact = Graph:Blocker(markAction, source, descriptor, markFacts, 0)
assert(exact and blocker == nil,
    "an unmarked exact selected hostile must admit the Mark edge")
assert(Graph:Blocker(markAction, source, offTarget, markFacts, 0)
        == "Hunter's Mark requires the selected hostile",
    "Mark must never leak to an unselected hostile")
local score = { action = markAction, state = source,
    descriptor = descriptor, tooltip = markFacts, effectDelivery = 0.5 }
assert(Graph:Score(score) and score.value == 0 and score.power == 0
    and score.expectedPower == 0 and score.effectivePower == 0
    and score.hunterMarkDelivery == 0.5 and score.estimated
    and score.reason == "enables exact target-local ranged weapon damage",
    "Mark itself must receive no fixed utility or immediate damage")

local candidate = { action = markAction, tooltip = markFacts,
    target = "target", targetRelation = "hostile", targetSource = "selected",
    targetKey = "selected-key", targetGUID = "selected-guid",
    descriptor = descriptor, effectDelivery = 0.5 }
assert(Graph:Apply(source, candidate),
    "a valid uncertain Mark edge must project its target-local aura")
local aura = source.hostiles.byKey["selected-key"]
    .projectedAuras["hunterMark:1130"]
assert(aura and aura.spellId == 1130 and aura.remaining == 120
    and aura.applicationProbability == 0.5
    and aura.rangedAttackPowerBonus == 20 and source.refreshed == 1,
    "projection must retain exact rank, duration, recipient, and delivery")
local active, auraHandled = Graph:AuraActive(
    markAction, source, descriptor, markFacts, 0)
assert(auraHandled and not active,
    "a low-probability application must allow one safe retry")

local bonus, estimated = Graph:AutoShotBonus(source, "selected-guid")
assert(math.abs(bonus - 2.2) < 0.0001 and estimated,
    "Auto Shot must gain expected target RAP / 14 * current speed * multiplier")
local otherBonus, otherEstimated = Graph:AutoShotBonus(source, "other-guid")
assert(otherBonus == 0 and not otherEstimated,
    "Mark power must remain local to its exact hostile GUID")
local weaponBonus
weaponBonus, estimated = Graph:WeaponActionBonus(multiAction, multiFacts,
    source, "selected-guid", { exact = true, normalized = true,
        normalizedSpeed = 2.8 })
assert(math.abs(weaponBonus - 2.2) < 0.0001 and estimated,
    "normalized ranged weapon actions must use the sealed normalized speed")
assert(Graph:WeaponActionBonus(multiAction, multiFacts,
        source, "selected-guid", { exact = false, normalized = true,
            normalizedSpeed = 2.8 }) == nil,
    "an unproven normalized weapon lane must fail closed")
local halfBonus
halfBonus, estimated = Graph:WeaponActionBonus(halfAction, halfFacts,
    source, "selected-guid", {})
assert(math.abs(halfBonus - 2.2) < 0.0001 and estimated,
    "target-side RAP is added after the 0.5 weapon coefficient, not scaled by it")
local directBonus = Graph:WeaponActionBonus(arcaneAction, arcaneFacts,
    source, "selected-guid", {})
assert(directBonus == nil,
    "direct ranged spell damage must fail closed outside the Mark AP lane")

assert(Graph:Apply(source, candidate),
    "the sub-threshold Mark branch must accept a second delivery edge")
aura = source.hostiles.byKey["selected-key"]
    .projectedAuras["hunterMark:1130"]
assert(aura.applicationProbability == 0.75,
    "retries must combine success mass without adding the AP bonus twice")
active = Graph:AuraActive(markAction, source, descriptor, markFacts, 0)
assert(active and Graph:Blocker(markAction, source, descriptor, markFacts, 0)
        == "target already has Hunter's Mark",
    "the shared 0.75 threshold must suppress a likely active duplicate")
bonus, estimated = Graph:AutoShotBonus(source, "selected-guid")
assert(math.abs(bonus - 3.3) < 0.0001 and estimated,
    "combined delivery must change only expected target-local AP")

local observedRecord = observed.hostiles.byKey["selected-key"]
table.insert(observedRecord.harmfulAuras.list,
    { spellId = 14325, remaining = 90, duration = 120 })
local observedBonus
observedBonus, estimated = Graph:AutoShotBonus(observed, "selected-guid")
assert(math.abs(observedBonus - 24.2) < 0.0001 and not estimated,
    "another Hunter's numeric Mark must grant its exact shared rank benefit")
local observedDescriptor = { unit = "target", relation = "hostile",
    source = "selected", key = "selected-key", guid = "selected-guid",
    record = observedRecord }
assert(Graph:Blocker(markAction, observed, observedDescriptor, markFacts, 0)
        == "Hunter's Mark rank interaction is unresolved",
    "a different active rank must fail closed without overwrite assumptions")

local incompleteRecord = incomplete.hostiles.byKey["selected-key"]
table.insert(incompleteRecord.harmfulAuras.list,
    { spellId = nil, remaining = 20 })
local incompleteDescriptor = { unit = "target", relation = "hostile",
    source = "selected", key = "selected-key", guid = "selected-guid",
    record = incompleteRecord }
assert(Graph:Blocker(markAction, incomplete, incompleteDescriptor,
        markFacts, 0) == "numeric hostile aura evidence unavailable",
    "missing live aura identity must not be interpreted as an unmarked target")
assert(Graph:AutoShotBonus(incomplete, "selected-guid") == nil,
    "incomplete live aura evidence must not invent an AP bonus")

GetSpellRecField, GetSpellDuration, GetSpellRangeData, UnitClass,
    UnitRangedDamage = savedDBC, savedDuration, savedRange, savedClass,
    savedRanged
Runtime:Invalidate()
records[1130].effectApplyAuraName = triple(68, 124)
local beforeInvalid = reads
local invalid, invalidReason, invalidHandled = Runtime:Classify(1130)
assert(invalid and not invalid.valid and invalidHandled
    and invalidReason == "Hunter's Mark DBC topology is incomplete"
    and reads > beforeInvalid,
    "a recognized Mark identity with changed aura semantics must fail closed")
local afterInvalid = reads
local cachedInvalid, cachedReason, cachedHandled = Runtime:Classify(1130)
assert(cachedInvalid and not cachedInvalid.valid and cachedHandled
    and cachedReason == invalidReason and reads == afterInvalid,
    "cached invalid Mark evidence must remain handled without rereading DBC")

print("ok: Hunter's Mark is exact target-local ranged weapon AP")
