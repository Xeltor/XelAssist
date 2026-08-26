-- Installed Expose Armor rows carry zero base magnitude and exact reduction in
-- effectPointsPerComboPoint. The own-action fact must reach graph consequences.
XelAssist = { Game = {}, Combat = {}, Graph = {} }
table.getn = table.getn or function(value)
    local count = 0
    while value[count + 1] ~= nil do count = count + 1 end
    return count
end

local records = {
    [8647] = { effect = { 6, 3, 0 }, effectApplyAuraName = { 22, 0, 0 },
        effectBasePoints = { -1, 0, 0 }, effectMiscValue = { 1, 0, 0 },
        effectPointsPerComboPoint = { -80, 0, 0 } },
    [8649] = { effect = { 6, 3, 0 }, effectApplyAuraName = { 22, 0, 0 },
        effectBasePoints = { -1, 0, 0 }, effectMiscValue = { 1, 0, 0 },
        effectPointsPerComboPoint = { -145, 0, 0 } },
    [99001] = { effect = { 2, 0, 0 }, effectApplyAuraName = { 22, 0, 0 },
        effectBasePoints = { -1, 0, 0 }, effectMiscValue = { 1, 0, 0 },
        effectPointsPerComboPoint = { -500, 0, 0 } },
    [99002] = { effect = { 6, 0, 0 }, effectApplyAuraName = { 22, 0, 0 },
        effectBasePoints = { -11, 0, 0 }, effectMiscValue = { 1, 0, 0 },
        effectPointsPerComboPoint = { -80, 0, 0 } },
}
GetSpellRecField = function(spellId, field)
    local record = records[spellId] or {}
    return record[field]
end

dofile("Game/TargetModifierFacts.lua")
local Facts = XelAssist.Game.TargetModifierFacts
local semantics = { armorDebuff = true, modifierGroup = "majorArmor" }
local rankOne = Facts:Get(8647, semantics)
local rankTwo = Facts:Get(8649, semantics)
assert(rankOne.recognized and rankOne.targetArmorReduction == 80
    and rankOne.targetArmorPerCombo and rankTwo.targetArmorReduction == 145,
    "installed per-combo magnitudes must remain rank exact")
assert(Facts:Get(8647, nil).recognized,
    "negative exact per-combo rows must recover active modifiers without names")
assert(not Facts:Get(99001, semantics).recognized
    and not Facts:Get(99002, semantics).recognized,
    "wrong effect and mixed base-plus-combo equations must fail closed")

local action = { name = "Locale independent finisher", spellId = 8647,
    facts = semantics }
local tooltip = {}
assert(Facts:Apply(action, tooltip) and tooltip.targetArmorReduction == 80
    and tooltip.targetArmorPerCombo,
    "own-action facts must not depend on an English spell name or table tooltip")

dofile("Combat/TargetModifiers.lua")
XelAssist.Graph.State = { CommitActiveHostile = function() end }
dofile("Graph/StackedModifiers.lua")
XelAssist.Graph.ComboState = {
    ConditionalExpected = function(_, _, targetGUID)
        assert(targetGUID == "target-guid")
        return 3
    end,
}
dofile("Graph/Effects.lua")
local state = { targetModifierEffects = {}, targetResistance = {},
    targetDamageTaken = {}, baseTargetDamageTaken = {}, auras = {} }
XelAssist.Graph.Effects:ApplyTargetModifier(state, action, tooltip,
    { combo = 3 }, 1, nil, nil, "target-guid")
assert(state.targetModifierEffects[action.name].resistanceReduction[0] == 240,
    "graph transition must multiply the exact rank amount by projected combo points")

print("ok: exact per-combo armor facts reach graph target consequences")
