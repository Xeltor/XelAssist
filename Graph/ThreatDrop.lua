-- Bounded player threat-drop projection. This module changes only projected
-- player threat evidence; hostile identities, live victims, pet ownership and
-- combat state remain immutable until a later live observation resolves them.
XelAssist.Graph.ThreatDrop = {}
local T = XelAssist.Graph.ThreatDrop

T.RESISTIBLE_ALL = "resistible-all-or-nothing"
T.REFERENCE_CLEAR = "reference-clear"
T.TEMPORARY_FLAT = "temporary-flat"
T.TARGET_LOCAL_FLAT = "target-local-flat"
T.UNKNOWN = "unknown"
local VALID = { [T.RESISTIBLE_ALL] = true,
    [T.REFERENCE_CLEAR] = true, [T.TEMPORARY_FLAT] = true,
    [T.TARGET_LOCAL_FLAT] = true, [T.UNKNOWN] = true }

local function evidenceOf(subject, tooltip)
    if type(subject) ~= "table" then return nil, tooltip or {} end
    if subject.action then
        tooltip = tooltip or subject.tooltip
        subject = subject.action
    end
    local facts = type(subject.facts) == "table" and subject.facts or subject
    return facts, type(tooltip) == "table" and tooltip or {}
end

function T:Model(subject, tooltip)
    local facts, observed = evidenceOf(subject, tooltip)
    local model = facts and facts.threatDropModel
        or observed.threatDropModel
    if facts and facts.kind == "threatDrop" then
        return VALID[model] and model or self.UNKNOWN, facts, observed
    end
    return nil, facts, observed
end

function T:Is(subject)
    return self:Model(subject) ~= nil
end

local function threatOf(record)
    return record and record.threat
end

local function projectedAggro(record)
    local threat = threatOf(record)
    if threat and threat.projectedPlayerReferenceKnown
        and threat.projectedPlayerReference == false then return false, true end
    if threat and (threat.projectedPlayerOwnershipUnknown
        or threat.projectedOwnershipUnknown) then return nil, false end
    if threat and threat.projectedPlayerHasAggro ~= nil then
        return threat.projectedPlayerHasAggro, true
    end
    if threat and threat.playerHasAggro ~= nil then
        return threat.playerHasAggro, true
    end
    if record and record.hasPlayerAggro ~= nil then
        return record.hasPlayerAggro, true
    end
    return nil, false
end

function T:Risk(state)
    if state and state.inCombat == false then return 0, 0, 0 end
    local certain, uncertain, total = 0, 0, 0
    local hostiles = state and state.hostiles
    local i, record
    for i = 1, table.getn(hostiles and hostiles.order or {}) do
        record = hostiles.byKey and hostiles.byKey[hostiles.order[i]]
        if record and record.dead ~= true then
            local aggro, exact = projectedAggro(record)
            total = total + 1
            if exact and aggro then certain = certain + 1
            elseif not exact then uncertain = uncertain + 1 end
        end
    end
    if total == 0 then
        if state and state.hasAggro == true then certain = 1
        elseif state and (state.hasAggro == nil
            or state.targetPlayerThreatDeltaExact == false) then
            uncertain = 1
        end
    end
    return certain, uncertain, total
end

local function temporaryFacts(context, facts, observed)
    local tooltip = context and context.tooltip or observed or {}
    local amount = tonumber(facts.threatDropAmount)
        or tonumber(tooltip.threatDropAmount)
    local duration = tonumber(facts.threatDropDuration)
        or tonumber(tooltip.threatDropDuration)
        or tonumber(tooltip.duration)
    if amount then amount = math.max(0, amount) end
    if duration then duration = math.max(0, duration) end
    return amount, duration
end

function T:Blocker(action, state, tooltip)
    local model, facts, observed = self:Model(action, tooltip)
    if not model then return nil end
    if model == self.UNKNOWN then return "threat drop mechanics unknown" end
    if model == self.TARGET_LOCAL_FLAT then
        local dedicated = XelAssist.Graph.RogueFeint
        if not (dedicated and dedicated:Is(action, tooltip)) then
            return "target-local threat mechanics unavailable"
        end
        return nil
    end
    if model == self.TEMPORARY_FLAT then
        local amount, duration = temporaryFacts(nil, facts, observed)
        if not amount or amount <= 0 or not duration or duration <= 0 then
            return "temporary threat reduction evidence unknown"
        end
    end
    return nil
end

local clearEvidence

