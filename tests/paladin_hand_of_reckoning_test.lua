table.getn = table.getn or function(values) return #values end
XelAssist = { Game = { Player = {}, Capabilities = {
    Usable = function() return true end,
} }, Graph = {} }

local row = {
    spellFamilyName = 10, school = 0, category = 82, rangeIndex = 7,
    durationIndex = 27, powerType = 0, manaCost = 0,
    manaCostPerlevel = 0, manaCostPercentage = 0,
    manaPerSecond = 0, manaPerSecondPerLevel = 0, recoveryTime = 0,
    categoryRecoveryTime = 10000,
    startRecoveryCategory = 0, startRecoveryTime = 0,
    effect = { 114, 6, 0 }, effectApplyAuraName = { 0, 11, 0 },
    effectImplicitTargetA = { 6, 6, 0 }, effectTriggerSpell = { 0, 0, 0 },
}
function UnitClass() return "Paladin", "PALADIN" end
function GetSpellRecField(spellId, field, array)
    if spellId ~= 51302 then return nil end
    local value = row[field]
    if array and type(value) == "table" then return value end
    if not array and type(value) == "number" then return value end
end

dofile("Game/Player/PaladinHandOfReckoning.lua")
local Hand = XelAssist.Game.Player.PaladinHandOfReckoning
local facts, reason, handled = Hand:InferKnowledge(51302)
assert(handled and not reason and facts and facts.kind == "taunt"
    and facts.kindExact and facts.playerTaunt and facts.tankOnly
    and facts.gcd == 0 and facts.tauntFocusDuration == 3
    and facts.handOfReckoningEvidence.noOpWhenTargetingCaster,
    "Hand of Reckoning must be exact numeric player-taunt evidence")
assert(Hand:Evidence({ spellId = 51302, facts = facts }),
    "the exact captured Hand of Reckoning profile must validate")

local unknown, unknownReason, unknownHandled = Hand:InferKnowledge(355)
assert(not unknown and not unknownReason and not unknownHandled,
    "the Paladin owner must not claim other taunt identities")

row.effect = { 114, 6, 3 }
Hand:Invalidate()
local malformed, malformedReason, malformedHandled = Hand:InferKnowledge(51302)
assert(not malformed and malformedHandled
    and malformedReason == "Octo Hand of Reckoning DBC topology is incomplete",
    "shifted Hand of Reckoning topology must fail closed")
row.effect = { 114, 6, 0 }
Hand:Invalidate()
facts = assert(Hand:InferKnowledge(51302))

row.startRecoveryTime = 1500
Hand:Invalidate()
local gcdShift, gcdShiftReason, gcdShiftHandled = Hand:InferKnowledge(51302)
assert(not gcdShift and gcdShiftHandled
    and gcdShiftReason == "Octo Hand of Reckoning DBC topology is incomplete",
    "off-GCD facts must fail closed when global recovery shifts")
row.startRecoveryTime = 0
row.manaCostPercentage = 5
Hand:Invalidate()
local costShift, costShiftReason, costShiftHandled = Hand:InferKnowledge(51302)
assert(not costShift and costShiftHandled
    and costShiftReason == "Octo Hand of Reckoning DBC topology is incomplete",
    "zero cost facts must include every client mana-cost channel")
row.manaCostPercentage = 0
Hand:Invalidate()
facts = assert(Hand:InferKnowledge(51302))

XelAssist.Graph.State = { FriendlyByUnit = function() return nil end }
local victimKind = "ally"
local function record()
    local player = victimKind == "player"
    return { guid = "target-guid", selected = true, dead = false,
        threat = {}, victim = { available = true,
            guid = player and "player-guid" or "ally-guid",
            groupUnit = player and nil or "party1",
            targetsPlayer = player, targetsPet = false,
            targetsGroup = not player } }
end
XelAssist.Graph.HostileState = {
    Selected = function() return record() end,
    Active = function() return record() end,
}
XelAssist.Graph.State.FriendlyByUnit = function(_, _, unit)
    if unit == "party1" then
        return { guid = "ally-guid", relation = "party", health = 500,
            healthMax = 1000 }
    end
end
dofile("Graph/PlayerTaunt.lua")
local action = { name = "Localized Reckoning", spellId = 51302,
    actor = "player", facts = facts }
local state = { time = 0, tank = true, targetGUID = "target-guid",
    actors = { player = { guid = "player-guid" } } }
local descriptor = { unit = "target", relation = "hostile",
    guid = "target-guid" }
assert(XelAssist.Graph.PlayerTaunt:Blocker(action, state, descriptor) == nil,
    "exact ally victim evidence must admit Hand of Reckoning")
victimKind = "player"
assert(XelAssist.Graph.PlayerTaunt:Blocker(action, state, descriptor)
        == "target already attacks player",
    "Hand of Reckoning must be a no-op when the target already attacks caster")

action.facts.handOfReckoningEvidence.rangeIndex = 99
victimKind = "ally"
assert(XelAssist.Graph.PlayerTaunt:Blocker(action, state, descriptor)
        == "unknown player Taunt rank",
    "mutated root identity must fail closed at the taunt boundary")

print("ok: exact Octo Hand of Reckoning player-taunt semantics")
