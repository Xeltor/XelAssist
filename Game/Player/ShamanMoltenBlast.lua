-- Numeric identities for the Shaman Flame Shock family and every Molten Blast
-- rank registered by ClassicAPI's Turtle duration-modifier mirror.
XelAssist.Game.Player.ShamanMoltenBlast = {}
local M = XelAssist.Game.Player.ShamanMoltenBlast
M.MOLTEN = { [36916] = 65, [36917] = 95, [36918] = 120,
    [36919] = 145, [36920] = 175, [36921] = 210 }
M.FLAME = { [8050] = true, [8052] = true, [8053] = true,
    [10447] = true, [10448] = true, [29228] = true }
local CACHE = {}

local function scalar(id, field)
    if type(GetSpellRecField) ~= "function" then return nil end
    local ok, value = pcall(GetSpellRecField, id, field)
    return ok and type(value) == "number" and value or nil
end
local function triple(id, field, a, b, c)
    if type(GetSpellRecField) ~= "function" then return false end
    local ok, values = pcall(GetSpellRecField, id, field, 1)
    return ok and type(values) == "table" and values[1] == a
        and values[2] == b and values[3] == c and values[4] == nil
end
local function classToken()
    if type(UnitClass) ~= "function" then return nil end
    local ok, _, token = pcall(UnitClass, "player")
    return ok and token or nil
end
local function validMolten(id)
    return scalar(id, "spellFamilyName") == 11
        and scalar(id, "spellFamilyFlags") == 562949953421312
        and scalar(id, "school") == 2 and scalar(id, "manaCost") == M.MOLTEN[id]
        and scalar(id, "rangeIndex") == 15
        and scalar(id, "startRecoveryCategory") == 133
        and scalar(id, "startRecoveryTime") == 1500
        and triple(id, "effect", 2, 0, 0)
        and triple(id, "effectImplicitTargetA", 6, 0, 0)
        and triple(id, "effectTriggerSpell", 0, 0, 0)
end
local function validFlame(id)
    return scalar(id, "spellFamilyName") == 11
        and scalar(id, "spellFamilyFlags") == 268435456
        and scalar(id, "school") == 2
        and triple(id, "effect", 2, 6, 0)
        and triple(id, "effectApplyAuraName", 0, 3, 0)
end
function M:InferKnowledge(spellId)
    if classToken() ~= "SHAMAN" then return nil, nil, false end
    local id = tonumber(spellId)
    if not (M.MOLTEN[id] or M.FLAME[id]) then return nil, nil, false end
    if CACHE[id] == nil then
        CACHE[id] = M.MOLTEN[id] and validMolten(id) or validFlame(id)
    end
    if CACHE[id] ~= true then
        return nil, "Octo Shaman Flame Shock refresh topology is incomplete", true
    end
    if M.MOLTEN[id] then
        return { inferred = true, kind = "damage", kindExact = true,
            ranged = true, shamanMoltenBlast = true,
            refreshesShamanFlameShock = true,
            source = "patch-5 DBC plus ClassicAPI Turtle duration mirror" }, nil, true
    end
    return { inferred = true, kind = "dot", kindExact = true, ranged = true,
        shamanFlameShock = true,
        source = "installed Octo Flame Shock family topology" }, nil, true
end
function M:Invalidate() CACHE = {} end
