XelAssist = { Game = { Player = {} }, Graph = {} }
table.getn = table.getn or function(value)
    local count = 0
    while value and value[count + 1] ~= nil do count = count + 1 end
    return count
end

local mageCalls = { consume = 0 }
local Mage = {}
function Mage:InferKnowledge(spellId)
    if spellId == 1 then
        return { kind = "absorb", mageManaShield = true }, nil, true
    end
    return nil, "not Mage shield", false
end
function Mage:CaptureFacts(action, facts)
    if action.facts.mageManaShield then facts.manaRatioCaptured = true end
    return facts
end
function Mage:Blocker(action)
    if action.facts.mageManaShield then return nil, true end
    return nil, false
end
function Mage:Is(subject)
    local facts = subject and subject.facts or subject
    return facts and facts.mageManaShield == true
end
function Mage:Entry(candidate)
    return { amount = candidate.power, applicationProbability = 1,
        mageManaShield = true, evidenceExact = true,
        manaPerDamage = 2, schoolMask = 1 }
end
function Mage:IsEntry(entry)
    return type(entry) == "table" and entry.mageManaShield == true
end
function Mage:ConsumeEntry(state, absorbs, name, damage, probability, school)
    local entry = absorbs[name]
    if not self:IsEntry(entry) then return damage, 0, 0, false, false end
    mageCalls.consume = mageCalls.consume + 1
    assert(damage == 20 and school == 0,
        "ordinary absorbs must resolve before the mana-funded shield")
    local used = math.min(damage, entry.amount)
    absorbs[name] = nil
    state.resource = state.resource - used * 2 * probability
    return damage - used, used * probability, used * 2 * probability,
        false, true
end
function Mage:EffectiveCapacity() return 7 end
function Mage:Invalidate() end

local Priest = {}
function Priest:InferKnowledge(spellId)
    if spellId == 2 then
        return { kind = "absorb", priestShield = true }, nil, true
    end
    return nil, "not Priest shield", false
end
function Priest:Is(subject)
    local facts = subject and subject.facts or subject
    return facts and facts.priestShield == true
end
function Priest:Capture(observed, action, descriptor)
    if not self:Is(action) then return false end
    observed.priestCaptured = descriptor.key
    return true, { known = true, active = false }
end
function Priest:Blocker(action)
    if self:Is(action) then return nil, true end
    return nil, false
end
function Priest:Apply(state, candidate)
    state.priestApplied = candidate.targetKey
    return true
end
function Priest:Invalidate() end

XelAssist.Game.Player.MageManaShield = Mage
XelAssist.Game.Player.PriestShield = Priest
dofile("Game/ActionInference.lua")
assert(XelAssist.Game.ActionInference:ClassKnowledge(1).mageManaShield
    and XelAssist.Game.ActionInference:ClassKnowledge(2).priestShield,
    "class inference must dispatch exact Mage and Priest shield identities")

dofile("Graph/ClassMechanics.lua")
local Mechanics = XelAssist.Graph.ClassMechanics
local mageAction = { name = "Opaque mana shield",
    facts = { kind = "absorb", mageManaShield = true } }
local priestAction = { name = "Opaque priest shield",
    facts = { kind = "absorb", priestShield = true } }
local captured = Mechanics:CaptureFacts(mageAction, {})
local observed = {}
Mechanics:CaptureRecipient(observed, priestAction, { key = "ally" })
assert(captured.manaRatioCaptured and observed.priestCaptured == "ally"
    and Mechanics:EvidenceBlocker(mageAction, {}, {}, captured) == nil,
    "root capture and legality must share the exact class evidence boundary")
assert(Mechanics:AbsorbCapacity({ action = mageAction, state = {} }) == 7,
    "Mage absorb scoring must use resource-funded effective capacity")

XelAssist.Graph.State = { FriendlyByKey = function(_, state, key)
    return state.friendlies.byKey[key]
end }
dofile("Graph/FriendlyActionEffects.lua")
local Friendly = XelAssist.Graph.FriendlyActionEffects
local state = { resource = 100, friendlies = { byKey = { ally = {
    guid = "ally-guid", health = 100, healthMax = 100,
    healthExact = true, auras = {}, absorbs = {} } } } }
local mageCandidate = { action = mageAction, targetKey = "ally",
    targetGUID = "ally-guid", targetRelation = "friendly", power = 60,
    tooltip = { duration = 60 }, effectDelivery = 1 }
assert(Friendly:Apply(state, mageCandidate,
    { action = mageAction, facts = mageAction.facts }))
assert(state.friendlies.byKey.ally.absorbs[mageAction.name].mageManaShield,
    "friendly effect projection must retain the exact Mana Shield entry")

local priestCandidate = { action = priestAction, targetKey = "ally",
    targetGUID = "ally-guid", targetRelation = "friendly", power = 80,
    tooltip = { duration = 30 }, effectDelivery = 1 }
Friendly:Apply(state, priestCandidate,
    { action = priestAction, facts = priestAction.facts })
assert(state.friendlies.byKey.ally.absorbs[priestAction.name].amount == 80
    and state.priestApplied == "ally",
    "Priest absorb projection must also apply its exact recipient lockout")

dofile("Graph/IncomingAbsorbs.lua")
local incomingState = { resource = 100 }
local recipient = { kind = "player", friendly = { absorbs = {
    ordinary = { amount = 30, applicationProbability = 1 },
    mana = Mage:Entry({ power = 40 }),
} } }
local residual, absorbed, partial = XelAssist.Graph.IncomingAbsorbs:Consume(
    incomingState, recipient, 50, 1, 0)
assert(residual == 0 and absorbed == 50 and not partial
    and incomingState.resource == 60 and mageCalls.consume == 1,
    "incoming physical damage must consume ordinary then mana-funded absorbs")

print("ok: Mage and Priest shields are wired through exact graph evidence and consequences")
