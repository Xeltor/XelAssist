XelAssist = { Game = { Player = {} }, Graph = {} }
table.getn = table.getn or function(value) return #value end

local classToken, exists, rank, maximum = "ROGUE", true, 3, 3
local talentID = 131
local rankSpell = { [1] = 14156, [2] = 14160, [3] = 14161 }
local dbcReads, talentReads = 0, 0

function UnitClass() return "Rogue", classToken end
function UnitExists() return exists end
function GetTalentIDByIndex(tab, index)
    talentReads = talentReads + 1
    assert(tab == 1 and index == 4)
    return talentID
end
function GetTalentInfo(tab, index)
    talentReads = talentReads + 1
    assert(tab == 1 and index == 4)
    return nil, nil, 2, 1, rank, maximum
end
function GetTalentSpellID(tab, index, requested)
    talentReads = talentReads + 1
    assert(tab == 1 and index == 4 and requested == rank)
    return rankSpell[requested]
end

local ZERO = { 0, 0, 0 }
local function row(chance, target)
    return {
        school = 0, attributes = 464, attributesEx = 0,
        attributesEx2 = 0, attributesEx3 = 0, attributesEx4 = 0,
        procFlags = 87376, procChance = chance, procCharges = 0,
        durationIndex = 21, powerType = 0, manaCost = 0, rangeIndex = 1,
        spellFamilyName = 8, spellFamilyFlags = 0,
        effect = { 6, 0, 0 }, effectDieSides = { 1, 0, 0 },
        effectBaseDice = { 1, 0, 0 }, effectBasePoints = { -1, 0, 0 },
        effectDicePerLevel = ZERO, effectRealPointsPerLevel = ZERO,
        effectImplicitTargetA = { target, 0, 0 },
        effectImplicitTargetB = ZERO, effectApplyAuraName = { 42, 0, 0 },
        effectItemType = { 4063232, 0, 0 },
        effectTriggerSpell = { 14157, 0, 0 }, effectMechanic = ZERO,
        effectRadiusIndex = ZERO, effectAmplitude = ZERO,
        effectMultipleValue = ZERO, effectChainTarget = ZERO,
        effectMiscValue = ZERO, effectPointsPerComboPoint = ZERO,
        dmgMultiplier = { 1, 0, 0 },
    }
end

local records = {
    [14156] = row(33, 6), [14160] = row(66, 6), [14161] = row(100, 1),
    [14157] = { attributes = 16, attributesEx = 1024,
        durationIndex = 0, rangeIndex = 2, spellFamilyName = 0,
        spellFamilyFlags = 0, effect = { 80, 0, 0 },
        effectDieSides = { 1, 0, 0 }, effectBaseDice = { 1, 0, 0 },
        effectDicePerLevel = ZERO, effectRealPointsPerLevel = ZERO,
        effectBasePoints = ZERO, effectImplicitTargetA = { 6, 0, 0 },
        effectImplicitTargetB = ZERO, effectApplyAuraName = ZERO,
        effectAmplitude = ZERO, effectMultipleValue = ZERO,
        effectChainTarget = ZERO, effectItemType = ZERO,
        effectMiscValue = ZERO, effectTriggerSpell = ZERO,
        effectPointsPerComboPoint = ZERO, dmgMultiplier = { 1, 0, 0 } },
    [2098] = { spellFamilyName = 8, spellFamilyFlags = 8519680,
        attributes = 327696, attributesEx = 1049088, powerType = 3 },
    [5171] = { spellFamilyName = 8, spellFamilyFlags = 262144,
        attributes = 537198608, attributesEx = 4195328, powerType = 3 },
    [1752] = { spellFamilyName = 8, spellFamilyFlags = 64,
        attributes = 327696, attributesEx = 134218240, powerType = 3 },
}

