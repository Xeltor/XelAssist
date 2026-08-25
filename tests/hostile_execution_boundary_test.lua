XelAssist = { Core = {}, Game = {}, Combat = {}, Graph = {}, UI = {} }
XelAssistCharDB = { toggles = { engagedTargets = false } }
table.getn = table.getn or function(value)
    local count = 0
    while value[count + 1] ~= nil do count = count + 1 end
    return count
end

local selectedGuid, otherGuid, petGuid, playerGuid, allyGuid = {}, {}, {}, {}, {}
local currentPlan
local units = {}
local deadStateMode
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
UnitCanAssist = function(_, unit)
    return units[unit] and not units[unit].hostile
        and not units[unit].unassistable and true or false
end
UnitIsDead = function(unit)
    if deadStateMode == "nil" then return nil end
    if deadStateMode == "error" then error("dead state unavailable") end
    return units[unit] and units[unit].dead and true or false
end
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
XelAssist.Game.Actors = { DispelTarget = function() return nil end,
    Facts = function(_, action) return action.mock or {} end }
dofile("Game/HostileEngagement.lua")
dofile("Graph/HostileTargetPolicy.lua")
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

local effects, hooks, wandPending = {}, {}, false
local playerDistance, playerDistanceKind = 3, "hitbox"
local petDistance, petDistanceKind = 3, "hitbox"
local geometryLineOfSight = true
local playerLineOfSight, petLineOfSight = nil, nil
local playerBehind, petBehind = nil, nil
local spellRangeVerdict = true
local function resetEffects()
    effects = { direct = 0, queue = 0, petAbility = 0, petAttack = 0,
        petFollow = 0, petPassive = 0, log = 0, observation = 0,
        pending = 0, auto = 0, wand = 0, resistance = 0, playerAttack = 0,
        petEffect = 0, item = 0 }
    hooks = {}
    playerDistance, playerDistanceKind = 3, "hitbox"
    petDistance, petDistanceKind = 3, "hitbox"
    geometryLineOfSight = true
    playerLineOfSight, petLineOfSight = nil, nil
    playerBehind, petBehind = nil, nil
    spellRangeVerdict = true
    wandPending = false
    deadStateMode = nil
    resetUnits()
    XelAssist.pendingAuras = {}
    if XelAssist.Core.PlayerNormalQueue then
        XelAssist.Core.PlayerNormalQueue:Reset()
    end
    XelAssist.lastReason = nil
end
local function assertNoExecution(message)
    assert(effects.direct == 0 and effects.queue == 0
        and effects.petAbility == 0 and effects.petAttack == 0
        and effects.petFollow == 0 and effects.petPassive == 0
        and effects.log == 0 and effects.observation == 0
        and effects.pending == 0 and effects.auto == 0 and effects.wand == 0
        and effects.resistance == 0
        and effects.playerAttack == 0
        and effects.petEffect == 0 and effects.item == 0, message)
end

CastSpellByName = function(name, unit)
    effects.direct, effects.directName, effects.directUnit =
        effects.direct + 1, name, unit
    if hooks.direct then hooks.direct(name, unit) end
