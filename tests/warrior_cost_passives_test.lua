XelAssist = { Game={Player={}}, Graph={} }
table.getn = table.getn or function(value)
 local count=0
 while value[count+1]~=nil do count=count+1 end
 return count
end

local learned = { [12664]=true, [24431]=true, [53200]=true }
local actionBase = { [78]=150, [1680]=250, [12294]=300, [23881]=300 }
local passive = {
 [12282]={attributes=262608,points=-11},
 [12663]={attributes=262608,points=-21},
 [12664]={attributes=262608,points=-31},
 [24431]={attributes=192,points=-31},
 [53200]={attributes=192,points=-101},
}
local modifiers = {
 [78]={-30,0,4}, [1680]={-30,0,2},
 [12294]={-100,0,1}, [23881]={0,0,0},
}
local charged = { [78]=120, [1680]=220, [12294]=200, [23881]=300 }

function IsPlayerSpell(id) return learned[id]==true end
function GetSpellModifiers(id,operation)
 assert(operation==14); local row=modifiers[id]; return row[1],row[2],row[3]
end
C_Spell = { GetSpellPowerCost=function(id)
 local cost=charged[id]
 return {{type=1,cost=cost,minCost=cost,costPercent=0,costPerSec=0,
   requiredAuraID=0,hasRequiredAura=false}}
end }
function GetSpellRecField(id,field,array)
 local profile=passive[id]
 if array then
  if profile then
   if field=="effect" then return {6,0,0} end
   if field=="effectApplyAuraName" then return {107,0,0} end
   if field=="effectBasePoints" then return {profile.points,0,0} end
   if field=="effectImplicitTargetB" then return {1,0,0} end
   if field=="effectMiscValue" then return {14,0,0} end
  end
  return {0,0,0}
 end
 if profile then
  if field=="attributes" then return profile.attributes end
  if field=="spellFamilyName" then return 4 end
  if field=="procFlags" then return 0 end
 end
 if actionBase[id] then
  if field=="manaCost" then return actionBase[id] end
  if field=="powerType" then return 1 end
  if field=="spellFamilyName" then return 4 end
 end
 return 0
end

dofile("Game/Player/WarriorCostPassives.lua")
dofile("Graph/WarriorCostPassives.lua")
local Runtime=XelAssist.Game.Player.WarriorCostPassives
local Graph=XelAssist.Graph.WarriorCostPassives
local hostile={relation="hostile",unit="target"}
local state={resourceType=1,resource=100,resourceMax=100}
local function capture(id,expected,passiveId)
 local action={spellId=id,facts={kind="damage",melee=true}}
 local facts=Runtime:CaptureFacts(action,action.facts)
 action.facts=facts
 local evidence=Runtime:Evidence(action)
 assert(evidence and facts.cost==expected
   and Graph:Blocker(action,state,hostile,facts)==nil,
   "engine-effective Warrior cost was not sealed")
 return action,facts
end

capture(78,12,12664)
capture(1680,22,24431)
capture(12294,20,53200)
learned[53200]=nil
capture(23881,30,nil)

-- The installed Nampower wrapper leaves the engine's neutral percentage
-- accumulator at 100 when no flat SpellMod exists. A low-level Warrior with
-- no Improved Heroic Strike must still be allowed to spend capped rage.
learned[12664]=nil
modifiers[78]={0,100,0}
charged[78]=150
local baseHeroic=select(1,capture(78,15,nil))
assert(Graph:Blocker(baseHeroic,
 {resourceType=1,resource=44,resourceMax=100},hostile,
 baseHeroic.facts)==nil,
 "neutral Nampower percent baseline must not withhold Heroic Strike")
learned[12664]=true
modifiers[78]={-30,0,4}
charged[78]=120

learned[53200]=true
charged[12294]=210
local badAction={spellId=12294,facts={kind="damage",melee=true}}
local bad=Runtime:CaptureFacts(badAction,badAction.facts)
badAction.facts=bad
assert(Runtime:Evidence(badAction) and bad.cost==21
 and Graph:Blocker(badAction,state,hostile,bad)==nil,
 "the engine-effective helper must outrank a redundant SpellMod reconstruction")

local forged={spellId=78,facts={kind="damage",melee=true,
 warriorCostEvidence={available=true,exact=true,group="heroic",
 actionSpellId=78,baseRaw=150,chargedRaw=50,cost=5,
 passiveLearned=true,passiveSpellId=12664,passiveRank=3,
 modifierFlat=-100,modifierPercent=0}}}
assert(not Runtime:Evidence(forged),"forged rage discounts must be rejected")
print("ok: exact Warrior permanent rage-cost passives")
