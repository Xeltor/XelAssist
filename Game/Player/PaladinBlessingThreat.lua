-- Exact all-threat Paladin blessing evidence from installed build-5875 DBC.
-- The single-recipient shape may promote the existing blessing lifecycle;
-- the class-group shape is root-observable but remains action-unrepresented.
XelAssist.Game.Player.PaladinBlessingThreat = {}
local B = XelAssist.Game.Player.PaladinBlessingThreat

B.PALADIN_FAMILY = 10
B.APPLY_AURA = 6
B.THREAT_AURA = 10
B.ALL_SCHOOLS = 127
B.SINGLE_FRIENDLY = 57
B.CLASS_GROUP = 61
B.CLASS_GROUP_RADIUS = 12
B.MAX_CACHE = 256

local CACHE, CACHE_COUNT = {}, 0

local function finite(value)
    return type(value) == "number" and value == value
        and value ~= math.huge and value ~= -math.huge and value or nil
end

local function integer(value, low, high)
    value = finite(value)
    if value == nil or value < low or value > high
        or math.floor(value) ~= value then return nil end
    return value
end

local function copy(source)
    local out, key, value = {}, nil, nil
    for key, value in pairs(source or {}) do out[key] = value end
    return out
end

local function triple(spellId, field)
    if type(GetSpellRecField) ~= "function" then return nil end
    local ok, values = pcall(GetSpellRecField, spellId, field, 1)
    if not ok or type(values) ~= "table" then return nil end
    local out, count, key, index = {}, 0, nil, nil
    for key in pairs(values) do
        if integer(key, 1, 3) == nil then return nil end
        count = count + 1
    end
    if count ~= 3 then return nil end
    for index = 1, 3 do
        out[index] = finite(values[index])
        if out[index] == nil then return nil end
    end
    return out
end

local function exactClassification(spellId, classification)
    return type(classification) == "table"
        and classification.exact == true
        and integer(classification.spellId, 1, 4294967295) == spellId
        and classification.family == B.PALADIN_FAMILY
        and classification.kind == "blessing"
        and classification.exclusiveFamily == "paladinBlessingByCaster"
end

local FIELDS = { "effect", "effectDieSides", "effectBaseDice",
    "effectDicePerLevel", "effectRealPointsPerLevel", "effectBasePoints",
    "effectMechanic", "effectImplicitTargetA", "effectImplicitTargetB",
    "effectRadiusIndex", "effectApplyAuraName", "effectAmplitude",
    "effectMultipleValue", "effectChainTarget", "effectItemType",
    "effectMiscValue", "effectTriggerSpell",
    "effectPointsPerComboPoint" }

local function record(spellId)
    local out, index, field = {}, nil, nil
    for index = 1, table.getn(FIELDS) do
        field = FIELDS[index]
        out[field] = triple(spellId, field)
        if not out[field] then return nil end
    end
    return out
end

local function zero(recordValue, index)
    return recordValue[index] == 0
end

local function inactive(found, index)
    local field
    for field in pairs(found) do
        if not zero(found[field], index) then return false end
    end
    return true
end

local function hasThreatAura(found)
    local index
    for index = 1, 3 do
        if found.effect[index] ~= 0
            and found.effectApplyAuraName[index] == B.THREAT_AURA then
            return true
        end
    end
    return false
end

local function exactThreatTopology(found)
    local target = found.effectImplicitTargetA[1]
    local radius = found.effectRadiusIndex[1]
    return found.effect[1] == B.APPLY_AURA
        and found.effectApplyAuraName[1] == B.THREAT_AURA
        and found.effectDieSides[1] == 1
        and found.effectBaseDice[1] == 1
        and found.effectDicePerLevel[1] == 0
        and found.effectRealPointsPerLevel[1] == 0
        and found.effectMechanic[1] == 0
        and (target == B.SINGLE_FRIENDLY or target == B.CLASS_GROUP)
        and (target == B.SINGLE_FRIENDLY and radius == 0
            or target == B.CLASS_GROUP and radius == B.CLASS_GROUP_RADIUS)
        and found.effectImplicitTargetB[1] == 0
        and found.effectAmplitude[1] == 0
        and found.effectMultipleValue[1] == 0
        and found.effectChainTarget[1] == 0
        and found.effectItemType[1] == 0
        and found.effectMiscValue[1] == B.ALL_SCHOOLS
        and found.effectTriggerSpell[1] == 0
        and found.effectPointsPerComboPoint[1] == 0
        and inactive(found, 2) and inactive(found, 3)