end
QueueSpellByName = function(name, guid)
    effects.queue, effects.queueName, effects.queueGuid =
        effects.queue + 1, name, guid
    if hooks.queue then hooks.queue(name, guid) end
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
        if not UnitCanAssist("player", ref.unit) then
            return nil, "ally no longer friendly"
        end
        if UnitIsDead(ref.unit) then return nil, "ally defeated" end
        return ref.unit
    end,
    InRange = function(_, name, unit)
        if hooks.inRange then hooks.inRange(name, unit) end
        return true
    end,
    Usable = function() return true end,
    IsReady = function() return true end,
    Distance = function()
        if hooks.distance then hooks.distance() end
        return playerDistance, playerDistanceKind
    end,
    Geometry = function(_, actor)
        local lineOfSight, behind
        if actor == "pet" then
            lineOfSight, behind = petLineOfSight, petBehind
        elseif actor == "player" then
            lineOfSight, behind = playerLineOfSight, playerBehind
        end
        if lineOfSight == nil then lineOfSight = geometryLineOfSight end
        return { lineOfSight = lineOfSight, behind = behind }
    end,
    CurrentCast = function() return nil, 0, false, 0, false end,
}
XelAssist.Game.Actors = {
    Facts = function(_, action) return action.mock or {} end,
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
        return petDistance, petDistanceKind
    end,
    PetCooldown = function() return 0 end,
}
XelAssist.Game.Pets = { EffectRuntime = { Submitted = function()
    effects.petEffect = effects.petEffect + 1
end } }
XelAssist.Game.Inventory = { Execute = function(action)
    effects.item = effects.item + 1
    if hooks.item then hooks.item(action) end
    return true
end }
XelAssist.Combat.Observations = {
    Submitted = function(_, _, target)
        effects.observation = effects.observation + 1
        effects.observationTarget = target
    end,
    SubmittedGuid = function(_, _, guid)
        effects.observation = effects.observation + 1
        effects.observationGuid = guid
    end,
}
dofile("Combat/AutoShotRange.lua")
XelAssist.Combat.AutoShot = {
    Snapshot = function(_, evidence) return evidence end,
    CanStart = function()
        if hooks.autoCanStart then hooks.autoCanStart() end
        return true
    end,
    Submitted = function() effects.auto = effects.auto + 1 end,
}
XelAssist.Combat.Wand = {
    Snapshot = function()
        return { active = false, activeKnown = true, pending = wandPending,
            currentTargetGuid = units.target and units.target.guid,
            clockKnown = true }
    end,
    CanStart = function(_, snapshot)
        if snapshot.pending then return false, "wand start pending" end
        return true
    end,
    Submitted = function(_, guid)
        assert(guid == selectedGuid)
        wandPending, effects.wand = true, effects.wand + 1
        return true
    end,
}
XelAssist.Combat.Resistance = {
    RememberUnit = function(_, unit) assert(unit == "target") end,
    Submitted = function(_, action, guid, tooltip)
        assert(action and action.facts
            and action.facts.dynamicSchool == "equippedWand")
        assert(guid == selectedGuid and type(tooltip) == "table")
        effects.resistance = effects.resistance + 1
    end,
}
XelAssist.Game.PlayerAttack = {
    Start = function()
        AttackTarget()
        return true
    end,
}
XelAssist.UI.HUD = { Refresh = function() end, RequestRefresh = function() end }
XelAssist.Core.RecommendationSnapshot = {
    Acquire = function() return currentPlan, nil end,
}
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
C_Spell = { IsSpellInRange = function(name, unit)
    if hooks.inRange then hooks.inRange(name, unit) end
    return spellRangeVerdict
end }
dofile("Core/TargetGuard.lua")
dofile("Game/SpellClassification.lua")
dofile("Game/Range.lua")
dofile("Game/Pets/Actions.lua")
dofile("Core/ExecutionReach.lua")
dofile("Core/DispatchReadiness.lua")
dofile("Core/WandExecution.lua")
dofile("Core/PlayerNormalQueue.lua")
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
XelAssist.Graph.Evaluate = function() return currentPlan, nil, false end

-- Graph instructions are display/hold contracts. Repeated macro presses must
-- never route them through a spell, item, or target mutation API.
resetEffects()
currentPlan = hostilePlan({ name = "Continue Mind Flay", rank = 0,
    actor = "player", executor = "instruction",
    facts = { kind = "channelContinuation", channelContinuation = true } })
XelAssist:Execute()
assertNoExecution("a channel continuation instruction must be a safe macro hold")
assert(string.find(XelAssist.lastReason or "", "Continue Mind Flay", 1, true),
    "an instruction hold must remain visible as the current execution reason")

-- A normal selected hostile reaches only Nampower's selected-target queue.
resetEffects()
currentPlan = hostilePlan(playerAction("Shadow Bolt"))
XelAssist:Execute()
assert(effects.queue == 1 and effects.queueGuid == selectedGuid
    and effects.direct == 0 and effects.log == 1
    and effects.observation == 1 and effects.observationTarget == "target"
    and effects.observationGuid == nil,
    "a selected-hostile queue submission must pin its validated GUID")

-- Shoot is a distinct client repeat boundary. It must never pass through the
-- Hunter Auto Shot validator, and macro tapping must not toggle it off.
resetEffects()
currentPlan = hostilePlan(playerAction("Shoot", { kind = "autoRepeat",
    autoRepeat = true, wandRepeat = true, ranged = true,
    dynamicSchool = "equippedWand" }))
hooks.autoCanStart = function()
    error("wand dispatch reached Hunter Auto Shot validation")
end
XelAssist:Execute()
assert(effects.direct == 1 and effects.directName == "Shoot"
    and effects.queue == 0 and effects.auto == 0 and effects.wand == 1
    and effects.resistance == 1 and effects.log == 1
    and effects.observation == 0,
    "a proven wand start must dispatch directly and seed dynamic resistance evidence")
XelAssist:Execute()
assert(effects.direct == 1 and effects.wand == 1 and effects.log == 1
    and effects.resistance == 1
    and string.find(XelAssist.lastReason or "", "wand start pending", 1, true),
    "a repeated wand input must hold while native repeat confirmation is pending")

