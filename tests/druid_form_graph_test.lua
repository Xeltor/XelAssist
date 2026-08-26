table.getn = table.getn or function(value)
    local count = 0
    while value and value[count + 1] ~= nil do count = count + 1 end
    return count
end

local formID, primary = 1, 3
local powers = {
    [0] = { 137, 260 }, [1] = { 0, 100 }, [3] = { 42, 100 },
}
local costCalls = 0
UnitClass = function() return "Druid", "DRUID" end
UnitExists = function() return true end
GetShapeshiftFormID = function() return formID end
UnitPowerType = function() return primary end
UnitPower = function(_, powerType) return powers[powerType][1] end
UnitPowerMax = function(_, powerType) return powers[powerType][2] end
CancelShapeshiftForm = function() end
C_Spell = { GetSpellPowerCost = function(spellId)
    costCalls = costCalls + 1
    if spellId == 5487 then return { { type = 0, cost = 40 } } end
    return nil
end }

XelAssist = { Game = { Player = {}, SpellSemantics = {} }, Graph = {} }
function XelAssist.Game.SpellSemantics:Resolve(spellId)
    if spellId == 5487 then return { complete = true, admissible = true,
        atoms = { { kind = "shapeshift", form = 5 } } } end
    return { complete = true, admissible = true, atoms = {} }
end

dofile("Game/Player/DruidFormState.lua")
dofile("Graph/DruidForms.lua")
local Forms = XelAssist.Game.Player.DruidFormState
local Druid = XelAssist.Graph.DruidForms

local state = { role = "auto", tank = false, resource = 42,
    resourceMax = 100, resourceType = 3, playerResourceExact = true,
    playerResourceClock = { resourceType = 3, verified = true },
    actors = { player = { resource = 42, resourceMax = 100,
        resourceType = 3 } } }
assert(Druid:Attach(state) and state.druidFormState.formID == 1
    and state.resource == 42 and state.resourceMax == 100
    and state.resourceType == 3 and state.playerResourceExact,
    "root state must use the exact explicit primary slot without losing mana")

local bear = { name = "Bear Form", spellId = 5487, actor = "player",
    facts = { kind = "buff", self = true, resourceType = "mana" } }
local captured = Forms:CaptureFacts(bear, { cost = 999, source = "fixture" })
assert(captured.druidFormEvidence and captured.druidFormEvidence.valid
    and captured.druidFormEvidence.targetForm == 5
    and captured.druidFormEvidence.cost.cost == 40 and costCalls == 1,
    "the mutable root must capture one exact semantic and effective-cost record")

local prepared, reason, handled = Druid:Prepare(bear, state, captured)
assert(handled and prepared and reason == nil and prepared.cost == 40
    and prepared.powerType == 0
    and prepared.druidFormTransition.targetPrimary == 1
    and costCalls == 1,
    "sealed graph preparation must use captured hidden-mana evidence only")

local candidate = { action = bear, cost = prepared.cost,
    tooltip = prepared,
    druidFormTransition = prepared.druidFormTransition }
local context = {}
assert(Druid:Consume(state, candidate, context)
    and context.druidFormCostPaid
    and state.druidFormState.powers[0].current == 97
    and state.resource == 42 and state.resourceType == 3,
    "form payment must deduct hidden mana rather than active Cat energy")
assert(Druid:Apply(state, candidate, context)
    and state.druidFormState.formID == 5 and state.resourceType == 1
    and state.resource == 0 and state.resourceMax == 0
    and state.playerResourceExact == false
    and state.druidDestinationPowerUnknown
    and state.playerResourceClock == nil and state.tank,
    "Bear projection must fail closed instead of inventing rage or Furor")

local cancelAction = { name = "Cancel form", actor = "player",
    facts = { kind = "form", self = true, druidFormCancel = true } }
prepared, reason, handled = Druid:Prepare(cancelAction, state, {})
assert(handled and prepared and reason == nil and prepared.cost == 0
    and prepared.druidFormTransition.targetForm == 0,
    "exact cancellation must expose a zero-cost caster transition")
candidate = { action = cancelAction, cost = 0, tooltip = prepared,
    druidFormTransition = prepared.druidFormTransition }
context = {}
assert(Druid:Consume(state, candidate, context)
    and Druid:Apply(state, candidate, context)
    and state.druidFormState.formID == 0 and state.resourceType == 0
    and state.resource == 97 and state.resourceMax == 260
    and state.playerResourceExact and not state.tank,
    "cancellation must restore the exact already-observed mana slot")

local ordinary = { name = "Healing Touch", spellId = 5185,
    actor = "player", facts = { kind = "heal" } }
prepared, reason, handled = Druid:Prepare(ordinary, state, {})
assert(not handled and prepared and reason == nil,
    "ordinary actions must remain outside the Druid form adapter")

print("ok: Druid form graph uses exact hidden mana and unknown destination power")
