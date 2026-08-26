XelAssist = { Game = { Player = {} } }
local rows, enchants, itemSpells, durations, counts = {}, {}, {}, {}, {}
local unpackValues = unpack or table.unpack
local weapon = { true,120000,17,7, true,45000,9,323,
    false,0,0,0 }
local function t(a,b,c) return {a or 0,b or 0,c or 0} end
function UnitClass() return "Rogue", "ROGUE" end
function GetSpellRecField(id, field, copied)
    local value=rows[id] and rows[id][field]
    if value==nil then error("missing fixture "..id..":"..field) end
    if copied and type(value)=="table" then return {value[1],value[2],value[3]} end
    return value
end
function GetSpellDuration(id) return durations[id] end
C_Item = {
    GetEnchantInfo=function(id) return enchants[id] end,
    GetItemSpell=function(id) return "Poison", itemSpells[id] end,
    GetItemCount=function(id,bank,uses)
        assert(bank==false and uses==false, "bag stock must exclude bank/uses")
        return counts[id] or 0
    end,
    GetWeaponEnchantInfo=function() return unpackValues(weapon) end,
}
dofile("Game/Player/RoguePoisons.lua")
local P=XelAssist.Game.Player.RoguePoisons
for spellId,spec in pairs(P.RANKS) do
    rows[spellId]={spellFamilyName=8,castingTimeIndex=15,equippedItemClass=2,
        equippedItemSubClassMask=173555,procChance=spec.chance,effect=t(54),
        effectMiscValue=t(spec.enchantId),effectImplicitTargetA=t(1)}
    rows[spec.createSpell]={effect=t(24),effectItemType=t(spec.itemId),
        effectImplicitTargetA=t(1)}
    local aura,effect,amplitude,stacks,lifetime=0,2,0,0,0
    if spec.family~="instant" then
        effect=6; aura=spec.family=="deadly" and 3
            or spec.family=="crippling" and 33 or 65
        amplitude=spec.family=="deadly" and 3000 or 0
        stacks=spec.family=="deadly" and 5 or 0
        lifetime=(spec.duration or 12)*1000
    end
    rows[spec.child]={school=3,dispel=4,stackAmount=stacks,effect=t(effect),
        effectApplyAuraName=t(aura),effectAmplitude=t(amplitude),
        effectImplicitTargetA=t(6),
        effectBasePoints=t(spec.family=="instant" and 18 or 8),
        effectBaseDice=t(1),effectDieSides=t(spec.family=="instant" and 7 or 1),
        effectDicePerLevel=t(),effectRealPointsPerLevel=t()}
    durations[spec.child]=lifetime
    enchants[spec.enchantId]={enchantID=spec.enchantId,spellID=spec.child,
        effects={{type=1,amount=spec.chance,arg=spec.child}}}
    itemSpells[spec.itemId]=spellId; counts[spec.itemId]=spec.rank
end

local root=P:Snapshot()
assert(root.available and root.exact and root.hands.main.active
    and root.hands.main.isPoison and root.hands.main.spellId==2823
    and root.hands.main.childSpellId==2818
    and root.hands.main.remaining==120 and root.hands.main.charges==17,
    "main-hand poison identity, lifetime and charges must be exact")
assert(root.hands.off.active and root.hands.off.isPoison
    and root.hands.off.spellId==8679 and root.hands.off.childSpellId==8680
    and root.hands.off.remaining==45 and root.hands.off.charges==9,
    "off-hand state must remain independent from main hand")
assert(root.stock.available and root.stock.exact
    and root.stock.byItem[2892]==1 and root.stock.bySpell[25351]==5
    and root.stock.byItem[8928]==6,
    "each ordinary poison item stock must be captured exactly")

weapon={false,0,0,0, true,30000,0,999,false,0,0,0}
root=P:Snapshot()
assert(root.available and not root.hands.main.active
    and root.hands.off.active and root.hands.off.isPoison==false
    and root.hands.off.enchantId==999 and root.hands.off.charges==0,
    "empty and non-poison temporary enchants must remain exact")
weapon={true,0,1,7,false,0,0,0,false,0,0,0}
root=P:Snapshot()
assert(not root.available and root.reason=="weapon enchant state incomplete",
    "an active poison with no remaining lifetime must fail closed")
C_Item.GetItemCount=nil; weapon={false,0,0,0,false,0,0,0,false,0,0,0}
root=P:Snapshot()
assert(root.available and root.stock.available==false
    and root.stock.reason=="item count API unavailable",
    "unknown stock must not be manufactured as zero")
print("ok: exact dual-hand Rogue poison state and carried stock")
