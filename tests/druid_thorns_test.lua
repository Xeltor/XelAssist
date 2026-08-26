-- Thorns must earn value only from exact player-directed hostile white rounds,
-- and each projected eligible round retaliates once against its exact attacker.
XelAssist = { Game = { Player = {} }, Graph = {}, Combat = {} }
math.huge = math.huge or 1 / 0
table.getn = table.getn or function(value) return #value end

local rank = { school=3,dispel=1,attributes=65536,attributesEx2=524288,
    stances=1073741824,castingTimeIndex=8,auraInterruptFlags=101,
    durationIndex=6,powerType=0,manaCost=35,rangeIndex=4,
    spellFamilyName=7,spellFamilyFlags=256,startRecoveryCategory=133,
    startRecoveryTime=1500,effect={6,0,0},effectBasePoints={2,0,0},
    effectImplicitTargetA={21,0,0},effectApplyAuraName={15,0,0} }
local improved = { attributes=448,durationIndex=21,spellFamilyName=7,
    effect={6,6,0},effectBasePoints={99,99,0},
    effectImplicitTargetA={1,1,0},effectApplyAuraName={108,108,0},
    effectMiscValue={1,8,0} }

function UnitClass() return "Druid", "DRUID" end
function GetSpellRecField(id, field)
    local source = id == 52354 and improved or id == 467 and rank or nil
    return source and source[field] or nil
end
function GetSpellDuration(id) return id == 467 and 600000 or nil end
function GetSpellModifiers(_, operation)
    if operation == 1 or operation == 8 then return 0, 0, 0 end
end
function IsPlayerSpell(id) return id == 467 end
C_Spell = { GetSpellPowerCost = function(id)
    return id == 467 and { { type=0, cost=35 } } or nil
end }
C_UnitAuras = { GetPlayerAuraBySpellID = function() return nil end }
function GetTime() return 100 end

dofile("Game/Player/DruidThorns.lua")
local Runtime = XelAssist.Game.Player.DruidThorns
local inferred, reason, handled = Runtime:InferKnowledge(467)
assert(handled and not reason and inferred.druidThorns == true,
    "installed Thorns must be class-owned")
local captured = Runtime:CaptureFacts({ facts=inferred }, inferred)
assert(captured.druidThornsEvidence.damage == 3
    and captured.druidThornsEvidence.duration == 600
    and captured.cost == 35,
    "root capture must seal effective Thorns damage, duration, and cost")
local snapshot = Runtime:Snapshot("DRUID")
assert(snapshot.available and snapshot.exact and not snapshot.active
    and snapshot.profile.spellId == 467,
    "learned rank and live self aura must be exact")

XelAssist.Combat.Resistance = { Estimate = function()
    return { exact=true, decisionMultiplier=0.8 }
end }
XelAssist.Graph.Effects = { Decision = function(_, estimate)
    return estimate.decisionMultiplier
end }
XelAssist.Graph.IncomingConsequences = { ApplyResolvedDamage = function(_, state,
    guid, amount)
    local hostile = state.hostiles.byKey[guid]
    if not hostile then return nil end
    local effective = math.min(hostile.health, amount)
    hostile.health = hostile.health - effective
    state.targetHealth = hostile.health
    return { effective=effective }
end }
dofile("Graph/DruidThorns.lua")
local Graph = XelAssist.Graph.DruidThorns
local state = { time=0,targetHealth=100,targetHealthExact=true,
    targetSurvival={available=true,lowerTimeToDie=5,upperTimeToDie=5},
    actors={player={guid="player",health=100,healthMax=100,healthExact=true}},
    hostiles={selectedKey="enemy",order={"enemy"},byKey={
        enemy={guid="enemy",health=100,healthMax=100,healthExact=true} }},
    hostileSwings={lanes={{phaseKnown=true,attackerGuid="enemy",
        attackerKey="enemy",victimGuid="player",victimKind="player",
        interval=2,nextSwingIn=0.5,retaliationProbability=0.5}}} }
assert(Graph:Attach(state,"DRUID"), "root Thorns state must attach")
local projection, blocker = Graph:Prepare({facts=captured},state,
    {unit="player",relation="self",guid="player"},captured)
assert(projection and not blocker, "inactive self Thorns must be legal")
local context = {state=state,wait=0,cast=1.5,downtime=1.5}
assert(Graph:Score(context,projection)
    and math.abs(context.expectedPower-2.4)<0.0001 and context.value>0,
    "two bounded half-probability rounds must earn resisted retaliation")
local candidate = {classMechanicProjection=projection}
assert(Graph:Apply(state,candidate) and state.druidThorns.active,
    "chosen Thorns must create a branch-local aura")
local event={kind="hostileWhiteSwing",attackerGuid="enemy",attackerKey="enemy",
    victimGuid="player",victimKind="player",retaliationProbability=0.5}
assert(Graph:ApplyRetaliation(state,event)
    and math.abs(state.targetHealth-98.8)<0.0001,
    "one eligible round must retaliate once against the exact attacker")
assert(Graph:Advance(state,600) and not state.druidThorns.active,
    "projected Thorns must expire")

IsPlayerSpell = function(id) return id == 467 or id == 52354 end
GetSpellModifiers = function(_, operation)
    if operation == 1 or operation == 8 then return 0, 100, 1 end
end
GetSpellDuration = function(id, base)
    return id == 467 and (base and 600000 or 1200000) or nil
end
Runtime:Invalidate()
local improvedFacts = Runtime:InferKnowledge(467)
improvedFacts = Runtime:CaptureFacts({facts=improvedFacts},improvedFacts)
assert(improvedFacts.druidThornsEvidence.improved == true
    and improvedFacts.druidThornsEvidence.damage == 6
    and improvedFacts.druidThornsEvidence.duration == 1200,
    "Improved Thorns must double both installed damage and duration")

GetSpellRecField = function(id,field)
    if id == 467 and field == "effectBasePoints" then return {3,0,0} end
    local source = id == 52354 and improved or id == 467 and rank or nil
    return source and source[field] or nil
end
Runtime:Invalidate()
local invalid, invalidReason = Runtime:InferKnowledge(467)
assert(not invalid and invalidReason == "Thorns DBC topology is incomplete",
    "shifted installed topology must fail closed")
print("ok: exact Druid Thorns retaliation and Improved Thorns boundary")
