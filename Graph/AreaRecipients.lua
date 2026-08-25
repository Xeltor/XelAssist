-- Conservative hostile-recipient projection from a bounded observation. This
-- module never discovers units: it only resolves geometry for keys already in
-- state.hostiles.order and keeps uncertain or collateral units out of damage.
XelAssist.Graph.AreaRecipients = {}
local A = XelAssist.Graph.AreaRecipients

A.MAX_EFFECTS = 3
A.MAX_HOSTILES = 5

local function appendUnique(list, seen, value)
    if seen[value] then return end
    seen[value] = true
    table.insert(list, value)
end

local function addUnknown(result, group, reason)
    appendUnique(result.unknowns, result._unknownSet, reason)
    result.additionalUnknown = true
    if group then
        appendUnique(group.unknowns, group._unknownSet, reason)
        group.additionalUnknown = true
    end
end

local function newGroup(effect, effectIndex)
    return { effectIndex = effectIndex, topology = effect,
        order = {}, byKey = {}, evidenceByKey = {}, secondaryOrder = {},
        collateral = {}, withheld = {}, unknowns = {}, _unknownSet = {},
        additionalUnknown = false }
end

local function hostileObservation(state)
    local hostiles = state and state.hostiles
    if type(hostiles) ~= "table" then return nil end
    if type(hostiles.order) ~= "table" or type(hostiles.byKey) ~= "table" then
        return nil
    end
    return hostiles
end

-- The selected key must itself occur in the bounded stable order. Falling back
-- to record.selected supports projected/test snapshots without enumerating the
-- byKey map or manufacturing an identity.
local function selectedHostile(hostiles, count)
    if not hostiles then return nil, nil end
    local fallbackKey, fallback
    local i
    for i = 1, count do
        local key = hostiles.order[i]
        local record = hostiles.byKey[key]
        if record then
            if key == hostiles.selectedKey then return key, record end
            if not fallback and record.selected == true then
                fallbackKey, fallback = key, record
            end
        end
    end
    return fallbackKey, fallback
end

local function actorFor(action)
    local facts = action and action.facts or {}
    return facts.damageActor or facts.effectActor
        or action and action.actor or "player"
end

local function actorDistance(record, actor)
    local geometry = record and record.geometry
    local observed = geometry and geometry[actor]
    local distance = observed and tonumber(observed.distance)
    if distance and distance >= 0 then
        return distance, observed.source or "hostile snapshot"
    end
    return nil, nil
end

local function selectedDistance(primary, record)
    local geometry = record and record.geometry
    local observed = geometry and geometry.selected
    if observed then
        local distance = tonumber(observed.distance)
        if distance and distance >= 0 then
            return distance, observed.source or "selected-pair snapshot", false
        end
        -- A present observation with no numeric distance is authoritative
        -- unknown; do not replace it with a later live answer.
        return nil, nil, false
    end
    if not (UnitXP and primary and primary.unit and record and record.unit) then
        return nil, nil, false
    end
    local ok, distance = pcall(UnitXP, "distanceBetween",
        primary.unit, record.unit)
    distance = tonumber(distance)
    if ok and distance and distance >= 0 then
        return distance, "live UnitXP fallback", true
    end
    return nil, nil, false
end

local function engagement(record)
    if not record then return nil end
    if record.selected == true or record.engaged == true
        or record.hasPlayerAggro == true or record.hasPetAggro == true
        or record.victim and (record.victim.targetsPlayer == true
            or record.victim.targetsPet == true) then return true end
    if record.engaged == false then return false end
    return nil
end

local function evidence(key, record, distance, source, primary, engaged)
    return { key = key, record = record, distance = distance,
        distanceSource = source, primary = primary == true,
        engaged = engaged }
end

local function credit(group, key, record, row, primary)
    if group.byKey[key] then return end
    group.byKey[key] = record
    group.evidenceByKey[key] = row
    table.insert(group.order, key)
    if primary then group.primaryKey = key
    else table.insert(group.secondaryOrder, key) end
end

local function markCollateral(result, group, row, reason, uncertain)
    row.reason = reason or "visible hostile is not engaged"
    row.uncertain = uncertain and true or false
    table.insert(group.collateral, row)
    table.insert(result.collateral, { effectIndex = group.effectIndex,
        topology = group.topology, key = row.key, record = row.record,
        distance = row.distance, distanceSource = row.distanceSource,
        reason = row.reason, uncertain = row.uncertain })
end

local function markWithheld(group, row, reason)
    row.reason = reason
    table.insert(group.withheld, row)
end

local function markWithheldEffect(result, group, row, reason)
    markWithheld(group, row, reason)
    table.insert(result.withheld, { effectIndex = group.effectIndex,
        topology = group.topology, key = row.key, record = row.record,
        distance = row.distance, distanceSource = row.distanceSource,
        reason = row.reason })
end

local function discoveryComplete(result, hostiles, observedCount)
    local complete = true
    local total = tonumber(hostiles and hostiles.total)
    if not hostiles or hostiles.discoveryComplete ~= true then
        addUnknown(result, nil, "hostile discovery is bounded")
        complete = false
    end
    if hostiles and hostiles.capped == true then
        addUnknown(result, nil, "hostile discovery is capped")
        complete = false
    end
    if hostiles and hostiles.additionalUnknown == true then
        addUnknown(result, nil, "additional hostile candidates are unobserved")
        complete = false
    end
    if total and total > observedCount then
        addUnknown(result, nil, "additional hostile candidates are unobserved")
        complete = false
    end
    if hostiles and table.getn(hostiles.order) > A.MAX_HOSTILES then
        addUnknown(result, nil, "recipient evaluation is capped")
        complete = false
    end
    return complete
end

