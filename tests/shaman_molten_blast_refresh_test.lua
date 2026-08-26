table.getn = table.getn or function(values) return #values end
XelAssist = { Game = { Player = {} }, Graph = {} }
local moltenCosts = { [36916] = 65, [36917] = 95, [36918] = 120,
    [36919] = 145, [36920] = 175, [36921] = 210 }
local flameIds = { 8050, 8052, 8053, 10447, 10448, 29228 }
local malformed
function UnitClass() return "Shaman", "SHAMAN" end
function GetSpellRecField(id, field, arrays)
    if moltenCosts[id] then
        local scalars = { spellFamilyName = 11,
            spellFamilyFlags = 562949953421312, school = 2,
            manaCost = moltenCosts[id], rangeIndex = 15,
            startRecoveryCategory = 133, startRecoveryTime = 1500 }
        local triples = { effect = { 2, malformed and 1 or 0, 0 },
            effectImplicitTargetA = { 6, 0, 0 },
            effectTriggerSpell = { 0, 0, 0 } }
        return arrays and triples[field] or scalars[field]
    end
    local index
    for index = 1, table.getn(flameIds) do
        if flameIds[index] == id then
            local scalars = { spellFamilyName = 11,
                spellFamilyFlags = 268435456, school = 2 }
            local triples = { effect = { 2, 6, 0 },
                effectApplyAuraName = { 0, 3, 0 } }
            return arrays and triples[field] or scalars[field]
        end
    end
end
dofile("Game/Player/ShamanMoltenBlast.lua")
local Owner = XelAssist.Game.Player.ShamanMoltenBlast
local id
for id in pairs(moltenCosts) do
    local facts, reason, handled = Owner:InferKnowledge(id)
    assert(handled and not reason and facts and facts.kind == "damage"
        and facts.shamanMoltenBlast and facts.refreshesShamanFlameShock,
        "every registered Molten Blast rank must own the refresh")
end
for _, id in ipairs(flameIds) do
    local facts, reason, handled = Owner:InferKnowledge(id)
    assert(handled and not reason and facts and facts.kind == "dot"
        and facts.shamanFlameShock,
        "every player Flame Shock rank must retain numeric family identity")
end
malformed = true; Owner:Invalidate()
local bad, badReason, badHandled = Owner:InferKnowledge(36916)
assert(not bad and badHandled
    and badReason == "Octo Shaman Flame Shock refresh topology is incomplete",
    "shifted Molten Blast topology must fail closed")
malformed = false; Owner:Invalidate()
local molten = assert(Owner:InferKnowledge(36916))
local flame = assert(Owner:InferKnowledge(8050))

dofile("Graph/ShamanFlameShockRefresh.lua")
local aura = { spellId = 8050, mine = true, duration = 12, remaining = 2,
    periodicNextIn = 1, periodicAction = { facts = flame } }
local state = { auras = { localized = aura }, targetAuras = {} }
local candidate = { action = { spellId = 36916, facts = molten },
    effectDelivery = 1 }
assert(XelAssist.Graph.ShamanFlameShockRefresh:Apply(state, candidate)
    and aura.remaining == 12 and aura.periodicNextIn == 1
    and aura.refreshedByMoltenBlast,
    "Molten Blast must refresh duration without resetting the tick phase")

aura.remaining, candidate.effectDelivery = 2, 0.5
XelAssist.Graph.ShamanFlameShockRefresh:Apply(state, candidate)
assert(aura.remaining == 2,
    "an uncertain Molten Blast delivery must not promise a refresh")
aura.mine, candidate.effectDelivery, aura.remaining = false, 1, 2
XelAssist.Graph.ShamanFlameShockRefresh:Apply(state, candidate)
assert(aura.remaining == 2,
    "Molten Blast must not refresh another Shaman's Flame Shock")

print("ok: exact Molten Blast refreshes owned Flame Shock without tick reset")
