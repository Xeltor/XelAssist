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

local function targetAuraState(encounter)
    local observed = encounter and encounter.targetHarmful
        and encounter.targetHarmful.byName or {}
    local families, actions, i = {}, XelAssist.Game.Actors and XelAssist.Game.Actors:Actions() or {}, nil
    for i = 1, table.getn(actions) do
        local action = actions[i]
        if action and action.name and action.facts and action.facts.exclusiveFamily then
            families[action.name] = action.facts.exclusiveFamily
        end
    end
    local out, name, aura = {}, nil, nil
    for name, aura in pairs(observed) do
        if type(aura) == "table" then
            local copy, key, value = {}, nil, nil
            for key, value in pairs(aura) do copy[key] = value end
            copy.exclusiveFamily = copy.exclusiveFamily or families[name]
            out[name] = copy
        else out[name] = aura end
    end
    return out
end

local function currentPlayerCast()
    local castName, castRemaining, casting, gcdRemaining =
        XelAssist.Game.Capabilities:CurrentCast()
    if not casting and XelAssist.playerCastUntil
        and XelAssist.playerCastUntil > GetTime() then
        castName, castRemaining, casting = XelAssist.playerCastName,
            XelAssist.playerCastUntil - GetTime(), true
    end
    return castName, castRemaining, casting, gcdRemaining
end

local function targetModifierState(encounter, hostile)
    local resistance = hostile and XelAssist.Combat.Resistance
        and XelAssist.Combat.Resistance:Snapshot("target", encounter) or nil
    if resistance then resistance.baseProjectedReduction = {} end
    local reduction, damageTaken, source, effects, auras =
        S:ActiveTargetModifiers(encounter, resistance)
    if resistance and reduction then
        resistance.rootModifierReduction = reduction
        if not resistance.live then
            resistance.projectedReduction = reduction
            resistance.projectedBy = "active "
                .. tostring(source or "target debuff")
        end
    end
    return resistance, damageTaken, source, effects, auras
end

