-- Pure graph consequences for root-sealed Power Infusion evidence. The spell
-- itself has no flat utility: its value emerges from later affected actions.
XelAssist.Graph.PriestPowerInfusion = {}
local P = XelAssist.Graph.PriestPowerInfusion

P.APPLICATION_BLOCK_THRESHOLD = 0.75
P.CONSUMER_KEY = "priestPowerInfusion:affectedSpell"

local function finite(value, low, high)
    value = tonumber(value)
    if value == nil or value ~= value or value == math.huge
        or value == -math.huge or value < low or value > high then return nil end
    return value
end

local function copy(source)
    local out, key, value = {}, nil, nil
    for key, value in pairs(source or {}) do out[key] = value end
    return out
end

local function runtime()
    return XelAssist.Game and XelAssist.Game.Player
        and XelAssist.Game.Player.PriestPowerInfusion
end

local function actionEvidence(action)
    local owner = runtime()
    return owner and owner:Evidence(action) or nil
end

local function validContract(contract, evidence)
    return type(contract) == "table" and contract.valid == true
        and contract.exact == true and evidence
        and contract.spellId == evidence.spellId
        and contract.family == evidence.family
        and contract.familyFlag == evidence.familyFlag
        and contract.healingAura == evidence.healingAura
        and contract.damageAura == evidence.damageAura
        and contract.schoolMask == evidence.schoolMask
        and finite(contract.duration, 0.001, 3600)
        and finite(contract.percent, 0.001, 1000)
        and finite(contract.multiplier, 1.00001, 11)
end

local function key(descriptor)
    return descriptor and (descriptor.key or descriptor.guid or descriptor.unit)
end

local function playerRecord(state)
    local friendlies = state and state.friendlies
    local playerKey = friendlies and friendlies.byUnit
        and friendlies.byUnit.player or nil
    local record = playerKey ~= nil and friendlies.byKey
        and friendlies.byKey[playerKey] or nil
    return record, playerKey
end

local function projected(state, descriptor)
    local owner = runtime()
    local record = descriptor and descriptor.record
    if not record and state and state.friendlies and state.friendlies.byKey then
        record = state.friendlies.byKey[key(descriptor)]
    end
    return owner and record and record.auras
        and record.auras[owner.PROJECTION_KEY] or nil
end

local function rootRecord(state, descriptorKey)
    local root = state and state.rootObservation
    local records = root and root.priestPowerInfusionEvidence
    return records and records[descriptorKey] or nil
end

local function activeProjected(entry)
    if type(entry) ~= "table" then return nil end
    local probability = finite(entry.applicationProbability, 0, 1) or 1
    local remaining = finite(entry.remaining, 0, 3600)
    if probability < P.APPLICATION_BLOCK_THRESHOLD
        or not remaining or remaining <= 0 then return false end
    return true
end

local function activeRoot(state, record)
    if not (record and record.known == true) then return nil end
    if not record.active then return false end
    local remaining = finite(record.remaining, 0, 3600)
    local elapsed = finite(state and state.time, 0, 1000000000)
    if not remaining or not elapsed then return nil end
    return elapsed < remaining
end

local function selfDescriptor(state, descriptor)
    local actor = state and state.actors and state.actors.player
    local record, playerKey = playerRecord(state)
    return actor and record and descriptor
        and descriptor.guid == actor.guid and record.guid == actor.guid
        and key(descriptor) == playerKey, record, playerKey
end

function P:Blocker(action, state, descriptor, tooltip)
    local evidence = actionEvidence(action)
    if not evidence then return nil, false end
    local isSelf = selfDescriptor(state, descriptor)
    if not isSelf then
        return "Power Infusion recipient consequences are not player-local", true
    end
    local contract = tooltip and tooltip.priestPowerInfusionContract
    if not validContract(contract, evidence) then
        return contract and contract.reason
            or "Power Infusion root contract unavailable", true
    end
    local future = projected(state, descriptor)
    if future and activeProjected(future) ~= false then
        return "Power Infusion active", true
    end
    local observed = rootRecord(state, key(descriptor))
    local active = activeRoot(state, observed)
    if active == nil then return "Power Infusion aura evidence unknown", true end
    if active then return "Power Infusion active", true end
    if not (observed.contract and validContract(observed.contract, evidence)) then
        return "Power Infusion recipient contract unavailable", true
    end
    return nil, true
end

function P:AuraActive(action, state, descriptor)
    if not actionEvidence(action) then return nil, false end
    local future = projected(state, descriptor)
    if future then return activeProjected(future) == true, true end
    local active = activeRoot(state, rootRecord(state, key(descriptor)))
    if active == nil then return nil, true, "Power Infusion aura evidence unknown" end
    return active, true
end