function GetSpellRecField(spellId, field, copied)
    dbcReads = dbcReads + 1
    local value = records[spellId] and records[spellId][field]
    if type(value) == "table" then
        assert(copied == 1)
        return { value[1], value[2], value[3] }
    end
    return value
end

dofile("Game/Player/RogueRuthlessness.lua")
local Runtime = XelAssist.Game.Player.RogueRuthlessness

local snapshot = Runtime:Snapshot()
assert(snapshot.available and snapshot.exact and snapshot.active
    and snapshot.rank == 3 and snapshot.spellId == 14161
    and snapshot.chancePercent == 100 and snapshot.comboGain == 1
    and snapshot.triggerSpellId == 14157,
    "rank three must seal the installed guaranteed combo trigger")

rank = 2
snapshot = Runtime:Snapshot()
assert(snapshot.available and snapshot.exact and snapshot.active
    and snapshot.spellId == 14160 and snapshot.chancePercent == 66,
    "rank two must retain the installed 66 percent probability")

rank = 0
snapshot = Runtime:Snapshot()
assert(snapshot.available and snapshot.exact and not snapshot.active
    and snapshot.rank == 0 and snapshot.chancePercent == 0,
    "an exact unallocated talent must preserve the generic combo transition")

rank = 3
local action = { spellId = 2098 }
local facts = Runtime:CaptureFacts(action, { kind = "damage", combo = true })
assert(facts.rogueRuthlessnessFinisher
    and facts.rogueRuthlessnessFinisherEvidence.exact
    and facts.rogueRuthlessnessFinisherEvidence.familyFlags == 8519680,
    "the installed finisher mask must be sealed without a localized name")
local builder = Runtime:CaptureFacts({ spellId = 1752 },
    { kind = "builder", comboBuilder = true })
assert(not builder.rogueRuthlessnessFinisher,
    "a builder outside the proc mask must remain unclaimed")
local selfFinisherFacts = Runtime:CaptureFacts({ spellId = 5171 },
    { kind = "buff", self = true, combo = true, comboSpendAll = true })
assert(selfFinisherFacts.rogueRuthlessnessFinisher,
    "a self-recipient finisher must retain its hostile combo owner")

talentID = 999
assert(not Runtime:Snapshot().available,
    "a shifted Talent.dbc identity must fail closed")
talentID = 131

dofile("Graph/ComboState.lua")
dofile("Graph/RogueRuthlessness.lua")
local Combo, Graph = XelAssist.Graph.ComboState,
    XelAssist.Graph.RogueRuthlessness

rank = 3
local state = { targetGUID = "target-a" }
assert(Graph:Attach(state) and state.rogueRuthlessness.active)
Combo:Attach(state, 5, "target-a", { selectedExact = true,
    globalExact = true, source = "test exact combo owner" })

local liveReads = dbcReads + talentReads
GetSpellRecField = function() error("graph search read mutable DBC") end
GetTalentInfo = function() error("graph search read mutable talent") end
GetTalentIDByIndex = GetTalentInfo
GetTalentSpellID = GetTalentInfo

local function probability(value, guid, points)
    local index
    for index = 1, table.getn(value.comboBranches or {}) do
        local branch = value.comboBranches[index]
        if branch.targetGUID == guid and branch.points == points then
            return branch.probability
        end
    end
    return 0
end

local candidate = { action = { spellId = 2098, facts = facts },
    targetGUID = "target-a", targetRelation = "hostile",
    comboTargetGUID = "target-a", comboAllOwners = false,
    resistance = { landChance = 0.75 }, tooltip = { comboSpendAll = true } }
assert(Graph:Apply(state, candidate)
    and math.abs(probability(state, "target-a", 5) - 0.25) < 0.0001
    and math.abs(probability(state, "target-a", 1) - 0.75) < 0.0001
    and probability(state, nil, 0) == 0
    and math.abs(state.combo - 2) < 0.0001
    and state.rogueRuthlessnessTransition.expectedComboGain == 0.75,
    "a miss must retain five points while a landed rank-three finisher adds one")
