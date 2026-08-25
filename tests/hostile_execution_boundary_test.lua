XelAssist = { Game = {}, Combat = {}, Graph = {}, UI = {} }
table.getn = table.getn or function(value)
    local count = 0
    while value[count + 1] ~= nil do count = count + 1 end
    return count
end

local selectedGuid, otherGuid, petGuid, playerGuid, allyGuid = {}, {}, {}, {}, {}
local units = {}
local function resetUnits()
    units = {
        player = { guid = playerGuid }, pet = { guid = petGuid },
        target = { guid = selectedGuid, hostile = true },
        mouseover = { guid = otherGuid, hostile = true },
        pettarget = { guid = selectedGuid, hostile = true },
        party1target = { guid = otherGuid, hostile = true },
        party1 = { guid = allyGuid },
    }
end
resetUnits()

UnitExists = function(unit)
    local record = units[unit]
    return record and true or false, record and record.guid or nil
end
UnitCanAttack = function(_, unit)
    return units[unit] and units[unit].hostile and true or false
end
UnitIsDead = function(unit) return units[unit] and units[unit].dead and true or false end
UnitIsUnit = function(first, second)
    return units[first] and units[second]
        and units[first].guid == units[second].guid and true or false
end
PlayerIsMoving = function() return false end

-- Target selection consumes only the selected hostile record and canonicalizes
-- its executable token, even when other observed aliases are present.
XelAssist.Graph.State = {
    FriendlyByUnit = function() return nil end,
    FriendlyByKey = function() return nil end,
    PrimaryFriendly = function() return nil end,
    Descriptor = function(_, unit, relation, source, guid, key, record)
        return { unit = unit, relation = relation, source = source, guid = guid,
            key = key, record = record,
            targetRef = record and record.targetRef or nil }
    end,
}
XelAssist.Game.Friendlies = { TargetKeys = function() return {} end }
XelAssist.Game.Actors = { DispelTarget = function() return nil end }
dofile("Graph/TargetSelection.lua")

local selectedRecord = { key = selectedGuid, guid = selectedGuid,
    unit = "mouseover", selected = true, priority = 1,
    targetRef = { unit = "mouseover", guid = selectedGuid,
        relation = "hostile", source = "mouseover" } }
local selectionState = { targetGUID = otherGuid,
    targetRef = { unit = "target", guid = otherGuid,
        relation = "hostile", source = "legacy" },
    hostiles = { selectedKey = selectedGuid,
        byKey = { [selectedGuid] = selectedRecord,
            [otherGuid] = { guid = otherGuid, unit = "pettarget" } },
        byUnit = { target = selectedGuid, mouseover = otherGuid,
            pettarget = otherGuid } } }
local hostileAction = { actor = "player", facts = { kind = "damage" } }
local descriptors = XelAssist.Graph.TargetSelection:Targets(
    hostileAction, selectionState)
assert(table.getn(descriptors) == 1 and descriptors[1].record == selectedRecord
    and descriptors[1].unit == "target" and descriptors[1].guid == selectedGuid
    and descriptors[1].relation == "hostile"
    and descriptors[1].targetRef.unit == "target"
    and descriptors[1].targetRef.guid == selectedGuid
    and descriptors[1].targetRef.relation == "hostile"
    and descriptors[1].targetRef.source == "selected",
    "hostile target selection must expose only the canonical selected record")
local legacy = XelAssist.Graph.TargetSelection:Targets(hostileAction, {
    targetGUID = selectedGuid,
    targetRef = { unit = "target", guid = selectedGuid,
        relation = "hostile", source = "legacy" } })[1]
assert(legacy and legacy.unit == "target" and legacy.guid == selectedGuid
    and legacy.targetRef.unit == "target"
    and legacy.targetRef.source == "selected",
    "legacy states must retain a canonical selected-target fallback")

local effects, hooks = {}, {}
local function resetEffects()
    effects = { direct = 0, queue = 0, petAbility = 0, petAttack = 0,
        petFollow = 0, petPassive = 0, log = 0, observation = 0,
        pending = 0, auto = 0, playerAttack = 0, petEffect = 0 }
    hooks = {}
    resetUnits()
    XelAssist.pendingAuras = {}
    XelAssist.lastReason = nil
end
local function assertNoExecution(message)
    assert(effects.direct == 0 and effects.queue == 0
        and effects.petAbility == 0 and effects.petAttack == 0
        and effects.petFollow == 0 and effects.petPassive == 0
        and effects.log == 0 and effects.observation == 0
        and effects.pending == 0 and effects.auto == 0
        and effects.playerAttack == 0
        and effects.petEffect == 0, message)