end

local function inspect(spellId, classification)
    spellId = integer(spellId, 1, 4294967295)
    if not spellId or not exactClassification(spellId, classification) then
        return { available = false, exact = false,
            reason = "captured Paladin blessing classification unavailable" }
    end
    if CACHE[spellId] then return copy(CACHE[spellId]) end
    local out = { available = false, exact = false, spellId = spellId,
        source = "installed build-5875 all-threat blessing DBC topology" }
    local found = record(spellId)
    if not found then
        out.reason = "Paladin blessing DBC effect evidence unavailable"
    elseif not hasThreatAura(found) then
        local index
        for index = 1, 3 do
            if found.effectTriggerSpell[index] ~= 0 then
                out.reason = "Paladin blessing triggered consequence unresolved"
                break
            end
        end
        if not out.reason then
            out.available, out.exact, out.recognized = true, true, false
        end
    elseif not exactThreatTopology(found) then
        out.recognized = true
        out.reason = "all-threat blessing DBC topology is incomplete"
    else
        local percent = found.effectBasePoints[1] + found.effectBaseDice[1]
        if percent >= 0 or percent <= -100 then
            out.recognized = true
            out.reason = "all-threat blessing modifier is outside its safe domain"
        else
            local target = found.effectImplicitTargetA[1]
            out.available, out.exact, out.recognized = true, true, true
            out.valid, out.percent = true, percent
            out.multiplier = (100 + percent) / 100
            out.schoolMask = B.ALL_SCHOOLS
            out.recipientShape = target == B.SINGLE_FRIENDLY
                and "single" or "classGroup"
            out.actionRepresented = target == B.SINGLE_FRIENDLY
        end
    end
    if CACHE_COUNT < B.MAX_CACHE then
        CACHE[spellId], CACHE_COUNT = copy(out), CACHE_COUNT + 1
    end
    return out
end

local function effect(found)
    if not (found and found.valid == true and found.exact == true) then return nil end
    return { exact = true, kind = "playerThreatMultiplier",
        actor = "recipient", sourceSpellId = found.spellId,
        schoolMask = found.schoolMask, percent = found.percent,
        multiplier = found.multiplier,
        recipientShape = found.recipientShape, source = found.source }
end

-- ActionInference calls this immediately after the exact Paladin family
-- adapter. Promotion therefore becomes immutable catalogue knowledge before
-- RootObservation copies actions for graph search.
function B:Promote(spellId, facts)
    if not (facts and facts.paladinBlessing == true) then return facts end
    local found = inspect(spellId, facts.paladinClassification)
    if not (found.valid == true and found.actionRepresented == true) then
        return facts
    end
    local out = copy(facts)
    out.paladinEffectRepresented = true
    out.paladinBlessingThreatEvidence = copy(found)
    out.paladinDownstreamEffect = effect(found)
    return out
end

function B:Inspect(spellId, classification)
    return copy(inspect(spellId, classification))
end

function B:Effect(subject)
    local facts = type(subject) == "table" and subject.facts or subject
    local found = facts and facts.paladinBlessingThreatEvidence
    if not (found and found.actionRepresented == true) then return nil end
    return effect(found)
end

function B:ActiveEffect(aura)
    local found = inspect(aura and aura.spellId,
        aura and aura.classification)
    return effect(found), found
end

function B:Invalidate()
    CACHE, CACHE_COUNT = {}, 0
end
