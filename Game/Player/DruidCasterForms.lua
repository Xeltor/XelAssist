-- Exact observed Moonkin and Tree of Life profiles from Octo patch-5.
-- The engine owns effective costs. Action legality is claimed only when the
-- action's own DBC stance masks provide an exact answer; tooltip prose never
-- becomes an invented spell-family restriction or party-aura consequence.
XelAssist.Game.Player.DruidCasterForms = {}
local C = XelAssist.Game.Player.DruidCasterForms

C.MANA, C.DRUID_FAMILY = 0, 7
C.FORMS = {
    [9] = { spellId = 45705, mask = 256, name = "Tree of Life" },
    [31] = { spellId = 51430, mask = 1073741824, name = "Moonkin" },
}
local CACHE = {}

local function finite(value)
    return type(value) == "number" and value == value
        and value ~= math.huge and value ~= -math.huge and value or nil
end
local function scalar(spellId, field)
    if type(GetSpellRecField) ~= "function" then return nil end
    local ok, value = pcall(GetSpellRecField, spellId, field)
    return ok and finite(value) or nil
end
local function triple(spellId, field)
    if type(GetSpellRecField) ~= "function" then return nil end
    local ok, values = pcall(GetSpellRecField, spellId, field, 1)
    if not ok or type(values) ~= "table" then return nil end
    local out, key, count, index = {}, nil, 0, nil
    for key in pairs(values) do
        if type(key) ~= "number" or key < 1 or key > 3
            or math.floor(key) ~= key then return nil end
        count = count + 1
    end
    if count ~= 3 then return nil end
    for index = 1, 3 do
        out[index] = finite(values[index]); if out[index] == nil then return nil end
    end
    return out
end
local function equal(values, a, b, c)
    return values and values[1] == a and values[2] == b and values[3] == c
end
local function baseTopology(spellId, familyFlags, manaPercent)
    return scalar(spellId, "school") == 0
        and scalar(spellId, "category") == 0
        and scalar(spellId, "dispel") == 0
        and scalar(spellId, "mechanic") == 0
        and scalar(spellId, "attributes") == 262160
        and scalar(spellId, "attributesEx") == 32768
        and scalar(spellId, "attributesEx2") == 0
        and scalar(spellId, "attributesEx3") == 0
        and scalar(spellId, "attributesEx4") == 0
        and scalar(spellId, "stances") == 0
        and scalar(spellId, "stancesNot") == 0
        and scalar(spellId, "targets") == 0
        and scalar(spellId, "casterAuraState") == 0
        and scalar(spellId, "targetAuraState") == 0
        and scalar(spellId, "castingTimeIndex") == 1
        and scalar(spellId, "recoveryTime") == 0
        and scalar(spellId, "categoryRecoveryTime") == 0
        and scalar(spellId, "procChance") == 101
        and scalar(spellId, "procCharges") == 0
        and scalar(spellId, "baseLevel") == 40
        and scalar(spellId, "spellLevel") == 40
        and scalar(spellId, "durationIndex") == 21
        and scalar(spellId, "powerType") == C.MANA
        and scalar(spellId, "manaCost") == 0
        and scalar(spellId, "manaCostPerlevel") == 0
        and scalar(spellId, "manaCostPercentage") == manaPercent
        and scalar(spellId, "rangeIndex") == 1
        and scalar(spellId, "startRecoveryCategory") == 133
        and scalar(spellId, "startRecoveryTime") == 1500
        and scalar(spellId, "spellFamilyName") == C.DRUID_FAMILY
        and scalar(spellId, "spellFamilyFlags") == familyFlags