-- A synchronous client rejection is not a submitted action. It must not leave
-- the ghost DoT reservation that would suppress the required immediate retry.
resetEffects()
currentPlan = hostilePlan(playerAction("Immolate", { kind = "dot" }))
currentPlan.action.spellId, currentPlan.tooltip.gcd = 348, 1.5
hooks.queue = function(_, guid)
    XelAssist.Core.PlayerNormalQueue:ServerFailure(348, guid, "701")
    XelAssist.Core.PlayerNormalQueue:CastEvent(0, 348, 0, guid, "701")
end
XelAssist:Execute()
assert(effects.queue == 1 and effects.log == 0 and effects.observation == 0
    and effects.pending == 0
    and not XelAssist.Core.PlayerNormalQueue:Current()
    and string.find(XelAssist.lastReason, "client cast failed", 1, true),
    "an immediate client failure must not create a ghost spell submission")

-- Nampower raises an exact local failure from inside the cast trampoline,
-- queues its configured retry, then emits the outer failed cast event. The
-- queued retry is a real submission and must remain guarded against overwrite.
resetEffects()
currentPlan = hostilePlan(playerAction("Serpent Sting", { kind = "dot" }))
currentPlan.action.spellId, currentPlan.tooltip.gcd = 1978, 1.5
hooks.queue = function()
    XelAssist.Core.PlayerNormalQueue:ServerFailure(1978, nil, "703")
    XelAssist.Core.PlayerNormalQueue:QueueEvent(2, 1978)
    XelAssist.Core.PlayerNormalQueue:CastEvent(
        0, 1978, 0, selectedGuid, "703")
end
XelAssist:Execute()
local localRetry = XelAssist.Core.PlayerNormalQueue:Current()
assert(effects.queue == 1 and effects.log == 1 and effects.observation == 1
    and effects.pending == 1 and localRetry and localRetry.phase == "queued",
    "a synchronous local retry must remain a logged and guarded submission")
XelAssist:Execute()
assert(effects.queue == 1 and effects.log == 1
    and XelAssist.Core.PlayerNormalQueue:Current() == localRetry,
    "the next input must not overwrite a locally retried normal spell")

resetEffects()
currentPlan = { action = { name = "Healing Potion", actor = "player",
        executor = "item", facts = { kind = "heal", consumable = true } },
    reason = "client failure", confidence = "client data", value = 1,
    threat = 0, wait = 0, cast = 0, downtime = 0,
    observed = {}, follow = {}, path = {}, tooltip = { gcd = 1.5 } }
hooks.item = function()
    XelAssist.Core.PlayerNormalQueue:CastEvent(0, 17534, 0, nil, "702")
end
XelAssist:Execute()
assert(effects.item == 1 and effects.log == 0
    and not XelAssist.Core.PlayerNormalQueue:Current()
    and string.find(XelAssist.lastReason, "client cast failed", 1, true),
    "a synchronously failed item proc must not be logged as submitted")

-- A proven normal queue survives the synchronous dispatch callback and blocks
-- only actions that could overwrite that one slot.
resetEffects()
currentPlan = hostilePlan(playerAction("Serpent Sting"))
currentPlan.action.spellId, currentPlan.tooltip.gcd = 1978, 1.5
hooks.queue = function()
    XelAssist.Core.PlayerNormalQueue:QueueEvent(2, 1978)
end
XelAssist:Execute()
local ownedQueue = XelAssist.Core.PlayerNormalQueue:Current()
assert(effects.queue == 1 and ownedQueue and ownedQueue.phase == "queued",
    "a synchronous normal queue event must survive dispatch finalization")
units.target.guid = otherGuid
assert(effects.queueGuid == selectedGuid and ownedQueue.targetGuid == selectedGuid,
    "a delayed normal cast must retain the captured hostile GUID across selection changes")
units.target.guid = selectedGuid
XelAssist:Execute()
assert(effects.queue == 1 and effects.log == 1 and effects.observation == 1
    and string.find(XelAssist.lastReason, "already queued", 1, true),
    "a repeated input must not replace XelAssist's pending normal spell")
XelAssist.Core.PlayerNormalQueue:QueueEvent(0, 1978)
XelAssist.Core.PlayerNormalQueue:QueueEvent(4, 1978)
XelAssist.Core.PlayerNormalQueue:QueueEvent(3, 9999)
assert(XelAssist.Core.PlayerNormalQueue:Current() == ownedQueue,
    "independent queue events and mismatched pops must retain the normal owner")

currentPlan = { action = playerAction("Lesser Heal", { kind = "heal" }),
    target = "party1", targetGUID = allyGuid, targetRelation = "ally",
    targetRef = { unit = "party1", guid = allyGuid,
        relation = "ally", source = "party" },
    reason = "queue boundary", confidence = "client data", value = 1,
    threat = 0, wait = 0, cast = 0, downtime = 0,
    observed = {}, follow = {}, path = {}, tooltip = { gcd = 1.5 } }
