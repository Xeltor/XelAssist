XelAssist = { Game = { Player = {} }, Graph = {} }

local learned = true
local rows = { [53201] = { attributes = 192, durationIndex = 21,
    spellFamilyName = 4, spellFamilyFlags = 0,
    effect = { 6, 0, 0 }, effectApplyAuraName = { 4, 0, 0 },
    effectImplicitTargetA = { 1, 0, 0 }, effectBasePoints = { 0, 0, 0 },
    effectBaseDice = { 1, 0, 0 } } }
function UnitClass() return "Warrior", "WARRIOR" end
function IsPlayerSpell(id) return id == 53201 and learned end
function GetSpellRecField(id, field, array)
    local value = rows[id] and rows[id][field]
    if array and type(value) == "table" then
        return { value[1], value[2], value[3] }
    end
    return value
end

dofile("Game/Player/WarriorChargeCombat.lua")
dofile("Graph/Charge.lua")
local C = XelAssist.Game.Player.WarriorChargeCombat
local action = { spellId = 100, facts = { chargeMovement = true,
    outOfCombat = true, rageGainBySpellId = { [100] = 9 } } }
local facts = C:CaptureFacts(action, action.facts)
assert(facts.chargeInCombat == true and facts.outOfCombat == false
    and facts.chargeInCombatEvidence.spellId == 53201,
    "the exact learned passive must remove Charge's combat restriction")

XelAssist.Graph.RootObservation = { Usability = function()
    return { known = true, usable = true }, "known"
end }
XelAssist.Game.Capabilities = { Usable = function() return true end }
action.facts = facts
local state = { inCombat = true, hostile = true, targetGUID = "mob",
    resourceType = 1, resource = 20, resourceMax = 100, time = 4 }
local target = { unit = "target", relation = "hostile", guid = "mob" }
assert(XelAssist.Graph.Charge:Blocker(action, state, target) == nil,
    "talented Charge must remain legal in an in-combat future state")

learned = false
C:Invalidate()
action.facts = C:CaptureFacts(action, { chargeMovement = true,
    outOfCombat = true, rageGainBySpellId = { [100] = 9 } })
assert(action.facts.chargeInCombat == nil and action.facts.outOfCombat == true,
    "ordinary Charge must retain its out-of-combat contract")
assert(XelAssist.Graph.Charge:Blocker(action, state, target) == "combat state",
    "ordinary Charge must still be blocked in combat")

learned = true
rows[53201].effectApplyAuraName = { 5, 0, 0 }
C:Invalidate()
local shifted = C:CaptureFacts(action, { chargeMovement = true,
    outOfCombat = true, rageGainBySpellId = { [100] = 9 } })
assert(shifted.chargeInCombat == nil and shifted.outOfCombat == true
    and shifted.chargeInCombatEvidenceIncomplete == true,
    "shifted passive topology must not manufacture in-combat legality")

print("ok: exact Octo Charge in Combat passive legality")
