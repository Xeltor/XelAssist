-- Hostile-local projection for exact single-target hard control.  All client
-- reads end in Game.CrowdControl root capture; these methods operate only on
-- frozen tooltip evidence and copied graph state.
XelAssist.Graph.CrowdControl = {}
local C = XelAssist.Graph.CrowdControl
local State = XelAssist.Graph.State

local function hunterControl()
    return XelAssist.Graph.HunterControl
end

C.APPLICATION_BLOCK_THRESHOLD = 0.75
C.MAX_HOSTILES = 5
local EPSILON = 0.0001

local function clamp(value)
    return math.max(0, math.min(1, tonumber(value) or 0))
end

local function evidence(action, tooltip)
    if not (action and action.facts
        and action.facts.kind == "crowdControl") then return nil end
    local found = tooltip and tooltip.crowdControlEvidence
    if type(found) ~= "table" or found.valid ~= true then return nil end
    return found
end

local function flagContains(mask, creatureTypeId)
    mask, creatureTypeId = tonumber(mask), tonumber(creatureTypeId)
    if not mask or not creatureTypeId or creatureTypeId < 1
        or creatureTypeId > 32
        or math.floor(creatureTypeId) ~= creatureTypeId then return nil end
    local flag = 2 ^ (creatureTypeId - 1)
    return math.floor(mask / flag)
        - math.floor(mask / (flag * 2)) * 2 == 1
end

local function recordFor(state, descriptor, key, guid)
    local record = descriptor and descriptor.record or nil
    if record and key ~= nil and record.key ~= nil and record.key ~= key then
        record = nil
    end
    if record and guid ~= nil and record.guid ~= nil and record.guid ~= guid then
        record = nil
    end
    if not record and State and State.HostileByKey and key ~= nil then
        record = State:HostileByKey(state, key)
    end
    if not record and State and State.ActiveHostile then
        local active = State:ActiveHostile(state)
        if active and (guid == nil or active.guid == guid) then record = active end
    end
    return record
end

local function auraSet(state, descriptor, key, guid)
    local record = recordFor(state, descriptor, key, guid)
    if record then return record.projectedAuras or {}, record end
    if guid == nil or state.targetGUID == nil or guid == state.targetGUID then
        return state.auras or {}, nil
    end
    return nil, nil
end

local function active(aura, lead)
    if type(aura) ~= "table" or aura.crowdControl ~= true then return false end
    if clamp(aura.applicationProbability or 1)
        < C.APPLICATION_BLOCK_THRESHOLD then return false end
    local remaining = tonumber(aura.remaining)
    if remaining == nil then return true end
    return remaining > math.max(0, tonumber(lead) or 0) + 0.0001
end

local function targetGuid(state, descriptor)
    if type(descriptor) == "table" then
        return descriptor.guid or descriptor.castGuid or state and state.targetGUID
    end
    return descriptor or state and state.targetGUID
end

local function modeledCast(state, descriptor)
    local guid = targetGuid(state, descriptor)
    local castState = XelAssist.Graph.HostileCastState
    return castState and castState:Find(state, guid), guid
end

local function applicationDelay(action, state, tooltip, actionStart)
    local cast = tonumber(action.facts.cast)
        or tonumber(tooltip and tooltip.cast) or 0
    return math.max(0, (tonumber(actionStart) or tonumber(state.time) or 0)
        - (tonumber(state.time) or 0)) + math.max(0, cast)
end

local function lifecycleBlocker(action, state, descriptor, tooltip, actionStart)
    if descriptor and descriptor.relation ~= "hostile" then
        return "crowd control requires a hostile target"
    end
    if action.facts.channel or tooltip and tooltip.channel then
        return "channeled control projection unavailable"
    end
    local duration = tonumber(tooltip and tooltip.duration)
    if not duration or duration <= 0 then
        return "crowd-control duration unknown"
    end
    local cast = modeledCast(state, descriptor)
    if not cast then return "control consequence unavailable" end
    local remaining = math.max(0, tonumber(cast.remaining) or 0)
    if applicationDelay(action, state, tooltip, actionStart) + EPSILON
        >= remaining then return "control arrives after modeled consequence" end
    local incoming = XelAssist.Graph.IncomingConsequences
    local value = incoming and incoming:PreventedValue(state, cast)
    if value == nil or value <= 0 then
        return "control consequence unavailable"
    end
    return nil
end

function C:Evidence(action, tooltip)
    return evidence(action, tooltip)
end