XelAssist:Execute()
assert(effects.direct == 0 and effects.queue == 1 and effects.log == 1
    and XelAssist.Core.PlayerNormalQueue:Current() == ownedQueue,
    "a normal friendly cast must not overwrite the occupied Nampower slot")

currentPlan = hostilePlan(playerAction("Volley",
    { kind = "damage", ground = true }))
currentPlan.tooltip.gcd = 1.5
XelAssist:Execute()
assert(effects.direct == 0 and effects.queue == 1 and effects.log == 1
    and XelAssist.Core.PlayerNormalQueue:Current() == ownedQueue,
    "a normal ground cast must not overwrite the occupied Nampower slot")

currentPlan = hostilePlan(playerAction("Revive Pet",
    { kind = "summon", petLifecycle = true }))
currentPlan.tooltip.gcd = 1.5
XelAssist:Execute()
assert(effects.direct == 0 and effects.queue == 1 and effects.log == 1
    and XelAssist.Core.PlayerNormalQueue:Current() == ownedQueue,
    "a normal pet-lifecycle cast must not overwrite the occupied Nampower slot")

currentPlan = { action = { name = "Healing Potion", actor = "player",
        executor = "item", facts = { kind = "heal", consumable = true } },
    reason = "queue boundary", confidence = "client data", value = 1,
    threat = 0, wait = 0, downtime = 0, observed = {}, follow = {}, path = {},
    tooltip = { gcd = 1.5 } }
XelAssist:Execute()
assert(effects.item == 0 and effects.log == 1
    and XelAssist.Core.PlayerNormalQueue:Current() == ownedQueue,
    "a normal item use must not overwrite the occupied Nampower slot")

currentPlan.tooltip.gcd = 0
XelAssist:Execute()
assert(effects.item == 1 and effects.log == 2
    and XelAssist.Core.PlayerNormalQueue:Current() == ownedQueue,
    "a proven non-GCD item must remain executable beside the normal slot")

currentPlan = hostilePlan(playerAction("Kill Command",
    { kind = "damage", gcd = 0 }))
currentPlan.action.spellId, currentPlan.tooltip.gcd = 34026, 0
hooks.queue = function()
    XelAssist.Core.PlayerNormalQueue:QueueEvent(4, 34026)
end
XelAssist:Execute()
assert(effects.queue == 2
    and XelAssist.Core.PlayerNormalQueue:Current() == ownedQueue,
    "a non-GCD action must remain executable beside the normal queue")

currentPlan = hostilePlan(playerAction("Raptor Strike",
    { kind = "damage", melee = true }))
currentPlan.action.spellId = 2973
currentPlan.tooltip = { gcd = 1.5, attributes = 4,
    onNextSwing = true, startRecoveryCategory = 0, normalGcd = false }
hooks.queue = function()
    XelAssist.Core.PlayerNormalQueue:QueueEvent(0, 2973)
end
XelAssist:Execute()
assert(effects.queue == 3
    and XelAssist.Core.PlayerNormalQueue:Current() == ownedQueue,
    "an on-next-swing action must remain independent of the normal queue")
XelAssist.Core.PlayerNormalQueue:CastEvent(1, 1978, 0, selectedGuid)
assert(XelAssist.Core.PlayerNormalQueue:QueueEvent(3, 1978)
    and XelAssist.Core.PlayerNormalQueue:Current() == ownedQueue
    and ownedQueue.phase == "popped",
    "the exact normal pop must remain latched before server evidence")
assert(not XelAssist.Core.PlayerNormalQueue:ServerAccepted(9999, selectedGuid)
    and XelAssist.Core.PlayerNormalQueue:Current() == ownedQueue,
    "mismatched server evidence must not reopen the slot")
assert(XelAssist.Core.PlayerNormalQueue:ServerAccepted(1978, selectedGuid)
    and not XelAssist.Core.PlayerNormalQueue:Current(),
    "matching server evidence after the pop must reopen the slot")

-- Implicit-target pet lifecycle spells establish ownership even though their
-- CastSpellByName call deliberately carries no dead/dismissed pet GUID.
resetEffects()
currentPlan = { action = playerAction("Revive Pet", { kind = "summon",
        petLifecycle = "revive", fixedTarget = "pet" }),
    target = "pet", targetRelation = "pet",
    reason = "queue boundary", confidence = "client data", value = 1,
    threat = 0, wait = 0, cast = 10, downtime = 10,
    observed = {}, follow = {}, path = {}, tooltip = { gcd = 1.5 } }
currentPlan.action.spellId = 982
hooks.direct = function()
    XelAssist.Core.PlayerNormalQueue:QueueEvent(2, 982)
end
XelAssist:Execute()
local lifecycleQueue = XelAssist.Core.PlayerNormalQueue:Current()
assert(effects.direct == 1 and effects.directUnit == nil
    and lifecycleQueue and lifecycleQueue.phase == "queued"
    and lifecycleQueue.targetGuid == nil,
    "a normal pet-lifecycle cast must own the slot without a synthetic target")