assert(liveReads == dbcReads + talentReads,
    "the graph transition must consume only sealed root evidence")

local copied = {}
assert(Graph:Copy(state, copied)
    and copied.rogueRuthlessness ~= state.rogueRuthlessness
    and copied.rogueRuthlessnessTransition
        ~= state.rogueRuthlessnessTransition,
    "branch copies must not share mutable Ruthlessness state")

GetSpellRecField = nil
Runtime:Invalidate()
-- Reinstall only the root DBC fixture after proving the search boundary.
GetSpellRecField = function(spellId, field, copiedFlag)
    dbcReads = dbcReads + 1
    local value = records[spellId] and records[spellId][field]
    if type(value) == "table" then
        assert(copiedFlag == 1); return { value[1], value[2], value[3] }
    end
    return value
end
GetTalentIDByIndex = function() return 131 end
GetTalentInfo = function() return nil, nil, 2, 1, 2, 3 end
GetTalentSpellID = function() return 14160 end

local rankTwo = { targetGUID = "target-a" }
assert(Graph:Attach(rankTwo))
Combo:Attach(rankTwo, 5, "target-a", { selectedExact = true,
    globalExact = true, source = "test exact combo owner" })
assert(Graph:Apply(rankTwo, candidate)
    and math.abs(probability(rankTwo, "target-a", 5) - 0.25) < 0.0001
    and math.abs(probability(rankTwo, "target-a", 1) - 0.495) < 0.0001
    and math.abs(probability(rankTwo, nil, 0) - 0.255) < 0.0001,
    "rank two must split miss, proc, and landed-no-proc branches exactly")

local split = { targetGUID = "target-a" }
assert(Graph:Attach(split))
split.comboBranches = {
    { targetGUID = "target-a", points = 3, probability = 0.4 },
    { targetGUID = "target-b", points = 2, probability = 0.6 },
}
split.comboProjected, split.comboObservedPoints = true, nil
Combo:Refresh(split)
local selfCandidate = { action = { spellId = 5171,
        facts = selfFinisherFacts },
    targetGUID = "player-guid", targetRelation = "self",
    comboAllOwners = true, tooltip = { comboSpendAll = true } }
assert(Graph:Apply(split, selfCandidate)
    and math.abs(probability(split, "target-a", 1) - 0.264) < 0.0001
    and math.abs(probability(split, "target-b", 1) - 0.396) < 0.0001
    and math.abs(probability(split, nil, 0) - 0.34) < 0.0001,
    "a self finisher must proc on each probability branch's hostile owner")

local lethal = { targetGUID = "target-a", targetHealth = 0,
    targetHealthExact = true }
assert(Graph:Attach(lethal))
Combo:Attach(lethal, 5, "target-a", { selectedExact = true,
    globalExact = true, source = "test exact combo owner" })
assert(Graph:Apply(lethal, candidate)
    and probability(lethal, "target-a", 1) == 0
    and math.abs(probability(lethal, nil, 0) - 0.75) < 0.0001
    and lethal.rogueRuthlessnessTransition.targetDefeated,
    "a proven lethal finisher must not invent a combo point on a dead target")

local unknown = { targetGUID = "target-a" }
assert(Graph:Attach(unknown))
Combo:Attach(unknown, 5, "target-a", { selectedExact = true,
    globalExact = true, source = "test exact combo owner" })
local uncertain = {}
for key, value in pairs(candidate) do uncertain[key] = value end
uncertain.resistance = { unknown = true }
assert(not Graph:Apply(unknown, uncertain)
    and Combo:Apply(unknown, uncertain, uncertain.action.facts)
    and unknown.comboTransitionUnknown,
    "unknown delivery must fall through to the generic fail-closed transition")

print("ok: exact Ruthlessness creates target-owned post-finisher combo branches")