local function addPrimary(group, key, record, distance, source)
    if not (key and record) then return false end
    local row = evidence(key, record, distance, source, true, true)
    credit(group, key, record, row, true)
    return true
end

local function candidateGeometry(result, group, effect, actor, primary,
    record)
    if effect.center == "caster" then
        if actor ~= "player" and actor ~= "pet" then
            addUnknown(result, group, "effect actor geometry is unavailable")
            return nil, nil
        end
        local distance, source = actorDistance(record, actor)
        if distance == nil then
            addUnknown(result, group, "caster-to-hostile distance is unknown")
        end
        return distance, source
    end
    local distance, source, live = selectedDistance(primary, record)
    if live then
        addUnknown(result, group, "live pairwise distance fallback was used")
    elseif distance == nil then
        addUnknown(result, group,
            "selected-to-hostile pairwise distance is unknown")
    end
    return distance, source
end

local function resolveCircle(result, group, hostiles, count, selectedKey,
    selected, effect, action, allowSecondary)
    local radius = tonumber(effect.radius)
    local radiusKnown = radius and radius > 0 and effect.radiusKnown ~= false
    local actor = actorFor(action)

    if effect.center == "target" then
        if not addPrimary(group, selectedKey, selected, 0,
            "selected area center") then
            addUnknown(result, group, "selected hostile is unavailable")
            return
        end
    elseif effect.center == "caster" and radiusKnown and selected then
        local distance, source = candidateGeometry(result, group, effect,
            actor, selected, selected)
        if distance and distance <= radius then
            addPrimary(group, selectedKey, selected, distance, source)
        end
    end

    if not radiusKnown then
        addUnknown(result, group, "hostile area radius is unknown")
        return
    end
    if not allowSecondary then
        addUnknown(result, group,
            "secondary credit is withheld for incomplete hostile discovery")
    end

    local i
    for i = 1, count do
        local key = hostiles.order[i]
        local record = hostiles.byKey[key]
        if key ~= selectedKey then
            if not record then
                addUnknown(result, group,
                    "hostile record is missing from the stable order")
            elseif record.dead ~= true then
                local distance, source = candidateGeometry(result, group,
                    effect, actor, selected, record)
                if distance and distance <= radius then
                    local engaged = engagement(record)
                    local row = evidence(key, record, distance, source,
                        false, engaged)
                    if engaged == false then
                        markCollateral(result, group, row,
                            "visible hostile is not engaged", false)
                    elseif engaged ~= true then
                        markCollateral(result, group, row,
                            "secondary engagement is unknown", true)
                        addUnknown(result, group,
                            "secondary engagement is unknown")
                    elseif not allowSecondary then
                        markWithheldEffect(result, group, row,
                            "secondary credit withheld for incomplete discovery")
                    else
                        credit(group, key, record, row, false)
                    end
                end
            end
        end
    end
end

local function topologyEffects(topology)
    if not topology then return nil end
    if topology.shape then return { topology } end
    if type(topology.effects) == "table" then return topology.effects end
    if type(topology.hostile) == "table" then return topology.hostile end
    return nil
end

function A:Resolve(state, action, topology)
    if topology == nil then
        topology = action and action.facts and action.facts.topology or nil
    end
    local result = { groups = {}, unknowns = {}, additionalUnknown = false,
        collateral = {}, withheld = {}, _unknownSet = {} }
    local effects = topologyEffects(topology)
    if not topology or topology.available == false or not effects then
        addUnknown(result, nil, "spell recipient topology is unavailable")
        result._unknownSet = nil
        return result
    end

    local hostiles = hostileObservation(state)
    local observedCount = hostiles
        and math.min(table.getn(hostiles.order), self.MAX_HOSTILES) or 0
    local selectedKey, selected = selectedHostile(hostiles, observedCount)
    local allowSecondary = hostiles
        and discoveryComplete(result, hostiles, observedCount) or false
    if not hostiles then
        addUnknown(result, nil, "hostile observation is unavailable")
    end

    local limit = math.min(table.getn(effects), self.MAX_EFFECTS)
    if table.getn(effects) > self.MAX_EFFECTS then
        addUnknown(result, nil, "DBC effect evaluation is capped")
    end
    local i
    for i = 1, limit do
        local effect = effects[i]
        local relation = effect and effect.relation
        if effect and (relation == "hostile" or relation == "unknown") then
            local group = newGroup(effect, tonumber(effect.index) or i)
            table.insert(result.groups, group)
            local shape, center = effect.shape, effect.center
            local facts = action and action.facts or {}
            if relation == "unknown" then
                addUnknown(result, group,
                    "effect implicit target relation is unknown")
            elseif facts.ground or facts.dynamicObject
                or shape == "ground" or center == "dynamicObject" then
                addUnknown(result, group,
                    "ground or dynamic-object recipients are unresolved")
            elseif shape == "cone" then
                addUnknown(result, group, "cone recipients are unresolved")
            elseif shape == "chain" then
                if center == "target" then
                    if not addPrimary(group, selectedKey, selected, 0,
                        "selected chain origin") then
                        addUnknown(result, group,
                            "selected hostile is unavailable")
                    end
                end
                addUnknown(result, group,
                    "chain secondary recipients are unresolved")
            elseif shape == "single" and center == "target" then
                if not addPrimary(group, selectedKey, selected, nil,
                    "selected single target") then
                    addUnknown(result, group,
                        "selected hostile is unavailable")
                end
            elseif shape == "area"
                and (center == "caster" or center == "target") then
                resolveCircle(result, group, hostiles or { order = {}, byKey = {} },
                    observedCount, selectedKey, selected, effect, action,
                    allowSecondary)
            else
                addUnknown(result, group,
                    "effect implicit target geometry is unknown")
            end
            group._unknownSet = nil
        end
    end
    result._unknownSet = nil
    return result
end
