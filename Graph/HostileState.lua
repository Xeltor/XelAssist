-- Target-local graph state built from the bounded hostile observation set.
-- Game.Hostiles owns live observation; this module owns mutable projections.
XelAssist.Graph.HostileState = {}
local H = XelAssist.Graph.HostileState

local function identityField(field)
    if type(field) ~= "string" then return false end
    local lower = string.lower(field)
    return lower == "key" or lower == "targetkey"
        or string.sub(lower, -4) == "guid"
end

local function copyAura(value, depth, field, seen)
    if type(value) ~= "table" or depth <= 0 then return value end
    if identityField(field) then return value end
    seen = seen or {}
    if seen[value] then return seen[value] end
    local out, key, entry = {}, nil, nil
    seen[value] = out
    for key, entry in pairs(value) do
        out[key] = copyAura(entry, depth - 1, key, seen)
    end
    return out
end

function H:ByKey(state, key)
    if key == nil or not state or not state.hostiles
        or not state.hostiles.byKey then return nil end
    return state.hostiles.byKey[key]
end

function H:ByUnit(state, unit)
    if not state or not state.hostiles or not state.hostiles.byUnit then return nil end
    return self:ByKey(state, state.hostiles.byUnit[unit])
end

function H:Selected(state)
    local hostiles = state and state.hostiles
    local selected = self:ByKey(state, hostiles and hostiles.selectedKey)
    if selected then return selected end
    local i, record
    for i = 1, table.getn(hostiles and hostiles.order or {}) do
        record = self:ByKey(state, hostiles.order[i])
        if record and record.selected then return record end
    end
    return nil
end

function H:Active(state)
    if state and state.targetContextKey ~= nil then
        return self:ByKey(state, state.targetContextKey)
    end
    return self:Selected(state)
end

local function sync(state, record)
    state.hostile = record ~= nil and record.dead ~= true
        and (record.selected ~= false or state.targetContextKey ~= nil) or false
    state.targetGUID, state.targetRef = record and record.guid, record and record.targetRef
    state.targetHealth = record and (tonumber(record.health) or 0) or 0
    state.targetMax = record and (tonumber(record.healthMax) or 0) or 0
    state.targetHealthExact = record and record.healthExact == true or false
    state.targetSurvival = record and record.survival or nil
    state.targetCreatureType = record and record.encounter
        and record.encounter.creatureType or nil
    state.targetReaction = record and (record.reaction
        or record.encounter and record.encounter.reaction) or nil
    state.targetAuras = record and record.targetAuras or {}
    state.auras = record and record.projectedAuras or {}
    state.targetResistance = record and record.resistance or nil
    state.targetResistances = record and record.resistances or nil
    state.targetDamageTaken = record and record.damageTaken or nil
    state.baseTargetDamageTaken = record and record.baseDamageTaken or nil
    state.targetModifierEffects = record and record.modifierEffects or nil
    state.activeModifierSource = record and record.activeModifierSource or nil
    state.targetCasting = record and record.casting
    state.targetCastRemaining = record and (tonumber(record.castRemaining) or 0) or 0
    state.targetCastProbability = record and record.castProbability or nil
    if record and record.threat then
        state.targetPlayerThreatDeltaExact = record.threat.playerDeltaExact ~= false
        if record.threat.projectedPlayerReferenceKnown
            and record.threat.projectedPlayerReference == false then
            state.hasAggro = false
        elseif record.threat.projectedPlayerOwnershipUnknown
            or record.threat.projectedOwnershipUnknown then
            state.hasAggro = nil
        elseif record.threat.projectedPlayerHasAggro ~= nil then
            state.hasAggro = record.threat.projectedPlayerHasAggro
        else state.hasAggro = record.threat.playerHasAggro end
        -- Only the selected/root compatibility view may update actor-global
        -- pet aggro. Off-target contexts are shallow views and must not leak.
        if state.targetContextKey == nil and state.actors and state.actors.pet then
            if record.threat.projectedOwnershipUnknown then
                state.actors.pet.hasAggro = nil
            elseif record.threat.projectedPetHasAggro ~= nil then
                state.actors.pet.hasAggro = record.threat.projectedPetHasAggro
            end
        end
    else
        state.hasAggro = record and record.hasPlayerAggro
        state.targetPlayerThreatDeltaExact = true
    end
    state.targetDistance = record and record.distance or nil
    state.targetDistanceKind = record and record.distanceKind or nil
    local spatial = record and state.spatialTargetGUID ~= nil
        and record.guid == state.spatialTargetGUID
    if spatial then
        state.targetLineOfSight = state.spatialTargetLineOfSight
        state.playerBehindTarget = state.spatialPlayerBehindTarget
    else
        state.targetLineOfSight = record and record.lineOfSight
        state.playerBehindTarget = record and record.behind
    end