end

CastSpellByName = function(name, unit)
    effects.direct, effects.directName, effects.directUnit =
        effects.direct + 1, name, unit
end
QueueSpellByName = function(name)
    effects.queue, effects.queueName = effects.queue + 1, name
end
CastPetAction = function(slot)
    effects.petAbility, effects.petSlot = effects.petAbility + 1, slot
end
PetAttack = function() effects.petAttack = effects.petAttack + 1 end
PetFollow = function() effects.petFollow = effects.petFollow + 1 end
PetPassiveMode = function() effects.petPassive = effects.petPassive + 1 end
AttackTarget = function() effects.playerAttack = effects.playerAttack + 1 end

XelAssist.Game.Capabilities = {
    CastName = function(_, action) return action.name end,
    SameUnitRef = function(_, ref)
        local exists, guid = UnitExists(ref and ref.unit)
        return exists and guid == ref.guid and true or false
    end,
    ValidateFriendlyRef = function(_, ref)
        if not ref or not (ref.relation == "ally" or ref.relation == "friendly"
            or ref.relation == "self" or ref.relation == "player"
            or ref.relation == "pet") then return nil, "ally required" end
        local exists, guid = UnitExists(ref.unit)
        if not exists or guid ~= ref.guid then return nil, "ally changed" end
        return ref.unit
    end,
    InRange = function(_, name, unit)
        if hooks.inRange then hooks.inRange(name, unit) end
        return true
    end,
    Usable = function() return true end,
    Distance = function()
        if hooks.distance then hooks.distance() end
        return 20
    end,
    Geometry = function() return { lineOfSight = true } end,
    CurrentCast = function() return nil, 0, false, 0, false end,
}
XelAssist.Game.Actors = {
    ValidateActorRef = function(_, ref)
        if hooks.actorValidation then hooks.actorValidation() end
        local exists, guid = UnitExists("pet")
        if not ref or not exists or guid ~= ref.guid then
            return nil, "companion changed"
        end
        return "pet", nil
    end,
    Distance = function()
        if hooks.actorDistance then hooks.actorDistance() end
        return 3
    end,
}
XelAssist.Game.Pets = { EffectRuntime = { Submitted = function()
    effects.petEffect = effects.petEffect + 1
end } }
XelAssist.Combat.Observations = { Submitted = function()
    effects.observation = effects.observation + 1
end }
XelAssist.Combat.AutoShot = {
    Snapshot = function(_, evidence) return evidence end,
    CanStart = function()
        if hooks.autoCanStart then hooks.autoCanStart() end
        return true
    end,
    Submitted = function() effects.auto = effects.auto + 1 end,
}
XelAssist.Game.PlayerAttack = {
    Start = function()
        AttackTarget()
        return true
    end,
}
XelAssist.UI.HUD = { Refresh = function() end }
DEFAULT_CHAT_FRAME = { AddMessage = function() end }
XelAssist.executionEnabled, XelAssist.mode = true, "smart"
XelAssist.CheckDependencies = function() end
XelAssist.RecordError = function() end
XelAssist.PlayerGUID = function() return playerGuid end
XelAssist.RecordDecision = function() effects.log = effects.log + 1 end
XelAssist.PendingAuraKey = function()
    if hooks.pendingKey then hooks.pendingKey() end
    return "pending-key"
end
XelAssist.MarkAuraPending = function()
    effects.pending = effects.pending + 1
end
dofile("Core/TargetGuard.lua")
dofile("Core/Executor.lua")

local function selectedRef()
    return { unit = "target", guid = selectedGuid,
        relation = "hostile", source = "selected" }
end
local function playerAction(name, facts)
    return { name = name, spellId = 1, rank = 1, actor = "player",
        executor = "playerSpell", facts = facts or { kind = "damage" } }
end
local function hostilePlan(action)
    return { action = action, actor = action.actor or "player",
        target = "target", targetGUID = selectedGuid,
        targetRelation = "hostile", targetRef = selectedRef(),
        reason = "boundary test", confidence = "client data", value = 1,
        threat = 0, wait = 0, cast = 0, downtime = 0,
        observed = {}, follow = {}, path = {}, tooltip = {} }
end
local currentPlan
XelAssist.Graph.Evaluate = function() return currentPlan, nil, false end

