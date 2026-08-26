-- Installed Octo Priest actions whose material secondary consequences live in
-- private server scripts.  Their numeric DBC identities are exact, but generic
-- heal/damage inference would omit self-damage or delayed self-healing.  Claim
-- these actions and fail closed until runtime evidence seals those transfers.
XelAssist.Game.Player.PriestDivergentActions = {}
local P = XelAssist.Game.Player.PriestDivergentActions

P.PRIEST_FAMILY = 6
P.SHADOW_SCHOOL = 5
P.SHADOW_MEND = 45554
P.SHADOW_MEND_FLAG = 268435456
P.PAIN_SPIKE_FLAG = 8388608
P.PAIN_SPIKE = { [45555] = { mana = 80, points = 65, sides = 20 },
    [57701] = { mana = 140, points = 148, sides = 24 },
    [57704] = { mana = 185, points = 208, sides = 32 },
    [57707] = { mana = 265, points = 332, sides = 46 } }
local CACHE = {}

local function number(value)
    value = tonumber(value)
    return value and value == value and value or nil
end

local function scalar(id, field)
    if type(GetSpellRecField) ~= "function" then return nil end
    local ok, value = pcall(GetSpellRecField, id, field)
    return ok and number(value) or nil
end

local function triple(id, field)
    if type(GetSpellRecField) ~= "function" then return nil end
    local ok, values = pcall(GetSpellRecField, id, field, 1)
    if not ok or type(values) ~= "table" or values[4] ~= nil then return nil end
    local out, index = {}, nil
    for index = 1, 3 do
        out[index] = number(values[index])
        if out[index] == nil then return nil end
    end
    return out
end

local function equal(values, first, second, third)
    return values and values[1] == first and values[2] == second
        and values[3] == third
end

local function classToken()
    if type(UnitClass) ~= "function" then return nil end
    local ok, _, token = pcall(UnitClass, "player")
    return ok and token or nil
end

local function shadowMend()
    local id = P.SHADOW_MEND
    return scalar(id, "school") == P.SHADOW_SCHOOL
        and scalar(id, "spellFamilyName") == P.PRIEST_FAMILY
        and scalar(id, "spellFamilyFlags") == P.SHADOW_MEND_FLAG
        and scalar(id, "powerType") == 0 and scalar(id, "manaCost") == 270
        and scalar(id, "rangeIndex") == 5
        and equal(triple(id, "effect"), 10, 0, 0)
        and equal(triple(id, "effectImplicitTargetA"), 21, 0, 0)
        and equal(triple(id, "effectTriggerSpell"), 0, 0, 0)
end

local function painSpike(id, rank)
    return scalar(id, "school") == P.SHADOW_SCHOOL
        and scalar(id, "spellFamilyName") == P.PRIEST_FAMILY
        and scalar(id, "spellFamilyFlags") == P.PAIN_SPIKE_FLAG
        and scalar(id, "powerType") == 0 and scalar(id, "manaCost") == rank.mana
        and scalar(id, "rangeIndex") == 4
        and equal(triple(id, "effect"), 2, 3, 0)
        and equal(triple(id, "effectImplicitTargetA"), 6, 6, 0)
        and equal(triple(id, "effectBasePoints"), rank.points, 0, 0)
        and equal(triple(id, "effectDieSides"), rank.sides, 1, 0)
        and equal(triple(id, "effectTriggerSpell"), 0, 0, 0)
end

local function profile(id)
    if CACHE[id] then return CACHE[id] end
    local found
    if id == P.SHADOW_MEND then
        found = { recognized = true, valid = shadowMend(), kind = "shadowMend",
            reason = "Shadow Mend self-damage transfer is unavailable" }
    elseif P.PAIN_SPIKE[id] then
        found = { recognized = true, valid = painSpike(id, P.PAIN_SPIKE[id]),
            kind = "painSpike",
            reason = "Pain Spike delayed self-healing is unavailable" }
    end
    if found then
        found.spellId, found.exact = id, found.valid == true
        found.source = "installed Octo patch-5 private-consequence boundary"
        CACHE[id] = found
    end
    return found
end

function P:InferKnowledge(spellId)
    if classToken() ~= "PRIEST" then return nil, nil, false end
    local id = tonumber(spellId)
    if id ~= self.SHADOW_MEND and not self.PAIN_SPIKE[id] then
        return nil, nil, false
    end
    local found = profile(id)
    if not (found and found.valid) then
        return nil, "Octo Priest divergent action topology is incomplete", true
    end
    return nil, found.reason, true
end

function P:Evidence(spellId)
    local found = profile(tonumber(spellId))
    if not (found and found.valid) then return nil end
    return { recognized = true, valid = true, exact = true,
        spellId = found.spellId, kind = found.kind, reason = found.reason,
        source = found.source }
end

function P:Invalidate() CACHE = {} end
