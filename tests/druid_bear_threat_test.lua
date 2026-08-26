-- Installed Bear passive and search-pure form consequence. Localized names
-- and typed rotation knowledge are intentionally unavailable.
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
    school = 3, category = 0, mechanic = 0, attributes = 464,
    attributesEx = 0, attributesEx2 = 0, attributesEx3 = 0,
    attributesEx4 = 0, stances = 0, stancesNot = 0, targets = 0,
    castingTimeIndex = 1, procFlags = 0, procChance = 101,
    procCharges = 0, baseLevel = 1, spellLevel = 1,
    durationIndex = 21, powerType = 0, manaCost = 0, rangeIndex = 1,
    startRecoveryCategory = 0, startRecoveryTime = 0,
    spellFamilyName = 7, spellFamilyFlags = 33554432,
    dmgClass = 0, preventionType = 0,
    effect = triple(6), effectDieSides = triple(1),
    effectBaseDice = triple(1), effectDicePerLevel = triple(),
    effectRealPointsPerLevel = triple(), effectBasePoints = triple(29),
    effectMechanic = triple(), effectImplicitTargetA = triple(1),
    effectImplicitTargetB = triple(), effectRadiusIndex = triple(),
    effectApplyAuraName = triple(10), effectAmplitude = triple(),
    effectMultipleValue = triple(), effectChainTarget = triple(),
    effectItemType = triple(), effectMiscValue = triple(127),
    effectTriggerSpell = triple(), effectPointsPerComboPoint = triple(),
}

local dbcCalls = 0
GetSpellRecField = function(spellId, field, copied)
    dbcCalls = dbcCalls + 1
    assert(spellId == 21178)
    local value = record[field]
    if copied and type(value) == "table" then
        return { value[1], value[2], value[3] }
    end
    return value
end
GetSpellName = function()
    error("Bear threat evidence must not inspect localized names")
end
local classToken = "DRUID"
UnitClass = function(unit)
    assert(unit == "player")
    return "localized class", classToken
end

dofile("Game/Player/DruidBearThreat.lua")
local Evidence = XelAssist.Game.Player.DruidBearThreat
local profile = Evidence:Snapshot()
assert(profile.available and profile.valid and profile.exact
    and profile.passiveSpellId == 21178 and profile.family == 7
    and profile.bearForm == 5 and profile.direBearForm == 8
    and profile.schoolMask == 127 and profile.percent == 30
    and profile.multiplier == 1.30,
    "the exact passive must expose +30% all-school Bear threat")
assert(Evidence:IsBearForm(5) and Evidence:IsBearForm(8)
    and not Evidence:IsBearForm(1) and not Evidence:IsBearForm("5"),
    "only exact numeric Bear and Dire Bear form IDs may activate the passive")

local beforeCache = dbcCalls
assert(Evidence:Profile().multiplier == 1.30 and dbcCalls == beforeCache,
    "installed passive topology must be cached")
record.effectBasePoints[1] = 30
Evidence:Invalidate()
local malformed = Evidence:Snapshot()
assert(not malformed.available and not malformed.exact
    and string.find(malformed.reason or "", "incomplete", 1, true),
    "a changed threat payload must fail the full topology closed")
record.effectBasePoints[1] = 29
record.effectMiscValue[1] = 126
Evidence:Invalidate()
assert(not Evidence:Snapshot().available,
    "a non-all-school modifier must not inherit Bear threat semantics")
record.effectMiscValue[1] = 127
Evidence:Invalidate()
profile = Evidence:Snapshot()
classToken = "WARRIOR"
assert(not Evidence:Snapshot().available,
    "another tank class must never inherit Druid form threat")
classToken = "DRUID"

XelAssist.Game.Player.DruidFormState = { FORMS = {
    [0] = {}, [1] = {}, [2] = {}, [3] = {}, [4] = {}, [5] = {},
    [8] = {}, [9] = {}, [11] = {}, [31] = {},
} }
dofile("Graph/DruidBearThreat.lua")
local Graph = XelAssist.Graph.DruidBearThreat
local function state(formID)
    return { druidFormState = { available = true, formID = formID } }
end

local caster = state(0)
assert(Graph:Attach(caster) and caster.druidBearThreat.exact
    and caster.druidBearThreat.multiplier == 1
    and not caster.druidBearThreat.active,
    "caster form must seal a neutral exact component")
local base, exact, component = Graph:Resolve(caster, "player", 0.75, true)
assert(base == 0.75 and exact and component == caster.druidBearThreat,
    "neutral caster form must preserve earlier player threat factors")
assert(Graph:Resolve(caster, "pet", 0.75, true) == 0.75,
    "pet threat must bypass the player form component")

local bear = state(5)
assert(Graph:Attach(bear) and bear.druidBearThreat.active
    and bear.druidBearThreat.multiplier == 1.30,
    "exact Bear form must activate the passive at the root")
base, exact = Graph:Resolve(bear, "player", 0.75, true)
assert(math.abs(base - 0.975) < 0.000001 and exact,
    "Bear threat must compose after an existing player-owned multiplier")
local dire = state(8)
assert(Graph:Attach(dire) and dire.druidBearThreat.multiplier == 1.30,
    "Dire Bear must share the exact server-attached passive")

local branch = state(0)
assert(Graph:Copy(bear, branch)
    and branch.druidBearThreat ~= bear.druidBearThreat
    and branch.druidBearThreat.profile ~= bear.druidBearThreat.profile
    and branch.druidBearThreat.multiplier == 1,
    "copy must reconcile the isolated component to the branch form")

local callsBeforeSearch = dbcCalls
GetSpellRecField = function()
    error("graph descendant reread installed spell topology")
end
UnitClass = function()
    error("graph descendant reread live class identity")
end
branch.druidFormState.formID = 5
assert(Graph:AfterForm(branch) and branch.druidBearThreat.projected
    and branch.druidBearThreat.active
    and branch.druidBearThreat.multiplier == 1.30,
    "an applied Bear transition must activate branch-local threat")
base, exact = Graph:Resolve(branch, "player", 1, true)
assert(base == 1.30 and exact and dbcCalls == callsBeforeSearch,
    "projected threat must remain search-pure")
dofile("Graph/PlayerThreat.lua")
base, exact = XelAssist.Graph.PlayerThreat:Resolve(branch, "player")
assert(base == 1.30 and exact
    and XelAssist.Graph.PlayerThreat:Resolve(branch, "pet") == 1,
    "production player-threat composition must include Bear but not pet threat")
branch.druidFormState.formID = 1
assert(Graph:AfterForm(branch) and not branch.druidBearThreat.active
    and branch.druidBearThreat.multiplier == 1,
    "a later Cat transition must remove Bear threat exactly")

branch.druidBearThreat.formID = 5
base, exact = Graph:Resolve(branch, "player", 1, true)
assert(base == 1 and exact == false,
    "a stale form/component identity must fail closed")
local unknown = state(7)
unknown.druidBearThreat = { profile = profile }
assert(not Graph:AfterForm(unknown),
    "an unrecognized form ID must not receive a neutral or Bear multiplier")

print("ok: Druid Bear threat is exact, branch-local, and search-pure")