XelAssist:Execute()
assert(effects.direct == 1 and effects.log == 1
    and string.find(XelAssist.lastReason, "already queued", 1, true),
    "a repeated pet-lifecycle input must not overwrite its normal slot")
XelAssist.Core.PlayerNormalQueue:CastEvent(1, 982, 0,
    "0x0000000000000000")
XelAssist.Core.PlayerNormalQueue:ServerAccepted(982,
    "0x0000000000000000")

-- GCD-triggering items establish the same owner; the actual proc spell ID can
-- arrive synchronously through Nampower after the provisional nil spell ID.
resetEffects()
currentPlan = { action = { name = "Healing Potion", actor = "player",
        executor = "item", facts = { kind = "heal", consumable = true } },
    reason = "queue boundary", confidence = "client data", value = 1,
    threat = 0, wait = 0, cast = 0, downtime = 0,
    observed = {}, follow = {}, path = {}, tooltip = { gcd = 1.5 } }
hooks.item = function()
    XelAssist.Core.PlayerNormalQueue:QueueEvent(2, 17534)
end
XelAssist:Execute()
local itemQueue = XelAssist.Core.PlayerNormalQueue:Current()
assert(effects.item == 1 and itemQueue and itemQueue.spellId == 17534
    and itemQueue.phase == "queued",
    "a normal item use must establish ownership from its proc evidence")
XelAssist:Execute()
assert(effects.item == 1 and effects.log == 1
    and string.find(XelAssist.lastReason, "already queued", 1, true),
    "a repeated item input must not overwrite its normal slot")
XelAssist.Core.PlayerNormalQueue:CastEvent(1, 17534, 0, nil)
XelAssist.Core.PlayerNormalQueue:ServerAccepted(17534, nil)

resetEffects()
local dualNormal = playerAction("Dual GCD", { kind = "damage",
    fixedTarget = "pet", effectTarget = "target", effectActor = "pet" })
dualNormal.spellId = 9001
currentPlan = hostilePlan(dualNormal)
currentPlan.castTarget, currentPlan.castTargetGUID = "pet", petGuid
currentPlan.castTargetRelation = "pet"
currentPlan.castTargetRef = { unit = "pet", guid = petGuid,
    relation = "pet", source = "controlled" }
currentPlan.tooltip.gcd = 1.5
hooks.direct = function(_, guid)
    XelAssist.Core.PlayerNormalQueue:CastEvent(1, 9001, 0, guid)
end
XelAssist:Execute()
local dualQueue = XelAssist.Core.PlayerNormalQueue:Current()
assert(effects.direct == 1 and effects.directUnit == petGuid
    and dualQueue and dualQueue.targetGuid == petGuid
    and dualQueue.phase == "attempted",
    "normal queue ownership must use a dual-target action's cast recipient")
assert(not XelAssist.Core.PlayerNormalQueue:ServerAccepted(9001, selectedGuid)
    and XelAssist.Core.PlayerNormalQueue:Current() == dualQueue,
    "effect-target evidence must not release a different cast recipient")
assert(XelAssist.Core.PlayerNormalQueue:ServerAccepted(9001, petGuid)
    and not XelAssist.Core.PlayerNormalQueue:Current(),
    "matching cast-recipient evidence must release the dual-target action")

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

-- The opt-in GUID lane can execute one ordinary hostile spell without a
-- target switch, but only while the exact observed enemy remains engaged.
resetEffects()
XelAssistCharDB.toggles.engagedTargets = true
units.mouseovertarget = { guid = playerGuid }
currentPlan = hostilePlan(playerAction("Engaged Bolt"))
currentPlan.target, currentPlan.targetGUID = "mouseover", otherGuid
currentPlan.targetSource = "engaged"
currentPlan.targetRef = { unit = "mouseover", guid = otherGuid,
    relation = "hostile", source = "engaged",
    engagement = "attacking player" }
XelAssist:Execute()
assert(effects.queue == 1 and effects.queueGuid == otherGuid
    and effects.direct == 0 and effects.log == 1
    and effects.playerAttack == 0 and effects.observation == 1
    and effects.observationGuid == otherGuid
    and effects.observationTarget == nil,
    "an exact engaged hostile spell must use one GUID-pinned queue call")

local deadModes = { "nil", "error" }
local deadIndex
for deadIndex = 1, table.getn(deadModes) do
    resetEffects()
    units.mouseovertarget = { guid = playerGuid }
    deadStateMode = deadModes[deadIndex]
    currentPlan = hostilePlan(playerAction("Uncertain-life Engaged Bolt"))
    currentPlan.target, currentPlan.targetGUID = "mouseover", otherGuid
    currentPlan.targetSource = "engaged"
    currentPlan.targetRef = { unit = "mouseover", guid = otherGuid,
        relation = "hostile", source = "engaged" }
    XelAssist:Execute()
    assertNoExecution("an engaged target with unavailable life state reached the queue")
