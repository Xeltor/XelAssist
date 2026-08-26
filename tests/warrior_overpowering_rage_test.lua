XelAssist = { Game = { Player = {} }, Graph = {} }
local function t(a, b, c) return { a or 0, b or 0, c or 0 } end
local rows = {
    [53203] = { attributes = 192, procFlags = 16, procChance = 100,
        procCharges = 0, durationIndex = 21, spellFamilyName = 4,
        effect = t(6), effectDieSides = t(1), effectBaseDice = t(1),
        effectBasePoints = t(99), effectImplicitTargetA = t(1),
        effectApplyAuraName = t(42), effectTriggerSpell = t(53202) },
    [53202] = { attributes = 0, procFlags = 0, procChance = 101,
        durationIndex = 7, rangeIndex = 1, spellFamilyName = 4,
        effect = t(6), effectDieSides = t(1), effectBaseDice = t(1),
        effectBasePoints = t(14), effectImplicitTargetA = t(1),
        effectApplyAuraName = t(138), effectTriggerSpell = t() },
}
function GetSpellRecField(id, field, copied)
    local value = rows[id] and rows[id][field]
    if copied and type(value) == "table" then
        return { value[1], value[2], value[3] }
    end
    return value
end
function GetSpellDuration(id, base)
    assert(id == 53202 and base == 1); return 5000
end
local class, learned, clock, aura = "WARRIOR", true, 100, nil
function UnitClass() return "Warrior", class end
function IsPlayerSpell(id) assert(id == 53203); return learned end
function GetTime() return clock end
C_UnitAuras = { GetPlayerAuraBySpellID = function(id)
    assert(id == 53202); return aura
end }

dofile("Game/Player/WarriorOverpoweringRage.lua")
local Runtime = XelAssist.Game.Player.WarriorOverpoweringRage
local root = Runtime:Snapshot()
assert(root.available and root.exact and root.learned and not root.active
    and root.hastePercent == 15 and root.duration == 5,
    "known Overpowering Rage must expose an exact inactive root")
aura = { spellId = 53202, expirationTime = 103.75 }
root = Runtime:Snapshot()
assert(root.active and root.remaining == 3.75,
    "the live triggered haste aura must expose its exact remaining clock")
local action = { spellId = 7384, facts = {
    warriorOverpower = true, kind = "damage" } }
local facts = Runtime:CaptureFacts(action, action.facts)
assert(facts.warriorOverpoweringRageEvidence.active
    and facts.warriorOverpoweringRageEvidence.learned,
    "Overpower facts must freeze passive ownership and aura evidence")
learned, aura = false, nil
root = Runtime:Snapshot()
assert(root.available and root.exact and not root.learned and not root.active,
    "an unlearned passive must be exact rather than an unknown proc")
class, learned = "MAGE", true
assert(not Runtime:Snapshot().available,
    "another class must not inherit Warrior haste")
class = "WARRIOR"

dofile("Graph/WarriorOverpoweringRage.lua")
local Graph = XelAssist.Graph.WarriorOverpoweringRage
learned = true
root = { available = true, exact = true, learned = true,
    portfolio = "warriorOverpoweringRage", passiveSpellId = 53203,
    hasteSpellId = 53202, hastePercent = 15, duration = 5 }
local state = { playerAttack = { attackRound = { speed = 2.3,
    interval = 2.35, speedTrusted = true, verified = true,
    projectable = true, targetGuid = "enemy" } } }
assert(Graph:Attach(state, root) and not state.warriorOverpoweringRage.active,
    "inactive exact haste must attach to the graph")
facts.warriorOverpoweringRageEvidence = root
local candidate = { action = { spellId = 7384, facts = facts },
    tooltip = facts, effectDelivery = 1 }
assert(Graph:Apply(state, candidate)
    and state.warriorOverpoweringRage.active
    and state.warriorOverpoweringRage.remaining == 5,
    "a guaranteed Overpower delivery must start the five-second clock")
local accelerated = Graph:IntervalAfter(state, "main", 1, 2.35)
assert(math.abs(accelerated - 2.05) < 0.000001,
    "only the next reset must receive fifteen-percent haste")
local copy = {}
assert(Graph:Copy(state, copy)
    and copy.warriorOverpoweringRage ~= state.warriorOverpoweringRage,
    "haste state must remain branch-local")
Graph:Advance(copy, 5)
assert(not copy.warriorOverpoweringRage.active
    and Graph:IntervalAfter(copy, "main", 6, 2.35) == 2.35,
    "expiry must restore the sealed base interval")
state.warriorOverpoweringRage.active = false
candidate.effectDelivery = 0.9
assert(not Graph:Apply(state, candidate),
    "an uncertain Overpower result must not manufacture deterministic haste")

dofile("Graph/PlayerSwingModifiers.lua")
local modifiers = XelAssist.Graph.PlayerSwingModifiers
state.classMechanicClass = "WARRIOR"
state.warriorOverpoweringRage.active = true
state.warriorOverpoweringRage.remaining = 5
assert(math.abs(modifiers:IntervalAfter(state, "main", 1, 2.35) - 2.05)
    < 0.000001,
    "the shared swing modifier compositor must include Warrior haste")
print("ok: exact Overpowering Rage five-second melee haste")
