table.getn = table.getn or function(value) return #value end
XelAssist = { Game = { Player = {} }, Graph = {} }

local fields = {
    spellFamilyName = 7, spellFamilyFlags = 0, spellFamilyFlags2 = 8,
    category = 82, stances = 144, stancesNot = 0, rangeIndex = 2,
    durationIndex = 27, powerType = 1, manaCost = 0, manaCostPerlevel = 0,
    manaCostPercentage = 0, manaPerSecond = 0, manaPerSecondPerLevel = 0,
    recoveryTime = 0,
    categoryRecoveryTime = 10000, startRecoveryCategory = 0,
    startRecoveryTime = 0, effect = { 114, 6, 0 },
    effectApplyAuraName = { 0, 11, 0 },
    effectImplicitTargetA = { 0, 0, 0 },
    effectImplicitTargetB = { 6, 6, 0 }, effectTriggerSpell = { 0, 0, 0 },
}
function UnitClass() return "Druid", "DRUID" end
function GetSpellRecField(id, field, copy)
    assert(id == 6795)
    local value = fields[field]
    if copy == 1 and type(value) == "table" then
        return { value[1], value[2], value[3] }
    end
    return value
end

dofile("Game/Player/DruidGrowl.lua")
local G = XelAssist.Game.Player.DruidGrowl
local facts, reason, handled = G:InferKnowledge(6795)
assert(handled and not reason and facts and facts.kind == "taunt"
    and facts.kindExact and facts.playerTaunt and facts.druidGrowl
    and facts.tankOnly and facts.immediateDispatch and facts.gcd == 0
    and G:Evidence(facts),
    "Druid Growl must become exact Bear-form player-taunt evidence")
fields.stances = 16
G:Invalidate()
local rejected, rejectedReason, rejectedHandled = G:InferKnowledge(6795)
assert(rejectedHandled and not rejected
    and rejectedReason == "Octo Druid Growl DBC topology is incomplete",
    "modified Growl form legality must fail closed")
fields.stances = 144
G:Invalidate()
UnitClass = function() return "Warrior", "WARRIOR" end
assert(select(3, G:InferKnowledge(6795)) == false,
    "another class must not claim Druid Growl")
print("ok: exact Octo Druid Growl player-taunt semantics")