end
local function installed(formID)
    if CACHE[formID] ~= nil then return CACHE[formID].valid and CACHE[formID] end
    local spec, valid = C.FORMS[formID], false
    if formID == 9 then
        valid = baseTopology(45705, 33554432, 28)
            and equal(triple(45705, "effect"), 6, 6, 6)
            and equal(triple(45705, "effectApplyAuraName"), 36, 77, 142)
            and equal(triple(45705, "effectBasePoints"), -1, -1, 179)
            and equal(triple(45705, "effectBaseDice"), 1, 1, 1)
            and equal(triple(45705, "effectDieSides"), 1, 1, 1)
            and equal(triple(45705, "effectImplicitTargetA"), 1, 1, 1)
            and equal(triple(45705, "effectImplicitTargetB"), 0, 0, 0)
            and equal(triple(45705, "effectMiscValue"), 9, 17, 1)
            and equal(triple(45705, "effectTriggerSpell"), 0, 0, 0)
    elseif formID == 31 then
        valid = baseTopology(51430, 536870912, 22)
            and equal(triple(51430, "effect"), 6, 6, 64)
            and equal(triple(51430, "effectApplyAuraName"), 36, 77, 0)
            and equal(triple(51430, "effectBasePoints"), -1, -1, -1)
            and equal(triple(51430, "effectBaseDice"), 1, 1, 1)
            and equal(triple(51430, "effectDieSides"), 1, 1, 1)
            and equal(triple(51430, "effectImplicitTargetA"), 1, 1, 1)
            and equal(triple(51430, "effectImplicitTargetB"), 0, 0, 0)
            and equal(triple(51430, "effectMiscValue"), 31, 17, 0)
            and equal(triple(51430, "effectTriggerSpell"), 0, 0, 24907)
    end
    CACHE[formID] = valid and { valid = true, exact = true,
        formID = formID, formMask = spec.mask, spellId = spec.spellId,
        name = spec.name, source = "installed Octo patch-5 form DBC topology" }
        or { valid = false }
    return valid and CACHE[formID]
end
local function druid()
    if type(UnitClass) ~= "function" then return false end
    local ok, _, token = pcall(UnitClass, "player")
    return ok and token == "DRUID"
end
local function observed(state)
    local form = state and state.playerForm
    local formID = form and tonumber(form.formID)
    if not druid() or not (form and form.available == true and C.FORMS[formID]) then
        return nil
    end
    return installed(formID)
end
local function effectiveCost(spellId)
    if not (C_Spell and type(C_Spell.GetSpellPowerCost) == "function") then return nil end
    local ok, costs = pcall(C_Spell.GetSpellPowerCost, spellId)
    if not ok or type(costs) ~= "table" or table.getn(costs) ~= 1
        or type(costs[1]) ~= "table" then return nil end
    local entry, cost = costs[1], finite(costs[1].cost)
    if tonumber(entry.type) ~= C.MANA or cost == nil or cost < 0 then return nil end
    return cost
end
local function flag(value, bit)
    value, bit = tonumber(value), tonumber(bit)
    if not value or value < 0 or not bit or bit <= 0 then return false end
    return math.floor(value / bit) - math.floor(value / (bit * 2)) * 2 == 1
end

function C:Profile(state) return observed(state) end
function C:CaptureFacts(action, facts, state)
    local profile = observed(state)
    if not (profile and action and tonumber(action.spellId)) then return facts end
    local spellId = tonumber(action.spellId)
    local power = scalar(spellId, "powerType")
    local stances, excluded = scalar(spellId, "stances"),
        scalar(spellId, "stancesNot")
    if power == nil or stances == nil or excluded == nil then return facts end
    local out, key, value = {}, nil, nil
    for key, value in pairs(facts or {}) do out[key] = value end
    out.stances, out.stancesNot = stances, excluded
    out.druidCasterFormEvidence = { exact = true, formID = profile.formID,
        formMask = profile.formMask, source = profile.source }
    if power == self.MANA then
        local cost = effectiveCost(spellId)
        if cost ~= nil then
            out.cost, out.druidCasterFormCostExact = cost, true
            out.druidCasterFormCostSource = "ClassicAPI effective engine cost while form observed"
        end
    end
    return out
end

-- `handled=false` deliberately means the DBC supplied no form restriction.
-- Tree/Moonkin tooltip prose is not enough to prohibit an otherwise unmasked
-- action; the generic exact-usability lane remains authoritative at the root.
function C:FormBlocker(action, state)
    local profile = observed(state)
    if not (profile and action and tonumber(action.spellId)) then return nil, false end
    local allowed = scalar(tonumber(action.spellId), "stances")
    local excluded = scalar(tonumber(action.spellId), "stancesNot")
    if allowed == nil or excluded == nil then
        return "action form masks unavailable", true
    end
    if allowed == 0 and excluded == 0 then return nil, false end
    if allowed > 0 and not flag(allowed, profile.formMask) then
        return "required player form inactive", true
    end
    if excluded > 0 and flag(excluded, profile.formMask) then
        return "current player form excluded", true
    end
    return nil, true
end
function C:Invalidate() CACHE = {} end
