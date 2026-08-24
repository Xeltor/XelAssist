table.getn = table.getn or function(value)
    local count = 0
    while value[count + 1] ~= nil do count = count + 1 end
    return count
end
dofile("XelAssist_Actions.lua")

local bleedNames = { "Rend", "Rupture", "Rip", "Lacerate" }
local i
for i = 1, table.getn(bleedNames) do
    local facts = XelAssistKnowledge[bleedNames[i]]
    assert(facts and facts.bleed and facts.ignoresArmor,
        bleedNames[i] .. " must remain Physical-school damage that ignores Armor")
end

local dynamic = {
    Shoot = "equippedWand",
    Judgement = "activeSeal",
    ["Kill Command"] = "petResult",
    ["Noxious Assault"] = "weaponsAndPoisons",
    ["Lightning Strike"] = "damageComponents",
}
local name, source
for name, source in pairs(dynamic) do
    local facts = XelAssistKnowledge[name]
    assert(facts and facts.dynamicSchool == source,
        name .. " must defer school resolution to " .. source)
    assert(facts.school == nil, name .. " must not guess one scalar school")
end

assert(XelAssistKnowledge.Shoot.ranged and XelAssistKnowledge.Shoot.weaponRanged,
    "Shoot must identify the equipped ranged weapon as its damage source")
assert(XelAssistKnowledge.Attack.whiteAttack
    and XelAssistKnowledge.Attack.weaponHand == "main"
    and not XelAssistKnowledge["Sinister Strike"].whiteAttack,
    "only Attack may opt into the white-swing dual-wield miss penalty")
assert(XelAssistKnowledge["Kill Command"].damageActor == "pet",
    "Kill Command damage must be attributed to the pet actor")
assert(XelAssistKnowledge["Noxious Assault"].mixedDamage,
    "Noxious Assault combines weapon hits with dynamically equipped poisons")

local lightning = XelAssistKnowledge["Lightning Strike"]
assert(lightning.mixedDamage and table.getn(lightning.damageComponents) == 2,
    "Lightning Strike must retain both documented damage components")
assert(lightning.damageComponents[1].school == 0
    and lightning.damageComponents[1].schoolMask == 1
    and lightning.damageComponents[1].mitigation == "armor"
    and lightning.damageComponents[1].weaponMultiplier == 0.60,
    "Lightning Strike physical component changed")
assert(lightning.damageComponents[2].school == 3
    and lightning.damageComponents[2].schoolMask == 8
    and lightning.damageComponents[2].mitigation == "resistance"
    and lightning.damageComponents[2].weaponMultiplier == 0.20,
    "Lightning Strike Nature component changed")

print("ok: explicit bleed, dynamic-school and mixed-damage action semantics")