-- Exact creature-type masks are numeric DBC evidence.  A localized creature
-- name is not accepted as a substitute when ClassicAPI did not capture the ID.
function C:CreatureBlocker(action, state, descriptor, tooltip)
    local found = evidence(action, tooltip)
    if not found then return nil, false end
    local mask = tonumber(found.targetCreatureMask) or 0
    if mask <= 0 then return nil, true end
    local record = recordFor(state, descriptor,
        descriptor and descriptor.key, descriptor and descriptor.guid)
    local creatureTypeId = record and record.encounter
        and record.encounter.creatureTypeId or record and record.creatureTypeId
            or state.targetCreatureTypeId
    local allowed = flagContains(mask, creatureTypeId)
    if allowed == nil then return "creature type evidence unknown", true end
    if not allowed then return "incompatible creature type", true end
    return nil, true
end

-- actionStart lets a cast begin before an old control expires when the new
-- application itself lands afterwards.  This is timing, not a refresh policy.
function C:Blocker(action, state, descriptor, tooltip, actionStart)
    local hunter = hunterControl()
    if hunter then
        local blocker, handled = hunter:Blocker(
            action, state, descriptor, tooltip, actionStart)
        if handled then return blocker, true end
    end
    local found = evidence(action, tooltip)
    if not found then
        if action and action.facts
            and action.facts.kind == "crowdControl" then
            return "exact crowd-control lifecycle unavailable", true
        end
        return nil, false
    end
    local blocker = self:CreatureBlocker(action, state, descriptor, tooltip)
    if blocker then return blocker, true end
    local auras = auraSet(state, descriptor,
        descriptor and descriptor.key, descriptor and descriptor.guid)
    local aura = auras and auras[action.name]
    local lead = applicationDelay(action, state, tooltip, actionStart)
    if active(aura, lead) then
        if aura.controlBreakOutcomeUnknown then
            return "control persistence unknown", true
        end
        return "target already controlled", true
    end
    blocker = lifecycleBlocker(action, state, descriptor, tooltip, actionStart)
    if blocker then return blocker, true end
    return nil, true
end

function C:Score(context)
    local hunter = hunterControl()
    if hunter and hunter:Score(context) then return true end
    local cast = modeledCast(context and context.state,
        context and context.descriptor)
    local incoming = XelAssist.Graph.IncomingConsequences
    local value, reason
    if incoming then value, reason = incoming:PreventedValue(
        context and context.state, cast) end
    if value == nil then
        context.value, context.reason = -1200,
            reason or "control consequence unavailable"
        return true
    end
    context.value = value * clamp(context.effectDelivery)
    context.reason = reason
    return true
end

local function suppressCast(out, candidate)
    local cast, guid = modeledCast(out, candidate and candidate.targetGUID)
    if not cast then return false end
    local castState = XelAssist.Graph.HostileCastState
    if not castState then return false end
    local delivery = clamp(candidate and candidate.effectDelivery)
    local probability = (tonumber(cast.probability) or 1) * (1 - delivery)
    if probability <= 0.05 then
        castState:Retire(out, guid, cast.generation)
    else castState:SetProbability(out, guid, cast.generation, probability) end
    return true
end

function C:Apply(out, candidate, context)
    local action, tooltip = candidate and candidate.action,
        candidate and candidate.tooltip
    local hunter = hunterControl()
    if hunter and hunter:Evidence(action, tooltip) then
        local applied = hunter:Apply(out, candidate, context)
        return applied, applied and nil or "Hunter control transition unavailable"
    end
    local found = evidence(action, tooltip)
    if not found or candidate.targetRelation ~= "hostile" then
        return false, "exact hostile control evidence unavailable"
    end
    if action.facts.channel then
        return false, "channeled control requires maintained-aura projection"
    end
    local duration = tonumber(tooltip.duration)
    if not duration or duration <= 0 then
        return false, "crowd-control duration unknown"
    end
    local remaining = duration - math.max(0,
        tonumber(context and context.applicationElapsed) or 0)
    local delivery = clamp(candidate.effectDelivery or 1)
    if remaining <= 0 or delivery <= 0 then
        return false, "crowd control does not remain after application"
    end
    local auras, record = auraSet(out, candidate.descriptor,
        candidate.targetKey, candidate.targetGUID)
    if not auras then return false, "hostile control target unavailable" end
    auras[action.name] = { remaining = remaining, duration = duration,
        mine = true, target = candidate.target, targetKey = candidate.targetKey,
        targetGuid = candidate.targetGUID, sourceActor = action.actor or "player",
        applicationProbability = delivery, crowdControl = true,
        controlType = found.controlType,
        breaksOnAnyDamage = found.breaksOnAnyDamage == true,
        breaksOnDirectDamage = found.breaksOnDirectDamage == true,
        damageBreakSpecified = found.damageBreakSpecified == true,
        crowdControlEvidenceSource = found.source }
    if record and State and State.RefreshHostileRecord then
        State:RefreshHostileRecord(out, record.key)
    end
    suppressCast(out, candidate)
    return true, nil
