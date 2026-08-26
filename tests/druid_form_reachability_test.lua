-- A localized spellbook name is intentionally opaque. Exact installed-client
-- mechanics must carry discovery through root capture, legality and payment.
table.getn = table.getn or function(value)
    local count = 0
    while value and value[count + 1] ~= nil do count = count + 1 end
    return count
end

XelAssist = { Core = {}, Game = { Player = {} }, Combat = { Knowledge = {} },
    Graph = {}, UI = {} }
XelAssistCharDB = { allowAoe = true, toggles = { cooldowns = true,
    reagents = true, consumables = true, petActions = true, petControl = true } }
BOOKTYPE_SPELL, UIParent = "spell", {}

local liveForm, livePrimary = 1, 3
local powers = { [0] = { 137, 260 }, [1] = { 0, 100 }, [3] = { 42, 100 } }
local cancelCalls, costCalls = 0, 0
UnitClass = function() return "Druid", "DRUID" end
UnitExists = function(unit) return unit == "player" end
GetShapeshiftFormID = function() return liveForm end
UnitPowerType = function() return livePrimary end
UnitPower = function(_, powerType) return powers[powerType][1] end
UnitPowerMax = function(_, powerType) return powers[powerType][2] end
CancelShapeshiftForm = function() cancelCalls = cancelCalls + 1 end
GetTime = function() return 100 end
GetSpellCooldown = function() return 0, 0 end
IsPassiveSpell = function() return false end
IsSpellUsable = function() return 1, 0 end
CreateFrame = function()
    error("semantic form discovery must not scrape a localized tooltip")
end

GetSpellName = function(slot)
    if slot == 1 then return "Lokalisierte Wildgestalt", "Rang 1" end
    return nil
end
GetSpellSlotTypeIdForName = function()
    return 1, BOOKTYPE_SPELL, 5487
end
C_Spell = { GetSpellPowerCost = function(spellId)
    costCalls = costCalls + 1
    if spellId == 5487 then return { { type = 0, cost = 40 } } end
    return nil
end }

XelAssist.Game.SpellSemantics = {}
function XelAssist.Game.SpellSemantics:Resolve(spellId)
    if spellId == 5487 then return { complete = true, admissible = true,
        atoms = { { kind = "shapeshift", form = 5 } } } end
    return { complete = true, admissible = true, atoms = {} }
end
XelAssist.Game.HealthTransfer = nil
XelAssist.Game.ResourceExchange = nil

dofile("Game/Player/DruidFormState.lua")
dofile("Game/SpellClassification.lua")
dofile("Game/ActionInference.lua")
dofile("Game/CapabilityInvalidation.lua")
dofile("Game/Capabilities.lua")

local capabilities = XelAssist.Game.Capabilities
local discovered = capabilities:Actions()
assert(table.getn(discovered) == 2,
    "BuildSpellIndex must publish the semantic form and executable cancel edge")
local formAction, cancelAction, index
for index = 1, table.getn(discovered) do
    local action = discovered[index]
    if action.facts.druidShapeshift then formAction = action end
    if action.facts.druidFormCancel then cancelAction = action end
end
assert(formAction and formAction.name == "Lokalisierte Wildgestalt"
    and formAction.facts.kind == "form" and formAction.spellId == 5487,
    "exact shapeshift atoms, never names, must discover form actions")
assert(cancelAction and cancelAction.executor == "playerFormCancel"
    and cancelAction.facts.requiresExactUsability,
    "the graph must advertise only the race-checked cancel executor")

capabilities.UnitHasBuff = function() return false end
XelAssist.Game.Actors = { Facts = function(_, action)
    assert(action.facts.druidShapeshift,
        "synthetic cancellation must not query a nonexistent spell slot")
    return { cost = 999, cast = 0, gcd = 1.5, powerType = 0,
        source = "fixture live spell facts" }
end }
XelAssist.Game.Inventory = { Blocker = function() return nil end }

