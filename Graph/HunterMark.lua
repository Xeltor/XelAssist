-- Target-local Hunter's Mark projection.  The mark has no fixed utility
-- score: its only value is the ranged-weapon damage it actually adds on this
-- hostile before the aura expires.  All DBC and character-sheet reads happen
-- in Game.Player.HunterMark before graph descendants are opened.
XelAssist.Graph.HunterMark = {}
local H = XelAssist.Graph.HunterMark

local APPLICATION_BLOCK_THRESHOLD = 0.75
local MAX_HOSTILES, EPSILON = 5, 0.0001
local KEY_PREFIX = "hunterMark:"

local function clamp(value)
    value = tonumber(value)
    if value == nil then return nil end
    return math.max(0, math.min(1, value))
end

local function copy(source)
    local out, key, value = {}, nil, nil
    for key, value in pairs(source or {}) do out[key] = value end
    return out
end

local function runtime()
    return XelAssist.Game and XelAssist.Game.Player
        and XelAssist.Game.Player.HunterMark
end

local function actionEvidence(action, tooltip)
    local owner = runtime()
    if not owner then return nil end
    return owner:Evidence(tooltip) or owner:Evidence(action)
end

local function rootEvidence(state)
    local root = state and state.hunterMarkRoot
    local lane = root and root.lane
    if not (type(root) == "table" and root.valid == true
        and root.portfolio == "hunterMark" and type(root.ranks) == "table"
        and type(lane) == "table" and lane.valid == true
        and lane.exact == true and tonumber(lane.speed)
        and lane.speed > 0 and tonumber(lane.damageMultiplier)
        and lane.damageMultiplier > 0
        and lane.damageMultiplierUnits == "factor") then
        return nil, "exact Hunter ranged damage lane unavailable"
    end
    return root, nil
end

local function sealedRank(root, spellId)
    local owner = runtime()
    local found = root and root.ranks and root.ranks[tonumber(spellId)]
    return owner and owner:Evidence({ hunterMarkEvidence = found }) or nil
end

local function hostileByIdentity(state, key, guid)
    local hostiles = state and state.hostiles
    if not (hostiles and type(hostiles.byKey) == "table") then return nil end
    local record = key ~= nil and hostiles.byKey[key] or nil
    if record and guid ~= nil and record.guid ~= guid then return nil end
    if record then return record end
    if guid == nil then return nil end
    record = hostiles.byKey[guid]
    if record and (record.guid == nil or record.guid == guid) then return record end
    local count = math.min(table.getn(hostiles.order or {}), MAX_HOSTILES)
    local index
    for index = 1, count do
        record = hostiles.byKey[hostiles.order[index]]
        if record and record.guid == guid then return record end
    end
    return nil
end

local function targetRecord(state, descriptor, guid)
    local expected = guid or descriptor and descriptor.guid
    local record = descriptor and descriptor.record
    if record then
        if descriptor.key ~= nil and record.key ~= nil
            and descriptor.key ~= record.key then return nil end
        if expected ~= nil and record.guid ~= expected then return nil end
        return record
    end
    return hostileByIdentity(state, descriptor and descriptor.key, expected)
end

local function activeAt(aura, lead)
    if type(aura) ~= "table" then return false end
    local remaining = tonumber(aura.remaining)
    return remaining == nil or remaining > math.max(0, tonumber(lead) or 0)
        + EPSILON
end

local function addMark(scan, root, aura, lead)
    if not activeAt(aura, lead) then return true end
    local spellId = tonumber(aura.spellId)
    if not spellId then return false end
    local found = sealedRank(root, spellId)
    if not found then return true end
    local probability = clamp(aura.applicationProbability or 1)
    if probability == nil then return false end
    if scan.spellId and scan.spellId ~= spellId then
        scan.ambiguous = true
        return false
    end
    scan.spellId, scan.evidence = spellId, found
    scan.probability = math.max(scan.probability or 0, probability)
    local remaining = tonumber(aura.remaining)
    if remaining == nil then scan.remaining = nil
    elseif scan.remaining ~= nil or scan.seenRemaining then
        scan.remaining = math.max(scan.remaining or 0, remaining)
    else
        scan.remaining, scan.seenRemaining = remaining, true
    end
    return true
end

local function scanProjected(scan, root, record, lead)
    local _, aura
    for _, aura in pairs(record.projectedAuras or {}) do
        if type(aura) == "table" and aura.hunterMark == true then
            if not addMark(scan, root, aura, lead) then return false end
        end
    end
    return true