end

local function controlAura(aura)
    return type(aura) == "table" and aura.crowdControl == true
end

local function markUncertain(aura, damage)
    aura.controlBreakOutcomeUnknown = true
    aura.controlBreakUncertaintySource = damage.source
        or "projected damage outcome"
end

-- A guaranteed positive hit clears only the cancellation modes proven by the
-- captured aura-interrupt flags.  Expected/probabilistic damage keeps the aura
-- branch and marks persistence unknown instead of inventing a successful hit.
function C:ApplyDamage(state, damage)
    damage = damage or {}
    if not (tonumber(damage.amount) and damage.amount > 0) then
        return { affected = 0, removed = 0, uncertain = 0 }
    end
    local auras, record = auraSet(state, nil,
        damage.targetKey, damage.targetGuid or damage.targetGUID)
    local result = { affected = 0, removed = 0, uncertain = 0 }
    if not auras then return result end
    local name, aura
    for name, aura in pairs(auras) do
        if controlAura(aura) then
            local matches = aura.breaksOnAnyDamage == true
                or aura.breaksOnDirectDamage == true and damage.direct == true
            local directUnknown = aura.breaksOnDirectDamage == true
                and damage.direct == nil and not aura.breaksOnAnyDamage
            local unspecified = aura.damageBreakSpecified ~= true
            if matches or directUnknown or unspecified then
                result.affected = result.affected + 1
                if matches and damage.guaranteed == true then
                    auras[name], result.removed = nil, result.removed + 1
                else
                    markUncertain(aura, damage)
                    result.uncertain = result.uncertain + 1
                end
            end
        end
    end
    if result.affected > 0 and record
        and State and State.RefreshHostileRecord then
        State:RefreshHostileRecord(state, record.key)
    end
    return result
end

local function hasControl(auras)
    local _, aura
    for _, aura in pairs(auras or {}) do
        if controlAura(aura) then return true end
    end
    return false
end

-- Timeline integration can take this bounded snapshot before an event and
-- resolve only health deltas on targets that actually have breakable control.
function C:DamageSnapshot(state)
    local snapshot = { order = {}, byKey = {} }
    local hostiles = state and state.hostiles
    if hostiles and type(hostiles.order) == "table"
        and type(hostiles.byKey) == "table" then
        local index, count = nil,
            math.min(table.getn(hostiles.order), self.MAX_HOSTILES)
        for index = 1, count do
            local key, record = hostiles.order[index], nil
            record = hostiles.byKey[key]
            if record and record.healthExact == true
                and tonumber(record.health)
                and hasControl(record.projectedAuras) then
                snapshot.byKey[key] = { health = record.health,
                    guid = record.guid or key }
                table.insert(snapshot.order, key)
            end
        end
    elseif state and state.targetHealthExact == true
        and tonumber(state.targetHealth) and hasControl(state.auras) then
        snapshot.legacy = { health = state.targetHealth,
            guid = state.targetGUID }
    end
    if table.getn(snapshot.order) == 0 and not snapshot.legacy then return nil end
    return snapshot
end

function C:ResolveDamage(state, snapshot, damage)
    local total = { affected = 0, removed = 0, uncertain = 0 }
    if not snapshot then return total end
    local function apply(entry, health, key)
        health = tonumber(health)
        if not health or health >= entry.health then return end
        local event = { amount = entry.health - health, targetKey = key,
            targetGuid = entry.guid, direct = damage and damage.direct,
            guaranteed = damage and damage.guaranteed,
            source = damage and damage.source }
        local result = self:ApplyDamage(state, event)
        total.affected = total.affected + result.affected
        total.removed = total.removed + result.removed
        total.uncertain = total.uncertain + result.uncertain
    end
    local index
    for index = 1, table.getn(snapshot.order or {}) do
        local key = snapshot.order[index]
        local entry = snapshot.byKey[key]
        local record = State and State.HostileByKey
            and State:HostileByKey(state, key)
        if record and (record.guid or key) == entry.guid then
            apply(entry, record.health, key)
        end
    end
    if snapshot.legacy and state.targetGUID == snapshot.legacy.guid then
        apply(snapshot.legacy, state.targetHealth, nil)
    end
    return total
end