local playerKey = {}
XelAssist.Graph.State = {
    FriendlyByKey = function(_, state, key)
        return state.friendlies and state.friendlies.byKey[key]
    end,
    FriendlyByUnit = function(_, state, unit)
        local key = state.friendlies and state.friendlies.byUnit[unit]
        return key and state.friendlies.byKey[key] or nil
    end,
    PrimaryFriendly = function(self, state)
        return self:FriendlyByUnit(state, "player")
    end,
    Descriptor = function(_, unit, relation, source, guid, key, record)
        return { unit = unit, relation = relation, source = source,
            guid = guid, key = key, record = record }
    end,
}
XelAssist.Graph.SpatialRequirements = {
    CaptureRoot = function() return nil end,
    Blocker = function() return nil end,
}
XelAssist.Graph.ResourceExchange = nil
XelAssist.Graph.HealthTransfer = nil
XelAssist.Graph.PlayerSwings = nil
XelAssist.Graph.CompanionResources = nil

dofile("Graph/DruidForms.lua")
dofile("Graph/TargetSelection.lua")
dofile("Graph/ActionAdmission.lua")
dofile("Graph/ActionContextPolicy.lua")
dofile("Graph/Targets.lua")
dofile("Graph/Candidate.lua")
dofile("Graph/ActionConsumption.lua")
dofile("Graph/RootObservation.lua")

local player = { unit = "player", relation = "self", source = "self",
    guid = playerKey, key = playerKey, health = 100, healthMax = 100,
    auras = { available = true } }
local state = { mode = "auto", hostile = true, inCombat = true,
    health = 100, healthMax = 100, resource = 42, resourceMax = 100,
    resourceType = 3, playerResourceExact = true,
    auras = {}, absorbs = {}, readyAt = {}, actorReadyAt = { player = 0 },
    playerGcdReadyAt = 0, time = 0, moving = false,
    playerCasting = false, playerChanneling = false, groupSize = 0,
    actors = { player = { guid = playerKey, resource = 42,
        resourceMax = 100, resourceType = 3 } },
    friendlies = { primaryKey = playerKey, byUnit = { player = playerKey },
        byKey = { [playerKey] = player }, order = { playerKey } },
    inventory = { itemCounts = {}, reagentCounts = {} },
}
assert(XelAssist.Graph.DruidForms:Attach(state),
    "the root graph must attach exact Cat energy and hidden mana")
assert(state.playerForm and state.playerForm.formID == 1,
    "the generic stance gate must share the exact attached Druid form")

local observation = XelAssist.Graph.RootObservation:Begin(state, discovered, 100)
local steps = 0
while not XelAssist.Graph.RootObservation:Step(observation) do
    steps = steps + 1
    assert(steps < 20, "Druid root observation exceeded its bounded fixture")
end
assert(XelAssist.Graph.RootObservation:Seal(observation),
    "Druid action evidence must seal before search")
local sealedActions = XelAssist.Graph.RootObservation:Actions(state)
for index = 1, table.getn(sealedActions) do
    if sealedActions[index].facts.druidShapeshift then
        formAction = sealedActions[index]
    elseif sealedActions[index].facts.druidFormCancel then
        cancelAction = sealedActions[index]
    end
end

local descriptor = XelAssist.Graph.Targets:Targets(formAction, state)[1]
local legal, reason, tooltip, _, actionStart, resolved =
    XelAssist.Graph.Targets:Legal(formAction, state, descriptor)
assert(legal and reason == nil and tooltip.druidFormTransition
    and tooltip.cost == 40 and actionStart == 0 and costCalls == 1,
    "RootObservation and Targets must expose one exact hidden-mana transition")
local candidate = XelAssist.Graph.Candidate:Build({ action = formAction,
    facts = formAction.facts, descriptor = resolved, tooltip = tooltip,
    cost = tooltip.cost, actionStart = actionStart, value = 0,
    reason = "form mechanics", expectedPower = 0, power = 0 })
local context = {}
assert(XelAssist.Graph.ActionConsumption:Consume(state, candidate, context)
    and context.druidFormCostPaid
    and state.druidFormState.powers[0].current == 97
    and state.resource == 42,
    "chosen form payment must use hidden mana without spending Cat energy")