function S:Snapshot(mode)
    local actors = XelAssist.Game.Actors:Snapshot()
    local encounter = XelAssist.Game.Encounter and XelAssist.Game.Encounter:Snapshot() or nil
    local inventory = XelAssist.Game.Inventory and XelAssist.Game.Inventory:Snapshot() or nil
    local friendlies = XelAssist.Game.Friendlies and XelAssist.Game.Friendlies:Snapshot(actors) or nil
    local primaryKey = friendlies and (friendlies.primaryKey
        or friendlies.order and friendlies.order[1]) or nil
    local primary = primaryKey and friendlies.byKey and friendlies.byKey[primaryKey] or nil
    if friendlies then friendlies.primaryKey = primaryKey end
    local healUnit = primary and primary.unit or "player"
    local healHealth = primary and primary.health or UnitHealth("player") or 0
    local healMax = primary and primary.healthMax or UnitHealthMax("player") or 0
    local castName, castRemaining, casting, gcdRemaining = currentPlayerCast()
    local hostile = UnitExists("target") and not UnitIsDead("target")
        and UnitCanAttack("player", "target")
    local targetHealth, targetMax, targetHealthExact = 0, 0, false
    if hostile then
        targetHealth, targetMax, targetHealthExact =
            XelAssist.Game.Capabilities:Health("target")
    end
    local role = XelAssistCharDB.role or "auto"
    local targetDistance, targetDistanceKind =
        XelAssist.Game.Capabilities:Distance(hostile and "target" or nil)
    local healDistance, healDistanceKind = primary and primary.distance,
        primary and primary.distanceKind
    if healDistance == nil then
        healDistance, healDistanceKind = XelAssist.Game.Capabilities:Distance(healUnit)
    end
    local distance = hostile and targetDistance or healDistance
    local distanceKind = hostile and targetDistanceKind or healDistanceKind
    local targetGeometry = XelAssist.Game.Capabilities:Geometry("player", "target")
    local _, currentTargetGUID = UnitExists("target")
    local hostileTargetRef = hostile and XelAssist.Game.Capabilities.UnitRef
        and XelAssist.Game.Capabilities:UnitRef("target", "hostile", "selected") or nil
    local targetCasting = XelAssist and XelAssist.targetCastUntil
        and XelAssist.targetCastUntil > GetTime()
        and XelAssist.targetCastGUID == currentTargetGUID
    local targetResistance, targetDamageTaken, activeModifierSource,
        activeModifierEffects, rootModifierAuras =
        targetModifierState(encounter, hostile)
    return {
        mode = mode, hostile = hostile, targetGUID = currentTargetGUID,
        targetRef = hostileTargetRef, friendlies = friendlies, healUnit = healUnit,
        health = UnitHealth("player") or 0, healthMax = UnitHealthMax("player") or 0,
        healHealth = healHealth, healMax = healMax,
        targetHealth = targetHealth, targetMax = targetMax,
        targetHealthExact = targetHealthExact,
        targetCreatureType = hostile and UnitCreatureType
            and UnitCreatureType("target") or nil,
        targetResistances = targetResistance and targetResistance.live or nil,
        targetResistance = targetResistance,
        targetDamageTaken = targetDamageTaken,
        baseTargetDamageTaken = activeModifierEffects and {} or nil,
        targetModifierEffects = activeModifierEffects,
        activeModifierSource = activeModifierSource,
        playerLevel = UnitLevel and UnitLevel("player") or nil,
        inCombat = UnitAffectingCombat and UnitAffectingCombat("player") and true or false,
        resource = UnitMana("player") or 0,
        resourceMax = UnitManaMax("player") or 0,
        resourceType = UnitPowerType and UnitPowerType("player") or nil,
        combo = GetComboPoints and GetComboPoints() or 0,
        moving = PlayerIsMoving and PlayerIsMoving() or false,
        pet = actors.pet ~= nil, actors = actors, inventory = inventory,
        encounter = encounter, targetAuras = targetAuraState(encounter),
        targetCasting = targetCasting and true or false,
        targetCastRemaining = targetCasting
            and (XelAssist.targetCastUntil - GetTime()) or 0,
        playerCasting = casting, playerCastName = castName,
        castRemaining = castRemaining or 0,
        groupSize = (GetNumRaidMembers and GetNumRaidMembers() or 0)
            + (GetNumPartyMembers and GetNumPartyMembers() or 0),
        hasAggro = hostile and UnitExists("targettarget")
            and UnitIsUnit("targettarget", "player"),
        tank = role == "tank" or (role == "auto" and inferredTank()), role = role,
        distance = distance, distanceKind = distanceKind,
        targetDistance = targetDistance, targetDistanceKind = targetDistanceKind,
        targetLineOfSight = targetGeometry.lineOfSight,
        playerBehindTarget = targetGeometry.behind,
        healDistance = healDistance, healDistanceKind = healDistanceKind,
        talentPoints = XelAssist.Game.Capabilities:TalentPoints(),
        instantNext = XelAssist.Game.Capabilities:UnitHasBuff("player", "Nature's Swiftness")
            or XelAssist.Game.Capabilities:UnitHasBuff("player", "Presence of Mind"),
        auras = rootModifierAuras or {}, absorbs = {}, readyAt = {}, time = 0,
        actorReadyAt = { player = math.max(castRemaining or 0,
            gcdRemaining or 0, XelAssist.Game.Capabilities:GCDRemaining()),
            pet = actors.pet and (actors.pet.castRemaining or 0) or 0 },
    }
end

local function identityField(field)
    if type(field) ~= "string" then return false end
    local lower = string.lower(field)
    return lower == "key" or string.sub(lower, -4) == "guid"
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
        out[key] = copyNested(entry, depth - 1, seen, key, atomic)
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
    out.auras = copyNested(state.auras or {}, 3, seen, nil, atomic)
    out.absorbs = copyNested(state.absorbs or {}, 3, seen, nil, atomic)
    out.readyAt = copyNested(state.readyAt or {}, 2, seen, nil, atomic)
    out.actorReadyAt = copyNested(state.actorReadyAt or {}, 2, seen, nil, atomic)
    if state.actors then out.actors = copyNested(state.actors, 4, seen, nil, atomic) end
    if state.friendlies then
        if XelAssist.Game.Friendlies and XelAssist.Game.Friendlies.Copy then
            out.friendlies = XelAssist.Game.Friendlies:Copy(state.friendlies)
        else out.friendlies = copyNested(state.friendlies, 6, seen, nil, atomic) end
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
    return out
end