-- A normal selected hostile reaches only Nampower's selected-target queue.
resetEffects()
currentPlan = hostilePlan(playerAction("Shadow Bolt"))
XelAssist:Execute()
assert(effects.queue == 1 and effects.direct == 0 and effects.log == 1
    and effects.observation == 1,
    "a valid selected hostile must retain normal queued execution")

-- No observed off-selected token can be promoted into an executable hostile.
local forgedTokens = { "mouseover", "pettarget", "party1target" }
local i
for i = 1, table.getn(forgedTokens) do
    resetEffects()
    local token = forgedTokens[i]
    currentPlan = hostilePlan(playerAction("Forged Bolt"))
    currentPlan.target, currentPlan.targetGUID = token, units[token].guid
    currentPlan.targetRef = { unit = token, guid = units[token].guid,
        relation = "hostile", source = "observed" }
    XelAssist:Execute()
    assertNoExecution("an off-selected hostile token reached a player API")

    resetEffects()
    currentPlan = hostilePlan(playerAction("Forged Cast Recipient"))
    currentPlan.castTarget, currentPlan.castTargetRelation = token, "hostile"
    currentPlan.castTargetRef = { unit = token, guid = units[token].guid,
        relation = "hostile", source = "observed" }
    XelAssist:Execute()
    assertNoExecution("an off-selected hostile cast recipient reached a player API")
end

resetEffects()
currentPlan = hostilePlan(playerAction("Aliased Reference"))
currentPlan.targetRef = { unit = "mouseover", guid = selectedGuid,
    relation = "hostile", source = "observed" }
XelAssist:Execute()
assertNoExecution("a hostile alias disguised with the selected GUID reached an API")

resetEffects()
currentPlan = hostilePlan(playerAction("Conflicting Recipient Metadata"))
currentPlan.castTargetRelation = "ally"
XelAssist:Execute()
assertNoExecution("conflicting hostile cast metadata reached an API")

-- A GUID change during range or aura inspection is caught at the dispatch edge.
resetEffects()
currentPlan = hostilePlan(playerAction("Racing Bolt"))
hooks.inRange = function() units.target.guid = otherGuid end
XelAssist:Execute()
assertNoExecution("a selected-target GUID race reached the queue")

resetEffects()
currentPlan = hostilePlan(playerAction("Attack", { kind = "command",
    playerAttack = true, ambient = true, startOnly = true }))
XelAssist:Execute()
assert(effects.playerAttack == 1 and effects.queue == 0 and effects.direct == 0
    and effects.log == 1 and effects.observation == 0,
    "a valid player Attack must use only its guarded start command")

resetEffects()
currentPlan = hostilePlan(playerAction("Attack", { kind = "command",
    playerAttack = true, ambient = true, startOnly = true }))
hooks.inRange = function() units.target.guid = otherGuid end
XelAssist:Execute()
assertNoExecution("a selected-target GUID race reached AttackTarget")

resetEffects()
currentPlan = hostilePlan(playerAction("Racing Dot", { kind = "dot" }))
hooks.pendingKey = function() units.target.guid = otherGuid end
XelAssist:Execute()
assertNoExecution("a selected-target aura race created execution side effects")

-- Auto Shot and ground targeting use the same captured hostile boundary.
resetEffects()
currentPlan = hostilePlan(playerAction("Auto Shot", {
    kind = "autoRepeat", autoRepeat = true }))
local autoChecks = 0
hooks.autoCanStart = function()
    autoChecks = autoChecks + 1
    if autoChecks == 2 then units.target.guid = otherGuid end
end
XelAssist:Execute()
assertNoExecution("an Auto Shot target race reached CastSpellByName")

resetEffects()
currentPlan = hostilePlan(playerAction("Volley", { kind = "damage", ground = true }))
XelAssist:Execute()
assert(effects.direct == 1 and effects.directUnit == "CLICK" and effects.log == 1,
    "a valid selected-hostile ground action must preserve direct targeting")

-- Dual-target Hunter buttons may cast on the captured pet, while their hostile
-- effect remains pinned to the selected target.
resetEffects()
local kill = playerAction("Kill Command", { kind = "damage", fixedTarget = "pet",
    effectTarget = "target", effectActor = "pet", requiresPetMelee = true,
    effectMinRange = 0, effectMaxRange = 5 })
currentPlan = hostilePlan(kill)
currentPlan.castTarget, currentPlan.castTargetGUID = "pet", petGuid
currentPlan.castTargetRelation = "pet"
currentPlan.castTargetRef = { unit = "pet", guid = petGuid,
    relation = "pet", source = "controlled" }
