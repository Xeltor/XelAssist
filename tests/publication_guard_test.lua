XelAssist = { Core = {}, Game = { Actors = {}, Capabilities = {} } }
local playerResource, petResource = 100, 50
function UnitMana(unit)
    return unit == "pet" and petResource or playerResource
end

local hostileValid, petValid, friendlyValid = true, true, true
XelAssist.Core.TargetGuard = {
    ValidateHostile = function(_, current)
        if current.targetRelation ~= "hostile"
            and current.castTargetRelation ~= "hostile" then
            return nil, nil, false
        end
        if hostileValid then return "hostile-guid", nil, true end
        return nil, "selected target defeated", true
    end,
    ValidatePetTarget = function()
        return petValid, petValid and nil or "companion target changed"
    end,
}
XelAssist.Game.Actors.ValidateActorRef = function(_, ref)
    if ref and ref.valid then return "pet", nil end
    return nil, "companion changed"
end
XelAssist.Game.Actors.HasReagent = function(_, name)
    return name ~= "Missing Shard"
end
XelAssist.Game.Capabilities.ValidateFriendlyRef = function(_, ref)
    if friendlyValid and ref and ref.valid then return ref.unit, nil end
    return nil, "ally changed"
end
local auraPending = false
function XelAssist:IsAuraPending() return auraPending end
local warriorSafe = true
XelAssist.Core.PlayerTauntGuard = { Validate = function(_, current)
    if current.action.facts.playerTaunt and not warriorSafe then
        return false, "Taunt victim changed"
    end
    return true, nil
end }

dofile("Core/PublicationGuard.lua")
local Guard = XelAssist.Core.PublicationGuard
local function plan(action)
    return { action = action, target = "target", targetGUID = "hostile-guid",
        targetRelation = "hostile",
        targetRef = { unit = "target", guid = "hostile-guid",
            relation = "hostile" },
        castTarget = "target", castTargetGUID = "hostile-guid",
        castTargetRelation = "hostile",
        castTargetRef = { unit = "target", guid = "hostile-guid",
            relation = "hostile" },
        tooltip = {}, cost = 30, costKnown = true, wait = 0 }
end

local bolt = plan({ name = "Shadow Bolt", actor = "player",
    executor = "playerSpell", facts = { kind = "damage" } })
assert(Guard:Validate(bolt),
    "an affordable action with stable identities must publish")
local taunt = plan({ name = "Taunt", actor = "player",
    executor = "playerSpell", facts = { kind = "taunt", playerTaunt = true } })
taunt.cost, taunt.costKnown, warriorSafe = 0, true, false
local tauntValid, tauntReason = Guard:Validate(taunt)
assert(not tauntValid and tauntReason == "Taunt victim changed",
    "publication must invoke the exact live Warrior tank guard")
warriorSafe = true
playerResource = 20
local valid, reason = Guard:Validate(bolt)
assert(not valid and reason == "resource changed",
    "selected affordability loss must reject stale work")
bolt.wait, playerResource = 1, 20
assert(Guard:Validate(bolt),
    "a projected resource wait must not be judged by immediate resource")

local corruption = plan({ name = "Corruption", actor = "player",
    executor = "playerSpell", facts = { kind = "dot" } })
corruption.cost, playerResource, auraPending = 10, 100, true
valid, reason = Guard:Validate(corruption)
assert(not valid and reason == "application already pending",
    "a newly pending application must not be republished")
local charge = plan({ name = "Charge", actor = "player",
    executor = "playerSpell", facts = { kind = "engage",
        submissionGuarded = true } })
charge.cost, charge.costKnown = 0, true
valid, reason = Guard:Validate(charge)
assert(not valid and reason == "application already pending",
    "a pending off-GCD engage submission must not be republished")
auraPending, hostileValid = false, false
valid, reason = Guard:Validate(corruption)
assert(not valid and reason == "selected target defeated",
    "silent target death must reject publication")

hostileValid = true
local petPlan = plan({ name = "Firebolt", actor = "pet",
    actorRef = { unit = "pet", guid = "pet-guid", valid = true },
    executor = "petAbility", facts = { kind = "damage" } })
petPlan.cost, petPlan.costKnown = 60, true
valid, reason = Guard:Validate(petPlan)
assert(not valid and reason == "companion resource changed",
    "companion affordability must use the companion resource")
petPlan.cost, petValid = 10, false
valid, reason = Guard:Validate(petPlan)
assert(not valid and reason == "companion target changed",
    "a changed companion target must reject publication")

petValid = true
local friendlyPlan = plan({ name = "Renew", actor = "player",
    executor = "playerSpell", facts = { kind = "hot" } })
friendlyPlan.target, friendlyPlan.castTarget = "party1", "party1"
friendlyPlan.targetRelation, friendlyPlan.castTargetRelation = "ally", "ally"
friendlyPlan.targetRef = { unit = "party1", guid = "ally-guid",
    relation = "ally", valid = true }
friendlyPlan.castTargetRef = friendlyPlan.targetRef
friendlyPlan.cost, friendlyPlan.costKnown = 0, true
friendlyValid = false
valid, reason = Guard:Validate(friendlyPlan)
assert(not valid and reason == "ally changed",
    "a changed friendly slot must reject publication")

print("publication guard tests passed")
