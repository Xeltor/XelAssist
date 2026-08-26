-- Graph adapter for exact Paladin exclusive-aura state. Attach is a mutable
-- root-boundary operation: it observes only the already-frozen friendly units
-- and stores exact per-recipient snapshots. Prepare and Apply perform no live
-- unit or aura reads. The adapter assigns no spell priority or aura utility.
XelAssist.Graph.PaladinAuraProjection = {}
local P = XelAssist.Graph.PaladinAuraProjection
local Auras = XelAssist.Game.Player.PaladinAuraState

P.MAX_RECIPIENTS = 8
P.MAX_CLASSIFICATIONS = 256
local CLASSIFICATION_CACHE, CLASSIFICATION_COUNT = {}, 0

local FRIENDLY = { self = true, pet = true, party = true,
    raid = true, friendly = true, ally = true, external = true }

local function validGUID(value)
    return value ~= nil and value ~= "" and value ~= "0x000000000"
        and value ~= "0x0000000000000000"
end

local function copyClassification(source)
    if type(source) ~= "table" then return nil end
    return { kind = source.kind, spellId = source.spellId,
        family = source.family, flags = source.flags,
        exclusiveFamily = source.exclusiveFamily,
        recipientRelation = source.recipientRelation,
        exact = source.exact, source = source.source }
end

local function copyAura(source)
    if type(source) ~= "table" then return nil end
    return { spellId = source.spellId, name = source.name,
        sourceGUID = source.sourceGUID, recipientGUID = source.recipientGUID,
        recipientRelation = source.recipientRelation,
        duration = source.duration, expirationTime = source.expirationTime,
        classification = copyClassification(source.classification),
        exclusiveFamily = source.exclusiveFamily,
        projected = source.projected, exact = source.exact }
end

local function copyLastJudgement(source)
    if type(source) ~= "table" then return nil end
    -- outcome is frozen root evidence and remains atomic across graph branches.
    return { targetGUID = source.targetGUID,
        sourceSealSpellId = source.sourceSealSpellId,
        outcome = source.outcome, downstreamPending = source.downstreamPending,
        exact = source.exact }
end

local function copyRecipient(source)
    if type(source) ~= "table" then return nil end
    local out = { available = source.available, reason = source.reason,
        unit = source.unit, key = source.key, expectedGUID = source.expectedGUID,
        guid = source.guid, playerGUID = source.playerGUID,
        rootRelation = source.rootRelation,
        recipientRelation = source.recipientRelation,
        source = source.source, activeSeal = copyAura(source.activeSeal),
        righteousFury = copyAura(source.righteousFury),
        lastJudgement = copyLastJudgement(source.lastJudgement),
        blessingsByCaster = {} }
    local caster, aura
    for caster, aura in pairs(source.blessingsByCaster or {}) do
        out.blessingsByCaster[caster] = copyAura(aura)
    end
    return out
end

local function unavailable(record, key, reason)
    return { available = false, unit = record and record.unit,
        key = key, expectedGUID = record and record.guid,
        rootRelation = record and record.relation, reason = reason,
        source = "frozen friendly Paladin aura recipient" }
end

local function observe(record, key)
    if not (record and type(record.unit) == "string"
        and validGUID(record.guid) and FRIENDLY[record.relation]) then
        return unavailable(record, key,
            "Paladin frozen recipient identity unavailable")
    end
    local ok, snapshot = pcall(
        Auras.Observe, Auras, record.unit, record.guid)
    if not ok or type(snapshot) ~= "table" then
        snapshot = unavailable(record, key,
            "Paladin aura observation unavailable")
    end
    snapshot.key, snapshot.expectedGUID = key, record.guid
    snapshot.rootRelation = record.relation
    return snapshot
end

local function playerRecord(state)
    local friendlies = state and state.friendlies
    local key = friendlies and friendlies.byUnit
        and friendlies.byUnit.player or nil
    local record = key ~= nil and friendlies.byKey
        and friendlies.byKey[key] or nil
    if not (record and record.unit == "player"
        and record.relation == "self" and validGUID(record.guid)) then
        return nil, nil
    end
    return record, key
end

