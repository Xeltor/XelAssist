XelAssist = { Game = { Player = {} }, Graph = {} }
math.huge = math.huge or 1 / 0
local function t(a, b, c) return { a or 0, b or 0, c or 0 } end
local rows, specs = {}, {
    [1] = { talent = 45721, trigger = 17080, haste = 45729,
        duration = 5999, rage = 5 },
    [2] = { talent = 45722, trigger = 17081, haste = 45730,
        duration = 11999, rage = 10 },
}
local rank, spec
for rank, spec in pairs(specs) do
    rows[spec.talent] = { attributes = 208, stances = 145,
        procFlags = 87376, procChance = 100, durationIndex = 21,
        spellFamilyName = 7, effect = t(6, 6, 6),
        effectDieSides = t(1, 1),
        effectBasePoints = t(spec.duration, -1, 100),
        effectApplyAuraName = t(107, 42, 109),
        effectTriggerSpell = t(0, spec.trigger, spec.haste),
        effectMiscValue = t(1, 0, rank == 1 and 0 or 7) }
    rows[spec.trigger] = { attributes = 384, procChance = 101,
        rangeIndex = 1, effect = t(30), effectBaseDice = t(1),
        effectBasePoints = t(spec.rage * 10 - 1),
        effectImplicitTargetA = t(1), effectMiscValue = t(1),
        effectTriggerSpell = t() }
end
rows[5229] = { attributes = 262416, stances = 144,
    recoveryTime = 60000, durationIndex = 1, powerType = 1,
    spellFamilyName = 7, spellFamilyFlags = 524288,
    effect = t(6, 3, 6), effectDieSides = t(1, 1),
    effectBasePoints = t(19, -76), effectImplicitTargetA = t(1, 0, 1),
    effectApplyAuraName = t(24, 0, 94), effectAmplitude = t(1000),
    effectMiscValue = t(1) }
function GetSpellRecField(id, field, copied)
    local value = rows[id] and rows[id][field]
    if value == nil then error("missing fixture " .. tostring(id) .. ":" .. field) end
    if copied then return { value[1], value[2], value[3] } end
    return value
end
GetSpellDuration = function(id, base) assert(id == 5229 and base == 1); return 10000 end
local class, learned = "DRUID", 2
UnitClass = function() return "Druid", class end
GetTalentIDByIndex = function(tab, index)
    assert(tab == 2 and index == 12); return 278
end
GetTalentInfo = function(tab, index)
    assert(tab == 2 and index == 12); return "", "", 3, 2, learned, 2
end
GetTalentSpellID = function(tab, index, wanted)
    assert(tab == 2 and index == 12); return specs[wanted].talent
end

dofile("Game/Player/DruidBloodFrenzy.lua")
local Runtime = XelAssist.Game.Player.DruidBloodFrenzy
local found = Runtime:Snapshot()
assert(found.available and found.exact and found.rank == 2
    and found.bonusRage == 10 and found.triggerSpellId == 17081,
    "rank two must seal the exact ten-rage packet")
local facts = Runtime:CaptureFacts({ spellId = 5229 }, { kind = "resource" })
assert(facts.kind == "resource" and facts.druidBloodFrenzyEnrage
    and facts.druidBloodFrenzyEvidence.bonusRage == 10,
    "Enrage facts must preserve prior semantics and add evidence")
learned = 1
assert(Runtime:Snapshot().bonusRage == 5,
    "rank one must seal the exact five-rage packet")
learned = 0
found = Runtime:Snapshot()
assert(found.available and found.exact and found.rank == 0,
    "unlearned Blood Frenzy must be exactly inactive")
class, learned = "MAGE", 2
assert(not Runtime:Snapshot().available,
    "another class must not inherit Blood Frenzy")
class = "DRUID"
Runtime:Invalidate()
rows[17081].effectBasePoints = t(999)
assert(not Runtime:Snapshot().available, "trigger drift must fail closed")
rows[17081].effectBasePoints = t(99)
Runtime:Invalidate()
facts = Runtime:CaptureFacts({ spellId = 5229 }, { kind = "resource" })

dofile("Graph/DruidBloodFrenzy.lua")
local Graph = XelAssist.Graph.DruidBloodFrenzy
GetSpellRecField = function() error("DBC read during graph search") end
local state = { resource = 35, resourceMax = 100, resourceType = 1,
    playerResourceExact = true,
    actors = { player = { resource = 35, resourceMax = 100 } },
    druidFormState = { available = true, formID = 5 } }
local candidate = { action = { spellId = 5229, facts = facts }, tooltip = facts }
assert(Graph:ApplyImmediate(state, candidate) and state.resource == 45
    and state.actors.player.resource == 45,
    "admitted Enrage must receive the exact immediate bonus")
state.resource, state.actors.player.resource = 96, 96
assert(Graph:ApplyImmediate(state, candidate) and state.resource == 100,
    "bonus rage must cap at observed capacity")
state.resource, state.druidFormState.formID = 35, 1
assert(not Graph:ApplyImmediate(state, candidate) and state.resource == 35,
    "Cat Form must not receive Enrage rage")
state.druidFormState.formID, state.playerResourceExact = 8, false
assert(not Graph:ApplyImmediate(state, candidate),
    "inexact resource state must fail closed")
candidate.action.spellId = 5217
state.playerResourceExact = true
assert(not Graph:ApplyImmediate(state, candidate),
    "another action must not consume the packet")
print("ok: Blood Frenzy seals exact supplemental Enrage rage")
