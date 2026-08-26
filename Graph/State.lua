-- Root combat-state observation and copying for the action graph. Identity
-- values from SuperWoW stay opaque: they are compared and indexed, never
-- stringified, parsed, persisted, or exposed as unit labels.
XelAssist.Graph.State = {}
local S = XelAssist.Graph.State
function S:FriendlyByKey(state, key)
    if key == nil or not state or not state.friendlies
        or not state.friendlies.byKey then return nil end
    return state.friendlies.byKey[key]
end
function S:FriendlyByUnit(state, unit)
    if not state or not state.friendlies or not state.friendlies.byUnit then return nil end
    return self:FriendlyByKey(state, state.friendlies.byUnit[unit])
end
function S:PrimaryFriendly(state)
    local friendlies = state and state.friendlies
    local key = friendlies and (friendlies.primaryKey
        or friendlies.order and friendlies.order[1]) or nil
    return self:FriendlyByKey(state, key)
end
function S:HostileByKey(state, key)
    return XelAssist.Graph.HostileState:ByKey(state, key)
end
function S:HostileByUnit(state, unit)
    return XelAssist.Graph.HostileState:ByUnit(state, unit)
end

function S:SelectedHostile(state)
    return XelAssist.Graph.HostileState:Selected(state)
end

function S:ActiveHostile(state)
    return XelAssist.Graph.HostileState:Active(state)
end

function S:SyncSelectedHostile(state)
    return XelAssist.Graph.HostileState:SyncSelected(state)
end

function S:SyncHostileContext(state, key)
    return XelAssist.Graph.HostileState:SyncContext(state, key)
end

function S:SyncActiveHostile(state)
    return XelAssist.Graph.HostileState:SyncActive(state)
end

function S:RefreshHostileRecord(state, key)
    return XelAssist.Graph.HostileState:RefreshRecord(state, key)
end

function S:CommitSelectedHostile(state)
    return XelAssist.Graph.HostileState:CommitSelected(state)
end

function S:CommitHostileContext(state, key)
    return XelAssist.Graph.HostileState:CommitContext(state, key)
end

function S:CommitActiveHostile(state)
    return XelAssist.Graph.HostileState:CommitActive(state)
end

function S:HostileContext(state, key)
    return XelAssist.Graph.HostileState:Context(state, key)
end

function S:SelectedHostileContext(state)
    return XelAssist.Graph.HostileState:SelectedContext(state)
end

function S:Missing(record)
    if not record then return 0 end
    return math.max(0, (tonumber(record.healthMax) or 0)
        - (tonumber(record.health) or 0))
end

function S:Descriptor(unit, relation, source, guid, key, record)
    local ref = record and record.targetRef or nil
    if not ref and XelAssist.Game.Capabilities and XelAssist.Game.Capabilities.UnitRef
        and unit and (relation == "friendly" or relation == "ally"
            or relation == "self" or relation == "pet") then
        ref = XelAssist.Game.Capabilities:UnitRef(unit, relation, source)
    end
    if ref then guid, relation, source = ref.guid, ref.relation, ref.source end
    return { unit = unit, relation = relation, source = source, guid = guid,
        key = key or guid or unit, record = record, targetRef = ref }
end

local function inferredTank()
    local _, class = UnitClass("player")
    local form = GetShapeshiftForm and GetShapeshiftForm() or 0
    if class == "WARRIOR" and form == 2 then return true end
    if class == "DRUID" and form == 1 then return true end
    if class == "PALADIN" and XelAssist.Game.Capabilities:UnitHasBuff(
        "player", "Righteous Fury") then return true end
    return false
end

function S:ActiveTargetModifiers(encounter, targetResistance)
    return XelAssist.Combat.TargetModifiers:Active(encounter, targetResistance)
end

local function currentPlayerCast()
    local castName, castRemaining, casting, gcdRemaining, channeling, spellId =
        XelAssist.Game.Capabilities:CurrentCast()
    if not casting and XelAssist.playerCastUntil
        and XelAssist.playerCastUntil > GetTime() then
        castName, castRemaining, casting = XelAssist.playerCastName,
            XelAssist.playerCastUntil - GetTime(), true
        channeling = XelAssist.playerCastChannel and true or false
        spellId = XelAssist.playerCastSpellId
    end
    return castName, castRemaining, casting, gcdRemaining, channeling, spellId
