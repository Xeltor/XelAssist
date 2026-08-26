-- Exact Frenzied Regeneration root sealing, first-tick value, and timeline.
XelAssist = { Game = { Player = {} }, Graph = {} }
table.getn = table.getn or function(value) return #value end

local function triple(first, second, third)
    return { first or 0, second or 0, third or 0 }
end

local rankData = {
    [22842] = { rank = 1, level = 36, life = 6 },
    [22895] = { rank = 2, level = 46, life = 7 },
    [22896] = { rank = 3, level = 56, life = 8 },
}
local rows = {}
local spellId, rank
for spellId, rank in pairs(rankData) do
    rows[spellId] = {
        school = 0, category = 1011, attributes = 262160,
        attributesEx = 0, attributesEx2 = 0, attributesEx3 = 0,
        attributesEx4 = 0, stances = 144, stancesNot = 0,
        castingTimeIndex = 1, categoryRecoveryTime = 300000,
        durationIndex = 1, powerType = 1, manaCost = 0,
        manaCostPerlevel = 0, manaCostPercentage = 0, rangeIndex = 1,
        startRecoveryCategory = 133, startRecoveryTime = 1500,
        spellFamilyName = 7, spellFamilyFlags = 4398046511104,
        maxAffectedTargets = 0, dmgClass = 0, preventionType = 2,
        baseLevel = rank.level, spellLevel = rank.level,
        effect = triple(6), effectDieSides = triple(1),
        effectBaseDice = triple(1), effectDicePerLevel = triple(),
        effectRealPointsPerLevel = triple(),
        effectBasePoints = triple(rank.life - 1),
        effectImplicitTargetA = triple(1), effectImplicitTargetB = triple(),
        effectApplyAuraName = triple(23), effectAmplitude = triple(1000),
        effectTriggerSpell = triple(), effectMiscValue = triple(),
        effectPointsPerComboPoint = triple(),
    }
end
rows[22845] = {
    school = 0, category = 0, attributes = 262160,
    attributesEx = 0, attributesEx2 = 268435456,
    attributesEx3 = 0, attributesEx4 = 0, castingTimeIndex = 1,
    durationIndex = 0, powerType = 0, rangeIndex = 1,
    equippedItemClass = -1, spellFamilyName = 0, spellFamilyFlags = 0,
    dmgClass = 0, preventionType = 0, effect = triple(10),
    effectDieSides = triple(1), effectBaseDice = triple(1),
    effectBasePoints = triple(), effectImplicitTargetA = triple(1),
    effectImplicitTargetB = triple(), effectApplyAuraName = triple(),
    effectTriggerSpell = triple(),
}
rows[90001] = { effectApplyAuraName = triple(118) }
rows[90002] = { effectApplyAuraName = triple(136) }

local dbcCalls, modifierCalls, auraList = 0, 0, {}
function GetSpellRecField(id, field, copied)
    dbcCalls = dbcCalls + 1
    local row = rows[id]
    if not row or row[field] == nil then error("missing DBC fixture field") end
    local value = row[field]
    if copied and type(value) == "table" then
        return { value[1], value[2], value[3] }
    end
    return value
end

local playerClass, modifierDirty = "DRUID", false
UnitClass = function() return "Druid", playerClass end
GetSpellDuration = function(id, base)
    assert(rankData[id], "duration requested for unexpected spell")
    return 10000
end
GetSpellModifiers = function(id, operation)
    modifierCalls = modifierCalls + 1
    assert(rankData[id] and (operation == 8 or operation == 19)
        or id == 22845 and (operation == 8 or operation == 0),
        "unexpected modifier contract")
    return modifierDirty and 1 or 0, 0, 0
end

local activeAuras, now = {}, 100
C_UnitAuras = {
    GetUnitAuras = function(unit, filter)
        assert(unit == "player" and filter == nil)
        return auraList
    end,
    GetPlayerAuraBySpellID = function(id) return activeAuras[id] end,
}
GetTime = function() return now end
GetSpellInfo = function() error("localized names must not select FR") end
GetSpellName = GetSpellInfo

dofile("Game/Player/DruidFrenziedRegeneration.lua")
local Runtime = XelAssist.Game.Player.DruidFrenziedRegeneration

