table.getn = table.getn or function(value) return #value end
XelAssist = { Game = { Player = {} } }
local token, rows = "DRUID", {}
local function formRow(id, flags, percent, effects, auras, points, misc, triggers)
    return { school=0, category=0, dispel=0, mechanic=0,
        attributes=262160, attributesEx=32768,
        attributesEx2=0, attributesEx3=0, attributesEx4=0,
        stances=0, stancesNot=0, targets=0, casterAuraState=0,
        targetAuraState=0, castingTimeIndex=1, recoveryTime=0,
        categoryRecoveryTime=0, procChance=101, procCharges=0,
        baseLevel=40, spellLevel=40, durationIndex=21,
        powerType=0, manaCost=0, manaCostPerlevel=0,
        manaCostPercentage=percent, rangeIndex=1,
        startRecoveryCategory=133, startRecoveryTime=1500,
        spellFamilyName=7, spellFamilyFlags=flags, effect=effects,
        effectApplyAuraName=auras, effectBasePoints=points,
        effectBaseDice={1,1,1}, effectDieSides={1,1,1},
        effectImplicitTargetA={1,1,1}, effectImplicitTargetB={0,0,0},
        effectMiscValue=misc, effectTriggerSpell=triggers }
end
rows[45705]=formRow(45705,33554432,28,{6,6,6},{36,77,142},{-1,-1,179},{9,17,1},{0,0,0})
rows[51430]=formRow(51430,536870912,22,{6,6,64},{36,77,0},{-1,-1,-1},{31,17,0},{0,0,24907})
rows[1001]={powerType=0,stances=1073741824,stancesNot=0}
rows[1002]={powerType=0,stances=256,stancesNot=0}
rows[1003]={powerType=0,stances=0,stancesNot=1073741824}
rows[1004]={powerType=0,stances=0,stancesNot=0}
UnitClass=function() return "Druid",token end
GetSpellRecField=function(id,field,array)
    local value=rows[id] and rows[id][field]
    if array and type(value)=="table" then return {value[1],value[2],value[3]} end
    return value
end
C_Spell={GetSpellPowerCost=function(id) return {{type=0,cost=id==1001 and 80 or 65}} end}
dofile("Game/Player/DruidCasterForms.lua")
local owner=XelAssist.Game.Player.DruidCasterForms
local moon={playerForm={available=true,formID=31}}
assert(owner:Profile(moon) and owner:Profile(moon).formMask==1073741824)
local facts=owner:CaptureFacts({spellId=1001,actor="player"},{cost=100},moon)
assert(facts.cost==80 and facts.druidCasterFormCostExact
    and facts.druidCasterFormEvidence.formID==31,
    "observed Moonkin must seal engine-effective mana cost")
local blocker,handled=owner:FormBlocker({spellId=1001},moon)
assert(handled and blocker==nil,"exact Moonkin mask must permit the action")
blocker,handled=owner:FormBlocker({spellId=1002},moon)
assert(handled and blocker=="required player form inactive")
blocker,handled=owner:FormBlocker({spellId=1003},moon)
assert(handled and blocker=="current player form excluded")
blocker,handled=owner:FormBlocker({spellId=1004},moon)
assert(not handled and blocker==nil,
    "unmasked action must not inherit tooltip-only family prohibitions")
local tree={playerForm={available=true,formID=9}}
assert(owner:Profile(tree) and owner:Profile(tree).formMask==256)
facts=owner:CaptureFacts({spellId=1002},{cost=90},tree)
assert(facts.cost==65 and facts.druidCasterFormCostExact,
    "observed Tree form must seal engine-effective mana cost")
rows[51430].effectMiscValue={30,17,0};owner:Invalidate()
assert(not owner:Profile(moon),"mutated Moonkin topology must fail closed")
token="MAGE";assert(not owner:Profile(tree),"foreign class must not own Druid form")
print("ok: exact observed Moonkin and Tree form boundaries")
