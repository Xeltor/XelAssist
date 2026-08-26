XelAssist = { Game = { Player = {} }, Graph = {} }
table.getn = table.getn or function(value)
    local count = 0
    while value and value[count + 1] ~= nil do count = count + 1 end
    return count
end

local shocks = { 8042, 8044, 8045, 8046, 10412, 10413, 10414,
    8050, 8052, 8053, 10447, 10448, 29228,
    8056, 8058, 10472, 10473 }
local talentRows = {
    [16040] = -334, [16113] = -667, [16114] = -1001,
}
local active, modifierValue = false, 0

function IsPlayerSpell(spellId) return spellId == active end
function GetSpellModifiers(_, operation)
    assert(operation == 11, "Shock cooldown must use the cooldown SpellMod")
    return modifierValue, 0, modifierValue == 0 and 0 or 1
end
function GetSpellRecField(spellId, field, array)
    local isShock = false
    local index
    for index = 1, table.getn(shocks) do
        if shocks[index] == spellId then isShock = true break end
    end
    if isShock then
        if field == "category" then return 19 end
        if field == "categoryRecoveryTime" then return 6000 end
        if field == "spellFamilyName" then return 11 end
    end
    local base = talentRows[spellId]
    if base then
        if field == "spellFamilyName" then return 11 end
        if array and field == "effect" then return { 6, 0, 0 } end
        if array and field == "effectApplyAuraName" then
            return { 107, 0, 0 }
        end
        if array and field == "effectMiscValue" then return { 11, 0, 0 } end
        if array and field == "effectBasePoints" then
            return { base, 0, 0 }
        end
    end
    return nil
end

dofile("Game/Player/ShamanShockCooldown.lua")
local S = XelAssist.Game.Player.ShamanShockCooldown
local talents = {
    { id = false, flat = 0, rank = 0, cooldown = 6 },
    { id = 16040, flat = -333, rank = 1, cooldown = 5.667 },
    { id = 16113, flat = -666, rank = 2, cooldown = 5.334 },
    { id = 16114, flat = -1000, rank = 3, cooldown = 5 },
}
local talent, shock
for talent = 1, table.getn(talents) do
    active, modifierValue = talents[talent].id, talents[talent].flat
    for shock = 1, table.getn(shocks) do
        local facts = S:CaptureFacts({ spellId = shocks[shock] },
            { categoryCooldown = 6, cooldownGroup = 19 })
        assert(facts.shamanShockCooldownExact
            and facts.shamanReverberationRank == talents[talent].rank
            and math.abs(facts.categoryCooldown
                - talents[talent].cooldown) < 0.00001
            and facts.cooldownGroup == 19,
            "every Shock rank must carry its effective shared cooldown")
    end
end

active, modifierValue = 16114, -1000
local saved = GetSpellRecField
GetSpellRecField = function(spellId, field, array)
    if spellId == 8050 and field == "category" then return 18 end
    return saved(spellId, field, array)
end
local malformed = S:CaptureFacts({ spellId = 8050 },
    { categoryCooldown = 6, cooldownGroup = 18 })
assert(not malformed.shamanShockCooldownExact
    and malformed.categoryCooldown == 6,
    "shifted Shock topology must not receive invented talent timing")
GetSpellRecField = saved

modifierValue = -666
local contradictory = S:CaptureFacts({ spellId = 8042 },
    { categoryCooldown = 6, cooldownGroup = 19 })
assert(not contradictory.shamanShockCooldownExact
    and contradictory.categoryCooldown == 6,
    "talent and engine disagreement must retain conservative raw timing")

active, modifierValue = 16113, -666
local effective = S:CaptureFacts({ spellId = 10473 },
    { categoryCooldown = 6, cooldownGroup = 19 })
dofile("Graph/ReadinessEffects.lua")
local out = { time = 10, readyAt = {}, actorReadyAt = {} }
XelAssist.Graph.ReadinessEffects:Apply(out, {
    actionStart = 10, cast = 0, downtime = 0, wait = 0,
    tooltip = effective,
}, { action = { name = "Localized Frost Shock", actor = "player" },
    facts = {} })
assert(math.abs(out.readyAt["group:19"] - 15.334) < 0.00001,
    "future cross-Shock readiness must use effective Reverberation timing")

print("ok: exact Reverberation timing governs every shared Shock cooldown")