-- Attach may retain unavailable entries for individual friendlies, but the
-- self snapshot must be exact or the whole Paladin projection is unavailable.
function P:Attach(state)
    if not (state and Auras and type(Auras.Observe) == "function") then
        return false
    end
    local root = { available = false, byKey = {}, byUnit = {}, byGUID = {},
        source = "exact root Paladin aura snapshots" }
    state.paladinAuraState = root
    local friendlies = state.friendlies
    local order = friendlies and friendlies.order or nil
    if type(order) ~= "table" or table.getn(order) > self.MAX_RECIPIENTS then
        root.reason = "Paladin friendly snapshot budget unavailable"
        return false
    end
    local selfRecord, selfKey = playerRecord(state)
    if not selfRecord then
        root.reason = "Paladin self recipient unavailable"
        return false
    end
    local selfSnapshot = observe(selfRecord, selfKey)
    root.byKey[selfKey], root.byUnit.player = selfSnapshot, selfKey
    root.byGUID[selfRecord.guid] = selfKey
    root.player, root.playerKey = selfSnapshot, selfKey
    if selfSnapshot.available ~= true
        or selfSnapshot.guid ~= selfRecord.guid then
        root.reason = selfSnapshot.reason or "Paladin self aura state unavailable"
        return false
    end

    local retained, index = 1, nil
    for index = 1, table.getn(order) do
        local key = order[index]
        if key ~= selfKey then
            local record = friendlies.byKey and friendlies.byKey[key]
            local snapshot = observe(record, key)
            root.byKey[key] = snapshot
            if record and type(record.unit) == "string" then
                root.byUnit[record.unit] = key
            end
            if record and validGUID(record.guid) then
                root.byGUID[record.guid] = key
            end
            retained = retained + 1
        end
    end
    root.available, root.playerGUID, root.recipientCount = true,
        selfSnapshot.playerGUID, retained
    return true
end

-- Graph.State:Copy can delegate here. Opaque keys and GUIDs remain identical;
-- only mutable aura records are duplicated for branch-local replacement.
function P:Copy(sourceState, targetState)
    local source = sourceState and sourceState.paladinAuraState
    if not (source and targetState) then return false end
    local out = { available = source.available, reason = source.reason,
        source = source.source, playerGUID = source.playerGUID,
        playerKey = source.playerKey, recipientCount = source.recipientCount,
        byKey = {}, byUnit = {}, byGUID = {} }
    local key, snapshot
    for key, snapshot in pairs(source.byKey or {}) do
        out.byKey[key] = copyRecipient(snapshot)
    end
    local unit
    for unit, key in pairs(source.byUnit or {}) do out.byUnit[unit] = key end
    local guid
    for guid, key in pairs(source.byGUID or {}) do out.byGUID[guid] = key end
    out.player = out.byKey[out.playerKey]
    targetState.paladinAuraState = out
    return true
end

local function retainedFriendly(state, descriptor)
    local root, friendlies = state and state.paladinAuraState,
        state and state.friendlies
    if not (root and root.available == true and friendlies
        and friendlies.byKey and descriptor and descriptor.key ~= nil
        and validGUID(descriptor.guid) and type(descriptor.unit) == "string") then
        return nil, "Paladin frozen recipient unavailable"
    end
    local record = friendlies.byKey[descriptor.key]
    local snapshot = root.byKey and root.byKey[descriptor.key]
    if descriptor.record ~= nil and descriptor.record ~= record then
        return nil, "Paladin frozen recipient changed"
    end
    if not (record and snapshot and snapshot.available == true
        and FRIENDLY[record.relation] and FRIENDLY[descriptor.relation]
        and record.guid == descriptor.guid and record.unit == descriptor.unit
        and snapshot.guid == record.guid and snapshot.unit == record.unit
        and snapshot.expectedGUID == record.guid) then
        return nil, "Paladin frozen recipient changed"
    end
    return snapshot, nil, descriptor.key
end

local function retainedPlayer(state)
    local root = state and state.paladinAuraState
    local snapshot = root and root.player
    if not (root and root.available == true and snapshot
        and snapshot.available == true and snapshot.guid == root.playerGUID
        and snapshot.playerGUID == root.playerGUID
        and snapshot.recipientRelation == "self") then
        return nil, "Paladin self-aura state unavailable"
    end
    return snapshot, nil, root.playerKey
end

local function exactHostile(state, descriptor)
    if not (descriptor and descriptor.relation == "hostile"
        and validGUID(descriptor.guid)) then
        return nil, "Judgement target identity unavailable"
    end
    local hostiles = state and state.hostiles
    if hostiles and hostiles.byKey then
        if descriptor.key == nil then
            return nil, "Judgement target identity unavailable"
        end
        local record = hostiles.byKey[descriptor.key]
        if descriptor.record ~= nil and descriptor.record ~= record then
            return nil, "Judgement target identity unavailable"
        end
        if not (record and record.relation == "hostile"
            and record.guid == descriptor.guid
            and record.unit == descriptor.unit and record.dead ~= true) then
            return nil, "Judgement target identity unavailable"
        end
    elseif descriptor.exact ~= true then
        return nil, "Judgement target identity unavailable"
    end
    return { guid = descriptor.guid, relation = "hostile", exact = true }, nil
end

