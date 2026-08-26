-- Exact boundaries for installed Octo Shaman actions whose material behavior
-- cannot be reconstructed from their generic DBC atom alone. Totemic Slam's
-- attack-power packet is private-scripted; Ethereal Form couples mitigation to
-- a spellcasting lock. Claim both before generic inference can misrepresent
-- them, while retaining inspectable topology for their future graph owners.
XelAssist.Game.Player.ShamanDivergentActions = {}
local S = XelAssist.Game.Player.ShamanDivergentActions

S.SHAMAN_FAMILY = 11
S.TOTEMIC_SLAM = 45500
S.TOTEMIC_SLAM_DEBUFF = 51364
S.ETHEREAL_FORM = 45502
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

local function token()
    if type(UnitClass) ~= "function" then return nil end
    local ok, _, class = pcall(UnitClass, "player")
    return ok and class or nil
end

local function slam()
    return scalar(S.TOTEMIC_SLAM, "school") == 0
        and scalar(S.TOTEMIC_SLAM, "spellFamilyName") == S.SHAMAN_FAMILY
        and scalar(S.TOTEMIC_SLAM, "rangeIndex") == 2
        and scalar(S.TOTEMIC_SLAM, "recoveryTime") == 90000
        and scalar(S.TOTEMIC_SLAM, "equippedItemClass") == 4
        and scalar(S.TOTEMIC_SLAM, "equippedItemSubClassMask") == 64
        and equal(triple(S.TOTEMIC_SLAM, "effect"), 2, 64, 0)
        and equal(triple(S.TOTEMIC_SLAM, "effectImplicitTargetA"), 6, 6, 0)
        and equal(triple(S.TOTEMIC_SLAM, "effectBasePoints"), 0, 0, 0)
        and equal(triple(S.TOTEMIC_SLAM, "effectTriggerSpell"),
            0, S.TOTEMIC_SLAM_DEBUFF, 0)
end

local function ethereal()
    return scalar(S.ETHEREAL_FORM, "school") == 3
        and scalar(S.ETHEREAL_FORM, "spellFamilyName") == S.SHAMAN_FAMILY
        and scalar(S.ETHEREAL_FORM, "rangeIndex") == 1
        and scalar(S.ETHEREAL_FORM, "categoryRecoveryTime") == 900000
        and equal(triple(S.ETHEREAL_FORM, "effect"), 6, 6, 6)
        and equal(triple(S.ETHEREAL_FORM, "effectImplicitTargetA"), 1, 1, 0)
        and equal(triple(S.ETHEREAL_FORM, "effectApplyAuraName"), 126, 27, 0)
        and equal(triple(S.ETHEREAL_FORM, "effectBasePoints"), 29,
            4294967295, 0)
        and equal(triple(S.ETHEREAL_FORM, "effectMiscValue"), 1, 0, 0)
end

local function inspect(id)
    if CACHE[id] then return CACHE[id] end
    local found
    if id == S.TOTEMIC_SLAM then
        found = { kind = "totemicSlam", valid = slam(),
            reason = "Totemic Slam private attack-power packet is unavailable" }
    elseif id == S.ETHEREAL_FORM then
        found = { kind = "etherealForm", valid = ethereal(),
            reason = "Ethereal Form spellcasting lock is not represented" }
    end
    if found then
        found.recognized, found.exact, found.spellId = true,
            found.valid == true, id
        found.source = "installed Octo patch-5 private-consequence boundary"
        CACHE[id] = found
    end
    return found
end

function S:InferKnowledge(spellId)
    if token() ~= "SHAMAN" then return nil, nil, false end
    local id = tonumber(spellId)
    if id ~= self.TOTEMIC_SLAM and id ~= self.ETHEREAL_FORM then
        return nil, nil, false
    end
    local found = inspect(id)
    if not (found and found.valid) then
        return nil, "Octo Shaman divergent action topology is incomplete", true
    end
    return nil, found.reason, true
end

function S:Evidence(spellId)
    local found = inspect(tonumber(spellId))
    if not (found and found.valid) then return nil end
    return { recognized = true, valid = true, exact = true,
        spellId = found.spellId, kind = found.kind, reason = found.reason,
        source = found.source }
end

function S:Invalidate() CACHE = {} end
