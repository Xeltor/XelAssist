XelAssist = { Core = {}, Game = {}, Combat = {}, Graph = {}, UI = {} }
XelAssistCharDB = { allowAoe = false, petThreat = "avoid", toggles = {
    cooldowns = true, consumables = true, engagedTargets = false,
    petActions = true, petControl = true, reagents = true,
} }
table.getn = table.getn or function(value)
    local count = 0
    while value[count + 1] ~= nil do count = count + 1 end
    return count
end

QueueSpellByName = function() end

local factsCalls = 0
XelAssist.Game.Actors = {
    Actions = function() return {} end,
    DispelTarget = function() return nil end,
    Facts = function(_, action)
        factsCalls = factsCalls + 1
        return action.tooltip or {}
    end,
}
XelAssist.Game.Friendlies = { TargetKeys = function() return {} end }
XelAssist.Game.Capabilities = {
    TargetHasDebuff = function() return false end,
    UnitHasBuff = function() return false end,
    Usable = function() return true end,
}
XelAssist.Game.Inventory = { Blocker = function() return nil end }

dofile("Game/Hostiles.lua")
dofile("Graph/HostileState.lua")
dofile("Graph/State.lua")
dofile("Graph/HostileTargetPolicy.lua")
dofile("Graph/TargetSelection.lua")

local selectedGuid = { label = "opaque selected" }
local engagedGuid = { label = "opaque engaged" }

local function hostileRecord(guid, unit, selected, health)
    local source = selected and "selected" or "companion"
    return {
        key = guid, guid = guid, unit = unit, source = source,
        selected = selected, selectedExecutable = selected,
        engagedAddressable = not selected, addressable = true, dead = false,
        health = health, healthMax = 1000, healthExact = true,
        targetAuras = {}, projectedAuras = {}, modifierEffects = {},
        damageTaken = {}, baseDamageTaken = {}, resistance = nil,
        casting = false, castRemaining = 0, castProbability = 0,
        threat = { playerHasAggro = false, petHasAggro = false,
            playerDeltaExact = true },
        engagement = selected and { engaged = true, unit = "target",
            reason = "selected hostile" } or { engaged = true, unit = unit,
            reason = "companion combat target" },
        context = { target = { guid = guid, unit = unit } },
        targetRef = { unit = unit, guid = guid, relation = "hostile",
            source = source },
    }
end

local selected = hostileRecord(selectedGuid, "target", true, 900)
local engaged = hostileRecord(engagedGuid, "pettarget", false, 100)
selected.targetAuras.Immolate = { mine = true, remaining = 12,
    duration = 15, applicationProbability = 1 }

local function graphState()
    local state = {
        mode = "smart", time = 0, inCombat = true,
        health = 1000, healthMax = 1000,
        resource = 1000, resourceMax = 1000, resourceType = 0,
        hostile = true, tank = false, role = "damage", groupSize = 0,
        moving = false, playerCasting = false, playerChanneling = false,
        playerStealthKnown = true, playerStealthed = false,
        pet = false, actors = {}, absorbs = {}, readyAt = {}, actorReadyAt = {},
        hostiles = { order = { selectedGuid, engagedGuid },
            byKey = { [selectedGuid] = selected, [engagedGuid] = engaged },
            byUnit = { target = selectedGuid, pettarget = engagedGuid },
            selectedKey = selectedGuid, total = 2, capped = false },
    }
    return XelAssist.Graph.State:SyncSelectedHostile(state)
end

local state = graphState()
local dot = { name = "Immolate", actor = "player", executor = "playerSpell",
    facts = { kind = "dot" },
    tooltip = { cost = 100, duration = 15, periodicInterval = 3 } }

local targets = XelAssist.Graph.TargetSelection:Targets(dot, state)
assert(table.getn(targets) == 1 and targets[1].guid == selectedGuid
    and targets[1].unit == "target" and targets[1].source == "selected",
    "engaged-hostile targeting must default to the selected enemy only")
assert(XelAssist.Graph.HostileTargetPolicy:Describe() == "selected enemy only",
    "the disabled policy must be visible to diagnostics")

XelAssistCharDB.toggles.engagedTargets = true
local savedQueue = QueueSpellByName
QueueSpellByName = nil
targets = XelAssist.Graph.TargetSelection:Targets(dot, state)
assert(table.getn(targets) == 1 and targets[1].guid == selectedGuid,
    "opt-in without an exact-GUID queue API must remain selected-only")