end

-- The installed ClassicAPI list is the exact live source.  If any entry has
-- no numeric identity, it could itself be a Mark and absence is not proven.
local function scanObserved(scan, root, record, lead)
    local harmful = record and record.harmfulAuras
    if not (type(harmful) == "table" and harmful.available == true
        and type(harmful.list) == "table") then return false end
    local index, aura
    for index = 1, table.getn(harmful.list) do
        aura = harmful.list[index]
        if type(aura) ~= "table" or tonumber(aura.spellId) == nil then
            return false
        end
        if sealedRank(root, aura.spellId)
            and not addMark(scan, root, aura, lead) then return false end
    end
    return true
end

local function currentMark(state, record, lead)
    local root, reason = rootEvidence(state)
    if not root then return nil, reason end
    local scan = {}
    if not scanProjected(scan, root, record, lead)
        or not scanObserved(scan, root, record, lead) then
        return nil, scan.ambiguous
            and "multiple Hunter's Mark ranks are unresolved"
            or "numeric hostile aura evidence unavailable"
    end
    if not scan.evidence then return false, nil end
    return { spellId = scan.spellId, evidence = scan.evidence,
        probability = scan.probability or 1, remaining = scan.remaining }, nil
end

local function exactDescriptor(descriptor, record)
    return descriptor and descriptor.unit == "target"
        and descriptor.relation == "hostile"
        and descriptor.source == "selected"
        and record and record.dead ~= true
        and (descriptor.key == nil or record.key == nil
            or descriptor.key == record.key)
        and (descriptor.guid == nil or record.guid == descriptor.guid)
end

local function applicationLead(action, state, tooltip, actionStart)
    local at = tonumber(state and state.time) or 0
    local start = math.max(at, tonumber(actionStart) or at)
    local cast = math.max(0, tonumber(tooltip and tooltip.cast)
        or tonumber(action and action.facts and action.facts.cast) or 0)
    return start - at + cast
end

function H:Attach(state)
    local owner = runtime()
    if not (state and owner and owner.RootEvidence) then return nil end
    state.hunterMarkRoot = owner:RootEvidence()
    return state.hunterMarkRoot
end

function H:Evidence(action, tooltip)
    return actionEvidence(action, tooltip)
end

function H:Blocker(action, state, descriptor, tooltip, actionStart)
    local found = actionEvidence(action, tooltip)
    if not found then return nil, false end
    if (action.actor or "player") ~= "player" then
        return "Hunter's Mark is player-owned", true
    end
    local root, reason = rootEvidence(state)
    if not root then return reason, true end
    local rootRank = sealedRank(root, found.spellId)
    if not rootRank or rootRank.rangedAttackPowerBonus
        ~= found.rangedAttackPowerBonus then
        return "Hunter's Mark root evidence changed", true
    end
    local record = targetRecord(state, descriptor)
    if not exactDescriptor(descriptor, record) then
        return "Hunter's Mark requires the selected hostile", true
    end
    local mark
    mark, reason = currentMark(state, record,
        applicationLead(action, state, tooltip, actionStart))
    if reason then return reason, true end
    if mark and mark.spellId ~= found.spellId then
        return "Hunter's Mark rank interaction is unresolved", true
    end
    if mark and mark.probability >= APPLICATION_BLOCK_THRESHOLD then
        return "target already has Hunter's Mark", true
    end
    return nil, true
end

function H:AuraActive(action, state, descriptor, tooltip, lead)
    local found = actionEvidence(action, tooltip)
    if not found then return nil, false end
    local record = targetRecord(state, descriptor)
    if not exactDescriptor(descriptor, record) then return false, true end
    local mark, reason = currentMark(state, record, lead)
    if reason then return nil, true, reason end
    return mark and mark.spellId == found.spellId
        and mark.probability >= APPLICATION_BLOCK_THRESHOLD or false, true
end

function H:Score(context)
    local action, tooltip = context and context.action,
        context and context.tooltip
    local found = actionEvidence(action, tooltip)
    if not found then return false end
    local blocker = self:Blocker(action, context.state, context.descriptor,
        tooltip, context.actionStart)
    if blocker then
        context.value, context.reason = -100000, blocker
        return true
    end
    local delivery = clamp(context.effectDelivery)
    if delivery == nil or delivery <= 0 then
        context.value, context.reason = -100000,
            "Hunter's Mark delivery unavailable"
        return true
    end
    context.power, context.expectedPower, context.effectivePower = 0, 0, 0
    context.value = 0
    context.hunterMarkDelivery = delivery
    context.reason = "enables exact target-local ranged weapon damage"
    if delivery < 0.999 then context.estimated = true end
    return true