XelAssist:Execute()
assert(effects.direct == 1 and effects.directUnit == petGuid
    and effects.queue == 0 and effects.log == 1,
    "a valid dual-target Hunter action must retain its captured pet recipient")

resetEffects()
currentPlan = hostilePlan(kill)
currentPlan.castTarget, currentPlan.castTargetGUID = "pet", petGuid
currentPlan.castTargetRelation = "pet"
currentPlan.castTargetRef = { unit = "pet", guid = petGuid,
    relation = "pet", source = "controlled" }
hooks.inRange = function() units.target.guid = otherGuid end
XelAssist:Execute()
assertNoExecution("a dual-target hostile race reached CastSpellByName")

resetEffects()
currentPlan = hostilePlan(kill)
currentPlan.castTarget, currentPlan.castTargetGUID = "pet", petGuid
currentPlan.castTargetRelation = "pet"
currentPlan.castTargetRef = { unit = "pet", guid = petGuid,
    relation = "pet", source = "controlled" }
hooks.actorDistance = function() units.pettarget.guid = otherGuid end
XelAssist:Execute()
assertNoExecution("a dual-target companion-target race reached CastSpellByName")

-- Hostile pet APIs are guarded after the final actor validation.
local petAction = { name = "Bite", spellId = 2, rank = 1, actor = "pet",
    executor = "petAbility", actionSlot = 4,
    actorRef = { unit = "pet", guid = petGuid,
        relation = "controlled", source = "pet" },
    facts = { kind = "damage" } }
local function petPlan(action)
    local out = hostilePlan(action)
    out.observed = { actors = { pet = { unit = "pet", guid = petGuid,
        actorRef = action.actorRef } } }
    return out
end
resetEffects()
currentPlan = petPlan(petAction)
XelAssist:Execute()
assert(effects.petAbility == 1 and effects.petSlot == 4 and effects.log == 1,
    "a valid selected-target pet ability must retain execution")

resetEffects()
currentPlan = petPlan(petAction)
local actorChecks = 0
hooks.actorValidation = function()
    actorChecks = actorChecks + 1
    if actorChecks == 2 then units.target.guid = otherGuid end
end
XelAssist:Execute()
assertNoExecution("a target race during final pet validation reached CastPetAction")

resetEffects()
local attack = { name = "Pet Attack", actor = "pet", executor = "petCommand",
    command = "attack", actorRef = petAction.actorRef,
    facts = { kind = "command" } }
currentPlan = petPlan(attack)
currentPlan.target, currentPlan.targetGUID = "pettarget", selectedGuid
currentPlan.targetRef = { unit = "pettarget", guid = selectedGuid,
    relation = "hostile", source = "companion" }
XelAssist:Execute()
assertNoExecution("a crafted pettarget attack command reached PetAttack")

-- Friendly and pet-self dispatch are deliberately unaffected.
resetEffects()
currentPlan = { action = playerAction("Arcane Intellect", { kind = "buff" }),
    target = "party1", targetGUID = allyGuid, targetRelation = "ally",
    targetRef = { unit = "party1", guid = allyGuid,
        relation = "ally", source = "party" },
    reason = "friendly test", confidence = "client data", value = 1,
    threat = 0, wait = 0, cast = 0, downtime = 0,
    observed = {}, follow = {}, path = {}, tooltip = {} }
XelAssist:Execute()
assert(effects.direct == 1 and effects.directUnit == allyGuid and effects.log == 1,
    "friendly GUID execution must be preserved")

resetEffects()
local petBuff = { name = "Pet Shield", actor = "pet", executor = "petAbility",
    actionSlot = 7, actorRef = petAction.actorRef,
    facts = { kind = "buff", self = true } }
currentPlan = { action = petBuff, actor = "pet", target = "pet",
    targetGUID = petGuid, targetRelation = "pet",
    targetRef = { unit = "pet", guid = petGuid,
        relation = "pet", source = "controlled" },
    reason = "pet self test", confidence = "client data", value = 1,
    threat = 0, wait = 0, cast = 0, downtime = 0,
    observed = { actors = { pet = { unit = "pet", guid = petGuid,
        actorRef = petAction.actorRef } } }, follow = {}, path = {}, tooltip = {} }
XelAssist:Execute()
assert(effects.petAbility == 1 and effects.petSlot == 7 and effects.log == 1,
    "pet-self execution must be preserved")

print("ok: selected-hostile planning and last-dispatch execution boundary")