QueueSpellByName = savedQueue

engaged.engagement.engaged = false
targets = XelAssist.Graph.TargetSelection:Targets(dot, state)
assert(table.getn(targets) == 1,
    "an observed but unengaged enemy must never become an action target")
engaged.engagement.engaged = true

targets = XelAssist.Graph.TargetSelection:Targets(dot, state)
assert(table.getn(targets) == 2 and targets[2].guid == engagedGuid
    and targets[2].key == engagedGuid and targets[2].unit == "pettarget"
    and targets[2].source == "engaged"
    and targets[2].targetRef.guid == engagedGuid
    and targets[2].targetRef.unit == "pettarget"
    and targets[2].targetRef.source == "engaged",
    "opt-in must publish the exact opaque GUID and proven engagement token")

local fixedActions = {
    { name = "Life Tap", actor = "player", executor = "playerSpell",
        facts = { kind = "resource", self = true } },
    { name = "Demon Armor", actor = "player", executor = "playerSpell",
        facts = { kind = "buff", self = true } },
    { name = "Summon Imp", actor = "player", executor = "playerSpell",
        facts = { kind = "summon" } },
}
local i
for i = 1, table.getn(fixedActions) do
    local fixed = XelAssist.Graph.TargetSelection:Targets(fixedActions[i], state)
    assert(table.getn(fixed) == 1 and fixed[1].unit == "player"
        and fixed[1].relation == "self",
        fixedActions[i].name .. " must remain fixed to the player")
end

local maxTargets = XelAssist.Game.Hostiles.MAX_TARGETS
for i = 3, maxTargets do
    local guid = { label = "opaque engaged " .. tostring(i) }
    local record = hostileRecord(guid, "party" .. tostring(i) .. "target",
        false, 500)
    table.insert(state.hostiles.order, guid)
    state.hostiles.byKey[guid] = record
    state.hostiles.byUnit[record.unit] = guid
end
state.hostiles.total = maxTargets
factsCalls = 0
local capped = XelAssist.Graph.TargetSelection:Targets(dot, state)
assert(table.getn(capped) == maxTargets and factsCalls == maxTargets - 1,
    "one action must produce at most the bounded hostile snapshot's edges")
state.hostiles.order = { selectedGuid, engagedGuid }
state.hostiles.byKey = { [selectedGuid] = selected, [engagedGuid] = engaged }
state.hostiles.byUnit = { target = selectedGuid, pettarget = engagedGuid }
state.hostiles.total = 2

XelAssist.Graph.ActionAdmission = {
    Start = function(_, _, value) return value.time, nil end,
    Readiness = function() return nil end,
    Timing = function()
        return 0, false, 1.5, true, 1.5, 1.5
    end,
}
XelAssist.Graph.SpatialRequirements = { Blocker = function() return nil end }
XelAssist.Graph.ResourceExchange = { Blocker = function() return nil end }
dofile("Graph/ActionContextPolicy.lua")
dofile("Graph/Targets.lua")

targets = XelAssist.Graph.Targets:Targets(dot, state)
local selectedAllowed, selectedReason, _, _, _, _, selectedState =
    XelAssist.Graph.Targets:Legal({ name = "Shadow Bolt", actor = "player",
        executor = "playerSpell", facts = { kind = "damage" },
        tooltip = { cost = 50 } }, state, targets[1])
assert(selectedAllowed and selectedReason == nil
    and selectedState.targetContextKey == nil
    and selectedState.targetGUID == selectedGuid,
    "selected descriptors must preserve the nil selected-target context key")

local selectedDotAllowed, selectedDotReason =
    XelAssist.Graph.Targets:Legal(dot, state, targets[1])
local engagedAllowed, engagedReason, _, _, _, _, engagedState =
    XelAssist.Graph.Targets:Legal(dot, state, targets[2])
assert(not selectedDotAllowed and selectedDotReason == "already active"
    and engagedAllowed and engagedReason == nil
    and engagedState.targetContextKey == engagedGuid
    and engagedState.targetGUID == engagedGuid
    and engagedState.targetAuras == engaged.targetAuras,
    "the same DoT must use each action target's independent aura state")