local actions, profiles = {}, {}
assert(rows[22842].spellFamilyFlags == 4398046511104
    and rows[22842].spellFamilyFlags > 4294967295,
    "the installed Druid family flag fixture must exercise the 64-bit-safe path")
for spellId, rank in pairs(rankData) do
    local facts, reason, handled = Runtime:InferKnowledge(spellId)
    assert(handled and not reason and facts.kind == "heal"
        and facts.druidFrenziedRegeneration
        and facts.runtimeUnverified == true
        and facts.druidFrenziedRegenerationEvidence.lifePerRage == rank.life,
        "every installed rank must infer from numeric topology: "
            .. tostring(reason))
    actions[spellId] = { spellId = spellId, actor = "player",
        executor = "playerSpell", facts = facts }
    profiles[spellId] = Runtime:CaptureFacts(actions[spellId], {})
    assert(Runtime:CapturedEvidence(profiles[spellId])
        and profiles[spellId].cost == 0
        and profiles[spellId].powerType == 1
        and profiles[spellId].duration == 10,
        "clean root evidence must seal each rank")
end
assert(modifierCalls == 12,
    "each rank must validate main and hidden spell modifiers")
local cachedCalls = dbcCalls
assert(Runtime:InferKnowledge(22842) and dbcCalls == cachedCalls,
    "installed topology must be immutable and cached")
local noFacts, _, handled = Runtime:InferKnowledge(123)
assert(not noFacts and handled == false,
    "unrelated spells must remain outside the mechanic")
playerClass = "MAGE"
local wrong, _, wrongHandled = Runtime:InferKnowledge(22842)
assert(not wrong and wrongHandled == false,
    "an exact non-Druid class must not claim the action")
playerClass = "DRUID"

modifierDirty = true
local dirtyModifier = Runtime:CaptureFacts(actions[22842], {})
assert(dirtyModifier.druidFrenziedRegenerationEvidence.exact == false,
    "modified healing magnitude must fail closed")
modifierDirty = false
auraList = { { spellId = 90001 } }
local dirtyHealing = Runtime:CaptureFacts(actions[22842], {})
assert(dirtyHealing.druidFrenziedRegenerationEvidence.exact == false,
    "active healing-taken multipliers must fail closed")
auraList = { { spellId = 90002 } }
dirtyHealing = Runtime:CaptureFacts(actions[22842], {})
assert(dirtyHealing.druidFrenziedRegenerationEvidence.exact == false,
    "active healing-done multipliers must fail closed")
auraList = {}
profiles[22842] = Runtime:CaptureFacts(actions[22842], {})
local seed = { preserved = true }
local copiedFacts = Runtime:CaptureFacts(actions[22842], seed)
assert(copiedFacts ~= seed and copiedFacts.preserved and seed.cost == nil
    and seed.druidFrenziedRegenerationEvidence == nil,
    "root capture must not mutate the supplied fact table")

local inactive = Runtime:Snapshot("DRUID")
assert(inactive.available and inactive.exact and inactive.active == false,
    "no numeric aura must be an exact inactive root")
activeAuras[22842] = { spellId = 22842, isHelpful = true,
    applications = 1, duration = 10, expirationTime = 106 }
local live = Runtime:Snapshot("DRUID")
assert(live.active and live.exact == false and live.phaseKnown == false
    and live.reason == "active Frenzied Regeneration tick phase unavailable",
    "an already-active aura must fail closed without tick phase")
activeAuras[22842] = nil

Runtime:Invalidate()
rows[22842].effectAmplitude = triple(999)
local malformed, malformedReason, malformedHandled =
    Runtime:InferKnowledge(22842)
assert(not malformed and malformedHandled
    and malformedReason == "Frenzied Regeneration DBC topology is incomplete",
    "recognized DBC drift must be claimed and blocked")
rows[22842].effectAmplitude = triple(1000)
Runtime:Invalidate()
local rebuilt = Runtime:InferKnowledge(22842)
actions[22842].facts = rebuilt
profiles[22842] = Runtime:CaptureFacts(actions[22842], {})
inactive = Runtime:Snapshot("DRUID")

dofile("Graph/DruidFrenziedRegeneration.lua")
local Graph = XelAssist.Graph.DruidFrenziedRegeneration
XelAssist.Game.SpellClassification = {
    NormalGcd = function() return true end,
}
dofile("Graph/ActionAdmission.lua")
local Admission = XelAssist.Graph.ActionAdmission