end

local function commit(state, record)
    if not (state and record) or state.targetGUID ~= record.guid then
        return nil
    end
    record.health = tonumber(state.targetHealth) or record.health
    record.healthMax = tonumber(state.targetMax) or record.healthMax
    record.healthExact = state.targetHealthExact == true
    record.targetAuras = state.targetAuras or {}
    record.projectedAuras = state.auras or {}
    record.resistance = state.targetResistance
    if record.resistance and record.resistance.live ~= nil then
        record.resistances = record.resistance.live
    else record.resistances = state.targetResistances end
    record.damageTaken = state.targetDamageTaken
    record.baseDamageTaken = state.baseTargetDamageTaken
    record.modifierEffects = state.targetModifierEffects
    record.activeModifierSource = state.activeModifierSource
    record.casting = state.targetCasting
    record.castProbability = state.targetCastProbability
    if state.targetCasting ~= nil or state.targetCastProbability ~= nil then
        record.castRemaining = tonumber(state.targetCastRemaining) or 0
    end
    if record.threat then
        -- Live victim evidence is immutable inside lookahead. Actions change a
        -- projected victim view, never the observation that seeded this state.
        record.threat.projectedPlayerHasAggro = state.hasAggro
        record.threat.playerDeltaExact = state.targetPlayerThreatDeltaExact ~= false
    end
    if record.healthExact and tonumber(record.health) and record.health <= 0 then
        record.dead, record.projectedDefeated = true, true
    end
    return record
end

function H:SyncSelected(state)
    if not state or not state.hostiles then return state end
    state.targetContextKey = nil
    local record = self:Selected(state)
    sync(state, record)
    state.encounter = record and record.context or state.encounter
    return state
end

function H:SyncContext(state, key)
    local record = self:ByKey(state, key)
    if not record then return state end
    state.targetContextKey = key
    sync(state, record)
    state.encounter = record.context or state.encounter
    return state
end

function H:SyncActive(state)
    if not state or not state.hostiles then return state end
    if state.targetContextKey ~= nil then
        return self:SyncContext(state, state.targetContextKey)
    end
    return self:SyncSelected(state)
end

local function pinnedGuid(value)
    return value and (value.targetGuid
        or value.attackRound and value.attackRound.targetGuid
        or value.offhandAttackRound
            and value.offhandAttackRound.targetGuid) or nil
end

local function stopPinned(state, record, field)
    local value = state and state[field]
    if not (value and record and record.dead == true) then return end
    local guid = pinnedGuid(value)
    if guid == record.guid or guid == nil and record.selected == true then
        value.active = false
        value.activeKnown = true
    end
end

-- Record-local ambient events may update any observed enemy. Refresh only the
-- compatibility view that was already active; never switch targets as a side
-- effect of a selected-target swing, projectile, pet event, or periodic tick.
function H:RefreshRecord(state, key)
    local record = self:ByKey(state, key)
    if not record then return state end
    stopPinned(state, record, "autoShot")
    stopPinned(state, record, "wand")
    stopPinned(state, record, "playerAttack")
    if state.targetContextKey ~= nil then
        if state.targetContextKey == key then self:SyncContext(state, key) end
        return state
    end
    local selected = self:Selected(state)
    if selected and selected.key == key then self:SyncSelected(state) end
    return state
end

function H:CommitSelected(state)
    if not state or state.targetContextKey ~= nil then return state end
    local record = commit(state, self:Selected(state))
    if record then sync(state, record) end
    return state
end

function H:CommitContext(state, key)
    if not state or state.targetContextKey ~= key then return state end
    local record = commit(state, self:ByKey(state, key))
    if record then
        sync(state, record)
        state.encounter = record.context or state.encounter
    end
    return state