assert(XelAssist.Graph.DruidForms:Apply(state, candidate, context)
    and state.druidFormState.formID == 5 and state.playerForm.formID == 5
    and state.resourceType == 1
    and state.playerResourceExact == false,
    "the Bear edge must remain reachable while destination rage stays unknown")

descriptor = XelAssist.Graph.Targets:Targets(cancelAction, state)[1]
legal, reason, tooltip, _, actionStart, resolved =
    XelAssist.Graph.Targets:Legal(cancelAction, state, descriptor)
assert(legal and reason == nil and tooltip.druidFormTransition.targetForm == 0,
    "projected Bear form must expose an exact cancel-to-caster edge")
local cancelCandidate = XelAssist.Graph.Candidate:Build({ action = cancelAction,
    facts = cancelAction.facts, descriptor = resolved, tooltip = tooltip,
    cost = 0, actionStart = actionStart, value = 0,
    reason = "return to caster", expectedPower = 0, power = 0 })
local cancelPlan = { action = cancelAction,
    druidFormTransition = cancelCandidate.druidFormTransition }
assert(not XelAssist.Graph.DruidForms:DispatchCancel(cancelPlan)
    and cancelCalls == 0,
    "a stale Cat live form must reject the projected Bear cancellation")
liveForm, livePrimary = 5, 1
assert(XelAssist.Graph.DruidForms:DispatchCancel(cancelPlan)
    and cancelCalls == 1,
    "an exact matching live Bear form must reach CancelShapeshiftForm once")
liveForm, livePrimary = 0, 0
assert(not XelAssist.Graph.DruidForms:DispatchCancel(cancelPlan)
    and cancelCalls == 1,
    "a target/victim-style form race must never replay cancellation")

XelAssist.Core.TargetGuard = {
    HostileAnchor = function() return nil, nil, false end,
    PreflightHostile = function() return nil, nil, false end,
    ValidateHostile = function() return nil, nil, false end,
    ValidateHostileEffect = function() return nil, nil end,
    TargetGuid = function() return playerKey end,
}
XelAssist.Core.ExecutionReach = { Validate = function() return true end }
XelAssist.Core.DispatchReadiness = { Player = function() return nil end }
XelAssist.Core.RecommendationSnapshot = {}
XelAssist.Core.WandExecution = {}
XelAssist.Core.PlayerNormalQueue = {
    MayOccupy = function() return false end,
}
XelAssist.Core.WarriorTankGuard = { Validate = function() return true end }
XelAssist.Game.Player.OnSwing = nil
capabilities.ValidateFriendlyRef = function() return "player", playerKey end
capabilities.SameUnitRef = function() return true end
XelAssist.UI.HUD = { RequestRefresh = function() end }
XelAssist.PlayerGUID = function() return playerKey end
local decisions = 0
XelAssist.RecordDecision = function() decisions = decisions + 1 end
XelAssist.Combat.Observations = nil
dofile("Core/Executor.lua")
liveForm, livePrimary = 5, 1
cancelPlan.target, cancelPlan.targetRelation = "player", "self"
cancelPlan.targetRef = { unit = "player", guid = playerKey,
    relation = "self", source = "self" }
cancelPlan.tooltip, cancelPlan.wait, cancelPlan.cast = tooltip, 0, 0
cancelPlan.reason = "return to caster"
XelAssist:ExecutePlayerPlan(cancelPlan, "auto")
assert(cancelCalls == 2 and decisions == 1,
    "the published synthetic edge must reach the guarded cancel executor")

context = {}
assert(XelAssist.Graph.ActionConsumption:Consume(
    state, cancelCandidate, context)
    and XelAssist.Graph.DruidForms:Apply(state, cancelCandidate, context)
    and state.playerForm.formID == 0
    and state.resourceType == 0 and state.resource == 97
    and state.playerResourceExact,
    "cancel projection must restore the exact mana lane for later caster actions")

print("ok: semantic Druid forms reach sealed graph transitions and safe cancel dispatch")