end

local function autoShotState(inventory, hostile, moving, casting, channeling,
    targetGuid, targetDistance, targetDistanceKind, targetGeometry)
    if not XelAssist.Combat.AutoShot then return nil end
    local evidence = { hostile = hostile and true or false, moving = moving,
        casting = casting and not channeling and true or false,
        channeling = channeling and true or false, distance = targetDistance,
        distanceKind = targetDistanceKind,
        lineOfSight = targetGeometry.lineOfSight }
    local evidenceSpellId = XelAssist.Combat.AutoShot:EvidenceSpellId()
    evidence = XelAssist.Combat.AutoShotRange:Evidence(
        evidence, targetGuid, evidenceSpellId)
    local auto = XelAssist.Combat.AutoShot:Snapshot(evidence)
    if auto and inventory and inventory.ammo and inventory.ammo.known
        and not auto.ammoKnown then
        auto.ammoKnown, auto.ammoCount = true, inventory.ammo.count
    end
    return auto
end

local function wandState(hostile, moving, casting, channeling, targetGuid)
    if not XelAssist.Combat.Wand then return nil end
    local wand = XelAssist.Combat.Wand:Snapshot({ hostile = hostile and true or false,
        moving = moving and true or false,
        casting = casting and not channeling and true or false,
        channeling = channeling and true or false, targetGuid = targetGuid })
    if wand then
        wand.speed, wand.damage = wand.rangedSpeed, wand.rangedDamage
        if wand.active then wand.nextShotIn = wand.speed end
    end
    return wand
end

local function snapshotContext()
    local actors = XelAssist.Game.Actors:Snapshot()
    local encounter = XelAssist.Game.Encounter and XelAssist.Game.Encounter:Snapshot() or nil
    local inventory = XelAssist.Game.Inventory and XelAssist.Game.Inventory:Snapshot() or nil
    local friendlies = XelAssist.Game.Friendlies and XelAssist.Game.Friendlies:Snapshot(actors) or nil
    local target = XelAssist.Graph.HostileState:Observe(encounter)
    local primaryKey = friendlies and (friendlies.primaryKey
        or friendlies.order and friendlies.order[1]) or nil
    local primary = primaryKey and friendlies.byKey and friendlies.byKey[primaryKey] or nil
    if friendlies then friendlies.primaryKey = primaryKey end
    local healUnit = primary and primary.unit or "player"
    local healHealth = primary and primary.health or UnitHealth("player") or 0
    local healMax = primary and primary.healthMax or UnitHealthMax("player") or 0
    local castName, castRemaining, casting, gcdRemaining, channeling, castSpellId =
        currentPlayerCast()
    local moving = PlayerIsMoving and PlayerIsMoving() or false
    local spatialLineOfSight, spatialBehind = target.geometry.lineOfSight,
        target.geometry.behind
    if XelAssist.Game.SpatialEvidence then
        moving, spatialLineOfSight, spatialBehind =
            XelAssist.Game.SpatialEvidence:Snapshot(target.guid, moving,
                target.geometry.lineOfSight, target.geometry.behind)
    end
    local role = XelAssistCharDB.role or "auto"
    local healDistance, healDistanceKind = primary and primary.distance,
        primary and primary.distanceKind
    if healDistance == nil then
        healDistance, healDistanceKind = XelAssist.Game.Capabilities:Distance(healUnit)
    end
    local distance = target.hostile and target.distance or healDistance
    local distanceKind = target.hostile and target.distanceKind or healDistanceKind
    local autoShot = autoShotState(inventory, target.hostile, moving,
        casting, channeling, target.guid, target.distance,
        target.distanceKind, target.geometry)
    local wand = wandState(target.hostile, moving, casting, channeling, target.guid)
    local playerAttack = XelAssist.Game.PlayerAttack
        and XelAssist.Game.PlayerAttack:Snapshot() or nil
    local engagement = XelAssist.Game.Player and XelAssist.Game.Player.Engagement
    local playerStealthed, playerStealthKnown, playerStealthSource = nil, false,
        "stealth state unavailable"
    if engagement then
        playerStealthed, playerStealthKnown, playerStealthSource =
            engagement:StealthState()
    end
    local onSwing = playerAttack and playerAttack.onSwing
    local onSwingCost = onSwing and onSwing.costKnown ~= false
        and tonumber(onSwing.cost) or nil
    local playerResourceReserved = onSwing and onSwing.occupied
        and (onSwingCost or UnitMana("player") or 0) or 0
    local comboObservation = XelAssist.Game.ComboMechanics
        and XelAssist.Game.ComboMechanics:Observe(target.guid, target.hostile)
        or { points = GetComboPoints and GetComboPoints() or 0,
            ownerGUID = target.guid, selectedExact = true,
            globalExact = false, source = "stock combo state" }
    local hitBonuses = XelAssist.Game.HitBonuses
        and XelAssist.Game.HitBonuses:Snapshot() or nil
    return {
        actors = actors, encounter = encounter, inventory = inventory,
        friendlies = friendlies, target = target, healUnit = healUnit,
        healHealth = healHealth, healMax = healMax, castName = castName,
        castRemaining = castRemaining, casting = casting,
        castSpellId = castSpellId,
        castTargetGUID = XelAssist.playerCastTargetGUID,
        gcdRemaining = gcdRemaining, channeling = channeling, moving = moving,
        spatialLineOfSight = spatialLineOfSight, spatialBehind = spatialBehind,
        role = role, healDistance = healDistance,
        healDistanceKind = healDistanceKind, distance = distance,
        distanceKind = distanceKind, autoShot = autoShot, wand = wand,
        playerAttack = playerAttack, playerStealthed = playerStealthed,
        playerStealthKnown = playerStealthKnown,
        playerStealthSource = playerStealthSource, onSwing = onSwing,
        onSwingCost = onSwingCost, playerResourceReserved = playerResourceReserved,
        comboObservation = comboObservation, hitBonuses = hitBonuses,
    }
