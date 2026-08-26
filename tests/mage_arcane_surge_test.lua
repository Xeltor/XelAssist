local function check(value,message) if not value then error(message) end end
XelAssist={Game={Player={}}}
local class,changed="MAGE",nil
function UnitClass() return "Mage",class end
function GetSpellRangeData(index) check(index==4,"wrong range row"); return 0,30 end
local ranks={ [51933]={1,37,32,85,201,43}, [51934]={2,45,40,110,289,60},
    [51935]={3,53,48,140,397,77}, [51936]={4,61,56,170,516,96} }
local common={school=6,attributes=65536,attributesEx=0,attributesEx2=0,
    attributesEx3=512,attributesEx4=513,casterAuraState=13,
    castingTimeIndex=1,recoveryTime=0,categoryRecoveryTime=8000,
    durationIndex=0,powerType=0,rangeIndex=4,startRecoveryCategory=133,
    startRecoveryTime=1500,spellFamilyName=3,spellFamilyFlags=0,
    spellFamilyFlags2=1,dmgClass=1,preventionType=1}
function GetSpellRecField(id,field,array)
    local rank=ranks[id]; if not rank then return nil end
    if changed==field then return 999 end
    if not array then
        if field=="maxLevel" then return rank[2] end
        if field=="baseLevel" or field=="spellLevel" then return rank[3] end
        if field=="manaCost" then return rank[4] end
        return common[field]
    end
    if field=="effect" then return {2,0,0} end
    if field=="effectDieSides" then return {rank[6],0,0} end
    if field=="effectBasePoints" then return {rank[5],0,0} end
    if field=="effectImplicitTargetA" then return {6,0,0} end
    return {0,0,0}
end
dofile("Game/Player/MageArcaneSurge.lua")
local S=XelAssist.Game.Player.MageArcaneSurge
for id,rank in pairs(ranks) do
    local found,reason,handled=S:Classify(id)
    check(found and handled and not reason and found.exact,"rank not classified")
    check(found.rank==rank[1] and found.mana==rank[4]
        and found.minimumDamage==rank[5]+1
        and found.maximumDamage==rank[5]+rank[6]
        and found.casterAuraState==13 and found.ignoresPositiveResistance,
        "Arcane Surge packet shifted")
    local facts=S:InferKnowledge(id)
    check(facts and facts.reactive and facts.ignoreResistances
        and facts.deliveryModel=="magic" and facts.requiresExactUsability,
        "unsafe Arcane Surge inference")
end
S:Invalidate(); changed="attributesEx4"
local found,reason,handled=S:Classify(51933)
check(not found and handled and reason=="Arcane Surge DBC topology is incomplete",
    "resistance-bypass shift must fail closed")
changed=nil; S:Invalidate(); class="WARLOCK"
local _,_,claimed=S:InferKnowledge(51933)
check(claimed==false,"non-Mage identity claimed")
print("ok: exact Arcane Surge ranks, resist reaction and bypass packet")
