-- Privacy-safe, bounded recommendation history and status correlation.
XelAssist.Core.DecisionLog = {}
local L = XelAssist.Core.DecisionLog
local XA = XelAssist

local function msg(text, r, g, b)
    DEFAULT_CHAT_FRAME:AddMessage("XelAssist: " .. text, r or 0.35, g or 0.85, b or 1)
end

local function resistanceComponents(plan)
    if not (plan.resistance and type(plan.resistance.components) == "table") then return nil end
    local out, i = {}, nil
    for i = 1, math.min(4, table.getn(plan.resistance.components)) do
        local component = plan.resistance.components[i]
        table.insert(out, { school = component.school, schoolName = component.schoolName,
            phase = component.componentPhase, weight = component.componentWeight,
            multiplier = component.multiplier, decisionWeight = component.decisionWeight,
            confidence = component.confidence, unknown = component.unknown and true or false,
            samples = component.samples })
    end
    return out
end

function L:Record(plan, mode)
    if type(XelAssistLog) ~= "table" then XelAssistLog = {} end
    local state, action = plan.observed or {}, plan.action
    table.insert(XelAssistLog, { at = time and time() or 0, mode = mode,
        action = action.name, spellId = action.spellId, rank = action.rank,
        actor = action.actor or "player", executor = action.executor or "playerSpell",
        reason = plan.reason, status = "attempted", confidence = plan.confidence,
        value = math.floor(plan.value or 0), downtime = plan.downtime,
        threat = math.floor(plan.threat or 0), hp = state.health, hpMax = state.healthMax,
        targetHp = state.targetHealth, targetMax = state.targetMax,
        resource = state.resource, resourceMax = state.resourceMax,
        moving = state.moving, aggro = state.hasAggro, tank = state.tank,
        distance = state.distance, distanceKind = state.distanceKind,
        resistanceSchool = plan.resistance and plan.resistance.school,
        resistanceSchoolName = plan.resistance and plan.resistance.schoolName,
        resistanceMode = plan.resistance and plan.resistance.mode,
        resistanceComponents = resistanceComponents(plan),
        resistanceMultiplier = plan.resistance and plan.resistance.multiplier,
        resistanceDecisionMultiplier = plan.resistance and plan.resistance.decisionMultiplier,
        resistanceDamageTakenMultiplier = plan.resistance and plan.resistance.damageTakenMultiplier,
        resistanceUncertaintyMultiplier = plan.resistance and plan.resistance.uncertaintyMultiplier,
        resistanceConfidence = plan.resistance and plan.resistance.confidence,
        resistanceSamples = plan.resistance and plan.resistance.samples,
        resistanceSource = plan.resistance and plan.resistance.source })
    while table.getn(XelAssistLog) > 200 do table.remove(XelAssistLog, 1) end
end

function L:UpdateStatus(spellId, actor, status)
    if type(XelAssistLog) ~= "table" or not spellId then return false end
    actor = actor or "player"
    local spellName = SpellInfo and SpellInfo(spellId) or nil
    local i
    for i = table.getn(XelAssistLog), 1, -1 do
        local row = XelAssistLog[i]
        local active = row.status == "attempted" or row.status == "queued"
            or row.status == "accepted" or row.status == "start"
            or row.status == "channel" or row.status == "go"
        if active and row.actor == actor
            and (tonumber(row.spellId) == tonumber(spellId)
                or not row.spellId and spellName and row.action == spellName) then
            row.status = string.lower(status or "event")
            return true
        end
    end
    return false
end

function L:RecordError(detail)
    if type(XelAssistCharDB.runtime) ~= "table" then XelAssistCharDB.runtime = {} end
    XelAssistCharDB.runtime.lastError = tostring(detail or "unknown evaluation failure")
    XelAssistCharDB.runtime.lastErrorAt = time and time() or 0
end

local function componentDetail(row)
    if type(row.resistanceComponents) ~= "table" then return "" end
    local parts, total, i = {}, 0, nil
    for i = 1, table.getn(row.resistanceComponents) do
        total = total + (tonumber(row.resistanceComponents[i].weight) or 0)
    end
    for i = 1, table.getn(row.resistanceComponents) do
        local component = row.resistanceComponents[i]
        local label = component.phase or component.schoolName
            or component.school ~= nil and XelAssist.Combat.Resistance
                and XelAssist.Combat.Resistance:SchoolName(component.school) or "part"
        local share = total > 0 and math.floor((component.weight or 0) * 100 / total + 0.5) or 0
        table.insert(parts, label .. " " .. math.floor((component.multiplier or 1) * 100 + 0.5)
            .. "%@" .. share .. "%" .. (component.unknown and " uncertain" or ""))
    end
    return " {" .. table.concat(parts, ", ") .. "}"
end

local function resistanceDetail(row)
    if not row.resistanceDecisionMultiplier then return "" end
    local school = row.resistanceSchoolName
        or row.resistanceSchool ~= nil and XelAssist.Combat.Resistance
            and XelAssist.Combat.Resistance:SchoolName(row.resistanceSchool)
        or row.resistanceMode == "mixed" and "Mixed" or "effect"
    local detail = " · " .. school .. " "
        .. math.floor(row.resistanceDecisionMultiplier * 100 + 0.5) .. "% scored"
        .. " [" .. tostring(row.resistanceConfidence or "unknown")
        .. ((row.resistanceSamples or 0) > 0
            and ", " .. tostring(row.resistanceSamples) .. " samples" or "") .. "]"
        .. componentDetail(row)
    if row.resistanceMultiplier then
        detail = detail .. " · expected " .. math.floor(row.resistanceMultiplier * 100 + 0.5) .. "%"
    end
    if row.resistanceDamageTakenMultiplier
        and math.abs(row.resistanceDamageTakenMultiplier - 1) > 0.001 then
        detail = detail .. " · target modifier "
            .. math.floor(row.resistanceDamageTakenMultiplier * 100 + 0.5) .. "%"
    end
    if row.resistanceUncertaintyMultiplier
        and math.abs(row.resistanceUncertaintyMultiplier - 1) > 0.001 then
        detail = detail .. " · confidence reserve "
            .. math.floor(row.resistanceUncertaintyMultiplier * 100 + 0.5) .. "%"
    end
    if row.resistanceSource then detail = detail .. " · " .. tostring(row.resistanceSource) end
    return detail
end

function L:PrintRecent()
    local first = math.max(1, table.getn(XelAssistLog) - 4)
    local i
    for i = first, table.getn(XelAssistLog) do
        local row = XelAssistLog[i]
        msg("log " .. i .. ": " .. row.action .. " R" .. (row.rank or 0)
            .. " — " .. row.reason .. " (" .. row.confidence .. ", "
            .. (row.status or "unknown") .. ")" .. resistanceDetail(row))
    end
    if table.getn(XelAssistLog) == 0 then msg("decision log is empty.") end
end

function L:Clear()
    XelAssistLog = {}
    msg("decision log cleared.")
end

function XA:RecordDecision(plan, mode) return L:Record(plan, mode) end
function XA:UpdateDecisionStatus(spellId, actor, status)
    return L:UpdateStatus(spellId, actor, status)
end
function XA:RecordError(detail) return L:RecordError(detail) end