end

function H:CommitActive(state)
    if not state or not state.hostiles then return state end
    if state.targetContextKey ~= nil then
        return self:CommitContext(state, state.targetContextKey)
    end
    return self:CommitSelected(state)
end

local function contextView(state, record)
    local out, field, value = {}, nil, nil
    for field, value in pairs(state) do out[field] = value end
    if state.actors then
        out.actors = {}
        for field, value in pairs(state.actors) do out.actors[field] = value end
        if state.actors.pet then
            out.actors.pet = {}
            for field, value in pairs(state.actors.pet) do
                out.actors.pet[field] = value
            end
            local geometry = record.geometry and record.geometry.pet
            if geometry then
                out.actors.pet.distance = geometry.distance
                out.actors.pet.distanceKind = geometry.distanceKind
                out.actors.pet.lineOfSight = geometry.lineOfSight
                out.actors.pet.behind = geometry.behind
            end
        end
    end
    return out
end

function H:Context(state, key)
    local record = self:ByKey(state, key)
    if not record then return nil end
    return self:SyncContext(contextView(state, record), key)
end

function H:SelectedContext(state)
    local record = self:Selected(state)
    if not record then return nil end
    return self:SyncSelected(contextView(state, record))
end

function H:AuraState(encounter)
    local observed = encounter and encounter.targetHarmful
        and encounter.targetHarmful.byName or {}
    local families = {}
    local actions = XelAssist.Game.Actors and XelAssist.Game.Actors:Actions() or {}
    local i
    for i = 1, table.getn(actions) do
        local action = actions[i]
        if action and action.name and action.facts and action.facts.exclusiveFamily then
            families[action.name] = action.facts.exclusiveFamily
        end
    end
    local out, name, aura = {}, nil, nil
    for name, aura in pairs(observed) do
        if type(aura) == "table" then
            local copy = copyAura(aura, 4)
            copy.exclusiveFamily = copy.exclusiveFamily or families[name]
            out[name] = copy
        else out[name] = aura end
    end
    return out
end

function H:ModifierState(encounter, hostile, unit, targetKey)
    local resistance = hostile and XelAssist.Combat.Resistance
        and XelAssist.Combat.Resistance:Snapshot(unit or "target", encounter) or nil
    if resistance then resistance.baseProjectedReduction = {} end
    local reduction, damageTaken, source, effects, auras =
        XelAssist.Graph.State:ActiveTargetModifiers(encounter, resistance)
    if resistance and reduction then
        resistance.rootModifierReduction = reduction
        if not resistance.live then
            resistance.projectedReduction = reduction
            resistance.projectedBy = "active " .. tostring(source or "target debuff")
        end
    end
    local name, aura
    for name, aura in pairs(auras or {}) do
        aura = copyAura(aura, 4)
        auras[name] = aura
        aura.target, aura.targetKey = unit or "target", targetKey
    end
    return resistance, damageTaken, source, effects, auras
end

local function encounterFor(hostiles, record)
    local location = hostiles and hostiles.location or {}
    return { zone = location.zone, subZone = location.subZone,
        minimapZone = location.minimapZone, inInstance = location.inInstance,
        instanceType = location.instanceType, target = record.encounter,
        targetHarmful = record.harmfulAuras,
        targetHelpful = record.helpfulAuras }
end

local function controlState(record, observed)
    local harmful = record.harmfulAuras
    local out = { available = harmful and harmful.available == true or false,
        byName = {}, active = false }
    if not out.available then return out end
    local actions = XelAssist.Game.Actors and XelAssist.Game.Actors:Actions() or {}
    local i, aura
    for i = 1, table.getn(actions) do
        local action = actions[i]
        if action and action.name and action.facts
            and action.facts.kind == "crowdControl" then
            aura = observed[action.name]
            if aura then
                out.byName[action.name], out.active = aura, true
                local remaining = tonumber(aura.remaining)
                if remaining and (not out.remaining or remaining > out.remaining) then
                    out.remaining = remaining
                end
            end
        end
    end
    return out
end