end

local function newState(mode, context)
    local actors, target = context.actors, context.target
    local state = {
        mode = mode, hostile = target.hostile, targetGUID = target.guid,
        targetRef = target.ref, friendlies = context.friendlies,
        hostiles = target.hostiles, healUnit = context.healUnit,
        health = UnitHealth("player") or 0, healthMax = UnitHealthMax("player") or 0,
        healHealth = context.healHealth, healMax = context.healMax,
        targetHealth = target.health, targetMax = target.healthMax,
        targetHealthExact = target.healthExact,
        targetSurvival = target.survival,
        targetCreatureType = target.creatureType,
        targetResistances = target.resistances,
        targetResistance = target.resistance,
        targetDamageTaken = target.damageTaken,
        baseTargetDamageTaken = target.baseDamageTaken,
        targetModifierEffects = target.modifierEffects,
        activeModifierSource = target.modifierSource,
        playerLevel = UnitLevel and UnitLevel("player") or nil,
        inCombat = UnitAffectingCombat and UnitAffectingCombat("player") and true or false,
        resource = UnitMana("player") or 0,
        resourceMax = UnitManaMax("player") or 0,
        resourceType = UnitPowerType and UnitPowerType("player") or nil,
        combo = context.comboObservation.points or 0,
        comboTargetGUID = context.comboObservation.ownerGUID,
        hitBonuses = context.hitBonuses,
        moving = context.moving,
        pet = actors.pet ~= nil, petLifecycle = actors.petLifecycle,
        actors = actors, inventory = context.inventory,
        autoShot = context.autoShot, wand = context.wand,
        playerAttack = context.playerAttack,
        playerStealthed = context.playerStealthed,
        playerStealthKnown = context.playerStealthKnown,
        playerStealthSource = context.playerStealthSource,
        playerResourceReserved = context.playerResourceReserved,
        playerResourceExact = not (context.onSwing and context.onSwing.occupied
            and context.onSwingCost == nil),
        encounter = context.encounter, targetAuras = target.targetAuras,
        targetCasting = target.casting,
        targetCastRemaining = target.castRemaining,
        playerCasting = context.casting,
        playerChanneling = context.channeling and true or false,
        playerCastName = context.castName,
        playerCastSpellId = context.castSpellId,
        playerCastTargetGUID = context.castTargetGUID,
        castRemaining = context.castRemaining or 0,
        groupSize = (GetNumRaidMembers and GetNumRaidMembers() or 0)
            + (GetNumPartyMembers and GetNumPartyMembers() or 0),
        hasAggro = target.hasAggro,
        targetPlayerThreatDeltaExact = true,
        tank = context.role == "tank"
            or (context.role == "auto" and inferredTank()), role = context.role,
        distance = context.distance, distanceKind = context.distanceKind,
        targetDistance = target.distance, targetDistanceKind = target.distanceKind,
        targetLineOfSight = context.spatialLineOfSight,
        playerBehindTarget = context.spatialBehind,
        spatialTargetGUID = target.guid,
        spatialTargetLineOfSight = context.spatialLineOfSight,
        spatialPlayerBehindTarget = context.spatialBehind,
        healDistance = context.healDistance,
        healDistanceKind = context.healDistanceKind,
        talentPoints = XelAssist.Game.Capabilities:TalentPoints(),
        instantNext = XelAssist.Game.Capabilities:UnitHasBuff("player", "Nature's Swiftness")
            or XelAssist.Game.Capabilities:UnitHasBuff("player", "Presence of Mind"),
        auras = target.projectedAuras, absorbs = {}, readyAt = {}, time = 0,
        playerGcdReadyAt = math.max(context.gcdRemaining or 0,
            XelAssist.Game.Capabilities:GCDRemaining()),
        actorReadyAt = { player = math.max(context.castRemaining or 0, 0),
            pet = actors.pet and (actors.pet.castRemaining or 0) or 0 },
    }
    return state
