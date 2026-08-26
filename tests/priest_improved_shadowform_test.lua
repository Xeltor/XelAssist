table.getn = table.getn or function(value) return #value end
XelAssist = { Game = { Player = {}, Capabilities = {} } }

local aura, learned, rows = true, true, {}
rows[45553] = { school=0, attributes=80, attributesEx=0, attributesEx2=0,
    attributesEx3=0, attributesEx4=0, stances=134217728, durationIndex=21,
    powerType=0, manaCost=0, manaCostPercentage=0, rangeIndex=1,
    spellFamilyName=6, spellFamilyFlags=0,
    effect={6,6,0}, effectApplyAuraName={72,134,0},
    effectBasePoints={-16,14,0}, effectBaseDice={1,1,0},
    effectDieSides={1,1,0}, effectImplicitTargetA={1,1,0},
    effectMiscValue={32,0,0}, effectTriggerSpell={0,0,0} }
rows[589] = { school=5, powerType=0 }
GetSpellRecField = function(id, field, copied)
    local value = rows[id] and rows[id][field]
    if copied and type(value) == "table" then return {value[1],value[2],value[3]} end
    return value
end
UnitGUID = function() return "priest-guid" end
IsPlayerSpell = function(id) return id == 45553 and learned end
C_UnitAuras = { GetUnitAuras = function()
    return aura and {{spellId=45553,isHelpful=true}} or {}
end }
C_Spell = { GetSpellPowerCost = function(id)
    assert(id == 589); return {{type=0,cost=85}} end }

dofile("Game/Player/PriestImprovedShadowform.lua")
local owner = XelAssist.Game.Player.PriestImprovedShadowform
local state = { playerForm={formID=28} }
assert(owner:Attach(state) and state.priestImprovedShadowform.shadowCostPercent == -15
    and state.priestImprovedShadowform.castingManaRegenPercent == 15
    and state.priestImprovedShadowform.castingRegenProjectable == false,
    "exact passive must retain cost and deliberately withheld regen evidence")
local facts = owner:CaptureFacts({spellId=589,actor="player"},{cost=100},state)
assert(facts.cost == 85 and facts.priestImprovedShadowformCostExact,
    "active exact passive must seal the engine-reported Shadow mana cost")
local copied = {}; assert(owner:Copy(state,copied)
    and copied.priestImprovedShadowform ~= state.priestImprovedShadowform)
aura=false; local inactive={playerForm={formID=28}}
assert(not owner:Attach(inactive) and not inactive.priestImprovedShadowform,
    "unobserved passive must fail closed")
rows[45553].effectBasePoints={-15,14,0}; owner:Invalidate(); aura=true
local drift={playerForm={formID=28}}
assert(not owner:Attach(drift), "mutated installed topology must fail closed")
print("ok: exact Improved Shadowform cost and withheld casting regen")
