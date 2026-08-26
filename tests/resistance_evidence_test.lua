XelAssist = { Game = {}, Combat = {}, Graph = {} }
XelAssistDB = {}
table.getn = table.getn or function(value)
    local count = 0
    while value and value[count + 1] ~= nil do count = count + 1 end
    return count
end

local calls = { dbc = 0, unit = 0, defense = 0, weapon = 0,
    penetration = 0, geometry = 0, hit = 0, item = 0 }
local targetGuid = {}
GetTime = function() return 10 end
time = function() return 100000 end
UnitExists = function(unit)
    calls.unit = calls.unit + 1
    if unit == "target" then return true, targetGuid end
    if unit == "player" then return true, {} end
    return false, nil
end
UnitLevel = function() return 60 end
UnitIsPlayer = function(unit) return unit == "target" end
UnitDefense = function(unit)
    calls.defense = calls.defense + 1
    assert(unit == "target")
    return 250, 5
end
GetInventoryItemLink = function(unit, slot)
    calls.item = calls.item + 1
    assert(unit == "player" and slot == 18)
    return "|Hitem:111:0:0:0|h[Test Wand]|h"
end

local records = {
    [348] = { school = 2, dmgClass = 1, attributesEx3 = 0,
        attributesEx4 = 0, effect = { 2, 6, 0 },
        effectApplyAuraName = { 0, 3, 0 } },
    [501] = { school = 0, dmgClass = 2, attributesEx3 = 0,
        attributesEx4 = 0, equippedItemClass = 2,
        effect = { 2, 0, 0 }, effectApplyAuraName = { 0, 0, 0 } },
    [719] = { school = 0, dmgClass = 3, attributesEx3 = 0,
        attributesEx4 = 0, equippedItemClass = 2,
        effect = { 2, 0, 0 }, effectApplyAuraName = { 0, 0, 0 } },
}
GetSpellRecField = function(spellId, field)
    calls.dbc = calls.dbc + 1
    local record = records[spellId]
    return record and record[field]
end

local skills = { main = { total = 300, known = true, source = "fixture" },
    off = { total = 300, known = true, source = "fixture" },
    ranged = { total = 300, known = true, source = "fixture" },
    mainToken = "main", offToken = "off", rangedToken = "ranged",
    dualWield = true, dualWieldKnown = true, formWeaponUseKnown = true }
XelAssist.Game.Capabilities = {
    WeaponSkills = function()
        calls.weapon = calls.weapon + 1
        return skills
    end,
    Penetration = function()
        calls.penetration = calls.penetration + 1
        return { spell = 0, armor = 0, known = true }
    end,
    Geometry = function()
        calls.geometry = calls.geometry + 1
        return { behind = false }
    end,
}
XelAssist.Game.HitBonuses = { Snapshot = function()
    calls.hit = calls.hit + 1
    return { melee = 0, ranged = 0, spell = 0,
        equipmentKnown = true, totalKnown = false }
end }
XelAssist.Combat.TargetModifiers = { Active = function() return nil end }

dofile("Combat/Delivery.lua")
dofile("Combat/HitDelivery.lua")
dofile("Combat/ResistanceMath.lua")
dofile("Combat/ResistanceSubmissions.lua")
dofile("Combat/Resistance.lua")
dofile("Combat/TriggeredActions.lua")
dofile("Graph/ResistanceEvidence.lua")

local Resistance = XelAssist.Combat.Resistance
local Evidence = XelAssist.Graph.ResistanceEvidence
local encounter = { instanceType = "none", target = { guid = targetGuid,
    level = 60, isPlayer = true }, targetHarmful = { list = {} } }
local identity = Resistance:Identity("target", encounter)
assert(identity and identity.defenseObserved
    and identity.defenseBase == 250 and identity.defenseModifier == 5,
    "the mutable root must seal hostile-player Defense evidence")

local physical = { name = "Weapon Strike", spellId = 501,
    actor = "player", facts = { kind = "damage", melee = true } }
local hybrid = { name = "Immolate", spellId = 348,
    actor = "player", facts = { kind = "dot", ranged = true } }
local dynamic = { name = "Shoot", spellId = 719,
    actor = "player", facts = { kind = "damage",
        dynamicSchool = "equippedWand", weaponRanged = true } }