end

local function candidateDescriptor(candidate)
    return { unit = candidate and candidate.target or "target",
        relation = candidate and candidate.targetRelation,
        source = candidate and candidate.targetSource,
        key = candidate and candidate.targetKey,
        guid = candidate and candidate.targetGUID,
        record = candidate and candidate.descriptor
            and candidate.descriptor.record }
end

function H:Apply(state, candidate)
    local found = actionEvidence(candidate and candidate.action,
        candidate and candidate.tooltip)
    if not found then return false end
    local descriptor = candidateDescriptor(candidate)
    local blocker = self:Blocker(candidate.action, state, descriptor,
        candidate.tooltip, state and state.time)
    if blocker then return false end
    local delivery = clamp(candidate.effectDelivery)
    if delivery == nil or delivery <= 0 then return false end
    local record = targetRecord(state, descriptor)
    if not record then return false end
    record.projectedAuras = record.projectedAuras or {}
    local key = KEY_PREFIX .. tostring(found.spellId)
    local prior = record.projectedAuras[key]
    local priorProbability = type(prior) == "table"
        and clamp(prior.applicationProbability) or 0
    local probability = priorProbability
        and priorProbability + (1 - priorProbability) * delivery or delivery
    record.projectedAuras[key] = { hunterMark = true,
        spellId = found.spellId, remaining = found.duration,
        duration = found.duration, applicationProbability = probability,
        mine = true, targetGuid = record.guid,
        targetKey = record.key, rangedAttackPowerBonus =
            found.rangedAttackPowerBonus, hunterMarkEvidence = copy(found) }
    if state.targetGUID == record.guid then state.auras = record.projectedAuras end
    local graphState = XelAssist.Graph.State
    if graphState and graphState.RefreshHostileRecord then
        graphState:RefreshHostileRecord(state, record.key)
    end
    return true
end

local function expectedAttackPower(state, targetGuid)
    local record = targetRecord(state, nil, targetGuid)
    if not record then return nil, false, "Hunter's Mark target unavailable" end
    local mark, reason = currentMark(state, record, 0)
    if reason then return nil, false, reason end
    if not mark then return 0, false, nil end
    return mark.evidence.rangedAttackPowerBonus * mark.probability,
        mark.probability < 0.999, nil
end

function H:AutoShotBonus(state, targetGuid)
    local root, reason = rootEvidence(state)
    if not root then return nil, false, reason end
    local attackPower, estimated
    attackPower, estimated, reason = expectedAttackPower(state, targetGuid)
    if attackPower == nil then return nil, false, reason end
    return attackPower / 14 * root.lane.speed * root.lane.damageMultiplier,
        estimated, nil
end

local function weaponDescriptor(action, tooltip)
    local found = tooltip and tooltip.hunterRangedWeaponEvidence
    if not (type(found) == "table" and found.valid == true
        and found.exact == true and found.portfolio == "hunterMark"
        and found.attackType == "ranged" and found.weaponEffectCount == 1
        and tonumber(action and action.spellId) == tonumber(found.spellId)
        and tonumber(tooltip.weaponCoefficient)
            == tonumber(found.weaponCoefficient)
        and (tooltip.weaponNormalized == true) == (found.normalized == true)) then
        return nil
    end
    return found
end

function H:WeaponActionBonus(action, tooltip, state, targetGuid, evidence)
    local found = weaponDescriptor(action, tooltip)
    if not found then return nil, false,
        "exact Hunter ranged weapon evidence unavailable" end
    local root, reason = rootEvidence(state)
    if not root then return nil, false, reason end
    if found.normalized and not (type(evidence) == "table"
        and evidence.exact == true and evidence.normalized == true) then
        return nil, false, "exact normalized ranged weapon lane unavailable"
    end
    local speed = found.normalized and tonumber(
        evidence and evidence.normalizedSpeed) or root.lane.speed
    if not (speed and speed > 0) then
        return nil, false, "exact ranged weapon multiplier unavailable"
    end
    local attackPower, estimated
    attackPower, estimated, reason = expectedAttackPower(state, targetGuid)
    if attackPower == nil then return nil, false, reason end
    -- VMaNGOS adds target-side AP once after the spell's weapon coefficient,
    -- then applies the ranged damage lane multiplier to that added component.
    return attackPower / 14 * speed * root.lane.damageMultiplier,
        estimated, nil
end
