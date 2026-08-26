-- Ordinary Rogue poisons must remain hand-local, delivery-gated and finite.
XelAssist = { Game = { Player = {} }, Graph = {}, Combat = {} }
if not table.getn then
    function table.getn(values)
        local count = 0
        while values[count + 1] ~= nil do count = count + 1 end
        return count
    end
end

local instant = { valid=true, exact=true, family="instant", spellId=8679,
    enchantId=323, child=8680, chance=20, damageAverage=22 }
local deadly = { valid=true, exact=true, family="deadly", spellId=2823,
    enchantId=7, child=2818, chance=30, damagePerStackTick=9,
    duration=12, interval=3, stackCap=5 }
local root = { available=true, exact=true, hands={
    main={available=true,exact=true,hand="main",active=true,isPoison=true,
        remaining=120,charges=2,enchantId=323,profile=instant},
    off={available=true,exact=true,hand="off",active=true,isPoison=true,
        remaining=90,charges=3,enchantId=7,profile=deadly},
} }
XelAssist.Game.Player.RoguePoisons = {
    Snapshot=function() return root end,
    ByChild=function(_, child)
        if child==2818 then return deadly end
    end,
}
XelAssist.Graph.State = {}
XelAssist.Graph.PlayerThreat = {}
XelAssist.Graph.Effects = { Decision=function(_, estimate)
    return estimate.multiplier, estimate.landChance
end }
XelAssist.Combat.Resistance = { Estimate=function(_, action)
    if action.facts.school == 0 then
        return { landChance=.75, multiplier=.60 }
    end
    return { landChance=.80, multiplier=.64 }
end }

dofile("Graph/StackedModifiers.lua")
dofile("Graph/EventAuras.lua")
dofile("Graph/RoguePoisons.lua")
local P = XelAssist.Graph.RoguePoisons

local state = { auras={}, targetAuras={} }
assert(P:Attach(state, "ROGUE") and state.roguePoisons
    and state.roguePoisons.hands.main ~= root.hands.main,
    "dual-hand poison state must attach by value")
local child = {}; assert(P:Copy(state, child)
    and child.roguePoisons.hands.off ~= state.roguePoisons.hands.off,
    "poison state must remain branch-local")

local observedState = { auras={}, targetAuras={ Deadly={ spellId=2818,
    mine=true, stacks=2, remaining=7 } } }
assert(P:Attach(observedState, "ROGUE")
    and observedState.auras["XelAssist:RoguePoison:2818"].expectedStacks==2
    and observedState.auras["XelAssist:RoguePoison:2818"].remaining==7,
    "an exact active owned Deadly aura must keep ticking before another swing")

local directRaw, directAction
local handled, reason = P:ResolveWhite(state, state, "main",
    function(action, _, raw)
        directAction, directRaw = action, raw
        return raw * .64
    end)
assert(handled and not reason and directAction.spellId==8680
    and math.abs(directRaw - 3.3) < .000001
    and math.abs(state.roguePoisons.hands.main.charges - 1.85) < .000001,
    "Instant Poison must follow landed white probability then separate delivery")

handled, reason = P:ResolveWhite(state, state, "off")
local aura = state.auras["XelAssist:RoguePoison:2818"]
assert(handled and not reason and aura and aura.remaining==12
    and aura.periodicInterval==3 and aura.periodicNextIn==3
    and aura.expectedStacks==1 and math.abs(aura.applicationProbability-.18)<.000001
    and math.abs(aura.periodicRawRate-3)<.000001
    and math.abs(state.roguePoisons.hands.off.charges-2.775)<.000001,
    "Deadly Poison must create one conditional stack on its exact tick clock")

aura.remaining, aura.periodicNextIn = 10, 1
handled, reason = P:ResolveWhite(state, state, "off")
aura = state.auras["XelAssist:RoguePoison:2818"]
assert(handled and not reason and aura.expectedStacks > 1
    and table.getn(aura.periodicBranches or {})==1
    and aura.periodicBranches[1].remaining < aura.remaining,
    "a later Deadly proc must retain the failed-refresh clock as a branch")

P:Advance(state, 200)
assert(not state.roguePoisons.hands.main.active
    and not state.roguePoisons.hands.off.active,
    "expired temporary enchants must stop all projected procs")
print("ok: finite dual-hand Rogue poison white-hit consequences")
