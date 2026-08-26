-- Installed Octowow Spell.dbc and VMaNGOS Spell::TakeAmmo agree that Hunter
-- actions using the ranged attack table consume one carried round. Explicit
-- catalogue entries must not bypass that shared inventory mechanic.
XelAssist = { Combat = {} }
table.getn = table.getn or function(values)
    local count = 0
    while values[count + 1] ~= nil do count = count + 1 end
    return count
end
dofile("Combat/Knowledge.lua")

local expected = {
    "Auto Shot",
    "Steady Shot",
    "Aimed Shot",
    "Arcane Shot",
    "Multi-Shot",
    "Volley",
    "Serpent Sting",
}

local index, name
for index = 1, table.getn(expected) do
    name = expected[index]
    local facts = XelAssist.Combat.Knowledge[name]
    assert(facts and facts.ranged and facts.weaponRanged and facts.ammunition,
        name .. " must use the DBC ranged-attack ammunition path")
end

print("ok: explicit Hunter ranged attacks consume shared ammunition")
