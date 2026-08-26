table.getn = table.getn or function(value) return #value end
XelAssist = { Game = {}, Graph = {}, Combat = {} }
XelAssistCharDB = {}
BOOKTYPE_SPELL = "spell"

local calls = { debuff = 0, buff = 0 }
local harmful = {}
for index = 1, 10 do harmful[index] = 1000 + index end
harmful[3] = 2001
harmful[7] = 2002
local names = { [2001] = "Corruption", [2002] = "Curse" }
SpellInfo = function(spellId)
    if spellId == 1005 then return nil end
    return names[spellId] or "Other " .. spellId
end
UnitDebuff = function(_, index)
    calls.debuff = calls.debuff + 1
    local spellId = harmful[index]
    if not spellId then return nil end
    return "texture", 0, spellId
end
UnitBuff = function()
    calls.buff = calls.buff + 1
    return nil
end
GetTime = function() return 100 end
GetSpellCooldown = function() return 0, 0 end
GetPetActionsUsable = function() return true end

XelAssist.Game.Actors = { Facts = function(_, action)
    return { cost = 0, cast = 0, gcd = 1.5, duration = 12,
        average = action.facts.kind == "damage" and 50 or 100 }
end }
XelAssist.Game.Capabilities = {
    Usable = function() return true end,
    BonusDamage = function() return 0 end,
}
XelAssist.Graph.ResistanceEvidence = nil
XelAssist.Graph.TargetSelection = { Targets = function()
    return { { unit = "target", relation = "hostile", source = "selected",
        key = "target-guid", guid = "target-guid" } }
end }
XelAssist.Graph.State = {}
XelAssist.Graph.SpatialRequirements = { CaptureRoot = function() return nil end }

dofile("Game/RootAuraEvidence.lua")
dofile("Graph/RootActionFacts.lua")
dofile("Graph/RootObservation.lua")

local actions = {}
for index = 1, 30 do
    local kind, name = "dot", "Absent " .. index
    if index == 2 then name = "Corruption" end
    if index == 3 then name = "Curse" end
    if index > 20 then kind = "damage" end
    actions[index] = { name = name, rank = 1, spellId = 3000 + index,
        slot = index, actor = "player", executor = "playerSpell",
        facts = { kind = kind } }
end
local state = { inventory = {}, rootObservation = nil }
local observed = assert(XelAssist.Graph.RootObservation:Begin(state, actions, 100))
local steps = 0
while not XelAssist.Graph.RootObservation:Step(observed) do
    steps = steps + 1
    assert(steps < 100, "root aura capture did not finish")
end
assert(XelAssist.Graph.RootObservation:Seal(observed))
assert(calls.debuff == 11,
    "one target aura snapshot must be shared by every application action")
assert(calls.buff == 0, "hostile capture must not scan helpful auras")

local sealed = assert(XelAssist.Graph.RootObservation:Actions(state))
local descriptor = { unit = "target", relation = "hostile",
    key = "target-guid", guid = "target-guid" }
local active = XelAssist.Graph.RootObservation:Aura(state, sealed[2], descriptor)
assert(active == true, "first cached application name was lost")
active = XelAssist.Graph.RootObservation:Aura(state, sealed[3], descriptor)
assert(active == true, "second cached application name was lost")
local status
active, status = XelAssist.Graph.RootObservation:Aura(
    state, sealed[1], descriptor)
assert(active == nil and status == "unknown",
    "an incomplete name snapshot must not fabricate aura absence")
local before = calls.debuff
active, status = XelAssist.Graph.RootObservation:Aura(
    state, sealed[30], descriptor)
assert(active == nil and status == "unknown" and calls.debuff == before,
    "direct damage should be marker-gated without fabricating absence")

UnitDebuff = function() error("sealed graph reread target auras") end
active = XelAssist.Graph.RootObservation:Aura(state, sealed[2], descriptor)
assert(active == true, "sealed aura evidence must not reread mutable APIs")

print("ok: root aura evidence scans each recipient once")