end

local function attachPlayerResource(state, actors)
    local energy = XelAssist.Game.Player and XelAssist.Game.Player.EnergyEvidence
    local resources = XelAssist.Game.Player and XelAssist.Game.Player.Resources
    if energy and resources then
        local clock = energy:Observe(actors.player and actors.player.guid,
            state.resource, state.resourceMax, GetTime(), false,
            state.resourceType)
        resources:Attach(state, clock)
    end
end
function S:Snapshot(mode)
    local context = snapshotContext()
    local state = newState(mode, context)
    if XelAssist.Graph.DruidForms then XelAssist.Graph.DruidForms:Attach(state) end
    local reactive = XelAssist.Game.Player and XelAssist.Game.Player.ReactiveEvidence
    if reactive then state.playerReactive = reactive:Snapshot() end
    local threat = XelAssist.Game.Player and XelAssist.Game.Player.Threat
    if threat then state.playerThreat = threat:Snapshot() end
    if XelAssist.Graph.ComboState then
        XelAssist.Graph.ComboState:Attach(state, state.combo,
            state.comboTargetGUID, context.comboObservation)
    end
    attachPlayerResource(state, context.actors)
    if XelAssist.Graph.HostileCastState then XelAssist.Graph.HostileCastState:Attach(state, GetTime and GetTime() or 0) end
    if context.target.hostiles then self:SyncSelectedHostile(state) end
    if XelAssist.Graph.AutoShotUncertainty then
        XelAssist.Graph.AutoShotUncertainty:Apply(state, context.autoShot)
    end
    state.distance = state.hostile and state.targetDistance or context.healDistance
    state.distanceKind = state.hostile and state.targetDistanceKind
        or context.healDistanceKind
    return state
end
local function identityField(field)
    if type(field) ~= "string" then return false end
    local lower = string.lower(field)
    return lower == "key" or string.sub(lower, -4) == "guid"
end

local function identityMap(field)
    if type(field) ~= "string" then return false end
    local lower = string.lower(field)
    return lower == "bykey" or string.sub(lower, -5) == "bykey"
end

local function copyNested(value, depth, seen, field, atomic)
    if type(value) ~= "table" or depth <= 0 then return value end
    if identityField(field) or atomic and atomic[value] then return value end
    seen = seen or {}
    if seen[value] then return seen[value] end
    local out, key, entry = {}, nil, nil
    seen[value] = out
    for key, entry in pairs(value) do
        -- Keys can themselves be opaque identities and remain unchanged.
        local childField = key
        if identityMap(field) then childField = nil end
        out[key] = copyNested(entry, depth - 1, seen, childField, atomic)
    end
    return out
