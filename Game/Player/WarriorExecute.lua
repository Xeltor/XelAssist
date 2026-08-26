-- Installed Octo Execute ranks. The client DBC owns rank identity, base damage,
-- rage conversion and the custom marker trigger; whether the private server
-- executes that declared profile remains explicitly runtime-unverified.
XelAssist.Game.Player.WarriorExecute = {}
local E = XelAssist.Game.Player.WarriorExecute

E.RANKS = { [5308] = { 125, 0.3 }, [20658] = { 200, 0.6 },
    [20660] = { 325, 0.9 }, [20661] = { 450, 1.2 },
    [20662] = { 600, 1.5 } }
E.MARKER_SPELL_ID = 26651
E.WARRIOR_FAMILY, E.FAMILY_FLAG = 4, 536870912
E.RAGE, E.RAGE_SCALE, E.BASE_COST_RAW = 1, 10, 150

local CACHE = {}

local function finite(value, low, high)
    value = tonumber(value)
    if not value or value ~= value or value == math.huge or value == -math.huge
        or value < low or value > high then return nil end
    return value
end

local function scalar(spellId, field)
    if type(GetSpellRecField) ~= "function" then return nil end
    local ok, value = pcall(GetSpellRecField, spellId, field)
    return ok and finite(value, -2147483648, 4294967295) or nil
end

local function triple(spellId, field)
    if type(GetSpellRecField) ~= "function" then return nil end
    local ok, values = pcall(GetSpellRecField, spellId, field, 1)
    if not ok or type(values) ~= "table" then return nil end
    local out, index, count = {}, nil, 0
    for index in pairs(values) do
        if type(index) ~= "number" or index < 1 or index > 3
            or math.floor(index) ~= index then return nil end
        count = count + 1
    end
    if count ~= 3 then return nil end
    for index = 1, 3 do
        out[index] = finite(values[index], -2147483648, 4294967295)
        if out[index] == nil then return nil end
    end
    return out
end

local function equal(values, a, b, c)
    return values and values[1] == a and values[2] == b and values[3] == c
end

local function near(a, b)
    return a and math.abs(a - b) < 0.00001
end

local function copy(source)
    local out, key, value = {}, nil, nil
    for key, value in pairs(source or {}) do out[key] = value end
    return out
end

local function classToken()
    if type(UnitClass) ~= "function" then return nil end
    local ok, _, token = pcall(UnitClass, "player")
    return ok and token or nil
end

local function classify(spellId)
    if CACHE[spellId] then return copy(CACHE[spellId]) end
    local rank = E.RANKS[spellId]
    if not rank then return nil end
    local basePoints, baseDice = triple(spellId, "effectBasePoints"),
        triple(spellId, "effectBaseDice")
    local multipliers = triple(spellId, "dmgMultiplier")
    local found = { recognized = true, valid = false, spellId = spellId,
        markerSpellId = E.MARKER_SPELL_ID,
        source = "installed Octo patch-5 Spell.dbc Execute profile" }
    if not (scalar(spellId, "school") == 0
        and scalar(spellId, "spellFamilyName") == E.WARRIOR_FAMILY
        and scalar(spellId, "spellFamilyFlags") == E.FAMILY_FLAG
        and scalar(spellId, "powerType") == E.RAGE
        and scalar(spellId, "manaCost") == E.BASE_COST_RAW
        and scalar(spellId, "targetAuraState") == 2
        and equal(triple(spellId, "effect"), 3, 64, 0)
        and equal(triple(spellId, "effectTriggerSpell"), 0,
            E.MARKER_SPELL_ID, 0)
        and equal(triple(spellId, "effectDieSides"), 1, 0, 0)
        and basePoints and baseDice and baseDice[1] == 1
        and basePoints[1] + baseDice[1] == rank[1]
        and multipliers and near(multipliers[1], rank[2])) then
        found.reason = "Octo Execute DBC topology is incomplete"
        CACHE[spellId] = copy(found)
        return found
    end
    found.valid, found.exact = true, true
    found.baseDamage, found.rawRageMultiplier = rank[1], rank[2]
    found.damagePerRage = rank[2] * E.RAGE_SCALE
    found.baseCost, found.executePercent = E.BASE_COST_RAW / E.RAGE_SCALE, 20
    found.powerType, found.school = E.RAGE, 0
    found.runtimeVerified = false
    CACHE[spellId] = copy(found)
    return found
end

function E:InferKnowledge(spellId)
    if classToken() ~= "WARRIOR" then return nil, nil, false end
    local found = classify(tonumber(spellId))
    if not found then return nil, nil, false end
    if not found.valid then return nil, found.reason, true end
    return { inferred = true, kind = "damage", kindExact = true,
        melee = true, execute = found.executePercent,
        warriorExecute = true, requiresExactWarriorExecute = true,
        warriorExecuteEvidence = copy(found), source = found.source }, nil, true
end

local function evidence(subject)
    local facts = type(subject) == "table" and subject.facts or subject
    local found = facts and facts.warriorExecuteEvidence
    local rank = found and E.RANKS[found.spellId]
    if not (facts and facts.warriorExecute == true
        and type(found) == "table" and found.valid == true
        and found.exact == true and rank
        and found.markerSpellId == E.MARKER_SPELL_ID
        and found.baseDamage == rank[1]
        and near(found.rawRageMultiplier, rank[2])
        and near(found.damagePerRage, rank[2] * E.RAGE_SCALE)
        and found.baseCost == 15 and found.executePercent == 20
        and found.powerType == E.RAGE and found.school == 0
        and found.runtimeVerified == false) then return nil end
    return found
end

function E:Evidence(subject)
    local found = evidence(subject)
    return found and copy(found) or nil
end

function E:CaptureFacts(action, facts)
    local out, key, value = {}, nil, nil
    for key, value in pairs(facts or {}) do out[key] = value end
    local found = action and evidence(action)
    if not found then return out end
    out.warriorExecute, out.requiresExactWarriorExecute = true, true
    out.warriorExecuteEvidence = copy(found)
    out.kind, out.kindExact, out.execute = "damage", true, found.executePercent
    out.school, out.powerType = found.school, found.powerType
    out.average = found.baseDamage
    return out
end

function E:Invalidate()
    CACHE = {}
end