local function state(resource, health, formID)
    local guid, playerKey = {}, {}
    local actor = { guid = guid, health = health, healthMax = 1000,
        resource = resource, resourceMax = 100 }
    local friendly = { key = playerKey, guid = guid, unit = "player",
        health = health, healthMax = 1000, exact = true }
    return { time = 0, resource = resource, resourceMax = 100,
        resourceType = (formID == 5 or formID == 8) and 1 or 0,
        playerResourceExact = true, health = health, healthMax = 1000,
        healHealth = health, healMax = 1000, inCombat = true,
        targetPlayerThreatDeltaExact = true,
        actors = { player = actor },
        friendlies = { order = { playerKey }, primaryKey = playerKey,
            byUnit = { player = playerKey }, byKey = { [playerKey] = friendly } },
        hostiles = { order = { "one" }, byKey = { one = {
            dead = false, threat = { playerDeltaExact = true } } } },
        druidFormState = { available = true, formID = formID },
        druidFrenziedRegeneration = { available = true, exact = true,
            active = false, phaseKnown = nil, source = "inactive root" },
    }
end

local descriptor = function(s)
    return { unit = "player", relation = "self",
        guid = s.actors.player.guid }
end
local root = state(33, 500, 5)
local prepared, reason, claimed = Graph:Prepare(
    actions[22842], root, descriptor(root), profiles[22842])
assert(claimed and not reason and prepared.classMechanic
    == "druidFrenziedRegeneration"
    and prepared.druidFrenziedRegenerationTransition.lifePerRage == 6,
    "an exact Bear self-recipient must prepare the lifecycle: "
        .. tostring(reason))

local projection = { classMechanic = "druidFrenziedRegeneration",
    druidFrenziedRegenerationTransition =
        prepared.druidFrenziedRegenerationTransition }
local cast, _, gcd, _, cycle, occupancy =
    Admission:Timing(actions[22842], root, prepared)
assert(cast == 0 and gcd == 1.5 and cycle == 1.5 and occupancy == 0.05,
    "the integration fixture must retain real instant-action admission timing")
local context = { state = root, wait = 0, cast = cast,
    downtime = cycle, advanceDowntime = occupancy,
    action = actions[22842],
    tooltip = prepared, cost = 0, facts = actions[22842].facts }
assert(Graph:Score(context, projection)
    and context.power == 60 and context.effectivePower == 60
    and context.value > 0 and context.estimated == true
    and context.classMechanicOwnsKindScore == true,
    "only the exact reachable first tick may provide direct healing value")

dofile("Graph/ClassEvidence.lua")
dofile("Graph/ClassState.lua")
dofile("Graph/ClassActionMechanics.lua")
dofile("Graph/ClassMechanics.lua")
local Mechanics = XelAssist.Graph.ClassMechanics
local integratedState = state(20, 600, 5)
local integrated, integratedReason, integratedHandled = Mechanics:Prepare(
    actions[22842], integratedState, descriptor(integratedState),
    profiles[22842])
local integratedContext = { state = integratedState, wait = 0, cast = 0,
    downtime = 1.5, advanceDowntime = 0.05,
    action = actions[22842], tooltip = integrated,
    cost = 0, facts = actions[22842].facts }
assert(integrated and integratedHandled and integratedReason == nil
    and Mechanics:Score(integratedContext, integrated)
    and integratedContext.classMechanicOwnsKindScore == true,
    "the production class boundary must preserve exact first-tick ownership")
assert(Mechanics:Apply(integratedState, {
        action = actions[22842], tooltip = integrated,
        classMechanicProjection = integrated,
    }) and Mechanics:Advance(integratedState, 1) == 0
    and integratedState.resource == 10 and integratedState.health == 660,
    "the production class boundary must apply and advance the exact lifecycle")
context.wait, context.advanceDowntime = 0.1, 0.15
local scored, scoreReason = Graph:Score(context, projection)
assert(not scored and scoreReason == "rage before the first tick is unresolved",
    "resource-changing waits must fail closed")

local candidate = { action = actions[22842], tooltip = prepared,
    classMechanicProjection = projection }
assert(Graph:Apply(root, candidate), "application must arm a fresh one-second phase")
assert(root.health == 500 and Graph:Advance(root, occupancy)
    and root.health == 500 and root.resource == 33,
    "the scored future tick must not be applied again at activation")
