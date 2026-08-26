XelAssist = { Game = { Player = {} }, Graph = {} }
local rows = {
    [45958] = { attributes=327680,procFlags=680,procChance=101,
        procCharges=0,durationIndex=21,spellFamilyName=4,effect={6,6,0},
        effectBasePoints={100,64,0},effectImplicitTargetB={1,1,0},
        effectApplyAuraName={109,43,0},effectTriggerSpell={45959,0,0} },
    [45959] = { attributes=327680,procFlags=680,procChance=100,
        procCharges=1,durationIndex=328,spellFamilyName=10,effect={6,6,0},
        effectBasePoints={49,0,0},effectImplicitTargetB={1,1,0},
        effectApplyAuraName={150,42,0},effectTriggerSpell={0,45962,0} },
    [45962] = { attributes=327680,procFlags=87380,procChance=100,
        procCharges=1,durationIndex=7,spellFamilyName=4,effect={6,0,0},
        effectBasePoints={149,0,0},effectImplicitTargetB={1,1,0},
        effectApplyAuraName={108,0,0},effectMiscValue={8,0,0} },
}
GetSpellRecField = function(id, field) return rows[id] and rows[id][field] end
UnitClass = function() return "Warrior", "WARRIOR" end
IsPlayerSpell = function(id) return id == 45958 end
GetSpellDuration = function(id) return id == 45959 and 250 or 5000 end

dofile("Game/Player/WarriorShieldMastery.lua")
dofile("Graph/WarriorShieldBlock.lua")
local Runtime = XelAssist.Game.Player.WarriorShieldMastery
local Graph = XelAssist.Graph.WarriorShieldBlock
local blockFacts = Runtime:CaptureFacts({ spellId=2565 }, {
    warriorShieldBlock=true, warriorShieldBlockEvidence={ exact=true,
        spellId=2565,charges=1,duration=5,blockChanceBonus=75,cost=10 } })
local revengeFacts = Runtime:CaptureFacts({ spellId=6572 }, {
    kind="damage",warriorRevengeThreat=true })
assert(blockFacts.warriorShieldMasteryEvidence.learned
    and revengeFacts.warriorShieldMasteryEvidence.learned,
    "root ownership must seal both Shield Block and Revenge consumers")

local state = { time=0,resourceType=1,resource=20,playerResourceExact=true,
    playerForm={available=true,formID=18},inventory={offHand={
        classificationKnown=true,classID=4,subClassID=6,broken=false}},
    hostileSwings={playerDefense={exact=true,selectedKey="enemy",
        selectedBehindPlayer=false,blockChance=5},lanes={{phaseKnown=true,
        victimKind="player",attackerKey="enemy",interval=2,nextSwingIn=1,
        expectedDamage=30,blockLowerBound=20,blockSamples=2}}} }
local tooltip, reason = Graph:Prepare({ spellId=2565,facts=blockFacts },
    state,{cost=10})
assert(tooltip and not reason)
local score = {state=state,wait=0,cast=0}
assert(Graph:Score(score,tooltip))
assert(Graph:Apply(state,{tooltip=tooltip,
    shieldBlockPrevention=score.shieldBlockPrevention}))
local left = Graph:AdjustProjectedSwing(state,
    {attackerKey="enemy",victimKind="player"},30)
assert(math.abs(left-7)<0.000001
    and math.abs(state.warriorShieldMastery.riposteProbability-0.8)<0.000001,
    "first-block probability must add bounded block value and arm Riposte")

local revenge = { state=state,action={spellId=6572,facts=revengeFacts},
    expectedPower=100,wait=0,cast=0 }
assert(Graph:AdjustRevenge(revenge)
    and math.abs(revenge.expectedPower-220)<0.000001,
    "Riposte must multiply Revenge only across its active probability")
assert(Graph:ConsumeRevenge(state,{effectDelivery=0.5,
    warriorShieldMasteryConsumption=revenge.warriorShieldMasteryConsumption})
    and math.abs(state.warriorShieldMastery.riposteProbability-0.4)<0.000001,
    "only delivered Revenge probability may consume Riposte")
Graph:Advance(state,5)
assert(state.warriorShieldMastery.riposteProbability==0,
    "Riposte must expire branch-locally after five seconds")

rows[45962].effectBasePoints={148,0,0}
local shifted=Runtime:CaptureFacts({spellId=6572},{warriorRevengeThreat=true})
assert(shifted.warriorShieldMasteryEvidence.exact==false,
    "forged linked topology must fail closed")
print("ok: exact Shield Mastery first-block and Riposte consequences")