local function classified(action)
    local facts = action and action.facts or {}
    local captured = facts.paladinClassification
    if facts.paladinAction == true then
        if type(captured) ~= "table" or captured.exact ~= true
            or tonumber(captured.spellId) ~= tonumber(action and action.spellId)
            or captured.family ~= Auras.PALADIN_FAMILY
            or type(captured.kind) ~= "string" then
            return nil, "captured Paladin action classification unavailable"
        end
        return captured, nil
    end
    if not (Auras and type(Auras.Classify) == "function") then
        return nil, "Paladin aura classifier unavailable"
    end
    local spellId = tonumber(action and action.spellId)
    local cached = spellId and CLASSIFICATION_CACHE[spellId] or nil
    if cached then return cached, nil end
    local ok, classification, reason = pcall(
        Auras.Classify, Auras, action and action.spellId)
    if not ok then return nil, "Paladin aura classifier unavailable" end
    if classification and spellId
        and CLASSIFICATION_COUNT < P.MAX_CLASSIFICATIONS then
        CLASSIFICATION_CACHE[spellId] = classification
        CLASSIFICATION_COUNT = CLASSIFICATION_COUNT + 1
    end
    return classification, reason
end

function P:Invalidate()
    CLASSIFICATION_CACHE, CLASSIFICATION_COUNT = {}, 0
end

local function claimed(action)
    local facts = action and action.facts or {}
    return facts.paladinAura == true or facts.paladinSeal == true
        or facts.paladinBlessing == true or facts.paladinJudgement == true
        or facts.exclusiveFamily == "paladinSeal"
        or facts.exclusiveFamily == "paladinBlessingByCaster"
end

function P:Prepare(action, state, descriptor, downstreamOutcome)
    local classification, reason = classified(action)
    if not classification then return nil, reason, claimed(action) end
    local kind = classification.kind
    if kind == "other" then return nil, nil, false end
    if action and action.actor and action.actor ~= "player" then
        return nil, "Paladin aura requires the player actor", true
    end
    local projection, key
    if kind == "seal" then
        local recipient
        recipient, reason, key = retainedFriendly(state, descriptor)
        local root = state and state.paladinAuraState
        if not recipient or key ~= (root and root.playerKey)
            or descriptor.unit ~= "player" or descriptor.relation ~= "self" then
            return nil, reason or "Paladin seal requires exact self recipient", true
        end
        projection, reason = Auras:PrepareSeal(action, recipient, classification)
    elseif kind == "blessing" then
        local recipient
        recipient, reason, key = retainedFriendly(state, descriptor)
        if not recipient then return nil, reason, true end
        projection, reason = Auras:PrepareBlessing(
            action, recipient, classification)
    elseif kind == "judgement" then
        local player, target
        player, reason, key = retainedPlayer(state)
        if not player then return nil, reason, true end
        target, reason = exactHostile(state, descriptor)
        if not target then return nil, reason, true end
        projection, reason = Auras:PrepareJudgement(
            action, player, target, downstreamOutcome, classification)
        key = descriptor.key
    else
        return nil, "Paladin aura downstream effect unavailable", true
    end
    if not projection then return nil, reason, true end
    projection.paladinAuraProjection = true
    projection.recipientKey = key
    projection.actionSpellId = tonumber(action and action.spellId)
    local records = kind == "judgement" and state.hostiles
        and state.hostiles.byKey or state.friendlies and state.friendlies.byKey
    local record = records and records[key]
    projection.frozenRecipientUnit = record and record.unit
        or descriptor and descriptor.unit
    projection.frozenRootRelation = record and record.relation
        or descriptor and descriptor.relation
    return projection, nil, true
end

function P:Blocker(action, state, descriptor, downstreamOutcome)
    local projection, reason, handled = self:Prepare(
        action, state, descriptor, downstreamOutcome)
    if not handled then return nil, false end
    if not projection then return reason, true, nil end
    return nil, true, projection
end

function P:Apply(state, projection)
    local root = state and state.paladinAuraState
    if not (root and root.available == true and projection
        and projection.paladinAuraProjection == true
        and projection.action and projection.actionSpellId
            == tonumber(projection.action.spellId)) then return false end
    if projection.kind == "seal" or projection.kind == "blessing" then
        local recipient = root.byKey and root.byKey[projection.recipientKey]
        local friendlies = state.friendlies
        local record = friendlies and friendlies.byKey
            and friendlies.byKey[projection.recipientKey]
        if not (recipient and recipient.available == true and record
            and record.guid == projection.recipientGUID
            and record.unit == recipient.unit
            and record.unit == projection.frozenRecipientUnit
            and record.relation == recipient.rootRelation
            and record.relation == projection.frozenRootRelation
            and recipient.guid == projection.recipientGUID) then return false end
        if projection.kind == "seal" then
            if projection.recipientKey ~= root.playerKey
                or recipient ~= root.player then return false end
            return Auras:ApplySeal(recipient, projection)
        end
        return Auras:ApplyBlessing(recipient, projection)
    elseif projection.kind == "judgement" then
        local hostiles = state.hostiles
        if hostiles and hostiles.byKey then
            local record = hostiles.byKey[projection.recipientKey]
            if not (record and record.relation == "hostile"
                and record.guid == projection.targetGUID
                and record.unit == projection.frozenRecipientUnit
                and record.relation == projection.frozenRootRelation
                and record.dead ~= true) then return false end
        end
        return Auras:ApplyJudgement(root.player, projection)
    end
    return false
end