local function referenceRisk(state, facts)
    if state and state.inCombat == false then return 0, 0 end
    local clearable, uncertain = 0, 0
    local hostiles = state and state.hostiles
    local i, record
    for i = 1, table.getn(hostiles and hostiles.order or {}) do
        record = hostiles.byKey and hostiles.byKey[hostiles.order[i]]
        if record and record.dead ~= true then
            local aggro, exact = projectedAggro(record)
            local eligible, known = clearEvidence(record,
                T.REFERENCE_CLEAR, facts)
            if known and eligible then
                if exact and aggro then clearable = clearable + 1
                elseif not exact then uncertain = uncertain + 1 end
            elseif not known and (not exact or aggro) then
                uncertain = uncertain + 1
            end
        end
    end
    if table.getn(hostiles and hostiles.order or {}) == 0 then
        if state and state.hasAggro == true then uncertain = 1
        elseif state and (state.hasAggro == nil
            or state.targetPlayerThreatDeltaExact == false) then
            uncertain = 1
        end
    end
    return clearable, uncertain
end

function T:Score(context)
    local model, facts, observed = self:Model(context)
    if not model then return false end
    local state = context.state or {}
    local certain, uncertain = self:Risk(state)
    context.estimated, context.threatDropModel = true, model
    if model == self.UNKNOWN then
        context.value, context.reason = -100000,
            "threat drop mechanics unknown"
        return true
    end
    if model == self.TARGET_LOCAL_FLAT then
        context.value, context.reason = -100000,
            "target-local threat scorer unavailable"
        return true
    end
    if state.tank then
        context.value, context.reason = -700, "preserves tank threat"
        return true
    end
    if model == self.TEMPORARY_FLAT then
        local amount, duration = temporaryFacts(context, facts, observed)
        if not amount or amount <= 0 or not duration or duration <= 0 then
            context.value, context.reason = -100000,
                "temporary threat reduction evidence unknown"
        elseif certain > 0 then
            context.value = 1350 + math.min(1500,
                math.sqrt(amount) * 45) * math.min(1, duration / 10)
            context.reason = "temporarily lowers unwanted threat"
        elseif uncertain > 0 then
            context.value, context.reason = 500,
                "temporarily lowers uncertain threat"
        else
            context.value, context.reason = -500, "no unwanted threat"
        end
    elseif model == self.REFERENCE_CLEAR then
        local clearable, unclear = referenceRisk(state, facts)
        if clearable > 0 then
            context.value = 4400 + math.min(3, clearable - 1) * 450
            context.reason = "clears unwanted hostile references"
        elseif unclear > 0 then
            context.value, context.reason = 900,
                "may clear an uncertain hostile reference"
        else
            context.value, context.reason = -500,
                "no clearable hostile reference"
        end
    elseif certain > 0 then
        context.value = 4200 + math.min(3, certain - 1) * 450
        context.reason = "may drop unwanted aggro"
    elseif uncertain > 0 then
        context.value, context.reason = 900, "may resolve uncertain aggro"
    else
        context.value, context.reason = -500, "no unwanted aggro"
    end
    return true
end

local function ensureThreat(record)
    if not record.threat then record.threat = { available = false,
        playerDelta = 0, playerDeltaExact = false, petDelta = 0 } end
    return record.threat
end

local function markUnknown(record, model)
    local threat = ensureThreat(record)
    threat.projectedPlayerOwnershipUnknown = true
    threat.projectedPlayerReferenceKnown = false
    threat.projectedThreatDropModel = model
    threat.projectedPlayerHasAggro = nil
    threat.playerDeltaExact = false
end

local function markCleared(record, model)
    local threat = ensureThreat(record)
    threat.projectedPlayerOwnershipUnknown = nil
    threat.projectedPlayerReferenceKnown = true
    threat.projectedPlayerReference = false
    threat.projectedPlayerHasAggro = false
    threat.projectedThreatDropModel = model
    threat.playerThreatOffset = nil
    threat.playerDelta, threat.playerDeltaExact = 0, true
    threat.containsBoundedPlayerThreat = nil
    if record.projectedThreat then record.projectedThreat.player = nil end
end

local function markUnchanged(record, model)
    local threat = ensureThreat(record)
    threat.projectedThreatDropModel = model
    threat.projectedReferenceClearEligible = false
end

clearEvidence = function(record, model, facts)
    local evidence = record and record.threatDropEvidence
    if evidence and evidence[model] then evidence = evidence[model] end
    if type(evidence) == "table" and evidence.model ~= nil
        and evidence.model ~= model then return nil, false end
    if type(evidence) == "table" and evidence.known == true
        and evidence.eligible ~= nil then
        return evidence.eligible and true or false, true
    end
    if facts.threatDropCoverageExact == true then return true, true end
    return nil, false
end

local function selectedKey(hostiles)
    if not hostiles then return nil end
    if hostiles.selectedKey ~= nil then return hostiles.selectedKey end
    local i, record
    for i = 1, table.getn(hostiles.order or {}) do
        record = hostiles.byKey and hostiles.byKey[hostiles.order[i]]
        if record and record.selected then return hostiles.order[i] end
    end
    return nil