end

resetEffects()
units.mouseovertarget = { guid = playerGuid }
currentPlan = hostilePlan(playerAction("Victim-race Engaged Bolt"))
currentPlan.target, currentPlan.targetGUID = "mouseover", otherGuid
currentPlan.targetSource = "engaged"
currentPlan.targetRef = { unit = "mouseover", guid = otherGuid,
    relation = "hostile", source = "engaged" }
hooks.inRange = function() units.mouseovertarget.guid = selectedGuid end
XelAssist:Execute()
assertNoExecution("an enemy that left the active fight reached the queue")

resetEffects()
units.mouseovertarget = { guid = playerGuid }
currentPlan = hostilePlan(playerAction("Engaged Reactive Strike",
    { kind = "damage", reactive = true }))
currentPlan.target, currentPlan.targetGUID = "mouseover", otherGuid
currentPlan.targetSource = "engaged"
currentPlan.targetRef = { unit = "mouseover", guid = otherGuid,
    relation = "hostile", source = "engaged" }
XelAssist:Execute()
assertNoExecution("a reactive action reached the engaged GUID lane")

resetEffects()
units.mouseovertarget = { guid = playerGuid }
currentPlan = hostilePlan(playerAction("Future Engaged Bolt"))
currentPlan.target, currentPlan.targetGUID = "mouseover", otherGuid
currentPlan.targetSource, currentPlan.wait = "engaged", 0.75
currentPlan.targetRef = { unit = "mouseover", guid = otherGuid,
    relation = "hostile", source = "engaged" }
XelAssist:Execute()
assertNoExecution("an engaged plan with future wait time reached the queue")

resetEffects()
units.mouseovertarget = { guid = playerGuid }
currentPlan = hostilePlan(playerAction("Racing Engaged Bolt"))
currentPlan.target, currentPlan.targetGUID = "mouseover", otherGuid
currentPlan.targetSource = "engaged"
currentPlan.targetRef = { unit = "mouseover", guid = otherGuid,
    relation = "hostile", source = "engaged" }
hooks.inRange = function() units.mouseover.guid = selectedGuid end
XelAssist:Execute()
assertNoExecution("an engaged-hostile GUID race reached the queue")

resetEffects()
currentPlan = hostilePlan(playerAction("Unengaged Bolt"))
currentPlan.target, currentPlan.targetGUID = "mouseover", otherGuid
currentPlan.targetSource = "engaged"
currentPlan.targetRef = { unit = "mouseover", guid = otherGuid,
    relation = "hostile", source = "engaged" }
XelAssist:Execute()
assertNoExecution("an observed but unengaged hostile reached the queue")

resetEffects()
units.mouseovertarget = { guid = playerGuid }
currentPlan = hostilePlan(playerAction("Off-target Builder",
    { kind = "builder", melee = true }))
currentPlan.target, currentPlan.targetGUID = "mouseover", otherGuid
currentPlan.targetSource = "engaged"
currentPlan.targetRef = { unit = "mouseover", guid = otherGuid,
    relation = "hostile", source = "engaged" }
XelAssist:Execute()
assertNoExecution("a selected-only builder reached the engaged GUID lane")

resetEffects()
units.mouseovertarget = { guid = playerGuid }
currentPlan = hostilePlan(playerAction("Off-target Melee Strike",
    { kind = "damage", melee = true }))
currentPlan.target, currentPlan.targetGUID = "mouseover", otherGuid
currentPlan.targetSource = "engaged"
currentPlan.targetRef = { unit = "mouseover", guid = otherGuid,
    relation = "hostile", source = "engaged" }
XelAssist:Execute()
assertNoExecution("a selected-only melee action reached the engaged GUID lane")
XelAssistCharDB.toggles.engagedTargets = false

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
    playerAttack = true, ambient = true, startOnly = true,
    effectMinRange = 0, effectMaxRange = 5, effectRangeHitbox = true }))
XelAssist:Execute()
assert(effects.playerAttack == 1 and effects.queue == 0 and effects.direct == 0
    and effects.log == 1 and effects.observation == 0,
    "a valid player Attack must use only its guarded start command")

resetEffects()
currentPlan = hostilePlan(playerAction("Attack", { kind = "command",
    playerAttack = true, ambient = true, startOnly = true,
    effectMinRange = 0, effectMaxRange = 5, effectRangeHitbox = true }))
hooks.distance = function() units.target.guid = otherGuid end
XelAssist:Execute()
assertNoExecution("a selected-target GUID race reached AttackTarget")

