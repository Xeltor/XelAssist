-- Exact installed Improved Shadowform recognition. Effective Shadow costs are
-- captured from the engine while the passive aura is observed. Its 15 percent
-- in-casting regeneration is retained as non-projectable evidence because the
-- client cannot separate the suppressed base rate or recover server tick phase.
XelAssist.Game.Player.PriestImprovedShadowform = {}
local I = XelAssist.Game.Player.PriestImprovedShadowform

I.SPELL_ID, I.SHADOWFORM_ID = 45553, 28
I.PRIEST_FAMILY, I.SHADOW_SCHOOL, I.SHADOW_MASK = 6, 5, 32
I.MAX_AURAS = 48
local PROFILE

local function finite(value)
    return type(value) == "number" and value == value
        and value ~= math.huge and value ~= -math.huge and value or nil
end
local function scalar(field)
    if type(GetSpellRecField) ~= "function" then return nil end
    local ok, value = pcall(GetSpellRecField, I.SPELL_ID, field)
    return ok and finite(value) or nil
end
local function triple(field)
    if type(GetSpellRecField) ~= "function" then return nil end
    local ok, value = pcall(GetSpellRecField, I.SPELL_ID, field, 1)
    if not ok or type(value) ~= "table" or table.getn(value) ~= 3 then return nil end
    local index, key, count = nil, nil, 0
    for key in pairs(value) do
        if type(key) ~= "number" or key < 1 or key > 3
            or math.floor(key) ~= key then return nil end
        count = count + 1
    end
    if count ~= 3 then return nil end
    for index = 1, 3 do if finite(value[index]) == nil then return nil end end
    return value
end
local function equal(value, a, b, c)
    return value and value[1] == a and value[2] == b and value[3] == c
end
local function profile()
    if PROFILE ~= nil then return PROFILE.valid and PROFILE or nil end
    local valid = scalar("school") == 0 and scalar("attributes") == 80
        and scalar("attributesEx") == 0 and scalar("attributesEx2") == 0
        and scalar("attributesEx3") == 0 and scalar("attributesEx4") == 0
        and scalar("stances") == 134217728 and scalar("durationIndex") == 21
        and scalar("powerType") == 0 and scalar("manaCost") == 0
        and scalar("manaCostPercentage") == 0 and scalar("rangeIndex") == 1
        and scalar("spellFamilyName") == I.PRIEST_FAMILY
        and scalar("spellFamilyFlags") == 0
        and equal(triple("effect"), 6, 6, 0)
        and equal(triple("effectApplyAuraName"), 72, 134, 0)
        and equal(triple("effectBasePoints"), -16, 14, 0)
        and equal(triple("effectBaseDice"), 1, 1, 0)
        and equal(triple("effectDieSides"), 1, 1, 0)
        and equal(triple("effectImplicitTargetA"), 1, 1, 0)
        and equal(triple("effectMiscValue"), I.SHADOW_MASK, 0, 0)
        and equal(triple("effectTriggerSpell"), 0, 0, 0)
    PROFILE = valid and { valid = true, exact = true,
        spellId = I.SPELL_ID, shadowCostPercent = -15,
        castingManaRegenPercent = 15,
        source = "installed patch-5 Improved Shadowform DBC topology" }
        or { valid = false }
    return valid and PROFILE or nil
end
local function playerGuid()
    if type(UnitGUID) ~= "function" then return nil end
    local ok, guid = pcall(UnitGUID, "player")
    return ok and guid or nil
end
local function activeAura()
    if type(IsPlayerSpell) ~= "function"
        or not (C_UnitAuras and type(C_UnitAuras.GetUnitAuras) == "function") then
        return nil
    end
    local ownershipOK, learned = pcall(IsPlayerSpell, I.SPELL_ID)
    local before = playerGuid()
    if not ownershipOK or type(learned) ~= "boolean" or not before then return nil end
    if not learned then return false end
    local ok, list = pcall(C_UnitAuras.GetUnitAuras, "player", "HELPFUL")
    if not ok or type(list) ~= "table" or table.getn(list) > I.MAX_AURAS
        or playerGuid() ~= before then return nil end
    local found, index = false, nil
    for index = 1, table.getn(list) do
        local aura = list[index]
        local spellId = type(aura) == "table" and tonumber(aura.spellId)
        if not spellId or spellId < 1 or math.floor(spellId) ~= spellId then
            return nil
        end
        if spellId == I.SPELL_ID then
            if found or aura.isHelpful ~= true then return nil end
            found = true
        end
    end
    return found
end
local function effectiveCost(spellId)
    if not (C_Spell and type(C_Spell.GetSpellPowerCost) == "function") then return nil end
    local ok, costs = pcall(C_Spell.GetSpellPowerCost, spellId)
    if not ok or type(costs) ~= "table" or table.getn(costs) ~= 1
        or type(costs[1]) ~= "table" then return nil end
    local entry, cost = costs[1], finite(costs[1].cost)
    if tonumber(entry.type) ~= 0 or not cost or cost < 0 then return nil end
    return cost
end
local function actionScalar(spellId, field)
    if type(GetSpellRecField) ~= "function" then return nil end
    local ok, value = pcall(GetSpellRecField, spellId, field)
    return ok and finite(value) or nil
end

function I:Attach(state)
    if not state then return false end
    state.priestImprovedShadowform = nil
    local found, aura = profile(), activeAura()
    if not found or aura ~= true or not state.playerForm
        or state.playerForm.formID ~= self.SHADOWFORM_ID then return false end
    state.priestImprovedShadowform = { exact = true, active = true,
        shadowCostPercent = found.shadowCostPercent,
        castingManaRegenPercent = found.castingManaRegenPercent,
        castingRegenProjectable = false,
        castingRegenReason = "base casting-regeneration rate and server phase unavailable",
        source = found.source }
    return true
end
function I:Copy(source, target)
    local found = source and source.priestImprovedShadowform
    if not found then target.priestImprovedShadowform = nil; return false end
    local out, key, value = {}, nil, nil
    for key, value in pairs(found) do out[key] = value end
    target.priestImprovedShadowform = out
    return true
end
function I:CaptureFacts(action, facts, state)
    local found = state and state.priestImprovedShadowform
    if not (found and found.exact == true and found.active == true
        and action and action.actor ~= "pet" and action.spellId
        and type(GetSpellRecField) == "function") then return facts end
    local school = actionScalar(action.spellId, "school")
    local power = actionScalar(action.spellId, "powerType")
    if tonumber(school) ~= self.SHADOW_SCHOOL or tonumber(power) ~= 0 then return facts end
    local cost = effectiveCost(action.spellId)
    if cost == nil then return facts end
    local out, key, value = {}, nil, nil
    for key, value in pairs(facts or {}) do out[key] = value end
    out.cost, out.priestImprovedShadowformCostExact = cost, true
    out.priestImprovedShadowformCostSource = found.source
    return out
end
function I:Invalidate() PROFILE = nil end