end

function S:Copy(state)
    local out, key, value = {}, nil, nil
    for key, value in pairs(state) do out[key] = value end
    local seen, atomic = {}, {}
    if state.friendlies and state.friendlies.byKey then
        local record
        for key, record in pairs(state.friendlies.byKey) do
            if type(key) == "table" then atomic[key] = true end
            if type(record) == "table" and type(record.guid) == "table" then
                atomic[record.guid] = true
            end
        end
    end
    if state.hostiles and state.hostiles.byKey then
        local record
        for key, record in pairs(state.hostiles.byKey) do
            if type(key) == "table" then atomic[key] = true end
            if type(record) == "table" and type(record.guid) == "table" then
                atomic[record.guid] = true
            end
        end
    end
    out.auras = copyNested(state.auras or {}, 4, seen, nil, atomic)
    out.absorbs = copyNested(state.absorbs or {}, 3, seen, nil, atomic)
    out.readyAt = copyNested(state.readyAt or {}, 2, seen, nil, atomic)
    out.actorReadyAt = copyNested(state.actorReadyAt or {}, 2, seen, nil, atomic)
    if state.comboBranches then
        out.comboBranches = copyNested(
            state.comboBranches, 3, seen, nil, atomic)
    end
    if state.actors then out.actors = copyNested(state.actors, 4, seen, nil, atomic) end
    if state.petLifecycle then
        out.petLifecycle = copyNested(state.petLifecycle, 3, seen, nil, atomic)
    end
    if state.friendlies then
        if XelAssist.Game.Friendlies and XelAssist.Game.Friendlies.Copy then
            out.friendlies = XelAssist.Game.Friendlies:Copy(state.friendlies)
        else out.friendlies = copyNested(state.friendlies, 6, seen, nil, atomic) end
    end
    if state.hostiles then
        out.hostiles = copyNested(state.hostiles, 9, seen, nil, atomic)
    end
    if state.targetRef then out.targetRef = copyNested(state.targetRef, 2, seen) end
    if state.targetAuras then out.targetAuras = copyNested(state.targetAuras, 3, seen) end
    if state.targetResistance then
        out.targetResistance = copyNested(state.targetResistance, 4, seen)
        if state.targetResistances == state.targetResistance.live then
            out.targetResistances = out.targetResistance.live
        end
    end
    if state.targetDamageTaken then
        out.targetDamageTaken = copyNested(state.targetDamageTaken, 2, seen)
    end
    if state.baseTargetDamageTaken then
        out.baseTargetDamageTaken = copyNested(state.baseTargetDamageTaken, 2, seen)
    end
    if state.targetModifierEffects then
        out.targetModifierEffects = copyNested(state.targetModifierEffects, 4, seen)
    end
    if state.inventory then
        out.inventory = copyNested(state.inventory, 2, seen)
        if state.inventory.itemCounts then
            out.inventory.itemCounts = copyNested(state.inventory.itemCounts, 2, seen)
        end
        if state.inventory.reagentCounts then
            out.inventory.reagentCounts = copyNested(state.inventory.reagentCounts, 2, seen)
        end
    end
    if state.autoShot then
        out.autoShot = copyNested(state.autoShot, 2, seen, nil, atomic)
    end
    if state.wand then
        out.wand = copyNested(state.wand, 2, seen, nil, atomic)
    end
    if state.playerAttack then
        out.playerAttack = copyNested(state.playerAttack, 2, seen, nil, atomic)
    end
    if state.playerResourceClock then
        out.playerResourceClock = copyNested(
            state.playerResourceClock, 2, seen, nil, atomic)
    end
    if state.druidFormState then out.druidFormState = copyNested(
        state.druidFormState, 4, seen, nil, atomic) end
    if state.hostileCasts and XelAssist.Graph.HostileCastState then out.hostileCasts =
        XelAssist.Graph.HostileCastState:Copy(state.hostileCasts, out) end
    if out.hostiles then
        if state.targetContextKey ~= nil then
            XelAssist.Graph.HostileState:SyncContext(out, state.targetContextKey)
        else self:SyncSelectedHostile(out) end
    end
    return out
end