resetEffects()
playerDistance = 12
currentPlan = hostilePlan(playerAction("Attack", { kind = "command",
    playerAttack = true, ambient = true, startOnly = true,
    effectMinRange = 0, effectMaxRange = 5, effectRangeHitbox = true }))
XelAssist:Execute()
assertNoExecution("Attack outside proven melee effect reach reached AttackTarget")

resetEffects()
playerDistance, playerDistanceKind = 4, "center"
currentPlan = hostilePlan(playerAction("Attack", { kind = "command",
    playerAttack = true, ambient = true, startOnly = true,
    effectMinRange = 0, effectMaxRange = 5, effectRangeHitbox = true }))
XelAssist:Execute()
assertNoExecution("center-only Attack geometry was treated as hitbox reach")

resetEffects()
playerDistance = 12
currentPlan = hostilePlan(playerAction("Soft Reach", { kind = "damage",
    ranged = true, effectMinRange = 0, effectMaxRange = 5,
    effectRangeHitbox = true }))
currentPlan.tooltip = { minRange = 0, maxRange = 30 }
XelAssist:Execute()
assertNoExecution("a command-range success bypassed the effect reach boundary")

resetEffects()
playerDistance = 4
currentPlan = hostilePlan(playerAction("Dead Zone", { kind = "damage",
    ranged = true, effectMinRange = 8, effectMaxRange = 30 }))
currentPlan.tooltip = { minRange = 8, maxRange = 30 }
XelAssist:Execute()
assertNoExecution("an explicit minimum-range violation reached the cast API")

resetEffects()
playerDistance, spellRangeVerdict = 40, true
currentPlan = hostilePlan(playerAction("Contradicted Bolt",
    { kind = "damage", ranged = true }))
currentPlan.tooltip = { minRange = 0, maxRange = 30 }
XelAssist:Execute()
assertNoExecution(
    "a permissive native verdict overrode the exact dispatch distance band")

resetEffects()
spellRangeVerdict = false
currentPlan = hostilePlan(playerAction("Raptor Strike",
    { kind = "damage", melee = true }))
currentPlan.tooltip = { gcd = 1.5, attributes = 4,
    onNextSwing = true, startRecoveryCategory = 0, normalGcd = false }
XelAssist:Execute()
assertNoExecution("an out-of-range on-swing action reached the queue API")

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

-- Fixed-pet player spells are implicit recipients, not range exemptions. A pet
-- that moved after planning must not receive a recorded ghost submission.
local function fixedPetPlan(name, kind, extra)
    local facts = { kind = kind, pet = true, fixedTarget = "pet" }
    local key, value
    for key, value in pairs(extra or {}) do facts[key] = value end
    return { action = playerAction(name, facts), actor = "player",
        target = "pet", targetGUID = petGuid, targetRelation = "pet",
        targetRef = { unit = "pet", guid = petGuid,
            relation = "pet", source = "controlled" },
        reason = "fixed pet boundary", confidence = "client data", value = 1,
        threat = 0, wait = 0, cast = 0, downtime = 0,
        observed = {}, follow = {}, path = {},
        tooltip = { minRange = 0, maxRange = 30 } }
end

resetEffects()
spellRangeVerdict = false
currentPlan = fixedPetPlan("Mend Pet", "petHeal", { channel = true })
XelAssist:Execute()
assertNoExecution("Mend Pet bypassed a fresh fixed-recipient range failure")

resetEffects()
spellRangeVerdict = false
currentPlan = fixedPetPlan("Bestial Wrath", "buff",
    { combatBuff = true, petCombatBuff = true })
XelAssist:Execute()
assertNoExecution("Bestial Wrath bypassed a fresh fixed-recipient range failure")

-- Dual-target Hunter buttons may cast on the captured pet, while their hostile
-- effect remains pinned to the selected target.
resetEffects()
local kill = playerAction("Kill Command", { kind = "damage", fixedTarget = "pet",
    effectTarget = "target", effectActor = "pet", requiresPetMelee = true,
    effectMinRange = 0, effectMaxRange = 5, commandMaxRange = 45 })
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
playerLineOfSight, playerBehind = false, false
petLineOfSight, petBehind = true, true
local positionedKill = playerAction("Positioned Kill Command", {
    kind = "damage", fixedTarget = "pet", effectTarget = "target",
    effectActor = "pet", requiresPetMelee = true, behind = true,
    effectMinRange = 0, effectMaxRange = 5, commandMaxRange = 45 })
currentPlan = hostilePlan(positionedKill)
currentPlan.castTarget, currentPlan.castTargetGUID = "pet", petGuid
currentPlan.castTargetRelation = "pet"
currentPlan.castTargetRef = { unit = "pet", guid = petGuid,
    relation = "pet", source = "controlled" }
