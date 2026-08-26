XelAssist = { Game = {}, Combat = { Knowledge = {} }, Graph = {}, UI = {} }
BOOKTYPE_SPELL = "spell"
UIParent = {}
GetNumSpellTabs = function() return 2 end
GetSpellTabInfo = function(index)
    if index == 1 then return "General", nil, 0, 0 end
    return "Warlock", nil, 0, 1
end

local records = {
    [1454] = { spellFamilyName = 5, spellFamilyFlags = 262144,
        powerType = 4294967294, effect = { 3, 0, 0 },
        effectImplicitTargetA = { 1, 0, 0 } },
    [1455] = { spellFamilyName = 5, spellFamilyFlags = 262144,
        powerType = -2, effect = { 3, 0, 0 },
        effectImplicitTargetA = { 1, 0, 0 } },
    [9999] = { spellFamilyName = 5, spellFamilyFlags = 262144,
        powerType = 4294967294, effect = { 3, 0, 0 },
        effectImplicitTargetA = { 6, 0, 0 } },
}
GetSpellRecField = function(spellId, field) return records[spellId][field] end

local tooltip = {}
tooltip.SetOwner = function() end
tooltip.ClearLines = function() end
tooltip.SetSpell = function() end
CreateFrame = function() return tooltip end
getglobal = function(name)
    if string.find(name, "TextLeft2", 1, true) then
        return { GetText = function() return "Wandelt Gesundheit in Mana um." end }
    end
    return nil
end
IsPassiveSpell = function() return false end
GetSpellName = function(slot)
    if slot == 1 then return "Aderlass", "Rang 1" end
    return nil
end
GetSpellSlotTypeIdForName = function(name)
    assert(name == "Aderlass(Rang 1)")
    return 1, "spell", 1454
end

dofile("Game/ResourceExchange.lua")
dofile("Game/ResourceCost.lua")
dofile("Game/SpellEffectPower.lua")
dofile("Game/SpellFactCache.lua")
dofile("Game/ActionInference.lua")
dofile("Game/CapabilityInvalidation.lua")
dofile("Game/RacialActions.lua")
dofile("Game/Capabilities.lua")

local unsigned = XelAssist.Game.ResourceExchange:InferDBC(1454)
assert(unsigned and unsigned.healthConversion and unsigned.resourceType == "mana",
    "unsigned -2 powerType must normalize before matching Life Tap")
assert(XelAssist.Game.ResourceExchange:InferDBC(1455),
    "signed -2 powerType must retain the same DBC semantics")
assert(XelAssist.Game.ResourceExchange:InferDBC(9999) == nil,
    "a DUMMY effect aimed at a hostile target must not become Life Tap")

local actions = XelAssist.Game.Capabilities:Actions()
assert(actions[1] and actions[1].name == "Aderlass"
    and actions[1].spellId == 1454 and actions[1].facts.dbcResourceExchange,
    "localized spell names must be inferred from DBC identity, not tooltip prose")

local magnitude = {}
assert(XelAssist.Game.ResourceExchange:Apply(actions[1], magnitude,
    "converts 20 health into 20 mana")
    and magnitude.healthCost == 20 and magnitude.resourceGain == 20,
    "English tooltip evidence must remain available for rank magnitude")
assert(not XelAssist.Game.ResourceExchange:Apply(actions[1], {},
    "wandelt 20 gesundheit in 20 mana um"),
    "unparsed localized prose must not invent a resource magnitude")

print("ok: localized Life Tap identity uses its exact DBC signature")