assert(Graph:Advance(root, 0.45)
    and root.resource == 33 and root.health == 500,
    "a partial period must not heal or spend rage")
assert(Graph:Advance(root, 0.5)
    and root.resource == 23 and root.health == 560
    and root.actors.player.health == 560
    and root.friendlies.byKey[root.friendlies.primaryKey].health == 560,
    "the first tick must spend ten displayed rage and heal rank-scaled health")
assert(root.hostiles.byKey.one.threat.playerDeltaExact == false
    and root.targetPlayerThreatDeltaExact == false,
    "hidden hostile-reference fanout must invalidate healing-threat exactness")
assert(Graph:Advance(root, 2) and root.resource == 3 and root.health == 680,
    "later exact periods must continue the causal conversion")
assert(Graph:Advance(root, 1) and root.resource == 0 and root.health == 698
    and root.druidFrenziedRegeneration.lastTick.rageSpent == 3,
    "the server's final partial-rage conversion must be retained")
assert(Graph:Advance(root, 6)
    and root.druidFrenziedRegeneration.active == false
    and root.druidFrenziedRegeneration.lastAdvance.ticks == 6,
    "the expiry boundary must retain the tenth periodic tick")

local casterExit = state(20, 500, 5)
assert(Graph:Apply(casterExit, candidate))
local exit = { sourceForm = 5, targetForm = 0 }
assert(Graph:FormBlocker(casterExit, exit) == nil
    and Graph:AfterForm(casterExit, exit))
casterExit.druidFormState.formID, casterExit.resourceType = 0, 0
casterExit.resource, casterExit.actors.player.resource = 777, 777
assert(Graph:Advance(casterExit, 1) and casterExit.resource == 777
    and casterExit.health == 500,
    "leaving Bear must make future ticks consume zero hidden rage, not mana")
local reentry = { sourceForm = 0, targetForm = 5 }
local formReason, formHandled = Graph:FormBlocker(casterExit, reentry)
assert(formHandled and formReason
    == "active Frenzied Regeneration destination rage unavailable",
    "an active aura must not invent destination rage on Bear re-entry")

local noRage = state(0, 500, 5)
assert(select(2, Graph:Prepare(actions[22842], noRage,
    descriptor(noRage), profiles[22842])) == "no rage to convert")
local full = state(30, 1000, 5)
assert(select(2, Graph:Prepare(actions[22842], full,
    descriptor(full), profiles[22842])) == "no exact missing player health")
local caster = state(30, 500, 0)
assert(select(2, Graph:Prepare(actions[22842], caster,
    descriptor(caster), profiles[22842]))
        == "exact Bear rage and health state unavailable")

local unresolved = state(30, 500, 5)
unresolved.druidFrenziedRegeneration = { active = true,
    available = false, exact = false, phaseKnown = false,
    reason = "active Frenzied Regeneration tick phase unavailable" }
assert(Graph:RootBlocker(unresolved)
    == "active Frenzied Regeneration tick phase unavailable",
    "live unknown periodic phase must block every graph action")

-- Root evidence is now sealed: branch work must not call any mutable API.
GetSpellRecField = function() error("graph search reread DBC") end
GetSpellDuration = function() error("graph search reread duration") end
GetSpellModifiers = function() error("graph search reread modifiers") end
C_UnitAuras.GetUnitAuras = function() error("graph search reread auras") end
C_UnitAuras.GetPlayerAuraBySpellID = function()
    error("graph search reread active aura")
end
UnitClass = function() error("graph search reread class") end
GetTime = function() error("graph search reread clock") end

local pure = state(10, 900, 8)
prepared = assert(Graph:Prepare(actions[22842], pure,
    descriptor(pure), profiles[22842]))
projection.druidFrenziedRegenerationTransition =
    prepared.druidFrenziedRegenerationTransition
context = { state = pure, wait = 0, cast = 0,
    downtime = 1.5, advanceDowntime = 0.05 }
assert(Graph:Score(context, projection)
    and Graph:Apply(pure, { action = actions[22842], tooltip = prepared,
        classMechanicProjection = projection })
    and Graph:Advance(pure, 1) and pure.health == 960,
    "prepare, score, apply, and advance must remain search API-pure")

print("druid_frenzied_regeneration_test: ok")