assert(Evidence:Attach(physical) and Evidence:Attach(hybrid)
    and Evidence:Attach(dynamic),
    "root resistance evidence must attach to every relevant action")
local source = { name = "Source", spellId = 348, actor = "player",
    facts = { kind = "damage", resultSpellId = 501 } }
Evidence:Attach(source)
local initialResult = XelAssist.Combat.TriggeredActions:ResultAction(source)
assert(Evidence:AttachResult(source, initialResult),
    "triggered result evidence must seal at the same root boundary")
assert(XelAssist.Combat.TriggeredActions:SealResultFacts(
    source, initialResult),
    "triggered result tooltip facts must seal at the root boundary")
Resistance:RememberSpellSchool(719, 6, nil,
    dynamic.resistanceDynamicContext)

local state = { playerLevel = 60, weaponSkills = skills,
    hitBonuses = { melee = 0, ranged = 0, spell = 0,
        equipmentKnown = true, totalKnown = false },
    playerBehindTarget = false,
    targetResistance = { identity = identity,
        live = { [0] = 0, [1] = 0, [2] = 0, [3] = 0,
            [4] = 0, [5] = 0, [6] = 0 },
        liveTrusted = true, liveSource = "sealed fixture",
        observedEpoch = 100000,
        penetration = { spell = 0, armor = 0, known = true } },
    encounter = encounter, actors = { player = { level = 60 },
        pet = { level = 60 } } }

-- Prove the action-local copies, not Resistance's mutable DBC cache, are the
-- graph inputs. Every listed provider becomes fatal after the root boundary.
Resistance.spellMetadata = {}
local baseline = {}
local key, value
for key, value in pairs(calls) do baseline[key] = value end
local function forbidden(name)
    return function() error(name .. " live read during graph search") end
end
GetSpellRecField = forbidden("DBC")
GetTime = forbidden("GetTime")
time = forbidden("time")
UnitExists = forbidden("UnitExists")
UnitLevel = forbidden("UnitLevel")
UnitIsPlayer = forbidden("UnitIsPlayer")
UnitDefense = forbidden("UnitDefense")
GetInventoryItemLink = forbidden("inventory")
XelAssist.Game.Capabilities.WeaponSkills = forbidden("weapon skill")
XelAssist.Game.Capabilities.Penetration = forbidden("penetration")
XelAssist.Game.Capabilities.Geometry = forbidden("geometry")
XelAssist.Game.HitBonuses.Snapshot = forbidden("hit bonus")

local delivered = Resistance:Estimate(
    physical, "target", { school = 0 }, state)
assert(delivered.targetDefenseKnown and delivered.targetDefense == 305,
    "sealed physical delivery must retain maximum-plus-bonus Defense")
local phases = Resistance:Estimate(hybrid, "target",
    { school = 2, directDamage = 40, periodicDamage = 60 }, state)
assert(phases.mode == "hybrid" and table.getn(phases.components) == 2,
    "derived hybrid actions must inherit sealed resistance metadata")
local contextual = Resistance:Estimate(dynamic, "target", {}, state)
assert(contextual.school == 6,
    "dynamic schools must consume the root-captured equipment context")
local result = XelAssist.Combat.TriggeredActions:ResultAction(source)
local resultFacts = XelAssist.Combat.TriggeredActions:EffectFacts(
    source, { cost = 12 })
local resultDelivery = Resistance:Estimate(result, "target", {}, state)
assert(result.spellId == 501 and result.resistanceMetadata.school == 0
    and resultFacts.school == 0 and resultFacts.cost == 12
    and resultDelivery.deliveryModel == "physical",
    "a triggered result must replace rather than inherit source metadata")
local mixed = Resistance:Estimate({ name = "Mixed", actor = "player",
    resistanceMetadataCaptured = true, facts = { kind = "damage",
        damageComponents = {
            { school = 0, mitigation = "armor", weight = 0.6 },
            { school = 2, mitigation = "resistance", weight = 0.4 },
        } } }, "target", {}, state)
assert(mixed.mode == "mixed" and table.getn(mixed.components) == 2,
    "derived component actions must stay inside the sealed evidence boundary")
for key, value in pairs(calls) do
    assert(value == baseline[key], key .. " provider was read after root capture")
end

print("ok: resistance estimates consume only sealed root evidence")
