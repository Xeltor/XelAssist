XelAssist = { Game = { Player = {} }, Graph = {} }
math.huge = math.huge or 1 / 0

local function triple(a, b, c) return { a or 0, b or 0, c or 0 } end
local rows = {}
local specs = {
    [1] = { talent = 51415, trigger = 51412, energy = 3 },
    [2] = { talent = 51416, trigger = 51413, energy = 5 },
}
local rank, spec
for rank, spec in pairs(specs) do
    rows[spec.talent] = { attributes = 464, stances = 1,
        procFlags = 262144, procChance = 100, durationIndex = 21,
        spellFamilyName = 7, effect = triple(6),
        effectBasePoints = triple(rank - 1),
        effectImplicitTargetA = triple(1), effectApplyAuraName = triple(42),
        effectTriggerSpell = triple(spec.trigger) }
    rows[spec.trigger] = { attributes = 0, procChance = 101,
        baseLevel = 60, spellLevel = 60, rangeIndex = 1,
        spellFamilyName = 7, effect = triple(30),
        effectBaseDice = triple(1), effectBasePoints = triple(spec.energy - 1),
        effectImplicitTargetA = triple(1), effectMiscValue = triple(3),
        effectTriggerSpell = triple() }
end

function GetSpellRecField(id, field, copied)
    local value = rows[id] and rows[id][field]
    if value == nil then error("missing fixture field: " .. tostring(field)) end
    if copied then return { value[1], value[2], value[3] } end
    return value
end
local class, talentRank = "DRUID", 2
UnitClass = function() return "Druid", class end
GetTalentIDByIndex = function(tab, index)
    assert(tab == 2 and index == 14); return 280
end
GetTalentInfo = function(tab, index)
    assert(tab == 2 and index == 14)
    return "", "", 4, 0, talentRank, 2
end
GetTalentSpellID = function(tab, index, requested)
    assert(tab == 2 and index == 14); return specs[requested].talent
end

dofile("Game/Player/DruidAncientBrutality.lua")
local Runtime = XelAssist.Game.Player.DruidAncientBrutality
local found = Runtime:Snapshot()
assert(found.available and found.exact and found.rank == 2
    and found.energy == 5 and found.talentSpellId == 51416
    and found.triggerSpellId == 51413,
    "rank two must seal the exact five-energy trigger")
talentRank = 1
found = Runtime:Snapshot()
assert(found.exact and found.energy == 3 and found.triggerSpellId == 51412,
    "rank one must seal the exact three-energy trigger")
talentRank = 0
found = Runtime:Snapshot()
assert(found.available and found.exact and found.rank == 0
    and found.energy == 0, "an unlearned talent must be exactly inactive")
class, talentRank = "MAGE", 2
assert(not Runtime:Snapshot().available,
    "another class must never inherit Druid evidence")
class = "DRUID"

Runtime:Invalidate()
rows[51413].effectBasePoints = triple(99)
assert(not Runtime:Snapshot().available,
    "payload drift must fail closed")
rows[51413].effectBasePoints = triple(4)
Runtime:Invalidate()

dofile("Graph/DruidAncientBrutality.lua")
local Graph = XelAssist.Graph.DruidAncientBrutality
local state = { resource = 80, resourceMax = 100, resourceType = 3,
    actors = { player = { resource = 80, resourceMax = 100 } },
    druidFormState = { available = true, formID = 1 } }
assert(Graph:Attach(state, "DRUID") and state.druidAncientBrutality.energy == 5,
    "exact root talent evidence must attach")
GetSpellRecField = function() error("DBC read during graph search") end
local entry = { kind = "periodicTick", aura = { mine = true,
    periodicAction = { actor = "player", facts = { bleed = true } } } }
assert(Graph:ApplyTick(state, entry, true, 1) and state.resource == 85
    and state.actors.player.resource == 85,
    "a delivered player bleed tick must restore exact energy")
assert(Graph:ApplyTick(state, entry, true, 0.5) and state.resource == 87.5,
    "a probabilistic application branch must restore expected energy")
state.resource = 99
assert(Graph:ApplyTick(state, entry, true, 1) and state.resource == 100,
    "energy restoration must cap at the observed maximum")
state.resource, state.druidFormState.formID = 80, 5
assert(not Graph:ApplyTick(state, entry, true, 1) and state.resource == 80,
    "Bear form must not receive the Cat-side payload")
state.druidFormState.formID = 1
entry.aura.periodicAction.facts.bleed = false
assert(not Graph:ApplyTick(state, entry, true, 1),
    "non-bleed periodic damage must remain outside the mechanic")
entry.aura.periodicAction.facts.bleed = true
assert(not Graph:ApplyTick(state, entry, false, 1),
    "a suppressed or dead-target tick must not restore energy")

local copied = {}
Graph:Copy(state, copied)
assert(copied.druidAncientBrutality ~= state.druidAncientBrutality
    and copied.druidAncientBrutality.energy == 5,
    "branch copies must not alias root evidence")
print("ok: exact Ancient Brutality Cat bleed ticks restore graph energy")