function H:Enrich(hostiles)
    if not (hostiles and hostiles.byKey) then return end
    local i, record
    for i = 1, table.getn(hostiles.order or {}) do
        record = hostiles.byKey[hostiles.order[i]]
        if record then
            record.context = encounterFor(hostiles, record)
            local resistance, damageTaken, source, effects, projected =
                self:ModifierState(record.context, true, record.unit, record.key)
            record.targetAuras = self:AuraState(record.context)
            record.projectedAuras = projected or {}
            record.resistance, record.resistances = resistance,
                resistance and resistance.live or nil
            record.damageTaken, record.baseDamageTaken = damageTaken,
                effects and {} or nil
            record.modifierEffects, record.activeModifierSource = effects, source
            record.castProbability = record.casting == true and 1
                or record.casting == false and 0 or nil
            record.control = controlState(record, record.targetAuras)
            record.threat = { available = record.victim
                    and record.victim.available == true or false,
                victimGuid = record.victim and record.victim.guid or nil,
                playerHasAggro = record.hasPlayerAggro,
                petHasAggro = record.hasPetAggro,
                playerDelta = 0, playerDeltaExact = true, petDelta = 0 }
        end
    end
end

function H:Observe(encounter)
    local hostiles = XelAssist.Game.Hostiles
        and XelAssist.Game.Hostiles:Snapshot() or nil
    if hostiles then self:Enrich(hostiles) end
    local selected = hostiles and hostiles.selectedKey and hostiles.byKey
        and hostiles.byKey[hostiles.selectedKey] or nil
    local hostile
    if hostiles then hostile = selected ~= nil
    else hostile = UnitExists("target") and not UnitIsDead("target")
        and UnitCanAttack("player", "target") end

    local health, maximum, exact = 0, 0, false
    if selected then
        health, maximum, exact = selected.health or 0,
            selected.healthMax or 0, selected.healthExact == true
    elseif hostile then
        health, maximum, exact = XelAssist.Game.Capabilities:Health("target")
    end
    local distance, distanceKind = selected and selected.distance,
        selected and selected.distanceKind
    if not hostiles then
        distance, distanceKind =
            XelAssist.Game.Capabilities:Distance(hostile and "target" or nil)
    end
    local geometry = selected and { lineOfSight = selected.lineOfSight,
        behind = selected.behind }
        or XelAssist.Game.Capabilities:Geometry("player", "target")
    local _, guid = UnitExists("target")
    if selected then guid = selected.guid end
    local ref = selected and selected.targetRef
        or hostile and XelAssist.Game.Capabilities.UnitRef
        and XelAssist.Game.Capabilities:UnitRef(
            "target", "hostile", "selected") or nil
    local casting
    if selected then casting = selected.casting
    else casting = XelAssist.targetCastUntil
        and XelAssist.targetCastUntil > GetTime()
        and XelAssist.targetCastGUID == guid end
    local hasAggro
    if selected then hasAggro = selected.hasPlayerAggro
    else hasAggro = hostile and UnitExists("targettarget")
        and UnitIsUnit("targettarget", "player") end
    local resistance, damageTaken, source, effects, projected
    if selected then
        resistance, damageTaken = selected.resistance, selected.damageTaken
        source, effects = selected.activeModifierSource, selected.modifierEffects
        projected = selected.projectedAuras
    else
        resistance, damageTaken, source, effects, projected =
            self:ModifierState(encounter, hostile)
    end
    return { hostiles = hostiles, selected = selected, hostile = hostile,
        guid = guid, ref = ref, health = health, healthMax = maximum,
        healthExact = exact, survival = selected and selected.survival or nil,
        distance = distance, distanceKind = distanceKind,
        geometry = geometry, casting = casting,
        castRemaining = selected and (tonumber(selected.castRemaining) or 0)
            or casting and (XelAssist.targetCastUntil - GetTime()) or 0,
        hasAggro = hasAggro, resistance = resistance,
        resistances = resistance and resistance.live or nil,
        damageTaken = damageTaken,
        baseDamageTaken = selected and selected.baseDamageTaken
            or effects and {} or nil,
        modifierEffects = effects, modifierSource = source,
        projectedAuras = projected or {}, targetAuras = selected
            and selected.targetAuras or self:AuraState(encounter),
        creatureType = selected and selected.encounter
            and selected.encounter.creatureType
            or hostile and UnitCreatureType and UnitCreatureType("target") or nil }
end
