-- Exact learned Reprisal damage modifier for Revenge. The server-side rage
-- refund is intentionally separate: patch-5 exposes its chance but not a
-- trigger/refund contract that can safely mutate a graph resource branch.
XelAssist.Game.Player = XelAssist.Game.Player or {}
XelAssist.Game.Player.WarriorReprisal = {}
local R = XelAssist.Game.Player.WarriorReprisal

R.DAMAGE_MOD = 0
R.RANKS = {
    [51593] = { rank = 1, damagePercent = 25, refundChance = 0.5 },
    [51594] = { rank = 2, damagePercent = 50, refundChance = 1 },
}
local REVENGE_IDS = { [6572] = true, [6574] = true, [7379] = true,
    [11600] = true, [11601] = true, [25288] = true }

local function finite(value, low, high)
    value = tonumber(value)
    if value == nil or value ~= value or value < low or value > high then
        return nil
    end
    return value
end
local function integer(value, low, high)
    value = finite(value, low, high)
    return value and math.floor(value) == value and value or nil
end
local function scalar(id, field)
    if type(GetSpellRecField) ~= "function" then return nil end
    local ok, value = pcall(GetSpellRecField, id, field)
    return ok and finite(value, -2147483648, 4294967295) or nil
end
local function triple(id, field)
    if type(GetSpellRecField) ~= "function" then return nil end
    local ok, values = pcall(GetSpellRecField, id, field, 1)
    if not ok or type(values) ~= "table" then return nil end
    local out, count, key, index = {}, 0, nil, nil
    for key in pairs(values) do
        if integer(key, 1, 3) == nil then return nil end
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
    return values and values[1] == a and values[2] == b
        and values[3] == c
end
local function warrior()
    if type(UnitClass) ~= "function" then return false end
    local ok, _, token = pcall(UnitClass, "player")
    return ok and token == "WARRIOR"
end

local function topology(id, spec)
    return scalar(id, "attributes") == 464
        and scalar(id, "procFlags") == 16
        and scalar(id, "procChance") == spec.refundChance * 100
        and scalar(id, "procCharges") == 0
        and scalar(id, "durationIndex") == 21
        and scalar(id, "spellFamilyName") == 4
        and equal(triple(id, "effect"), 6, 6, 0)
        and equal(triple(id, "effectDieSides"), 1, 1, 0)
        and equal(triple(id, "effectBaseDice"), 1, 1, 0)
        and equal(triple(id, "effectBasePoints"),
            spec.damagePercent - 1, 0, 0)
        and equal(triple(id, "effectImplicitTargetA"), 1, 1, 0)
        and equal(triple(id, "effectApplyAuraName"), 108, 4, 0)
        and equal(triple(id, "effectMiscValue"), 0, 0, 0)
        and equal(triple(id, "effectTriggerSpell"), 0, 0, 0)
end

local function knownRank()
    if not warrior() then return nil, "player is not an exactly identified Warrior" end
    if type(IsPlayerSpell) ~= "function" then
        return nil, "Reprisal ownership unavailable"
    end
    local rank, id
    for _, id in ipairs({ 51594, 51593 }) do
        local ok, known = pcall(IsPlayerSpell, id)
        if not ok or type(known) ~= "boolean" then
            return nil, "Reprisal ownership unavailable"
        end
        if known and not rank then
            local spec = R.RANKS[id]
            rank = { rank = spec.rank, damagePercent = spec.damagePercent,
                refundChance = spec.refundChance, spellId = id }
        end
    end
    if rank and not topology(rank.spellId, rank) then
        return nil, "Reprisal installed topology unavailable"
    end
    return rank or false
end

local function modifier(spellId)
    if type(GetSpellModifiers) ~= "function" then return nil end
    local ok, flat, percent, changed = pcall(
        GetSpellModifiers, spellId, R.DAMAGE_MOD)
    flat, percent, changed = tonumber(flat), tonumber(percent), tonumber(changed)
    if not ok or not finite(flat, -1000000, 1000000)
        or not finite(percent, -1000, 1000)
        or integer(changed, 0, 4294967295) == nil then return nil end
    return { exact = true, operation = R.DAMAGE_MOD,
        flat = flat, percent = percent, changed = changed }
end

function R:CaptureFacts(action, facts)
    if not (action and REVENGE_IDS[tonumber(action.spellId)]
        and facts and facts.warriorRevengeThreat == true) then return facts end
    local out, key, value = {}, nil, nil
    for key, value in pairs(facts) do out[key] = value end
    local rank, reason = knownRank()
    local evidence = { available = rank ~= nil, exact = rank ~= nil,
        learned = rank ~= false, portfolio = "warriorReprisal",
        source = "installed patch-5 Reprisal topology and engine modifier" }
    if rank == nil then evidence.available, evidence.exact, evidence.reason =
        false, false, reason
    elseif rank then
        local effective = modifier(action.spellId)
        if not (effective and effective.flat == 0
            and effective.percent == rank.damagePercent
            and effective.changed ~= 0) then
            evidence.available, evidence.exact = false, false
            evidence.reason = "Reprisal engine damage modifier unavailable"
        else
            evidence.rank, evidence.passiveSpellId = rank.rank, rank.spellId
            evidence.damagePercent, evidence.refundChance =
                rank.damagePercent, rank.refundChance
            evidence.damageModifier = effective
            evidence.refundMode = "withheld-private-success-trigger"
        end
    else
        evidence.damagePercent, evidence.refundChance = 0, 0
    end
    out.warriorReprisalEvidence = evidence
    return out
end
