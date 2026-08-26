-- Some player buttons cause a different spell, sometimes from a controlled
-- actor, to affect the hostile target. Preserve the cast button for execution
-- while scoring and learning against the exact result spell.
XelAssist.Combat.TriggeredActions = {}
local T = XelAssist.Combat.TriggeredActions

local function copy(source)
    local out, key, value = {}, nil, nil
    for key, value in pairs(source or {}) do out[key] = value end
    return out
end

function T:ResultAction(action)
    local resultId = action and action.facts and action.facts.resultSpellId
    if not resultId then return action end
    local out = copy(action)
    out.facts = copy(action.facts)
    out.spellId = resultId
    local evidence = action.triggeredResistanceEvidence
    local sealed = evidence and tonumber(evidence.spellId) == tonumber(resultId)
        and evidence or nil
    out.resistanceMetadata = sealed and sealed.metadata or nil
    out.resistanceMetadataCaptured = sealed
        and sealed.metadataCaptured == true or nil
    out.resistanceDynamicContext = sealed and sealed.dynamicContext or nil
    out.resistanceDynamicContextCaptured = sealed
        and sealed.dynamicContextCaptured == true or nil
    out.actor = out.facts.damageActor or out.facts.effectActor or action.actor
    if out.facts.resultMelee ~= nil then
        out.facts.melee = out.facts.resultMelee and true or false
    end
    out.facts.dynamicSchool = nil
    out.facts.resultOfSpellId = action.spellId
    out.facts.resultSpell = true
    return out
end

local function scalar(spellId, field)
    if not (spellId and GetSpellRecField) then return nil end
    local ok, value = pcall(GetSpellRecField, spellId, field)
    return ok and type(value) == "number" and value or nil
end

local function array(spellId, field)
    if not (spellId and GetSpellRecField) then return nil end
    local ok, value = pcall(GetSpellRecField, spellId, field, 1)
    return ok and type(value) == "table" and value or nil
end

function T:DBCResultFacts(spellId)
    if not spellId then return {} end
    self.cache = self.cache or {}
    local level = UnitLevel and UnitLevel("player") or 60
    local key = tostring(spellId) .. ":" .. tostring(level)
    if self.cache[key] then return self.cache[key] end
    local out = { school = scalar(spellId, "school"),
        source = "result spell DBC" }
    local base = array(spellId, "effectBasePoints")
    local sides = array(spellId, "effectDieSides")
    local perLevel = array(spellId, "effectRealPointsPerLevel")
    local spellLevel = scalar(spellId, "spellLevel") or level
    local scaledLevel = math.max(0, level - spellLevel)
    local best, i = 0, nil
    for i = 1, table.getn(base or {}) do
        local amount = math.abs((base[i] or 0) + 1)
            + math.abs((sides and sides[i] or 0)) / 2
            + math.abs((perLevel and perLevel[i] or 0)) * scaledLevel
        if amount > best then best = amount end
    end
    if best > 0 then out.dbcAverage = best end
    local attributes = scalar(spellId, "attributesEx4")
    if attributes ~= nil then
        out.ignoresResistances = attributes - math.floor(attributes / 2) * 2 == 1
    end
    self.cache[key] = out
    return out
end

function T:SealResultFacts(action, result)
    local resultId = result and result.spellId
    if not (action and tonumber(resultId)) then return false end
    action.triggeredResultFacts = {
        spellId = resultId, facts = copy(self:DBCResultFacts(resultId)) }
    action.triggeredResultFactsCaptured = true
    return true
end

function T:EffectFacts(action, baseFacts)
    local result = self:ResultAction(action)
    if result == action then return baseFacts end
    local out = copy(baseFacts)
    local sealed = action.triggeredResultFacts
    local resultFacts
    if sealed and tonumber(sealed.spellId) == tonumber(result.spellId) then
        resultFacts = sealed.facts or {}
    elseif action.triggeredResultFactsCaptured then resultFacts = {}
    else resultFacts = self:DBCResultFacts(result.spellId) end
    local key, value
    for key, value in pairs(resultFacts) do
        out[key] = value
    end
    return out
end

function T:ScriptedPower(action, state)
    local facts = action and action.facts or {}
    local threatBase = tonumber(facts.deferredThreatBase)
    if threatBase then
        local pet = state and state.actors and state.actors.pet
        local level = tonumber(pet and pet.level)
            or tonumber(facts.deferredThreatLevel) or 0
        local start = tonumber(facts.deferredThreatLevel) or level
        local perLevel = tonumber(facts.deferredThreatPerLevel) or 0
        return math.max(0, threatBase
            + math.max(0, level - start) * perLevel), false,
            "pet-level result spell DBC"
    end
    local coefficient = tonumber(facts.petAttackPowerCoefficient)
    if not coefficient then return nil end
    local pet = state and state.actors and state.actors.pet
    if not (pet and pet.attackPowerKnown
        and type(pet.attackPower) == "number") then
        return nil, true, "pet attack power unavailable"
    end
    return math.max(0, pet.attackPower * coefficient), true,
        facts.serverScriptPower and "advertised private-server script formula"
            or "pet attack power"
end
