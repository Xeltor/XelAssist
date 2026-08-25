XelAssist = { Game = {}, Combat = {}, Graph = {}, UI = {} }
table.getn = table.getn or function(value)
    local count = 0
    while value[count + 1] ~= nil do count = count + 1 end
    return count
end
dofile("Combat/Knowledge.lua")

local bleedNames = { "Rend", "Rupture", "Rip", "Lacerate" }
local i
for i = 1, table.getn(bleedNames) do
    local facts = XelAssist.Combat.Knowledge[bleedNames[i]]
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
    local facts = XelAssist.Combat.Knowledge[name]
    assert(facts and facts.dynamicSchool == source,
        name .. " must defer school resolution to " .. source)
    assert(facts.school == nil, name .. " must not guess one scalar school")
end

assert(XelAssist.Combat.Knowledge.Shoot.ranged and XelAssist.Combat.Knowledge.Shoot.weaponRanged,
    "Shoot must identify the equipped ranged weapon as its damage source")
assert(XelAssist.Combat.Knowledge.Attack.whiteAttack
    and XelAssist.Combat.Knowledge.Attack.weaponHand == "main"
    and not XelAssist.Combat.Knowledge["Sinister Strike"].whiteAttack,
    "only Attack may opt into the white-swing dual-wield miss penalty")
assert(XelAssist.Combat.Knowledge["Kill Command"].damageActor == "pet",
    "Kill Command damage must be attributed to the pet actor")
local hunter = XelAssist.Combat.Knowledge
local autoShot = hunter["Auto Shot"]
assert(autoShot.kind == "autoRepeat" and autoShot.autoRepeat
    and autoShot.ambient and autoShot.startOnly
    and autoShot.gcd == 0 and autoShot.cast == 0
    and autoShot.spellIds[1] == 75,
    "Auto Shot must start ambient auto-repeat rather than model a damage press")
local mendPet = hunter["Mend Pet"]
assert(mendPet.kind == "petHeal" and mendPet.pet
    and mendPet.fixedTarget == "pet" and mendPet.channel
    and table.getn(mendPet.spellIds) == 7,
    "Mend Pet must remain a fixed-pet channel across verified player ranks")
assert(hunter["Call Pet"].petLifecycle == "call"
    and hunter["Call Pet"].spellIds[1] == 883,
    "Call Pet must retain its verified lifecycle identity")
assert(hunter["Revive Pet"].petLifecycle == "revive"
    and hunter["Revive Pet"].requiresPetState == "dead"
    and hunter["Revive Pet"].fixedTarget == "pet"
    and hunter["Revive Pet"].cast == 10,
    "Revive Pet must require the dead companion and retain its ten-second cast")
assert(hunter["Dismiss Pet"].petLifecycle == "dismiss"
    and hunter["Dismiss Pet"].fixedTarget == "pet"
    and hunter["Dismiss Pet"].cast == 5,
    "Dismiss Pet must retain its fixed companion and five-second cast")
assert(hunter["Feed Pet"].fixedTarget == "pet"
    and hunter["Feed Pet"].itemTarget
    and hunter["Feed Pet"].spellIds[1] == 6991,
    "Feed Pet must retain both its pet recipient and item-target requirement")
assert(hunter["Bestial Wrath"].fixedTarget == "pet"
    and hunter["Bestial Wrath"].triggeredSpellId == 52995
    and hunter["Bestial Wrath"].petCombatEffects[1].duration == 18
    and hunter["Bestial Wrath"].petCombatEffects[2].duration == 8
    and hunter["Bestial Wrath"].petCombatEffects[2].damageMultiplier == 1.4,
    "Bestial Wrath must separate its verified immunity and damage windows")
assert(hunter["Intimidation"].fixedTarget == "pet"
    and hunter["Intimidation"].effectTarget == "target"
    and hunter["Intimidation"].deferredUntilPetMelee
    and hunter["Intimidation"].resultSpellId == 24394
    and hunter["Intimidation"].resultMelee
    and hunter["Intimidation"].petCombatEffects[1].threatMultiplier == 1.5
    and hunter["Intimidation"].triggeredSpellIds[1] == 24394
    and hunter["Intimidation"].triggeredSpellIds[2] == 51556,
    "Intimidation must model its deferred pet-melee control and threat effects")
local killCommand = hunter["Kill Command"]
assert(killCommand.fixedTarget == "pet" and killCommand.effectTarget == "target"
    and killCommand.requiresHunterCritical and killCommand.gcd == 0
    and killCommand.triggeredSpellId == 41828
    and killCommand.petAttackPowerCoefficient == 0.8
    and killCommand.effectMaxRange == 5
    and killCommand.spellIds[1] == 41827,
    "Kill Command must preserve its crit gate and pet-executed triggered damage")
assert(hunter["Rapid Fire"].self and hunter["Rapid Fire"].cooldown
    and hunter["Rapid Fire"].gcd == 0
    and hunter["Rapid Fire"].spellIds[1] == 3045,
    "Rapid Fire must remain the verified off-GCD self buff")
assert(hunter["Baited Shot"] == nil,
    "unverified Baited Shot must not enter explicit Hunter knowledge")
assert(XelAssist.Combat.Knowledge["Noxious Assault"].mixedDamage,
    "Noxious Assault combines weapon hits with dynamically equipped poisons")

local lightning = XelAssist.Combat.Knowledge["Lightning Strike"]
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