end

local function applyTemporary(record, action, candidate, facts)
    local amount, duration = temporaryFacts(candidate, facts)
    if not amount or amount <= 0 or not duration or duration <= 0 then
        markUnknown(record, T.TEMPORARY_FLAT)
        return false
    end
    local threat = ensureThreat(record)
    threat.playerThreatOffset = { amount = -amount, remaining = duration,
        exact = true, sourceSpellId = tonumber(action.spellId),
        model = T.TEMPORARY_FLAT }
    markUnknown(record, T.TEMPORARY_FLAT)
    return true
end

local function playerReference(record)
    local threat = ensureThreat(record)
    if threat.projectedPlayerReferenceKnown then
        return threat.projectedPlayerReference and true or false, true
    end
    if threat.playerReferenceKnown then
        return threat.playerReference and true or false, true
    end
    if threat.playerHasAggro == true or record.hasPlayerAggro == true
        or (tonumber(threat.playerDelta) or 0) > 0 then return true, true end
    return nil, false
end

function T:Apply(out, candidate)
    local action = candidate and candidate.action
    local model, facts = self:Model(candidate)
    if not model or model == self.UNKNOWN
        or model == self.TARGET_LOCAL_FLAT or not out then return false end
    local hostiles, affected, cleared, uncertain, unchanged = out.hostiles,
        {}, 0, 0, 0
    local selected, selectedOutcome = selectedKey(hostiles), nil
    local i, key, record
    for i = 1, table.getn(hostiles and hostiles.order or {}) do
        key = hostiles.order[i]
        record = hostiles.byKey and hostiles.byKey[key]
        if record and record.dead ~= true then
            table.insert(affected, record.key or key)
            local outcome = "unknown"
            if model == self.REFERENCE_CLEAR then
                local eligible, known = clearEvidence(record, model, facts)
                if known and eligible then
                    markCleared(record, model)
                    cleared, outcome = cleared + 1, "cleared"
                elseif known then
                    markUnchanged(record, model)
                    unchanged, outcome = unchanged + 1, "unchanged"
                else
                    markUnknown(record, model)
                    uncertain = uncertain + 1
                end
            elseif model == self.TEMPORARY_FLAT then
                local exists, known = playerReference(record)
                if known and not exists then
                    markUnchanged(record, model)
                    unchanged, outcome = unchanged + 1, "unchanged"
                elseif known and applyTemporary(
                    record, action, candidate, facts) then
                    uncertain, outcome = uncertain + 1, "unknown"
                else
                    markUnknown(record, model)
                    uncertain = uncertain + 1
                end
            else
                markUnknown(record, model)
                uncertain = uncertain + 1
            end
            if key == selected then selectedOutcome = outcome end
        end
    end
    if table.getn(affected) == 0 then uncertain = 1 end
    local complete = hostiles and hostiles.capped == false or false
    out.playerThreatDrop = { model = model,
        outcomeKnown = uncertain == 0 and complete,
        affectedKeys = affected, cleared = cleared, uncertain = uncertain,
        unchanged = unchanged, hostileSetComplete = complete,
        sourceSpellId = tonumber(action.spellId),
        outcomeCoupled = model == self.RESISTIBLE_ALL and true or nil }
    if selectedOutcome == "cleared" then out.hasAggro = false
    elseif selectedOutcome == "unknown" or not selectedOutcome then
        out.hasAggro = nil
    end
    local selectedRecord = selected and hostiles
        and hostiles.byKey and hostiles.byKey[selected] or nil
    if selectedOutcome == "cleared" then
        out.targetPlayerThreatDeltaExact = true
    elseif selectedOutcome == "unchanged" then
        out.targetPlayerThreatDeltaExact = not (selectedRecord
            and selectedRecord.threat
            and selectedRecord.threat.playerDeltaExact == false)
    elseif selectedOutcome == "unknown" or not selectedOutcome then
        out.targetPlayerThreatDeltaExact = false
    end
    return true
end

function T:Advance(out, elapsed)
    elapsed = math.max(0, tonumber(elapsed) or 0)
    if elapsed <= 0 then return end
    local hostiles, i, record = out and out.hostiles, nil, nil
    for i = 1, table.getn(hostiles and hostiles.order or {}) do
        record = hostiles.byKey and hostiles.byKey[hostiles.order[i]]
        local threat = threatOf(record)
        local offset = threat and threat.playerThreatOffset
        if offset and offset.model == self.TEMPORARY_FLAT then
            offset.remaining = math.max(0,
                (tonumber(offset.remaining) or 0) - elapsed)
            if offset.remaining <= 0 then threat.playerThreatOffset = nil end
        end
    end
end
