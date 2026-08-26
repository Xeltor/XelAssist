-- Installed Cat passive and search-pure form consequence. Localized names and
-- typed rotation knowledge are intentionally unavailable.
XelAssist = { Game = { Player = {} }, Graph = {} }
table.getn = table.getn or function(value)
    local count = 0
    while value[count + 1] ~= nil do count = count + 1 end
    return count
end

local function triple(first, second, third)
    return { first or 0, second or 0, third or 0 }
end

local record = {
    school = 3, category = 0, mechanic = 0, attributes = 208,
    attributesEx = 0, attributesEx2 = 0, attributesEx3 = 0,
    attributesEx4 = 0, stances = 1, stancesNot = 0, targets = 0,
    castingTimeIndex = 1, procFlags = 0, procChance = 101,
    procCharges = 0, baseLevel = 20, spellLevel = 20,
    durationIndex = 21, powerType = 0, manaCost = 0, rangeIndex = 1,
    startRecoveryCategory = 0, startRecoveryTime = 0,
    spellFamilyName = 7, spellFamilyFlags = 134217728,
    dmgClass = 0, preventionType = 0,
    effect = triple(6, 6), effectDieSides = triple(1, 1),
    effectBaseDice = triple(1, 1), effectDicePerLevel = triple(),
    effectRealPointsPerLevel = triple(),
    effectBasePoints = triple(39, -30), effectMechanic = triple(),
    effectImplicitTargetA = triple(1, 1),
    effectImplicitTargetB = triple(), effectRadiusIndex = triple(),
    effectApplyAuraName = triple(99, 10), effectAmplitude = triple(),
    effectMultipleValue = triple(), effectChainTarget = triple(),
    effectItemType = triple(), effectMiscValue = triple(0, 127),
    effectTriggerSpell = triple(), effectPointsPerComboPoint = triple(),
}

local dbcCalls = 0
GetSpellRecField = function(spellId, field, copied)
    dbcCalls = dbcCalls + 1
    assert(spellId == 3025)
    local value = record[field]
    if copied and type(value) == "table" then
        return { value[1], value[2], value[3] }
    end
    return value
end
GetSpellName = function()
    error("Cat threat evidence must not inspect localized names")
end
local classToken = "DRUID"
UnitClass = function(unit)
    assert(unit == "player")
    return "localized class", classToken
end

dofile("Game/Player/DruidCatThreat.lua")
local Evidence = XelAssist.Game.Player.DruidCatThreat
local profile = Evidence:Snapshot()
assert(profile.available and profile.valid and profile.exact
    and profile.passiveSpellId == 3025 and profile.family == 7
    and profile.catForm == 1 and profile.schoolMask == 127
    and profile.percent == -29 and profile.multiplier == 0.71,
    "the exact passive must expose build-5875's -29% Cat threat")
assert(Evidence:IsCatForm(1) and not Evidence:IsCatForm(5)
    and not Evidence:IsCatForm("1"),
    "only exact numeric Cat form ID 1 may activate the passive")

local beforeCache = dbcCalls
assert(Evidence:Profile().multiplier == 0.71 and dbcCalls == beforeCache,
    "installed passive topology must be cached")
record.effectBasePoints[2] = -31
Evidence:Invalidate()
local malformed = Evidence:Snapshot()
assert(not malformed.available and not malformed.exact
    and string.find(malformed.reason or "", "incomplete", 1, true),
    "a changed negative threat payload must fail the topology closed")
record.effectBasePoints[2] = -30
record.effectMiscValue[2] = 126
Evidence:Invalidate()
assert(not Evidence:Snapshot().available,
    "a non-all-school payload must not inherit Cat threat semantics")
record.effectMiscValue[2] = 127
Evidence:Invalidate()
profile = Evidence:Snapshot()
classToken = "ROGUE"
assert(not Evidence:Snapshot().available,
    "another melee class must never inherit Druid form threat")
classToken = "DRUID"

XelAssist.Game.Player.DruidFormState = { FORMS = {
    [0] = {}, [1] = {}, [2] = {}, [3] = {}, [4] = {}, [5] = {},
    [8] = {}, [9] = {}, [11] = {}, [31] = {},
} }
dofile("Graph/DruidCatThreat.lua")
local Graph = XelAssist.Graph.DruidCatThreat
local function state(formID)
    return { druidFormState = { available = true, formID = formID } }
end

local caster = state(0)
assert(Graph:Attach(caster) and caster.druidCatThreat.exact
    and caster.druidCatThreat.multiplier == 1
    and not caster.druidCatThreat.active,
    "caster form must seal a neutral exact Cat component")
local base, exact, component = Graph:Resolve(caster, "player", 1.2, true)
assert(base == 1.2 and exact and component == caster.druidCatThreat,
    "neutral caster form must preserve earlier threat factors")
assert(Graph:Resolve(caster, "pet", 1.2, true) == 1.2,
    "pet threat must bypass the player Cat form component")

local cat = state(1)
assert(Graph:Attach(cat) and cat.druidCatThreat.active
    and cat.druidCatThreat.multiplier == 0.71,
    "exact Cat form must activate the passive at the root")
base, exact = Graph:Resolve(cat, "player", 1.3, true)
assert(math.abs(base - 0.923) < 0.000001 and exact,
    "Cat threat must compose after an existing player threat factor")

local branch = state(0)
assert(Graph:Copy(cat, branch)
    and branch.druidCatThreat ~= cat.druidCatThreat
    and branch.druidCatThreat.profile ~= cat.druidCatThreat.profile
    and branch.druidCatThreat.multiplier == 1,
    "copy must reconcile the isolated component to the branch form")

local callsBeforeSearch = dbcCalls
GetSpellRecField = function()
    error("graph descendant reread installed spell topology")
end
UnitClass = function()
    error("graph descendant reread live class identity")
end
branch.druidFormState.formID = 1
assert(Graph:AfterForm(branch) and branch.druidCatThreat.projected
    and branch.druidCatThreat.active
    and branch.druidCatThreat.multiplier == 0.71,
    "an applied Cat transition must activate branch-local threat")
base, exact = Graph:Resolve(branch, "player", 1, true)
assert(base == 0.71 and exact and dbcCalls == callsBeforeSearch,
    "projected Cat threat must remain search-pure")

branch.druidFormState.formID = 5
assert(Graph:AfterForm(branch) and not branch.druidCatThreat.active
    and branch.druidCatThreat.multiplier == 1,
    "a later Bear transition must remove Cat threat exactly")
branch.druidCatThreat.formID = 1
base, exact = Graph:Resolve(branch, "player", 1, true)
assert(base == 1 and exact == false,
    "a stale form/component identity must fail closed")
local unknown = state(7)
unknown.druidCatThreat = { profile = profile }
assert(not Graph:AfterForm(unknown),
    "an unrecognized form ID must not receive a neutral Cat multiplier")

print("ok: Druid Cat threat is exact, branch-local, and search-pure")
