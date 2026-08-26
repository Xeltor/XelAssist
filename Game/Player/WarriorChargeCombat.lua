-- Octo's Charge in Combat passive changes an ordinary action legality rule.
-- It is sealed into Charge facts at root capture; graph descendants never
-- query the spellbook or mutable DBC.
XelAssist.Game.Player.WarriorChargeCombat = {}
local C = XelAssist.Game.Player.WarriorChargeCombat

C.PASSIVE_ID = 53201
C.CHARGE_IDS = { [100] = true, [6178] = true, [11578] = true }
local PROFILE

local function scalar(id, field)
    if type(GetSpellRecField) ~= "function" then return nil end
    local ok, value = pcall(GetSpellRecField, id, field)
    return ok and tonumber(value) or nil
end

local function triple(id, field, first, second, third)
    if type(GetSpellRecField) ~= "function" then return false end
    local ok, values = pcall(GetSpellRecField, id, field, 1)
    if not ok or type(values) ~= "table" or values[4] ~= nil then return false end
    return tonumber(values[1]) == first and tonumber(values[2]) == second
        and tonumber(values[3]) == third
end

local function learned()
    if type(IsPlayerSpell) ~= "function" then return nil end
    local ok, value = pcall(IsPlayerSpell, C.PASSIVE_ID)
    if not ok then return nil end
    return value == true or value == 1
end

local function warrior()
    if type(UnitClass) ~= "function" then return false end
    local ok, _, token = pcall(UnitClass, "player")
    return ok and token == "WARRIOR"
end

local function profile()
    if PROFILE then return PROFILE end
    local active = warrior() and learned() or false
    PROFILE = { recognized = true, valid = false, active = active,
        spellId = C.PASSIVE_ID,
        source = "installed Octo Charge in Combat passive DBC" }
    if active ~= true then
        PROFILE.valid, PROFILE.exact = true, true
        return PROFILE
    end
    if not (scalar(C.PASSIVE_ID, "attributes") == 192
        and scalar(C.PASSIVE_ID, "durationIndex") == 21
        and scalar(C.PASSIVE_ID, "spellFamilyName") == 4
        and scalar(C.PASSIVE_ID, "spellFamilyFlags") == 0
        and triple(C.PASSIVE_ID, "effect", 6, 0, 0)
        and triple(C.PASSIVE_ID, "effectApplyAuraName", 4, 0, 0)
        and triple(C.PASSIVE_ID, "effectImplicitTargetA", 1, 0, 0)
        and triple(C.PASSIVE_ID, "effectBasePoints", 0, 0, 0)
        and triple(C.PASSIVE_ID, "effectBaseDice", 1, 0, 0)) then
        PROFILE.reason = "Charge in Combat passive topology is incomplete"
        return PROFILE
    end
    PROFILE.valid, PROFILE.exact = true, true
    return PROFILE
end

local function copy(source)
    local out, key, value = {}, nil, nil
    for key, value in pairs(source or {}) do out[key] = value end
    return out
end

function C:CaptureFacts(action, facts)
    local out = copy(facts)
    if not (action and self.CHARGE_IDS[tonumber(action.spellId)]) then return out end
    local found = profile()
    if found.active ~= true then return out end
    if found.valid ~= true or found.exact ~= true then
        out.chargeInCombatEvidenceIncomplete = true
        return out
    end
    out.outOfCombat = false
    out.chargeInCombat = true
    out.chargeInCombatEvidence = copy(found)
    return out
end

function C:Invalidate() PROFILE = nil end
