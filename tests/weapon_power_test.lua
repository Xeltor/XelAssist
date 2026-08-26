XelAssist = { Game = {} }

local mainItem, rangedItem = 100, 200
local records = {
    [100] = { inventoryType = 13, subclass = 15 },
    [101] = { inventoryType = 13, subclass = 7 },
    [102] = { inventoryType = 17, subclass = 8 },
    [200] = { inventoryType = 15, subclass = 2 },
}

GetInventoryItemLink = function(_, slot)
    local item = slot == 18 and rangedItem or mainItem
    return "|Hitem:" .. tostring(item) .. ":0:0:0|h[Test]|h"
end
GetItemStatsField = function(item, field)
    return records[item] and records[item][field]
end
UnitDamage = function()
    return 50, 70, 0, 0, 0, 0, 1.2
end
UnitRangedDamage = function()
    return 3, 80, 100, 0, 0, 1.1
end
UnitAttackPower = function() return 140, 0, 0 end
UnitRangedAttackPower = function() return 280, 0, 0 end
UnitAttackSpeed = function() return 2.5 end
GetUnitField = function(_, field)
    local values = { baseAttackTime = 2500, rangedAttackTime = 3000,
        attackPower = 140, attackPowerMods = 0, rangedAttackPower = 280,
        rangedAttackPowerMods = 0, attackPowerMultiplier = 0,
        rangedAttackPowerMultiplier = 0 }
    return values[field]
end

dofile("Game/WeaponPower.lua")
local W = XelAssist.Game.WeaponPower
local melee = { facts = { melee = true } }
local ranged = { facts = { ranged = true } }
local normalized = { weaponNormalized = true, school = 0 }
local daggerMastery = false
IsPlayerSpell = function(spellId)
    return spellId == 45591 and daggerMastery
end

local function close(actual, expected, message)
    assert(math.abs(actual - expected) < 0.0001,
        message .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
end

local power, evidence = W:Basis(melee, normalized)
close(power, 50.4, "dagger normalization")
assert(evidence.exact and evidence.normalizedSpeed == 1.7,
    "dagger basis must be exact from live damage, AP, time and item type")

daggerMastery = true
power, evidence = W:Basis(melee, normalized)
close(power, 57.6, "Dagger Mastery normalization")
assert(evidence.exact and evidence.normalizedSpeed == 2.3
    and evidence.source == "live UnitDamage; Dagger Mastery normalized speed",
    "known patch-5 Dagger Mastery must replace the dagger normalization lane")
daggerMastery = false

mainItem = 101
power, evidence = W:Basis(melee, normalized)
close(power, 58.8, "one-handed normalization")
assert(evidence.normalizedSpeed == 2.4, "one-handed normalized speed missing")

mainItem = 102
GetUnitField = function(_, field)
    local values = { baseAttackTime = 3800, rangedAttackTime = 3000,
        attackPower = 140, attackPowerMods = 0, rangedAttackPower = 280,
        rangedAttackPowerMods = 0, attackPowerMultiplier = 0,
        rangedAttackPowerMultiplier = 0 }
    return values[field]
end
power, evidence = W:Basis(melee, normalized)
close(power, 54, "two-handed normalization")
assert(evidence.normalizedSpeed == 3.3, "two-handed normalized speed missing")

power, evidence = W:Basis(ranged, normalized)
close(power, 85.6, "ranged normalization")
assert(evidence.exact and evidence.normalizedSpeed == 2.8,
    "ranged normalized speed missing")

power, evidence = W:Basis(melee, { weaponNormalized = false, school = 0 })
assert(power == 60 and evidence.exact and not evidence.normalized,
    "ordinary weapon effects must retain live character-sheet damage")

GetUnitField = function(_, field)
    if field == "baseAttackTime" then return 3800 end
    return nil
end
power, evidence = W:Basis(melee, normalized)
close(power, 54, "normalization with multiplier uncertainty")
assert(not evidence.exact and evidence.gap == "exact attack power",
    "missing exact AP fields must remain explicit")

print("ok: live ordinary and normalized melee/ranged weapon power evidence")
