XelAssist = { Game = { Player = {} } }
local rows, enchants, itemSpells, durations = {}, {}, {}, {}
local function t(a,b,c) return {a or 0,b or 0,c or 0} end
function UnitClass() return "Rogue", "ROGUE" end
function GetSpellRecField(id, field, copied)
    local value = rows[id] and rows[id][field]
    if value == nil then error("missing fixture "..id..":"..field) end
    if copied and type(value)=="table" then return {value[1],value[2],value[3]} end
    return value
end
function GetSpellDuration(id) return assert(durations[id], "duration fixture") end
C_Item = {
    GetEnchantInfo=function(id) return enchants[id] end,
    GetItemSpell=function(id) return "Poison", itemSpells[id] end,
}
dofile("Game/Player/RoguePoisons.lua")
local P = XelAssist.Game.Player.RoguePoisons
for spellId, spec in pairs(P.RANKS) do
    rows[spellId] = { spellFamilyName=8, castingTimeIndex=15,
        equippedItemClass=2, equippedItemSubClassMask=173555,
        procChance=spec.chance, effect=t(54),
        effectMiscValue=t(spec.enchantId), effectImplicitTargetA=t(1) }
    rows[spec.createSpell] = { effect=t(24), effectItemType=t(spec.itemId),
        effectImplicitTargetA=t(1) }
    local aura, effect, amplitude, stacks, lifetime = 0, 2, 0, 0, 0
    if spec.family ~= "instant" then
        effect = 6
        aura = spec.family=="deadly" and 3
            or spec.family=="crippling" and 33 or 65
        amplitude = spec.family=="deadly" and 3000 or 0
        stacks = spec.family=="deadly" and 5 or 0
        lifetime = (spec.duration or 12) * 1000
    end
    rows[spec.child] = { school=3, dispel=4, stackAmount=stacks,
        effect=t(effect), effectApplyAuraName=t(aura),
        effectAmplitude=t(amplitude), effectImplicitTargetA=t(6),
        effectBasePoints=t(spec.family=="instant" and 18 or 8),
        effectBaseDice=t(1), effectDieSides=t(spec.family=="instant" and 7 or 1),
        effectDicePerLevel=t(), effectRealPointsPerLevel=t() }
    durations[spec.child] = lifetime
    enchants[spec.enchantId] = { enchantID=spec.enchantId,
        spellID=spec.child, effects={ {type=1,amount=spec.chance,arg=spec.child} } }
    itemSpells[spec.itemId] = spellId
end

local count, spellId = 0, nil
for spellId in pairs(P.RANKS) do
    local found, reason, recognized = P:Profile(spellId)
    assert(found and not reason and recognized and found.valid and found.exact
        and found.spellId==spellId and found.itemId and found.child
        and found.source=="installed Octo spell, item and enchant topology")
    if found.family=="instant" then
        assert(found.damageMin==19 and found.damageMax==25
            and found.damageAverage==22, "Instant power must be topology-sealed")
    elseif found.family=="deadly" then
        assert(found.damagePerStackTick==9 and found.duration==12
            and found.interval==3 and found.stackCap==5,
            "Deadly per-stack tick clock must be topology-sealed")
    end
    assert(P:ByEnchant(found.enchantId).spellId == spellId)
    assert(P:ByChild(found.child).spellId == spellId)
    count = count + 1
end
assert(count==16, "all ordinary Deadly/Instant/Crippling/Mind-numbing ranks")
local unknown, reason, recognized = P:Profile(45612)
assert(not unknown and reason=="not an ordinary Rogue poison" and not recognized,
    "custom/private poisons must remain outside the ordinary owner")

enchants[323].effects[1].amount = 21; P:Invalidate()
local shifted, shiftedReason = P:Profile(8679)
assert(not shifted and shiftedReason=="ordinary Rogue poison topology unavailable",
    "enchant proc chance drift must fail closed")
enchants[323].effects[1].amount = 20; P:Invalidate()
itemSpells[6947] = 2823
shifted, shiftedReason = P:Profile(8679)
assert(not shifted and shiftedReason=="ordinary Rogue poison topology unavailable",
    "item-to-parent drift must fail closed")
itemSpells[6947]=8679; rows[8680].effectDieSides[1]=8; P:Invalidate()
shifted, shiftedReason=P:Profile(8679)
assert(not shifted or shifted.damageMax~=25,
    "Instant damage topology drift must never retain the old packet")
print("ok: exact ordinary Rogue poison parent/enchant/child/item topology")