function P:Prepare(action, state, descriptor, tooltip)
    local evidence = actionEvidence(action)
    if not evidence then return nil, nil, false end
    local blocker = self:Blocker(action, state, descriptor, tooltip)
    if blocker then return nil, blocker, true end
    local contract = tooltip.priestPowerInfusionContract
    return { classMechanic = "priestPowerInfusion",
        priestPowerInfusionTransition = { kind = "priestPowerInfusion",
            exact = true, spellId = evidence.spellId,
            targetKey = key(descriptor), targetGUID = descriptor.guid,
            contract = copy(contract), source = contract.source } }, nil, true
end

function P:Score(context, projection)
    local transition = projection and projection.priestPowerInfusionTransition
    local evidence = actionEvidence(context and context.action)
    if not (transition and transition.exact == true and evidence
        and transition.kind == "priestPowerInfusion"
        and transition.spellId == evidence.spellId
        and validContract(transition.contract, evidence)) then
        return false, "Power Infusion transition evidence unavailable"
    end
    context.power, context.expectedPower, context.effectivePower = 0, 0, 0
    context.value, context.estimated = 0, false
    context.reason = "arms an exact downstream spell multiplier"
    return true
end

local function transition(candidate)
    local projection = candidate and candidate.classMechanicProjection
    return projection and projection.priestPowerInfusionTransition
        or candidate and candidate.priestPowerInfusionTransition
        or candidate and candidate.tooltip
            and candidate.tooltip.priestPowerInfusionTransition
end

function P:Apply(state, candidate)
    local found = transition(candidate)
    local action = candidate and candidate.action
    local evidence = actionEvidence(action)
    local record, playerKey = playerRecord(state)
    if not (found and found.exact == true and evidence
        and found.kind == "priestPowerInfusion"
        and found.spellId == evidence.spellId
        and found.targetKey == playerKey
        and record and record.guid == found.targetGUID
        and candidate.targetKey == playerKey
        and candidate.targetGUID == record.guid
        and validContract(found.contract, evidence)) then return false end
    local probability = finite(candidate.effectDelivery, 0, 1) or 1
    if probability < self.APPLICATION_BLOCK_THRESHOLD then return false end
    local contract = found.contract
    record.auras = record.auras or {}
    record.auras[runtime().PROJECTION_KEY] = {
        exact = true, spellId = evidence.spellId,
        duration = contract.duration, remaining = contract.duration,
        percent = contract.percent, multiplier = contract.multiplier,
        contract = copy(contract), applicationProbability = probability,
        source = "projected exact Power Infusion application" }
    return true
end

local function activeContract(state)
    local record, playerKey = playerRecord(state)
    local owner = runtime()
    local future = owner and record and record.auras
        and record.auras[owner.PROJECTION_KEY] or nil
    if future and activeProjected(future) then
        local evidence = { spellId = owner.SPELL_ID,
            family = owner.PRIEST_FAMILY, familyFlag = owner.FAMILY_FLAG,
            healingAura = owner.HEALING_DONE_PERCENT,
            damageAura = owner.DAMAGE_DONE_PERCENT,
            schoolMask = owner.MAGIC_SCHOOL_MASK }
        if validContract(future.contract, evidence) then
            return future.contract, nil, true
        end
        return nil, "projected Power Infusion contract unavailable", true
    end
    local observed = rootRecord(state, playerKey)
    local active = activeRoot(state, observed)
    if active == nil then return nil, "Power Infusion aura evidence unknown", true end
    if not active then return nil, nil, false end
    if observed.exact == true and type(observed.contract) == "table" then
        return observed.contract, nil, true
    end
    return nil, observed.reason or "active Power Infusion magnitude unknown", true
end

function P:Adjust(context)
    local contract, reason, active = activeContract(context and context.state)
    if not active then return false, nil, false end
    local marker = context and context.tooltip
        and context.tooltip.priestPowerInfusionConsumer
        or context and context.facts and context.facts.priestPowerInfusionConsumer
    if not marker or marker.claimed ~= true then return false, nil, false end
    if marker.exact ~= true then
        return false, marker.reason
            or "Power Infusion consumer evidence unavailable", true
    end
    if not contract then return false, reason, true end
    local power = finite(context.power, 0, 1000000000)
    local expected = finite(context.expectedPower, 0, 1000000000)
    if not power or not expected then
        return false, "Power Infusion action power unavailable", true
    end
    context.power = power * contract.multiplier
    context.expectedPower = expected * contract.multiplier
    context.priestPowerInfusionMultiplier = contract.multiplier
    context.setupConsumerKey = self.CONSUMER_KEY
    return true, nil, true
end

function P:ConsumerKey(facts)
    local marker = facts and facts.priestPowerInfusionConsumer
    return marker and marker.claimed == true and marker.exact == true
        and self.CONSUMER_KEY or nil
end

function P:StrategicSetup(tooltip)
    local evidence = tooltip and tooltip.priestPowerInfusionEvidence
    local contract = tooltip and tooltip.priestPowerInfusionContract
    if not (tooltip and tooltip.priestPowerInfusion == true
        and evidence and validContract(contract, evidence)) then return nil end
    return { key = "priestPowerInfusion:" .. tostring(evidence.spellId),
        consumerKey = self.CONSUMER_KEY }
end
