-- Exact patch-5 Berserker Rage must amplify only incoming-damage rage during
-- its finite branch-local aura. Control immunity remains unvalued without a
-- hostile control ledger.
XelAssist = { Game = { Player = {} }, Graph = {} }

local arrays = {
    effect = { 6, 6, 6 }, effectApplyAuraName = { 77, 77, 226 },
    effectBasePoints = { -1, -1, 29 },
    effectImplicitTargetA = { 0, 0, 0 },
    effectImplicitTargetB = { 1, 1, 1 },
    effectMiscValue = { 5, 14, 0 },
}
local scalars = { spellFamilyName = 4, spellFamilyFlags = 268435456,
    powerType = 0, manaCost = 0 }
function UnitClass() return "Warrior", "WARRIOR" end
function GetSpellDuration(id) assert(id == 18499); return 10000 end
function GetSpellRecField(id, field, array)
    assert(id == 18499)
    if array then
        local source, out, index = arrays[field], {}, nil
        for index = 1, 3 do out[index] = source[index] end
        return out
    end
    return scalars[field]
end

dofile("Game/Player/WarriorBerserkerRage.lua")
local Runtime = XelAssist.Game.Player.WarriorBerserkerRage
local facts, reason, handled = Runtime:InferKnowledge(18499)
assert(handled and not reason and facts.kind == "buff"
    and facts.warriorBerserkerRage,
    "installed Berserker Rage must be class-owned without a priority rule")
local captured = Runtime:CaptureFacts({ spellId = 18499, facts = facts }, facts)
assert(captured.duration == 10 and captured.cost == 0
    and Runtime:Evidence(captured).incomingRageMultiplier == 1.3,
    "root capture must seal the exact finite incoming-rage multiplier")

dofile("Graph/WarriorBerserkerRage.lua")
dofile("Graph/PlayerRage.lua")
local Graph, Rage = XelAssist.Graph.WarriorBerserkerRage,
    XelAssist.Graph.PlayerRage
local action = { spellId = 18499, facts = captured }
local state = { resourceType = 1, resource = 0, resourceMax = 100,
    playerLevel = 60, playerResourceExact = true }
local descriptor = { unit = "player", relation = "friendly" }
assert(Graph:Blocker(action, state, descriptor, captured) == nil,
    "an inactive exact self aura must be legal")
local context = { action = action, tooltip = captured }
assert(Graph:Score(context) and context.value == 0
    and context.estimated == false,
    "the setup edge must rely on future causal rage, not invented immunity value")
assert(Graph:Apply(state, { action = action, tooltip = captured })
    and state.warriorBerserkerRage.remaining == 10,
    "application must start one exact branch-local ten-second window")
assert(Graph:Blocker(action, state, descriptor, captured)
        == "Berserker Rage already active",
    "the active window must prevent wasteful reapplication")

local baseline = Rage:FromIncomingDamage({ resourceType = 1,
    playerLevel = 60 }, 1000)
local amplified = Rage:FromIncomingDamage(state, 1000)
assert(amplified == math.floor(baseline * 1.3)
        or amplified == math.floor(1000 * 2.5 * 1.3
            / Rage:Conversion(60)),
    "only incoming damage must receive the exact 30-percent multiplier")
assert(Rage:FromOutgoingDamage(state, 1000)
        == Rage:FromOutgoingDamage({ resourceType = 1, playerLevel = 60 }, 1000),
    "Berserker Rage must not amplify outgoing white-hit rage")

local branch = { resourceType = 1, resource = 0, resourceMax = 100,
    playerLevel = 60, playerResourceExact = true }
assert(Graph:Copy(state, branch) and branch.warriorBerserkerRage
    ~= state.warriorBerserkerRage,
    "the active window must copy without aliasing graph branches")
Graph:Advance(branch, 9.5)
assert(branch.warriorBerserkerRage
    and branch.warriorBerserkerRage.remaining == 0.5,
    "the multiplier must survive only its exact remaining lifetime")
Graph:Advance(branch, 0.5)
assert(branch.warriorBerserkerRage == nil
    and Rage:FromIncomingDamage(branch, 1000) == baseline,
    "expiry must restore baseline incoming rage")

function GetPlayerBuff(index) return index == 0 and 7 or -1 end
function GetPlayerBuffID(slot) assert(slot == 7); return 18499 end
function GetPlayerBuffTimeLeft(slot) assert(slot == 7); return 6.25 end
local live = Runtime:Snapshot()
assert(live and live.exact and live.remaining == 6.25
    and live.incomingRageMultiplier == 1.3,
    "live root capture must preserve the exact remaining aura lifetime")

arrays.effectApplyAuraName = { 77, 77, 0 }
Runtime:Invalidate()
local invalid, invalidReason = Runtime:InferKnowledge(18499)
assert(not invalid and invalidReason == "Berserker Rage DBC topology is incomplete",
    "divergent patch data must fail closed")

print("ok: exact Berserker Rage incoming-rage window")