XelAssist:Execute()
assert(effects.direct == 1 and effects.directUnit == petGuid
    and effects.log == 1,
    "a pet-owned effect must use pet line-of-sight and behind geometry")

resetEffects()
playerLineOfSight, petLineOfSight, petBehind = true, false, true
currentPlan = hostilePlan(positionedKill)
currentPlan.castTarget, currentPlan.castTargetGUID = "pet", petGuid
currentPlan.castTargetRelation = "pet"
currentPlan.castTargetRef = { unit = "pet", guid = petGuid,
    relation = "pet", source = "controlled" }
    XelAssist:Execute()
assert(effects.direct == 1 and effects.directUnit == petGuid
    and effects.log == 1,
    "an unproven pet line-of-sight hint must not suppress a reachable effect")

resetEffects()
currentPlan = hostilePlan(kill)
currentPlan.castTarget, currentPlan.castTargetGUID = "pet", petGuid
currentPlan.castTargetRelation = "pet"
currentPlan.castTargetRef = { unit = "pet", guid = petGuid,
    relation = "pet", source = "controlled" }
hooks.distance = function() units.target.guid = otherGuid end
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
    facts = { kind = "damage", melee = true } }
local function petPlan(action)
    local out = hostilePlan(action)
    out.tooltip = action.tooltip or { minRange = 0, maxRange = 5 }
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
petDistance = 12
currentPlan = petPlan(petAction)
XelAssist:Execute()
assertNoExecution("an out-of-range companion melee ability reached CastPetAction")

resetEffects()
petDistance = 35
local firebolt = { name = "Firebolt", spellId = 3, rank = 1, actor = "pet",
    executor = "petAbility", actionSlot = 5, actorRef = petAction.actorRef,
    facts = { kind = "damage", ranged = true },
    tooltip = { minRange = 0, maxRange = 30 } }
currentPlan = petPlan(firebolt)
XelAssist:Execute()
assertNoExecution("an out-of-range companion ranged ability reached CastPetAction")

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
petDistance = 40
geometryLineOfSight = false
currentPlan = petPlan(attack)
XelAssist:Execute()
assert(effects.petAttack == 1 and effects.petAbility == 0 and effects.log == 1,
    "Pet Attack must remain a legal engagement command outside effect reach")

resetEffects()
currentPlan = petPlan(attack)
currentPlan.target, currentPlan.targetGUID = "pettarget", selectedGuid
currentPlan.targetRef = { unit = "pettarget", guid = selectedGuid,
    relation = "hostile", source = "companion" }
XelAssist:Execute()
assertNoExecution("a crafted pettarget attack command reached PetAttack")

resetEffects()
local friendlyPetAction = { name = "Companion Aid", spellId = 4, rank = 1,
    actor = "pet", executor = "petAbility", actionSlot = 6,
    actorRef = petAction.actorRef, facts = { kind = "buff" },
    tooltip = { minRange = 0, maxRange = 30 } }
currentPlan = petPlan(friendlyPetAction)
currentPlan.target, currentPlan.targetGUID = "party1", allyGuid
currentPlan.targetRelation = "ally"
currentPlan.targetRef = { unit = "party1", guid = allyGuid,
    relation = "ally", source = "party" }
XelAssist:Execute()
assertNoExecution("an unpinnable arbitrary companion recipient reached CastPetAction")

resetEffects()
units.target = { guid = allyGuid }
petDistance = 20
currentPlan = petPlan(friendlyPetAction)
currentPlan.target, currentPlan.targetGUID = "target", allyGuid
currentPlan.targetRelation = "ally"
currentPlan.targetRef = { unit = "target", guid = allyGuid,
    relation = "ally", source = "selected" }
XelAssist:Execute()
assert(effects.petAbility == 1 and effects.petSlot == 6
    and effects.log == 1 and effects.pending == 1,
    "a selected friendly recipient must remain valid for stock CastPetAction")

resetEffects()
units.target = { guid = allyGuid, dead = true }
currentPlan = petPlan(friendlyPetAction)
currentPlan.target, currentPlan.targetGUID = "target", allyGuid
currentPlan.targetRelation = "ally"
currentPlan.targetRef = { unit = "target", guid = allyGuid,
    relation = "ally", source = "selected" }
XelAssist:Execute()
assertNoExecution("a defeated selected friendly reached CastPetAction")

resetEffects()
units.target = { guid = allyGuid, unassistable = true }
currentPlan = petPlan(friendlyPetAction)
currentPlan.target, currentPlan.targetGUID = "target", allyGuid
currentPlan.targetRelation = "ally"
currentPlan.targetRef = { unit = "target", guid = allyGuid,
    relation = "ally", source = "selected" }
XelAssist:Execute()
assertNoExecution("an unassistable selected friendly reached CastPetAction")

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