local fallbackCalls = 0
XelAssist.Game.Capabilities.TargetHasDebuff = function()
    fallbackCalls = fallbackCalls + 1
    return true
end
local freshDot = { name = "Corruption", actor = "player",
    executor = "playerSpell", facts = { kind = "dot" }, tooltip = {} }
assert(not XelAssist.Graph.Targets:AuraActive(
        freshDot, engagedState, targets[2]) and fallbackCalls == 0,
    "off-selected aura checks must not fall back to the selected target API")
assert(XelAssist.Graph.Targets:AuraActive(
        freshDot, selectedState, targets[1]) and fallbackCalls == 1,
    "the selected descriptor may retain the live selected-target aura fallback")

XelAssist.Graph.Effects = {}
XelAssist.Graph.ActorScoring = { Score = function() return false end }
XelAssist.Graph.ThreatScoring = { Apply = function() end }
XelAssist.Graph.PlayerSwings = { Blocker = function() return nil end }
XelAssist.Graph.PlayerSwingScoring = {
    Project = function() end,
    Effective = function(_, context, health, exact)
        if exact then return math.min(context.expectedPower, health) end
        return context.expectedPower
    end,
    DamageValue = function(_, context, effective)
        return effective * 4 / math.max(0.5, context.downtime)
    end,
    Finishes = function() return false end,
}
XelAssist.Graph.ComboScoring = { Apply = function() end }
XelAssist.Graph.ActionPower = {
    Estimate = function() return 100, false, "test power" end,
}
dofile("Graph/PeriodicScoring.lua")
dofile("Graph/Candidate.lua")
dofile("Graph/Scoring.lua")

local execute = { name = "Shadowburn", actor = "player",
    executor = "playerSpell", facts = { kind = "damage", execute = 20 },
    tooltip = { cost = 50 } }
local executeTargets = XelAssist.Graph.Targets:Targets(execute, state)
local selectedExecute, selectedExecuteReason =
    XelAssist.Graph.Scoring:Evaluate(execute, state, executeTargets[1])
local engagedExecute, engagedExecuteReason =
    XelAssist.Graph.Scoring:Evaluate(execute, state, executeTargets[2])
assert(not selectedExecute and selectedExecuteReason == "execute range"
    and engagedExecute and engagedExecuteReason == nil
    and engagedExecute.targetGUID == engagedGuid
    and engagedExecute.targetSource == "engaged",
    "execute legality must use the candidate recipient's health, not selection health")

XelAssist.Graph.ActionEffects = { Context = function() return {} end }
XelAssist.Graph.Timeline = {
    Run = function(_, out, _, candidate)
        out.auras[candidate.action.name] = { remaining = 10,
            duration = 10, mine = true, applicationProbability = 1 }
        XelAssist.Graph.State:CommitActiveHostile(out)
        return out
    end,
}
dofile("Graph/Transitions.lua")

local engagedAfter = XelAssist.Graph.Transitions:Advance(state, {
    action = dot, target = "pettarget", targetKey = engagedGuid,
    targetGUID = engagedGuid, targetRelation = "hostile",
    targetSource = "engaged",
})
assert(engagedAfter.targetContextKey == engagedGuid
    and engagedAfter.hostiles.byKey[engagedGuid].projectedAuras.Immolate
    and not engagedAfter.hostiles.byKey[selectedGuid].projectedAuras.Immolate
    and not state.hostiles.byKey[engagedGuid].projectedAuras.Immolate,
    "an engaged-target transition must change only its copied hostile record")

local selectedAfter = XelAssist.Graph.Transitions:Advance(engagedAfter, {
    action = { name = "Selected Mark", facts = { kind = "debuff" } },
    target = "target", targetKey = selectedGuid, targetGUID = selectedGuid,
    targetRelation = "hostile", targetSource = "selected",
})
assert(selectedAfter.targetContextKey == nil
    and selectedAfter.targetGUID == selectedGuid
    and selectedAfter.hostiles.byKey[selectedGuid].projectedAuras["Selected Mark"]
    and selectedAfter.hostiles.byKey[engagedGuid].projectedAuras.Immolate,
    "returning to the selected enemy must clear engaged context without losing it")

print("ok: bounded opt-in engaged-hostile action targets and local graph state")
