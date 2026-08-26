-- Root-sealed patch-5 Shield Mastery ownership and linked proc topology.
-- The graph owns timing and probability; this module only authenticates the
-- installed rows and engine-visible ownership/durations.
XelAssist.Game.Player.WarriorShieldMastery = {}
local M = XelAssist.Game.Player.WarriorShieldMastery

M.ROOT_ID, M.BLOCK_ID, M.RIPOSTE_ID = 45958, 45959, 45962
M.BLOCK_VALUE_MULTIPLIER = 1.5
M.REVENGE_DAMAGE_MULTIPLIER = 2.5
M.RIPOSTE_DURATION = 5
local SHIELD_BLOCK_ID = 2565
local REVENGE_IDS = { [6572] = true, [6574] = true, [7379] = true,
    [11600] = true, [11601] = true, [25288] = true }

local function finite(value, low, high)
    value = tonumber(value)
    if not value or value ~= value or value < low or value > high then return nil end
    return value
end
local function scalar(id, field)
    if type(GetSpellRecField) ~= "function" then return nil end
    local ok, value = pcall(GetSpellRecField, id, field)
    return ok and finite(value, -2147483648, 4294967295) or nil
end
local function triple(id, field)
    if type(GetSpellRecField) ~= "function" then return nil end
    local ok, values = pcall(GetSpellRecField, id, field, 1)
    if not ok or type(values) ~= "table" or values[4] ~= nil then return nil end
    local out, index = {}, nil
    for index = 1, 3 do
        out[index] = finite(values[index], -2147483648, 4294967295)
        if out[index] == nil then return nil end
    end
    return out
end
local function equal(values, a, b, c)
    return values and values[1] == a and values[2] == b and values[3] == c
end
local function topology()
    return scalar(45958, "attributes") == 327680
        and scalar(45958, "procFlags") == 680
        and scalar(45958, "procChance") == 101
        and scalar(45958, "procCharges") == 0
        and scalar(45958, "durationIndex") == 21
        and scalar(45958, "spellFamilyName") == 4
        and equal(triple(45958, "effect"), 6, 6, 0)
        and equal(triple(45958, "effectBasePoints"), 100, 64, 0)
        and equal(triple(45958, "effectImplicitTargetB"), 1, 1, 0)
        and equal(triple(45958, "effectApplyAuraName"), 109, 43, 0)
        and equal(triple(45958, "effectTriggerSpell"), 45959, 0, 0)
        and scalar(45959, "attributes") == 327680
        and scalar(45959, "procFlags") == 680
        and scalar(45959, "procChance") == 100
        and scalar(45959, "procCharges") == 1
        and scalar(45959, "durationIndex") == 328
        and scalar(45959, "spellFamilyName") == 10
        and equal(triple(45959, "effect"), 6, 6, 0)
        and equal(triple(45959, "effectBasePoints"), 49, 0, 0)
        and equal(triple(45959, "effectImplicitTargetB"), 1, 1, 0)
        and equal(triple(45959, "effectApplyAuraName"), 150, 42, 0)
        and equal(triple(45959, "effectTriggerSpell"), 0, 45962, 0)
        and scalar(45962, "attributes") == 327680
        and scalar(45962, "procFlags") == 87380
        and scalar(45962, "procChance") == 100
        and scalar(45962, "procCharges") == 1
        and scalar(45962, "durationIndex") == 7
        and scalar(45962, "spellFamilyName") == 4
        and equal(triple(45962, "effect"), 6, 0, 0)
        and equal(triple(45962, "effectBasePoints"), 149, 0, 0)
        and equal(triple(45962, "effectImplicitTargetB"), 1, 1, 0)
        and equal(triple(45962, "effectApplyAuraName"), 108, 0, 0)
        and equal(triple(45962, "effectMiscValue"), 8, 0, 0)
end
local function warrior()
    if type(UnitClass) ~= "function" then return false end
    local ok, _, token = pcall(UnitClass, "player")
    return ok and token == "WARRIOR"
end
local function learned()
    if type(IsPlayerSpell) ~= "function" then return nil end
    local ok, value = pcall(IsPlayerSpell, M.ROOT_ID)
    return ok and type(value) == "boolean" and value or ok and false or nil
end
local function duration(id)
    if type(GetSpellDuration) ~= "function" then return nil end
    local ok, value = pcall(GetSpellDuration, id)
    value = ok and finite(value, 1, 60000) or nil
    return value and value / 1000 or nil
end

function M:CaptureFacts(action, facts)
    local id = tonumber(action and action.spellId)
    if not (warrior() and facts and (id == SHIELD_BLOCK_ID
        or REVENGE_IDS[id])) then return facts end
    local out, key, value = {}, nil, nil
    for key, value in pairs(facts) do out[key] = value end
    local owned = learned()
    local evidence = { portfolio = "warriorShieldMastery",
        available = owned ~= nil, exact = owned ~= nil,
        learned = owned == true, rootSpellId = M.ROOT_ID,
        blockSpellId = M.BLOCK_ID, riposteSpellId = M.RIPOSTE_ID,
        blockValueMultiplier = M.BLOCK_VALUE_MULTIPLIER,
        revengeDamageMultiplier = M.REVENGE_DAMAGE_MULTIPLIER,
        source = "installed patch-5 linked rows and engine ownership" }
    if owned == nil then
        evidence.available, evidence.exact = false, false
        evidence.reason = "Shield Mastery ownership unavailable"
    elseif owned then
        local blockDuration, riposteDuration = duration(M.BLOCK_ID),
            duration(M.RIPOSTE_ID)
        if not topology() or blockDuration ~= 0.25
            or riposteDuration ~= M.RIPOSTE_DURATION then
            evidence.available, evidence.exact = false, false
            evidence.reason = "Shield Mastery installed topology unavailable"
        else
            evidence.blockDuration = blockDuration
            evidence.riposteDuration = riposteDuration
        end
    end
    out.warriorShieldMasteryEvidence = evidence
    return out
end
