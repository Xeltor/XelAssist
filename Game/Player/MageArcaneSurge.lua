-- Exact installed Octo Arcane Surge identity. Its caster-aura-state gate is
-- consumed by the existing root-sealed reactive ledger, while the DBC's
-- attributesEx4 packet proves that positive resistance is ignored.
XelAssist.Game.Player = XelAssist.Game.Player or {}
XelAssist.Game.Player.MageArcaneSurge = {}
local S = XelAssist.Game.Player.MageArcaneSurge

S.MAGE_FAMILY = 3
S.AURA_STATE_MAGE_RESIST = 13
local RANKS = {
    [51933] = { rank=1, max=37, level=32, mana=85, points=201, sides=43 },
    [51934] = { rank=2, max=45, level=40, mana=110, points=289, sides=60 },
    [51935] = { rank=3, max=53, level=48, mana=140, points=397, sides=77 },
    [51936] = { rank=4, max=61, level=56, mana=170, points=516, sides=96 },
}
local CACHE = {}

local function integer(value)
    value = tonumber(value)
    return value and value == value and math.floor(value) == value
        and value >= -2147483648 and value <= 4294967295 and value or nil
end
local function scalar(id, field)
    if type(GetSpellRecField) ~= "function" then return nil end
    local ok, value = pcall(GetSpellRecField, id, field)
    return ok and integer(value) or nil
end
local function triple(id, field, signed)
    if type(GetSpellRecField) ~= "function" then return nil end
    local ok, values = pcall(GetSpellRecField, id, field, 1)
    if not ok or type(values) ~= "table" or values[4] ~= nil then return nil end
    local out, index = {}, nil
    for index = 1, 3 do
        out[index] = integer(values[index]); if out[index] == nil then return nil end
        if signed and out[index] >= 2147483648 then
            out[index] = out[index] - 4294967296
        end
    end
    return out
end
local function equal(values, a, b, c)
    return values and values[1] == a and values[2] == b and values[3] == c
end
local function copy(source)
    local out, key, value = {}, nil, nil
    for key, value in pairs(source or {}) do out[key] = value end
    return out
end
local function rangeExact(id)
    if scalar(id, "rangeIndex") ~= 4 or type(GetSpellRangeData) ~= "function" then
        return false
    end
    local ok, minimum, maximum = pcall(GetSpellRangeData, 4)
    return ok and minimum == 0 and maximum == 30
end
local function topology(id, rank)
    return scalar(id,"school") == 6 and scalar(id,"attributes") == 65536
        and scalar(id,"attributesEx") == 0 and scalar(id,"attributesEx2") == 0
        and scalar(id,"attributesEx3") == 512
        and scalar(id,"attributesEx4") == 513
        and scalar(id,"casterAuraState") == S.AURA_STATE_MAGE_RESIST
        and scalar(id,"castingTimeIndex") == 1
        and scalar(id,"recoveryTime") == 0
        and scalar(id,"categoryRecoveryTime") == 8000
        and scalar(id,"durationIndex") == 0 and scalar(id,"powerType") == 0
        and scalar(id,"manaCost") == rank.mana
        and scalar(id,"maxLevel") == rank.max
        and scalar(id,"baseLevel") == rank.level
        and scalar(id,"spellLevel") == rank.level
        and scalar(id,"startRecoveryCategory") == 133
        and scalar(id,"startRecoveryTime") == 1500
        and scalar(id,"spellFamilyName") == S.MAGE_FAMILY
        and scalar(id,"spellFamilyFlags") == 0
        and scalar(id,"spellFamilyFlags2") == 1
        and scalar(id,"dmgClass") == 1 and scalar(id,"preventionType") == 1
        and equal(triple(id,"effect"),2,0,0)
        and equal(triple(id,"effectDieSides",true),rank.sides,0,0)
        and equal(triple(id,"effectBasePoints",true),rank.points,0,0)
        and equal(triple(id,"effectImplicitTargetA"),6,0,0)
        and rangeExact(id)
end
local function mage()
    if type(UnitClass) ~= "function" then return false end
    local ok, _, token = pcall(UnitClass,"player")
    return ok and token == "MAGE"
end

function S:Classify(id)
    id = integer(id); local rank = id and RANKS[id]
    if not rank then return nil,"not an installed Arcane Surge identity",false end
    local found = CACHE[id]
    if found then return found.valid and copy(found) or nil,found.reason,true end
    found = { recognized=true,valid=false,exact=false,spellId=id,
        rank=rank.rank,source="installed Octo patch-5 Arcane Surge DBC topology" }
    if not topology(id,rank) then
        found.reason="Arcane Surge DBC topology is incomplete"; CACHE[id]=found
        return nil,found.reason,true
    end
    found.valid,found.exact=true,true
    found.minimumDamage,found.maximumDamage=rank.points+1,rank.points+rank.sides
    found.mana,found.cooldown,found.gcd=rank.mana,8,1.5
    found.casterAuraState=S.AURA_STATE_MAGE_RESIST
    found.ignoresPositiveResistance=true
    CACHE[id]=found; return copy(found),nil,true
end

function S:InferKnowledge(id)
    if not mage() then return nil,"player is not an exactly identified Mage",false end
    local found,reason,handled=self:Classify(id)
    if not found then return nil,reason,handled end
    return { inferred=true,kind="damage",kindExact=true,ranged=true,hostile=true,
        reactive=true,mageArcaneSurge=true,school=6,deliveryModel="magic",
        ignoreResistances=true,requiresExactUsability=true,submissionGuarded=true,
        mageArcaneSurgeEvidence=copy(found),source=found.source },nil,true
end
function S:Invalidate() CACHE={} end
