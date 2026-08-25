XelAssist = { Game = {}, Combat = {}, Graph = {}, UI = {} }
table.getn = table.getn or function(value)
    local count = 0
    while value[count + 1] ~= nil do count = count + 1 end
    return count
end

XelAssistDB = {}
local clock, wallClock = 10, 100000
GetTime = function() return clock end
time = function() return wallClock end

local targetGuid, targetCreature, targetLevel, targetIsPlayer = "target-a", 1725, 60, false
local unitGuids = { player = "player-a", pet = "pet-a" }
UnitExists = function(unit)
    if unit == "target" then return true, targetGuid end
    if unitGuids[unit] then return true, unitGuids[unit] end
    return false, nil
end
UnitCreatureID = function(unit) if unit == "target" then return targetCreature end end
UnitLevel = function(unit)
    if unit == "target" then return targetLevel end
    return 60
end
UnitIsPlayer = function(unit) return unit == "player" or unit == "target" and targetIsPlayer end
local rangedItemLink = "|Hitem:111:0:0:0|h[Test Wand]|h"
GetInventoryItemLink = function(unit, slot)
    if unit == "player" and slot == 18 then return rangedItemLink end
end

local liveValues = { [0] = 5500, [1] = 0, [2] = 150, [3] = 0, [4] = 0, [5] = 0, [6] = 0 }
UnitResistance = function(unit, school)
    if unit ~= "target" then return nil end
    local value = liveValues[school] or 0
    return value, value, 0, 0
end
GetUnitField = function(unit, field)
    if unit == "target" and field == "resistances" then
        return { liveValues[0], liveValues[1], liveValues[2], liveValues[3],
            liveValues[4], liveValues[5], liveValues[6] }
    end
end

local penetration = { spell = 0, armor = 0, known = true }
local liveBehind
local weaponSkills = {
    main = { total = 300, known = true, source = "test main skill" },
    off = { total = 295, known = true, source = "test off skill" },
    ranged = { total = 300, known = true, source = "test ranged skill" },
    unarmed = { total = 280, known = true, source = "test unarmed skill" },
    mainToken = "test-main", offToken = "test-off", rangedToken = "test-ranged",
    dualWield = false, dualWieldKnown = true,
}
XelAssist.Game.Capabilities = { Penetration = function() return penetration end,
    WeaponSkills = function() return weaponSkills end,
    Geometry = function(_, from, to)
        assert((from == "player" or from == "pet") and to == "target")
        return { behind = liveBehind, source = "UnitXP" }
    end }

-- Focused evidence fixtures submit against synthetic target GUIDs. Treat the
-- most recently submitted GUID as selected unless a test replaces these
-- providers explicitly to exercise a target-swap boundary.
local testCurrentTarget = targetGuid
XelAssist.Combat.TargetModifiers = { Active = function() return nil end }
XelAssist.Game.Encounter = { Snapshot = function()
    return { target = { guid = testCurrentTarget } }
end }

local spellRecords = {
    [133] = { school = 2, dmgClass = 1, attributesEx4 = 0,
        effect = { 2, 0, 0 }, effectApplyAuraName = { 0, 0, 0 } },
    [348] = { school = 2, dmgClass = 1, attributesEx4 = 0,
        effect = { 2, 6, 0 }, effectApplyAuraName = { 0, 3, 0 } },
    [116] = { school = 4, dmgClass = 1, attributesEx4 = 0,
        effect = { 2, 6, 0 }, effectApplyAuraName = { 0, 33, 0 } },
    [999] = { school = 5, dmgClass = 1, attributesEx4 = 1,
        effect = { 2, 0, 0 }, effectApplyAuraName = { 0, 0, 0 } },
    [501] = { school = 0, dmgClass = 3, attributesEx4 = 0, equippedItemClass = 2,
        effect = { 2, 0, 0 }, effectApplyAuraName = { 0, 0, 0 } },
    [700] = { school = 0, dmgClass = 2, attributesEx4 = 0, equippedItemClass = 2,
        effect = { 6, 0, 0 }, effectApplyAuraName = { 9, 0, 0 } },
    [701] = { school = 0, dmgClass = 2, attributesEx4 = 1, equippedItemClass = 2,
        effect = { 6, 0, 0 }, effectApplyAuraName = { 9, 0, 0 } },
    [702] = { school = 2, dmgClass = 2, attributesEx4 = 1, equippedItemClass = 2,
        effect = { 2, 0, 0 }, effectApplyAuraName = { 0, 0, 0 } },
    [703] = { school = 0, dmgClass = 2, attributesEx4 = 0, equippedItemClass = 2,
        effect = { 2, 0, 0 }, effectApplyAuraName = { 0, 0, 0 } },
    [704] = { school = 0, dmgClass = 2, attributesEx4 = 0, equippedItemClass = 2,
        effect = { 2, 6, 0 }, effectApplyAuraName = { 0, 3, 0 } },
    [705] = { school = 6, dmgClass = 1, attributesEx3 = 32768, attributesEx4 = 0,
        equippedItemClass = 2,
        effect = { 2, 0, 0 }, effectApplyAuraName = { 0, 0, 0 } },
    [706] = { school = 3, dmgClass = 1, attributesEx3 = 262144, attributesEx4 = 0,
        effect = { 2, 0, 0 }, effectApplyAuraName = { 0, 0, 0 } },
    [707] = { school = 4, dmgClass = 1, attributesEx3 = 262144, attributesEx4 = 0,
        effect = { 2, 6, 0 }, effectApplyAuraName = { 0, 33, 0 } },
    [709] = { school = 6, dmgClass = 1, attributesEx3 = 16384, attributesEx4 = 0,
        effect = { 2, 0, 0 }, effectApplyAuraName = { 0, 0, 0 } },
    [710] = { school = 0, dmgClass = 2, attributesEx3 = 262144, attributesEx4 = 0,
        equippedItemClass = 2,
        effect = { 2, 0, 0 }, effectApplyAuraName = { 0, 0, 0 } },
    [711] = { school = 5, dmgClass = 1, attributesEx3 = 0, attributesEx4 = 0,
        effect = { 2, 0, 0 }, effectApplyAuraName = { 0, 0, 0 } },
    [712] = { school = 2, dmgClass = 1, attributesEx3 = 0, attributesEx4 = 0,
        effect = { 2, 2, 0 }, effectApplyAuraName = { 0, 0, 0 } },
    [713] = { school = 0, dmgClass = 2, attributesEx3 = 0, attributesEx4 = 0,
        rangeIndex = 3, equippedItemClass = -1,
        effect = { 2, 0, 0 }, effectApplyAuraName = { 0, 0, 0 } },
    [714] = { school = 0, dmgClass = 2, attributesEx3 = 0, attributesEx4 = 0,
        equippedItemClass = -1,
        effect = { 2, 0, 0 }, effectApplyAuraName = { 0, 0, 0 } },
    [715] = { school = 0, attributesEx3 = 0, attributesEx4 = 0,
        effect = { 2, 0, 0 }, effectApplyAuraName = { 0, 0, 0 } },
    [716] = { school = 3, dmgClass = 1, attributesEx3 = 0, attributesEx4 = 0,
        effect = { 2, 0, 0 }, effectApplyAuraName = { 0, 0, 0 } },
    [717] = { school = 0, dmgClass = 1, attributesEx3 = 0, attributesEx4 = 0,
        effect = { 2, 0, 0 }, effectApplyAuraName = { 0, 0, 0 } },
    [718] = { school = 2, dmgClass = 0, attributesEx3 = 0, attributesEx4 = 0,
        effect = { 2, 0, 0 }, effectApplyAuraName = { 0, 0, 0 } },
    [719] = { school = 0, dmgClass = 3, attributesEx3 = 0, attributesEx4 = 0,
        equippedItemClass = 2,
        effect = { 2, 0, 0 }, effectApplyAuraName = { 0, 0, 0 } },
    [720] = { school = 0, dmgClass = 2, attributesEx3 = 0, attributesEx4 = 0,
        rangeIndex = 2, equippedItemClass = -1,
        effect = { 2, 0, 0 }, effectApplyAuraName = { 0, 0, 0 } },
    [721] = { school = 2, dmgClass = 0, attributesEx3 = 32768, attributesEx4 = 0,
        rangeIndex = 2, equippedItemClass = -1,
        effect = { 2, 0, 0 }, effectApplyAuraName = { 0, 0, 0 } },
    [777] = { school = 5, dmgClass = 1, attributesEx4 = 0,
        effect = { 6, 0, 0 }, effectApplyAuraName = { 22, 0, 0 } },
    [778] = { school = 5, dmgClass = 1, attributesEx4 = 0,
        effect = { 6, 0, 0 }, effectApplyAuraName = { 53, 0, 0 } },
    [20271] = { school = 2, dmgClass = 1, attributesEx4 = 0,
        effect = { 2, 6, 0 }, effectApplyAuraName = { 0, 22, 0 } },
}
GetSpellRecField = function(spellId, field)
    local record = spellRecords[spellId]
    return record and record[field]
end
GetSpellRangeData = function(index)
    if index == 2 then return 0, 5, 0, "noncombat" end
end
GetCVar = function() return "1" end
GetNampowerVersion = function() return 4, 6, 2 end
local activeSealId = 9001
C_UnitAuras = { GetUnitAuras = function(unit, filter)
    if unit == "player" and filter == "HELPFUL" then
        return { { name = "Seal of Flame", spellId = activeSealId } }
    end
    return {}
end }

dofile("Combat/Delivery.lua")
dofile("Combat/HitDelivery.lua")
dofile("Combat/ResistanceSubmissions.lua")
dofile("Combat/Resistance.lua")

local submittedForCurrentTarget = XelAssist.Combat.Resistance.Submitted
function XelAssist.Combat.Resistance:Submitted(action, guid, tooltip, refresh)
    testCurrentTarget = guid
    return submittedForCurrentTarget(self, action, guid, tooltip, refresh)
end

local function encounter()
    return { instanceType = "none", target = { guid = targetGuid, creatureId = targetCreature,
        level = targetLevel, isPlayer = targetIsPlayer }, targetHarmful = { list = {} } }
end
local function close(actual, expected, message)
    assert(math.abs(actual - expected) < 0.0001,
        (message or "values differ") .. ": " .. tostring(actual) .. " vs " .. tostring(expected))
end
local function deliveryByPrefix(profile, prefix)
    local key, record
    for key, record in pairs(profile.deliveryContexts or {}) do
        if string.find(key, prefix, 1, true) == 1 then return record, key end
    end
    return nil, nil
end
local function isolatedState(guid, creatureId, level, values)
    local identity = { guid = guid, creatureId = creatureId, level = level,
        instanceType = "none", isPlayer = false,
        profileKey = "npc:" .. tostring(creatureId) .. ":l" .. tostring(level) .. ":none" }
    XelAssist.Combat.Resistance.identities[guid] = identity
    local profile = XelAssist.Combat.Resistance:Profile(identity, true)
    return profile, { targetResistance = { identity = identity, live = values,
        liveTrusted = true, liveSource = "isolated live fixture",
        penetration = { spell = 0, armor = 0, known = true } },
        playerLevel = 60, encounter = { instanceType = "none", target = identity },
        actors = { pet = { level = 60 } } }
end

local snapshot = XelAssist.Combat.Resistance:Snapshot("target", encounter())
assert(snapshot.liveTrusted and snapshot.live[0] == 5500 and snapshot.live[2] == 150,
    "Turtle UnitResistance vector or 0-based school mapping failed")
local qualifiedIdentity = XelAssist.Combat.Resistance.identities[targetGuid]
assert(string.find(qualifiedIdentity.profileKey, ":none", 1, true),
    "snapshot identity must retain instance context")
assert(XelAssist.Combat.Resistance:RememberUnit("target") == qualifiedIdentity,
    "submission without encounter data must not overwrite qualified identity")
local state = { targetResistance = snapshot, playerLevel = 60, actors = {
    pet = { level = 60 } }, encounter = encounter() }
local action = { name = "Fireball", spellId = 133, actor = "player",
    facts = { kind = "damage", ranged = true } }
local dotAction = { name = "Immolate", spellId = 348, actor = "player",
    facts = { kind = "dot", ranged = true } }
local fire = XelAssist.Combat.Resistance:Estimate(action, "target", { school = 2 }, state)
close(fire.multiplier, 0.6064,
    "150 Fire resistance plus equal-level spell delivery at level 60")
assert(fire.schoolMask == 4 and fire.source == "Turtle UnitResistance target data",
    "school mask or live provenance missing")
local hitState = { targetResistance = snapshot, playerLevel = 60,
    hitBonuses = { melee = 1, ranged = 2, spell = 2,
        equipmentKnown = true, totalKnown = false,
        source = "test equipped hit", gap = "talent and aura +hit" },
    actors = { pet = { level = 60 } }, encounter = encounter() }
local gearedFire = XelAssist.Combat.Resistance:Estimate(
    action, "target", { school = 2 }, hitState)
close(gearedFire.baseHitChance, 0.98,
    "equipped spell hit must improve the ordinary spell-delivery prior")
assert(gearedFire.hitBonus == 2 and gearedFire.equipmentHitKnown
    and not gearedFire.hitBonusKnown
    and string.find(gearedFire.source, "equipped +2% spell hit applied", 1, true),
    "spell delivery must expose applied equipment hit and the remaining gap")
local volatile = XelAssist.Combat.Resistance:Estimate(action, "target",
    { school = 2 }, { targetContextKey = "off-target",
        playerLevel = 60, actors = { pet = { level = 60 } },
        encounter = { instanceType = "none",
            target = { level = 60, isPlayer = false } } })
assert(volatile.targetIdentityUnknown and volatile.unknown
    and volatile.raw == nil
    and volatile.source ~= "Turtle UnitResistance target data",
    "a vanished off-target token must not borrow the live selected profile")
local dotFire = XelAssist.Combat.Resistance:Estimate(dotAction, "target", { school = 2 }, state)
close(dotFire.multiplier, 0.9243,
    "periodic resistance should scale chance before the Vanilla outcome table")
local hybridFire = XelAssist.Combat.Resistance:Estimate(dotAction, "target",
    { school = 2, directDamage = 40, periodicDamage = 60 }, state)
close(hybridFire.multiplier, 0.79714,
    "hybrid damage must weight normal direct and reduced periodic resistance separately")
assert(hybridFire.mode == "hybrid" and hybridFire.components[1].componentPhase == "direct"
    and hybridFire.components[2].componentPhase == "periodic",
    "hybrid resistance components must remain explainable to the graph")
close(hybridFire.landChance, 0.96,
    "hybrid aggregates must expose their one shared application roll")
close(hybridFire.mitigationOnLand, hybridFire.multiplier / 0.96,
    "hybrid landed-hit value must not apply shared delivery twice")
liveValues[2] = 300
snapshot = XelAssist.Combat.Resistance:Snapshot("target", encounter())
state.targetResistance = snapshot
local cappedDot = XelAssist.Combat.Resistance:Estimate(dotAction, "target", { school = 2 }, state)
close(cappedDot.multiplier, 0.8888,
    "periodic mitigation must use one-tenth chance before table interpolation")
liveValues[2] = 150
snapshot = XelAssist.Combat.Resistance:Snapshot("target", encounter())
state.targetResistance = snapshot
state.targetResistance.projectedReduction = { [2] = 50 }
state.targetResistance.projectedBy = "Curse of Elements"
local projectedFire = XelAssist.Combat.Resistance:Estimate(action, "target", { school = 2 }, state)
close(projectedFire.multiplier, 0.72, "projected resistance debuff was not applied")
assert(projectedFire.projectedReduction == 50
    and string.find(projectedFire.source, "projected Curse of Elements", 1, true),
    "projected resistance provenance missing")
liveValues[2] = 50
snapshot = XelAssist.Combat.Resistance:Snapshot("target", encounter())
state.targetResistance = snapshot
state.targetResistance.projectedReduction = { [2] = 100 }
state.targetResistance.projectedBy = "over-reduction control"
local projectedFloor = XelAssist.Combat.Resistance:Estimate(action, "target", { school = 2 }, state)
close(projectedFloor.raw, 0,
    "projected reduction must not flip nonnegative base resistance into vulnerability")
close(projectedFloor.mitigationOnLand, 1,
    "over-reducing positive resistance must stop at zero mitigation")
liveValues[2] = -50
snapshot = XelAssist.Combat.Resistance:Snapshot("target", encounter())
state.targetResistance = snapshot
state.targetResistance.projectedReduction = { [2] = 100 }
state.targetResistance.projectedBy = "negative-resistance control"
local projectedVulnerability = XelAssist.Combat.Resistance:Estimate(action, "target",
    { school = 2 }, state)
close(projectedVulnerability.raw, -150,
    "an already-negative base resistance must retain projected vulnerability")
close(projectedVulnerability.mitigationOnLand, 1.495,
    "projected reduction must deepen an existing vulnerability")
liveValues[2] = 150
snapshot = XelAssist.Combat.Resistance:Snapshot("target", encounter())
state.targetResistance = snapshot
state.targetResistance.projectedReduction, state.targetResistance.projectedBy = nil, nil
local petFire = XelAssist.Combat.Resistance:Estimate(
    { name = "Firebolt", spellId = 348, actor = "pet", facts = { kind = "damage" } },
    "target", { school = 2 }, state)
assert(petFire.penetrationUnknown, "companion penetration must stay explicitly unknown")

liveValues[2] = -50
snapshot = XelAssist.Combat.Resistance:Snapshot("target", encounter())
state.targetResistance = snapshot
local vulnerable = XelAssist.Combat.Resistance:Estimate(action, "target", { school = 2 }, state)
close(vulnerable.multiplier, 1.1170666667,
    "negative target resistance must use the discrete vulnerability table")
targetLevel = 63
snapshot = XelAssist.Combat.Resistance:Snapshot("target", encounter())
state.targetResistance, state.encounter = snapshot, encounter()
local vulnerableHigherTarget = XelAssist.Combat.Resistance:Estimate(action, "target",
    { school = 2 }, state)
close(vulnerableHigherTarget.mitigationOnLand, 1.1636111111,
    "negative resistance must use attacker skill rather than target level")
local vulnerableDot = XelAssist.Combat.Resistance:Estimate(dotAction, "target", { school = 2 }, state)
close(vulnerableDot.multiplier, 0.8415277778,
    "negative resistance must remain vulnerability and use the periodic one-tenth shape")
targetLevel = 60
liveValues[2] = 150

penetration = { spell = 50, armor = 1000, known = true }
snapshot = XelAssist.Combat.Resistance:Snapshot("target", encounter())
state.targetResistance = snapshot
fire = XelAssist.Combat.Resistance:Estimate(action, "target", { school = 2 }, state)
close(fire.multiplier, 0.72, "spell penetration was not subtracted")
local physical = XelAssist.Combat.Resistance:Estimate(
    { name = "Attack", actor = "player", facts = { kind = "damage", school = 0,
        melee = true, whiteAttack = true, weaponHand = "main" } },
    "target", { school = 0 }, state)
close(physical.multiplier, 0.5225,
    "armor mitigation must be combined with the physical delivery prior")
local bleed = XelAssist.Combat.Resistance:Estimate(
    { name = "Rend", actor = "player",
        facts = { kind = "dot", bleed = true, melee = true } },
    "target", { school = 0 }, state)
close(bleed.multiplier, 0.95, "bleeds bypass Armor but still require physical delivery")
assert(bleed.mode == "ignore-armor", "bleeds must bypass Armor")

targetLevel, liveValues[2] = 63, 0
snapshot = XelAssist.Combat.Resistance:Snapshot("target", encounter())
state.targetResistance, state.encounter = snapshot, encounter()
local holy = XelAssist.Combat.Resistance:Estimate(
    { name = "Holy", actor = "player", facts = { kind = "damage", school = 1 } },
    "target", { school = 1 }, state)
local levelFire = XelAssist.Combat.Resistance:Estimate(action, "target", { school = 2 }, state)
close(holy.mitigationOnLand, 0.9391666667,
    "higher-level innate resistance applies to Holy in the Vanilla prior")
close(holy.landChance, 0.83, "higher-level spell delivery prior")
close(levelFire.multiplier, 0.7795083333,
    "higher-level Turtle innate resistance and spell delivery")

targetLevel, liveValues[2], penetration = 60, 150, { spell = 0, armor = 0, known = true }
snapshot = XelAssist.Combat.Resistance:Snapshot("target", encounter())
state.targetResistance, state.encounter = snapshot, encounter()
liveValues[4] = 300
snapshot = XelAssist.Combat.Resistance:Snapshot("target", encounter())
state.targetResistance = snapshot
local binaryFrost = XelAssist.Combat.Resistance:Estimate(
    { name = "Frostbolt", spellId = 116, actor = "player", facts = { kind = "damage" } },
    "target", { school = 4 }, state)
close(binaryFrost.landChance, 0.24,
    "binary positive resistance must reduce delivery linearly after base spell hit")
close(binaryFrost.mitigationOnLand, 1,
    "positive resistance must not partially mitigate landed binary damage")
liveValues[4] = -50
snapshot = XelAssist.Combat.Resistance:Snapshot("target", encounter())
state.targetResistance = snapshot
binaryFrost = XelAssist.Combat.Resistance:Estimate(
    { name = "Frostbolt", spellId = 116, actor = "player", facts = { kind = "damage" } },
    "target", { school = 4 }, state)
close(binaryFrost.landChance, 0.99,
    "binary vulnerability may improve delivery but remains server-capped")
close(binaryFrost.multiplier, 1.151975,
    "binary negative resistance must retain landed-damage vulnerability")
liveValues[4] = 0
snapshot = XelAssist.Combat.Resistance:Snapshot("target", encounter())
state.targetResistance = snapshot

local deliveryProfile, deliveryState = isolatedState("delivery-target", 91001, 60,
    { [0] = 0, [1] = 0, [2] = 0, [3] = 0, [4] = 0, [5] = 0, [6] = 0 })
XelAssist.Combat.Resistance:Submitted(action, "delivery-target")
XelAssist.Combat.Resistance:Miss(133, "delivery-target", 1, "player-a")
local learnedDelivery = XelAssist.Combat.Resistance:Estimate(action, "target", { school = 2 },
    deliveryState)
close(learnedDelivery.landChance, 0.768,
    "one exact miss must update alternate shared/spell estimates only once")
assert(deliveryProfile.deliveryContexts["player:l60:p0:direct"].samples == 1
    and deliveryProfile.spellDeliveryContexts["133:player:l60:p0:direct"].samples == 1,
    "one miss must be retained once in each alternate evidence scope")
local siblingDelivery = XelAssist.Combat.Resistance:Estimate(
    { name = "Unseen Fire Spell", actor = "player", facts = { kind = "damage", school = 2 } },
    "target", { school = 2 }, deliveryState)
close(siblingDelivery.landChance, 0.768,
    "unseen spells should inherit the learned general delivery context")

local physicalAction = { name = "Weapon Strike", spellId = 501, actor = "player",
    facts = { kind = "damage", school = 0 } }
XelAssist.Combat.Resistance:Submitted(physicalAction, "delivery-target")
XelAssist.Combat.Resistance:DamageEvent("delivery-target", "player-a", 501, 50,
    "0,0,0", 0, 0, "2,0,0,0")
local learnedPhysical = XelAssist.Combat.Resistance:Estimate(physicalAction, "target",
    { school = 0 }, deliveryState)
close(learnedPhysical.landChance, 0.96,
    "an exact physical hit must update the physical delivery context")
local rangedDelivery, rangedDeliveryKey = deliveryByPrefix(deliveryProfile,
    "physical-ranged:player:l60:p-:w")
assert(rangedDelivery and rangedDelivery.hits == 1
    and deliveryProfile.deliveryContexts["player:l60:p0:direct"].samples == 1,
    "physical and magical delivery evidence must remain separate")
assert(string.find(rangedDeliveryKey, ":s300:sk1:d300:dk1:u1:wt0:mc1:", 1, true)
    and string.find(rangedDeliveryKey, ":direct", 1, true),
    "physical delivery evidence must include the live skill/defense fingerprint")
local factsOnlyMelee = { name = "Facts-only Melee", spellId = 715, actor = "player",
    facts = { kind = "damage", school = 0, melee = true, usesWeaponSkill = true } }
XelAssist.Combat.Resistance:Submitted(factsOnlyMelee, "delivery-target")
XelAssist.Combat.Resistance:DamageEvent("delivery-target", "player-a", 715, 50,
    "0,0,0", 0, 0, "2,0,0,0")
local factsOnlyEstimate = XelAssist.Combat.Resistance:Estimate(factsOnlyMelee, "target",
    { school = 0 }, deliveryState)
local factsOnlyRecord, factsOnlyKey = deliveryByPrefix(deliveryProfile,
    "physical-melee:player:l60:p-:w")
assert(factsOnlyEstimate.deliverySubtype == "melee" and factsOnlyRecord
    and factsOnlyRecord.hits == 1
    and string.find(factsOnlyKey, ":s300:sk1:d300:dk1:u1:wt0:mc0:", 1, true),
    "delayed outcomes must restore a facts-derived subtype and train Estimate's exact key")
local overrideProfile, overrideState = isolatedState("override-target", 91019, 60,
    { [0] = 0, [1] = 0, [2] = 0, [3] = 0, [4] = 0, [5] = 0, [6] = 0 })
local explicitPhysical = { name = "Elemental Weapon Strike", spellId = 716,
    actor = "player", facts = { kind = "damage", school = 3,
        deliveryModel = "physical", deliverySubtype = "melee", usesWeaponSkill = true } }
XelAssist.Combat.Resistance:Submitted(explicitPhysical, "override-target")
XelAssist.Combat.Resistance:DamageEvent("override-target", "player-a", 716, 50,
    "0,0,0", 0, 3, "2,0,0,0")
local overrideEstimate = XelAssist.Combat.Resistance:Estimate(explicitPhysical, "target",
    { school = 3 }, overrideState)
local overrideDelivery = deliveryByPrefix(overrideProfile,
    "physical-melee:player:l60:p-:w")
assert(overrideEstimate.deliveryModel == "physical" and overrideDelivery
    and overrideDelivery.hits == 1,
    "an explicit physical-delivery override must survive its magic-school DBC row on delayed events")
local physicalSchoolMagic = XelAssist.Combat.Resistance:Estimate(
    { name = "Physical-school Magic Class", spellId = 717, actor = "player",
        facts = { kind = "damage", school = 0, melee = true } },
    "target", { school = 0 }, overrideState)
close(physicalSchoolMagic.landChance, 0.96,
    "a physical-school magic-class spell must use spell delivery, not weapon skill")
assert(physicalSchoolMagic.deliveryModel == "magic"
    and physicalSchoolMagic.deliveryModelKnown and not physicalSchoolMagic.weaponSkill,
    "DBC DmgClass must classify delivery independently from damage school and range hints")
local noneProfile, noneState = isolatedState("none-delivery-target", 91020, 60,
    { [0] = 0, [1] = 0, [2] = 0, [3] = 0, [4] = 0, [5] = 0, [6] = 0 })
local noneAction = { name = "No Ordinary Roll", spellId = 718, actor = "player",
    facts = { kind = "damage" } }
local flaggedNoneFacts = XelAssist.Combat.Resistance:SpellFacts(721)
assert(flaggedNoneFacts.normalRanged and flaggedNoneFacts.deliveryModel == "none"
    and flaggedNoneFacts.deliverySubtype == nil,
    "NORMAL_RANGED may override MAGIC delivery only, never DmgClass NONE")
XelAssist.Combat.Resistance:Submitted(noneAction, "none-delivery-target")
XelAssist.Combat.Resistance:DamageEvent("none-delivery-target", "player-a", 718, 20,
    "0,0,0", 0, 2, "2,0,0,0")
local unseenAfterNone = XelAssist.Combat.Resistance:Estimate(action, "target",
    { school = 2 }, noneState)
assert(unseenAfterNone.deliverySamples == 0
    and not noneProfile.deliveryContexts["player:l60:p0:direct"]
    and not noneProfile.contexts["2:player:l60:p0:direct"].landSamples,
    "DmgClass NONE outcomes may teach mitigation but must not pollute ordinary magic delivery")
local dynamicProfile, dynamicState = isolatedState("dynamic-miss-target", 91021, 60,
    { [0] = 0, [1] = 0, [2] = 0, [3] = 0, [4] = 0, [5] = 0, [6] = 0 })
local savedPenetration = penetration
penetration = { spell = 25, armor = 200, known = true }
local firstWandMiss = { name = "First Wand School", spellId = 719, actor = "player",
    facts = { kind = "damage", dynamicSchool = "equippedWand", weaponRanged = true } }
XelAssist.Combat.Resistance:Submitted(firstWandMiss, "dynamic-miss-target")
assert(XelAssist.Combat.Resistance:Miss(719, "dynamic-miss-target", 1, "player-a") == 0,
    "a first dynamic-school wand miss must remain attributable")
XelAssist.Combat.Resistance:RememberSpellSchool(719, 6, nil,
    XelAssist.Combat.Resistance:DynamicContext("equippedWand"))
local discoveredWand = XelAssist.Combat.Resistance:Estimate(firstWandMiss, "target", {}, dynamicState)
local dynamicDelivery = deliveryByPrefix(dynamicProfile,
    "physical-ranged:player:l60:p-:w")
assert(discoveredWand.school == 6 and discoveredWand.deliverySamples == 1
    and dynamicDelivery and dynamicDelivery.misses == 1,
    "physical delivery evidence must ignore armor/spell penetration so a first wand miss survives school discovery")
penetration = savedPenetration
XelAssist.Combat.Resistance:Submitted(physicalAction, "delivery-target")
XelAssist.Combat.Resistance:Miss(501, "delivery-target", 1, "player-a")
learnedPhysical = XelAssist.Combat.Resistance:Estimate(physicalAction, "target",
    { school = 0 }, deliveryState)
close(learnedPhysical.landChance, 0.8,
    "physical ranged misses must train the same ranged delivery context")
local unseenMelee = XelAssist.Combat.Resistance:Estimate(
    { name = "Unseen Melee", actor = "player",
        facts = { kind = "damage", school = 0, melee = true } },
    "target", { school = 0 }, deliveryState)
close(unseenMelee.landChance, 0.95,
    "ranged hit evidence must not leak into an unseen melee delivery context")

local physicalEffectProfile, physicalEffectState = isolatedState(
    "physical-effect-target", 91007, 60,
    { [0] = 5500, [1] = 0, [2] = 0, [3] = 0, [4] = 0, [5] = 0, [6] = 0 })
local physicalEffect = { name = "Weapon Debuff", spellId = 700, actor = "player",
    facts = { kind = "debuff", melee = true } }
local physicalEffectPrior = XelAssist.Combat.Resistance:Estimate(physicalEffect, "target",
    { school = 0 }, physicalEffectState)
close(physicalEffectPrior.landChance, 0.95,
    "physical target effects must use a conservative weapon-delivery prior")
assert(physicalEffectPrior.mode == "physical-effect"
    and physicalEffectPrior.mitigationOnLand == 1 and physicalEffectPrior.unknown
    and string.find(physicalEffectPrior.deliveryPriorGaps, "active defenses", 1, true),
    "Armor must not apply to a non-damage physical effect, while its incomplete cold landing prior stays visible")
XelAssist.Combat.Resistance:Submitted(physicalEffect, "physical-effect-target")
assert(XelAssist.Combat.Resistance:AuraLanded(
    "physical-effect-target", 700, "player-a") == 0,
    "an owned physical aura must confirm its exact application")
local physicalEffectLanded = XelAssist.Combat.Resistance:Estimate(physicalEffect, "target",
    { school = 0 }, physicalEffectState)
close(physicalEffectLanded.landChance, 0.96,
    "a successful physical aura must train physical delivery")
local physicalShared = deliveryByPrefix(physicalEffectProfile,
    "physical-melee:player:l60:p-:w")
XelAssist.Combat.Resistance:Submitted(physicalEffect, "physical-effect-target")
XelAssist.Combat.Resistance:Miss(700, "physical-effect-target", 2, "player-a")
local physicalEffectResisted = XelAssist.Combat.Resistance:Estimate(physicalEffect, "target",
    { school = 0 }, physicalEffectState)
close(physicalEffectResisted.landChance, 0.8,
    "a physical mechanic resist must train a spell-specific conditional roll")
assert(physicalShared.samples == 1
    and physicalEffectProfile.spells["700:0:player:l60:p0:direct"].resistanceRejects == 1
    and physicalEffectResisted.combinedDeliverySamples == 2,
    "physical mechanic resistance must not contaminate the shared weapon hit table")
local flaggedPhysical = XelAssist.Combat.Resistance:Estimate(
    { name = "Flagged Weapon Debuff", spellId = 701, actor = "player",
        facts = { kind = "debuff", melee = true } },
    "target", { school = 0 }, physicalEffectState)
close(flaggedPhysical.landChance, 0.96,
    "a magic ignore-resistance flag must retain the learned physical hit table")
assert(flaggedPhysical.landChance < 1,
    "a physical ignore-resistance flag must not force certain delivery")
local elementalWeapon = XelAssist.Combat.Resistance:Estimate(
    { name = "Unresistable Fire Strike", spellId = 702, actor = "player",
        facts = { kind = "damage", melee = true } },
    "target", { school = 2 }, physicalEffectState)
close(elementalWeapon.landChance, 0.96,
    "an elemental weapon spell must keep physical delivery")
assert(elementalWeapon.mitigationOnLand == 1
    and elementalWeapon.mode == "physical-delivery-ignore-resistance",
    "the magic ignore-resistance flag must bypass landed resistance, not physical delivery")
local physicalDamageMechanic = { name = "Mechanic Strike", spellId = 703,
    actor = "player", facts = { kind = "damage", melee = true } }
XelAssist.Combat.Resistance:Submitted(physicalDamageMechanic, "physical-effect-target")
XelAssist.Combat.Resistance:Miss(703, "physical-effect-target", 2, "player-a")
local resistedPhysicalDamage = XelAssist.Combat.Resistance:Estimate(
    physicalDamageMechanic, "target", { school = 0 }, physicalEffectState)
close(resistedPhysicalDamage.landChance, 0.768,
    "physical damage must retain its spell-specific mechanic-resist evidence")
close(resistedPhysicalDamage.multiplier, 0.384,
    "physical mechanic delivery and Armor mitigation must each apply exactly once")

do
assert(XelAssist.Combat.Resistance:SpellFacts(501).usesWeaponSkill == true
    and XelAssist.Combat.Resistance:SpellFacts(713).usesWeaponSkill == false,
    "DBC weapon requirements must distinguish actual-skill abilities from level-max attacks")
assert(XelAssist.Combat.Resistance:SpellFacts(720).usesWeaponSkill == true
    and XelAssist.Combat.Resistance:SpellFacts(720).combatRange == true,
    "Combat Range index 2 must use actual weapon skill without consulting range-row flags")
assert(XelAssist.Combat.Resistance:SpellFacts(714).usesWeaponSkill == nil,
    "non-weapon equipment metadata alone must not guess an unavailable range mode")
local skillProfile, skillState = isolatedState("skill-target", 91011, 60,
    { [0] = 0, [1] = 0, [2] = 0, [3] = 0, [4] = 0, [5] = 0, [6] = 0 })
weaponSkills.main.total, weaponSkills.ranged.total = 280, 260
local lowMain = XelAssist.Combat.Resistance:Estimate(
    { name = "Low Main", spellId = 700, actor = "player",
        facts = { kind = "debuff", melee = true } },
    "target", { school = 0 }, skillState)
close(lowMain.landChance, 0.91,
    "a 20-point NPC weapon-skill deficit must add four percentage points of miss")
assert(lowMain.weaponSkill == 280 and lowMain.targetDefense == 300
    and lowMain.weaponSkillKnown and lowMain.targetDefenseKnown
    and lowMain.usesActualWeaponSkill == true
    and lowMain.hitBonusKnown == false
    and string.find(lowMain.source, "equipment +hit", 1, true),
    "physical delivery diagnostics must expose skill, defense, source and excluded +hit")
local ignoredHitProfile, hitSkillState = isolatedState("skill-target-hit", 91012, 60,
    { [0] = 0, [1] = 0, [2] = 0, [3] = 0, [4] = 0, [5] = 0, [6] = 0 })
hitSkillState.hitBonuses = { melee = 2, ranged = 3, spell = 4,
    equipmentKnown = true, totalKnown = false,
    source = "test equipped hit", gap = "talent and aura +hit" }
local gearedMain = XelAssist.Combat.Resistance:Estimate(
    { name = "Geared Main", spellId = 700, actor = "player",
        facts = { kind = "debuff", melee = true } },
    "target", { school = 0 }, hitSkillState)
close(gearedMain.landChance, 0.93,
    "equipped melee hit must offset the skill-versus-defense miss roll")
assert(gearedMain.weaponBaseMissChance == 9 and gearedMain.weaponMissChance == 7
    and gearedMain.hitBonus == 2 and gearedMain.equipmentHitKnown
    and string.find(gearedMain.source, "equipped +2% hit applied", 1, true)
    and string.find(gearedMain.source, "talent and aura +hit excluded", 1, true),
    "physical delivery must partition known equipment hit from unresolved hit")
weaponSkills.main.total = 1
close(XelAssist.Combat.Resistance:Estimate(
    { name = "Untrained Main", spellId = 700, actor = "player",
        facts = { kind = "damage", melee = true } },
    "target", { school = 0 }, skillState).landChance, 0.40,
    "an extremely untrained weapon must honor the server's 60% miss cap")
weaponSkills.main.total = 280
local levelMaxAbility = XelAssist.Combat.Resistance:Estimate(
    { name = "Level-max Physical", spellId = 713, actor = "player",
        facts = { kind = "damage", melee = true } },
    "target", { school = 0 }, skillState)
close(levelMaxAbility.landChance, 0.95,
    "physical abilities without a weapon requirement must use level-max skill")
assert(levelMaxAbility.weaponSkill == 300
    and levelMaxAbility.usesActualWeaponSkill == false,
    "level-max physical delivery provenance missing")
local unresolvedSkillMode = XelAssist.Combat.Resistance:Estimate(
    { name = "Unknown Skill Mode", spellId = 714, actor = "player",
        facts = { kind = "damage", melee = true } },
    "target", { school = 0 }, skillState)
assert(unresolvedSkillMode.usesActualWeaponSkill == nil
    and unresolvedSkillMode.deliveryPriorUnknown and unresolvedSkillMode.unknown,
    "unproven range/weapon mode must remain visibly unknown")

weaponSkills.dualWield = true
local dualWhite = XelAssist.Combat.Resistance:Estimate(
    { name = "Attack", actor = "player", facts = { kind = "damage", school = 0,
        melee = true, whiteAttack = true, weaponHand = "main" } },
    "target", { school = 0 }, skillState)
close(dualWhite.landChance, 0.72,
    "dual-wield white attacks must add 19% after the current skill miss term")
assert(dualWhite.dualWieldWhitePenalty == 19,
    "white dual-wield penalty provenance missing")
local yellowWhileDual = XelAssist.Combat.Resistance:Estimate(
    { name = "Yellow Strike", spellId = 700, actor = "player",
        facts = { kind = "damage", melee = true } },
    "target", { school = 0 }, skillState)
close(yellowWhileDual.landChance, 0.91,
    "dual wield must never add its white-hit penalty to a yellow ability")
local offWhite = XelAssist.Combat.Resistance:Estimate(
    { name = "Off Swing", actor = "player", facts = { kind = "damage", school = 0,
        melee = true, whiteAttack = true, weaponHand = "off" } },
    "target", { school = 0 }, skillState)
close(offWhite.landChance, 0.755,
    "off-hand white delivery must use the off-hand skill and dual penalty")
assert(offWhite.weaponHand == "off" and offWhite.weaponSkill == 295,
    "off-hand skill must remain distinct from main-hand skill")
local offHandSpecial = XelAssist.Combat.Resistance:Estimate(
    { name = "Off-hand Required Special", spellId = 700, actor = "player",
        facts = { kind = "damage", melee = true, weaponHand = "off" } },
    "target", { school = 0 }, skillState)
assert(offHandSpecial.weaponHand == "main" and offHandSpecial.weaponSkill == 280,
    "current vMaNGOS melee-special miss rolls must use BASE_ATTACK even when later processing identifies an off hand")
local ignoredLowLevelProfile, lowLevelState = isolatedState("low-level-target", 91018, 5,
    { [0] = 0, [1] = 0, [2] = 0, [3] = 0, [4] = 0, [5] = 0, [6] = 0 })
weaponSkills.main.total = 25
local lowLevelDual = XelAssist.Combat.Resistance:Estimate(
    { name = "Low-level dual Attack", actor = "player", facts = { kind = "damage",
        school = 0, melee = true, whiteAttack = true, weaponHand = "main" } },
    "target", { school = 0 }, lowLevelState)
close(lowLevelDual.landChance, 0.88,
    "low-level scaling must apply to the complete white dual-wield miss chance")
assert(ignoredLowLevelProfile and lowLevelDual.dualWieldWhitePenalty == 19,
    "low-level white delivery fixture must retain its dual-wield provenance")
weaponSkills.main.total = 280
weaponSkills.dualWield = false

local rangedSkillAction = { name = "Ranged Skill", spellId = 501, actor = "player",
    facts = { kind = "damage", school = 0, weaponRanged = true } }
local lowRanged = XelAssist.Combat.Resistance:Estimate(rangedSkillAction, "target",
    { school = 0 }, skillState)
close(lowRanged.landChance, 0.87,
    "a ranged weapon spell must use current ranged skill")
XelAssist.Combat.Resistance:Submitted(rangedSkillAction, "skill-target")
XelAssist.Combat.Resistance:Miss(501, "skill-target", 1, "player-a")
local learnedLowRanged = XelAssist.Combat.Resistance:Estimate(rangedSkillAction, "target",
    { school = 0 }, skillState)
close(learnedLowRanged.landChance, 0.696,
    "exact ranged miss evidence must update its matching skill context")
weaponSkills.ranged.total = 300
local trainedRanged = XelAssist.Combat.Resistance:Estimate(rangedSkillAction, "target",
    { school = 0 }, skillState)
close(trainedRanged.landChance, 0.95,
    "raising ranged skill must not reuse stale low-skill outcomes")
assert(trainedRanged.deliverySamples == 0,
    "skill fingerprints must partition exact learned outcomes")
weaponSkills.rangedToken = "changed-ranged"
local swappedRanged = XelAssist.Combat.Resistance:Estimate(rangedSkillAction, "target",
    { school = 0 }, skillState)
assert(swappedRanged.deliverySamples == 0,
    "weapon swaps must not reuse another weapon fingerprint")
weaponSkills.rangedToken, weaponSkills.ranged.total = "test-ranged", 260
close(XelAssist.Combat.Resistance:Estimate(rangedSkillAction, "target",
    { school = 0 }, skillState).landChance, 0.696,
    "returning to a skill/weapon fingerprint must preserve its exact outcomes")
weaponSkills.main.total, weaponSkills.ranged.total = 300, 300

local savedTargetGuid = targetGuid
targetGuid = "position-target"
local positionProfile, positionState = isolatedState(targetGuid, 91012, 60,
    { [0] = 0, [1] = 0, [2] = 0, [3] = 0, [4] = 0, [5] = 0, [6] = 0 })
local positionAction = { name = "Position Strike", spellId = 700, actor = "player",
    facts = { kind = "damage", melee = true } }
positionState.playerBehindTarget, liveBehind = false, false
local frontalDelivery = XelAssist.Combat.Resistance:Estimate(positionAction, "target",
    { school = 0 }, positionState)
assert(frontalDelivery.positionKnown and frontalDelivery.attackPosition == "front"
    and frontalDelivery.positionSource == "state UnitXP geometry",
    "state-backed frontal geometry must be visible in delivery diagnostics")
XelAssist.Combat.Resistance:Submitted(positionAction, targetGuid)
XelAssist.Combat.Resistance:Miss(700, targetGuid, 3, "player-a")
close(XelAssist.Combat.Resistance:Estimate(positionAction, "target",
    { school = 0 }, positionState).landChance, 0.76,
    "a frontal dodge must train only the frontal physical delivery context")
positionState.playerBehindTarget, liveBehind = true, true
local behindDelivery = XelAssist.Combat.Resistance:Estimate(positionAction, "target",
    { school = 0 }, positionState)
close(behindDelivery.landChance, 0.95,
    "frontal active-defense evidence must not bias delivery from behind")
assert(behindDelivery.positionKnown and behindDelivery.attackPosition == "behind"
    and behindDelivery.deliverySamples == 0,
    "behind geometry must have an independent exact-outcome fingerprint")
positionState.playerBehindTarget, liveBehind = nil, nil
local unknownPosition = XelAssist.Combat.Resistance:Estimate(positionAction, "target",
    { school = 0 }, positionState)
assert(not unknownPosition.positionKnown and unknownPosition.attackPosition == "unknown"
    and unknownPosition.deliverySamples == 0,
    "unknown melee position must remain a separate evidence context")
targetGuid, liveBehind = savedTargetGuid, nil

-- Nampower's attack-round event teaches genuine white outcomes without
-- inventing Armor mitigation from already-resolved packet damage. Main hand,
-- off hand, pet, and white/yellow tables remain independent fingerprints.
local autoSavedTargetGuid, autoSavedTargetCreature = targetGuid, targetCreature
local autoSavedTargetLevel, autoSavedTargetPlayer = targetLevel, targetIsPlayer
local autoSavedDual = weaponSkills.dualWield
targetGuid, targetCreature, targetLevel, targetIsPlayer =
    "auto-attack-target", 91030, 60, false
liveBehind, weaponSkills.dualWield = false, true
local autoProfile, autoState = isolatedState(targetGuid, targetCreature, targetLevel,
    { [0] = 0, [1] = 0, [2] = 0, [3] = 0, [4] = 0, [5] = 0, [6] = 0 })
autoState.playerBehindTarget = false
local autoHit = XelAssist.Combat.Resistance:AutoAttack(
    "player-a", targetGuid, 50, 0, 1, 1, 0, 0, 0)
local autoPartialBlock = XelAssist.Combat.Resistance:AutoAttack(
    "player-a", targetGuid, 20, 0, 1, 1, 10, 0, 0)
local autoFullBlock = XelAssist.Combat.Resistance:AutoAttack(
    "player-a", targetGuid, 0, 0, 5, 1, 30, 0, 0)
local autoNoAction = XelAssist.Combat.Resistance:AutoAttack(
    "player-a", targetGuid, 20, 65536, 1, 1, 0, 0, 0)
local autoInterruptState = XelAssist.Combat.Resistance:AutoAttack(
    "player-a", targetGuid, 20, 0, 4, 1, 0, 0, 0)
XelAssist.Combat.Resistance:AutoAttack("player-a", targetGuid, 0, 20, 0, 1, 0, 0, 0)
XelAssist.Combat.Resistance:AutoAttack("player-a", targetGuid, 0, 4, 2, 1, 0, 0, 0)
XelAssist.Combat.Resistance:AutoAttack("pet-a", targetGuid, 35, 0, 1, 1, 0, 0, 0)
assert(autoHit.exactDelivery and autoHit.evidence == "hit"
    and autoPartialBlock.evidence == "hit"
    and autoFullBlock.evidence == "ordinary-miss",
    "white hit, partial block, and full block delivery classification failed")
assert(not autoNoAction.exactDelivery and autoNoAction.outcome == "melee spell packet"
    and not autoInterruptState.exactDelivery,
    "melee-spell and undocumented attack packets must not train white evidence")
local autoMainRecord, autoOffRecord, autoPetRecord, autoKey, autoRecord
for autoKey, autoRecord in pairs(autoProfile.deliveryContexts) do
    if string.find(autoKey, "physical-melee:player:l60:p-:wmain", 1, true)
        and string.find(autoKey, ":wt1:", 1, true)
        and string.find(autoKey, ":dw1:", 1, true) then
        autoMainRecord = autoRecord
    elseif string.find(autoKey, "physical-melee:player:l60:p-:woff", 1, true)
        and string.find(autoKey, ":wt1:", 1, true) then
        autoOffRecord = autoRecord
    elseif string.find(autoKey, "physical-melee:pet:l60:p-:wmain", 1, true)
        and string.find(autoKey, ":wt1:", 1, true) then
        autoPetRecord = autoRecord
    end
end
assert(autoMainRecord and autoMainRecord.samples == 3
    and autoMainRecord.hits == 2 and autoMainRecord.misses == 1,
    "main-hand exact white outcomes were not learned once each")
assert(autoOffRecord and autoOffRecord.samples == 2
    and not autoOffRecord.hits and autoOffRecord.misses == 2,
    "LEFTSWING white outcomes must use the off-hand skill context")
assert(autoPetRecord and autoPetRecord.samples == 1 and autoPetRecord.hits == 1,
    "owned-pet white outcomes must train their actor context")
assert(next(autoProfile.contexts) == nil and next(autoProfile.schools) == nil,
    "resolved white damage must never be inverted into school/Armor mitigation evidence")

-- A single-wield white context must still not collide with a yellow special;
-- dual-wield state alone is not a sufficient table discriminator.
weaponSkills.dualWield = false
XelAssist.Combat.Resistance:AutoAttack("player-a", targetGuid, 40, 0, 1, 1, 0, 0, 0)
local singleWhite = XelAssist.Combat.Resistance:Estimate(
    { name = "Attack", actor = "player", facts = { kind = "damage", school = 0,
        melee = true, whiteAttack = true, weaponHand = "main" } },
    "target", { school = 0 }, autoState)
local singleYellow = XelAssist.Combat.Resistance:Estimate(
    { name = "Single-wield Strike", spellId = 700, actor = "player",
        facts = { kind = "damage", melee = true } },
    "target", { school = 0 }, autoState)
assert(singleWhite.deliverySamples == 1 and singleYellow.deliverySamples == 0,
    "white attack-round evidence must not contaminate a single-wield yellow table")

targetGuid, targetCreature, targetLevel, targetIsPlayer = autoSavedTargetGuid,
    autoSavedTargetCreature, autoSavedTargetLevel, autoSavedTargetPlayer
liveBehind, weaponSkills.dualWield = nil, autoSavedDual

local playerSkillProfile, playerSkillState = isolatedState("player-skill-target", nil, 60,
    { [0] = 0, [1] = 0, [2] = 0, [3] = 0, [4] = 0, [5] = 0, [6] = 0 })
playerSkillState.targetResistance.identity.isPlayer = true
playerSkillState.encounter.target.isPlayer = true
local playerDefense = XelAssist.Combat.Resistance:Estimate(
    { name = "PvP Strike", spellId = 700, actor = "player",
        facts = { kind = "damage", melee = true } },
    "target", { school = 0 }, playerSkillState)
close(playerDefense.landChance, 0.95,
    "player-versus-player delivery must retain the victim's level-max Defense prior")
assert(not playerDefense.targetDefenseKnown and playerDefense.targetDefense == 300
    and playerDefense.targetDefenseSource == "PvP defense bonuses unverified",
    "PvP maximum Defense must remain partial until its bonus term is observable")
local savedUnitDefense = UnitDefense
playerSkillState.targetResistance.identity.guid = targetGuid
UnitDefense = function(unit) if unit == "target" then return 250, 5 end end
local bonusedPlayerDefense = XelAssist.Combat.Resistance:Estimate(
    { name = "Bonused PvP Strike", spellId = 700, actor = "player",
        facts = { kind = "damage", melee = true } },
    "target", { school = 0 }, playerSkillState)
close(bonusedPlayerDefense.landChance, 0.948,
    "PvP delivery must add live Defense bonuses to level-max Defense")
assert(bonusedPlayerDefense.targetDefenseKnown
    and bonusedPlayerDefense.targetDefense == 305
    and bonusedPlayerDefense.targetDefenseSource
        == "PvP maximum defense plus live bonuses",
    "PvP maximum-plus-bonus Defense provenance missing")
local ignoredNoLevelProfile, noLevelState = isolatedState(
    "unknown-level-player", nil, nil,
    { [0] = 0, [1] = 0, [2] = 0, [3] = 0, [4] = 0, [5] = 0, [6] = 0 })
noLevelState.targetResistance.identity.isPlayer = true
noLevelState.targetResistance.identity.guid = targetGuid
noLevelState.encounter.target.isPlayer = true
local noLevelPvP = XelAssist.Combat.Resistance:Estimate(
    { name = "Unknown-level PvP Strike", spellId = 700, actor = "player",
        facts = { kind = "damage", melee = true } },
    "target", { school = 0 }, noLevelState)
assert(ignoredNoLevelProfile and not noLevelPvP.targetDefenseKnown
    and noLevelPvP.targetDefense == nil,
    "PvP must never substitute live current Defense when maximum Defense lacks a target level")
UnitDefense = function(unit) if unit == "target" then return 0, 0 end end
local unknownPetDefense = XelAssist.Combat.Resistance:Estimate(
    { name = "Pet PvP Strike", spellId = 700, actor = "pet",
        facts = { kind = "damage", melee = true } },
    "target", { school = 0 }, playerSkillState)
assert(not unknownPetDefense.targetDefenseKnown and unknownPetDefense.deliveryPriorUnknown,
    "a hostile UnitDefense zero sentinel must not prove current Defense for a pet attacker")
UnitDefense = function(unit) if unit == "target" then return 300, 5 end end
local knownPetDefense = XelAssist.Combat.Resistance:Estimate(
    { name = "Pet PvP Strike", spellId = 700, actor = "pet",
        facts = { kind = "damage", melee = true } },
    "target", { school = 0 }, playerSkillState)
close(knownPetDefense.landChance, 0.948,
    "pet-versus-player delivery must use live current Defense and the PvP skill formula")
assert(knownPetDefense.targetDefenseKnown and knownPetDefense.targetDefense == 305,
    "live current player Defense provenance missing for a non-player attacker")
local certaintyProfile, certaintyState = isolatedState(
    "defense-certainty-target", nil, 60,
    { [0] = 0, [1] = 0, [2] = 0, [3] = 0, [4] = 0, [5] = 0, [6] = 0 })
certaintyState.targetResistance.identity.isPlayer = true
certaintyState.encounter.target.isPlayer = true
local certaintyAction = { name = "Defense Certainty Strike", spellId = 700,
    actor = "player", facts = { kind = "damage", melee = true } }
UnitDefense = function(unit) if unit == "target" then return 250, 0 end end
XelAssist.Combat.Resistance:Submitted(certaintyAction, "defense-certainty-target")
XelAssist.Combat.Resistance:DamageEvent("defense-certainty-target", "player-a", 700, 20,
    "0,0,0", 0, 0, "2,0,0,0")
certaintyState.targetResistance.identity.guid = targetGuid
XelAssist.Combat.Resistance:Submitted(certaintyAction, "defense-certainty-target")
XelAssist.Combat.Resistance:DamageEvent("defense-certainty-target", "player-a", 700, 20,
    "0,0,0", 0, 0, "2,0,0,0")
local unknownDefenseRecord, knownDefenseRecord, certaintyKey, certaintyRecord
for certaintyKey, certaintyRecord in pairs(certaintyProfile.deliveryContexts) do
    if string.find(certaintyKey, ":d300:dk0:", 1, true) then
        unknownDefenseRecord = certaintyRecord
    elseif string.find(certaintyKey, ":d300:dk1:", 1, true) then
        knownDefenseRecord = certaintyRecord
    end
end
assert(unknownDefenseRecord and knownDefenseRecord
    and unknownDefenseRecord.hits == 1 and knownDefenseRecord.hits == 1,
    "equal numeric Defense must not pool unverified and API-proven evidence keys")
UnitDefense = savedUnitDefense
end

local binaryProfile, binaryState = isolatedState("binary-target", 91002, 60,
    { [0] = 0, [1] = 0, [2] = 0, [3] = 0, [4] = 300, [5] = 0, [6] = 0 })
local frostAction = { name = "Frostbolt", spellId = 116, actor = "player",
    facts = { kind = "damage", ranged = true } }
XelAssist.Combat.Resistance:Submitted(frostAction, "binary-target")
XelAssist.Combat.Resistance:Miss(116, "binary-target", 2, "player-a")
local learnedBinary = XelAssist.Combat.Resistance:Estimate(frostAction, "target",
    { school = 4 }, binaryState)
close(learnedBinary.landChance, 0.32,
    "a binary code-2 outcome must update the combined spell roll exactly once")
assert(not binaryProfile.deliveryContexts["player:l60:p0:direct"]
    and learnedBinary.combinedDeliverySamples == 1,
    "binary combined rejects must not contaminate ordinary delivery evidence")

local observed = XelAssist.Combat.Resistance:DamageEvent(targetGuid, "player-a", 348, 80,
    "20,0,20", 0, 2, "2,6,0,0")
assert(observed.phaseUnknown,
    "unreserved aura-less hybrid damage must not guess direct versus periodic")
local identity = XelAssist.Combat.Resistance.identities[targetGuid]
local profile = XelAssist.Combat.Resistance:Profile(identity, false)
local contextKey = "2:player:l60:p0:direct"
assert(not profile.contexts[contextKey],
    "phase-ambiguous hybrid damage must not train either phase")
XelAssist.Combat.Resistance:Submitted(dotAction, targetGuid,
    { cast = 2, directDamage = 40, periodicDamage = 60 })
clock = clock + 2
observed = XelAssist.Combat.Resistance:DamageEvent(targetGuid, "player-a", 348, 80,
    "20,0,20", 0, 2, "2,6,0,0")
close(observed.basis, 120, "absorbs must remain in pre-resistance basis")
close(observed.delivered, 5 / 6, "partial-resist delivery fraction")
assert(not observed.periodic and profile.contexts[contextKey].samples == 1
    and not profile.contexts["2:player:l60:p0:application"]
    and XelAssist.Combat.Resistance:Submission(targetGuid, "player-a", 348),
    "a hybrid direct impact must not prove or consume its aura application")
assert(XelAssist.Combat.Resistance:AuraLanded(targetGuid, 348, "player-a") == 2
    and profile.contexts["2:player:l60:p0:application"].landSamples == 1,
    "the exact caster-bearing aura must confirm the hybrid application")
local hybridDirectLandBeforeTick = profile.contexts[contextKey].landSamples or 0
XelAssist.Combat.Resistance:Submitted(dotAction, targetGuid)
XelAssist.Combat.Resistance:DamageEvent(targetGuid, "player-a", 348, 80,
    "0,0,20", 0, 2, "2,6,0,3")
assert(profile.contexts[contextKey].landSamples == hybridDirectLandBeforeTick,
    "periodic ticks must not masquerade as repeated spell applications")
assert(profile.contexts["2:player:l60:p0:application"].landSamples == 2,
    "the first owned periodic outcome should confirm one application")
XelAssist.Combat.Resistance:Submitted(dotAction, targetGuid)
XelAssist.Combat.Resistance:Miss(348, targetGuid, 2, "player-a")
close(profile.contexts["2:player:l60:p0:application"].landSamples, 2,
    "a nonbinary code-2 rejection must not masquerade as raw resistance")
assert(profile.contexts["2:player:l60:p0:application"].ordinaryMisses == 1
    and profile.deliveryContexts["player:l60:p0:application"].misses == 1,
    "a nonbinary code-2 rejection must train ordinary spell delivery")
XelAssist.Combat.Resistance:Submitted(action, targetGuid)
XelAssist.Combat.Resistance:Miss(133, targetGuid, 1, "player-a")
assert(profile.contexts[contextKey].landSamples == hybridDirectLandBeforeTick
    and profile.contexts[contextKey].ordinaryMisses == 1
    and profile.deliveryContexts["player:l60:p0:direct"].misses == 1,
    "ordinary misses must train shared delivery without impersonating school resistance")
local applicationBeforeRefresh = profile.contexts["2:player:l60:p0:application"].landSamples
XelAssist.Combat.Resistance:Submitted(dotAction, targetGuid, { cast = 2 }, true)
clock = clock + 3
XelAssist.Combat.Resistance:DamageEvent(targetGuid, "player-a", 348, 20,
    "0,0,0", 0, 2, "6,0,0,3")
assert(profile.contexts["2:player:l60:p0:application"].landSamples == applicationBeforeRefresh
    and XelAssist.Combat.Resistance:Submission(targetGuid, "player-a", 348),
    "an old periodic tick must not confirm a refresh application")
assert(XelAssist.Combat.Resistance:AuraLanded(targetGuid, 348, "player-a") == 2
    and not XelAssist.Combat.Resistance:Submission(targetGuid, "player-a", 348),
    "the exact caster-bearing aura event must confirm and consume the refresh")
local learnedHybrid = XelAssist.Combat.Resistance:Estimate(dotAction, "target",
    { school = 2, directDamage = 40, periodicDamage = 60 }, state)
close(learnedHybrid.components[1].landChance, learnedHybrid.components[2].landChance,
    "hybrid direct and periodic portions must share the application landing roll")
local leechAction = { name = "Drain Life", spellId = 778, actor = "player",
    facts = { kind = "damage", channel = true } }
XelAssist.Combat.Resistance:Submitted(leechAction, targetGuid)
XelAssist.Combat.Resistance:DamageEvent(targetGuid, "player-a", 778, 20,
    "0,0,0", 0, 5, "6,0,0,0")
assert(profile.contexts["5:player:l60:p0:periodic"].samples == 1,
    "aura-less periodic leech/channel outcomes must not train the direct context")
local curseAction = { name = "Curse of Shadow", spellId = 777, actor = "player",
    facts = { kind = "debuff" } }
XelAssist.Combat.Resistance:Submitted(curseAction, targetGuid)
assert(XelAssist.Combat.Resistance:AuraLanded(targetGuid, 777) == 5,
    "owned aura confirmation should retain its school")
assert(profile.contexts["5:player:l60:p0:direct"].landHits == 1,
    "owned aura confirmation should teach one successful application")
XelAssist.Combat.Resistance:Submitted(curseAction, targetGuid)
assert(XelAssist.Combat.Resistance:Miss(777, targetGuid, 11, "player-a") == 5
    and not XelAssist.Combat.Resistance:Submission(targetGuid, "player-a", 777),
    "every defined terminal miss outcome must retire its submission")

do
local savedModifiers, savedEncounter = XelAssist.Combat.TargetModifiers, XelAssist.Game.Encounter
local activeShadowReduction = 0
local modifierEncounterTarget = "modifier-target"
XelAssist.Combat.TargetModifiers = { Active = function()
    return activeShadowReduction ~= 0 and { [5] = activeShadowReduction } or nil
end }
XelAssist.Game.Encounter = { Snapshot = function()
    return { target = { guid = modifierEncounterTarget } }
end }
local modifierProfile, modifierState = isolatedState("modifier-target", 91013, 60, nil)
modifierState.targetResistance.live = nil
local modifierCurse = { name = "Modifier Curse", spellId = 777, actor = "player",
    facts = { kind = "debuff" } }
XelAssist.Combat.Resistance:Submitted(modifierCurse, "modifier-target")
activeShadowReduction = 50
assert(XelAssist.Combat.Resistance:AuraLanded("modifier-target", 777, "player-a") == 5,
    "the modifier's own exact aura must confirm its application")
assert(modifierProfile.contexts["5:player:l60:p0:direct"].landSamples == 1
    and not modifierProfile.contexts["5:player:l60:p0:r50:direct"],
    "a modifier's own landing roll must use its captured pre-cast resistance state")
local shadowBolt = { name = "Shadow Bolt", spellId = 711, actor = "player",
    facts = { kind = "damage" } }
XelAssist.Combat.Resistance:Submitted(shadowBolt, "modifier-target")
XelAssist.Combat.Resistance:DamageEvent("modifier-target", "player-a", 711, 40,
    "0,0,10", 0, 5, "2,0,0,0")
assert(modifierProfile.contexts["5:player:l60:p0:r50:direct"].samples == 1
    and modifierProfile.deliveryContexts["player:l60:p0:direct"].samples == 1
    and not modifierProfile.deliveryContexts["player:l60:p0:r50:direct"],
    "modifier-state mitigation must stay separate while ordinary delivery remains shared")
modifierState.targetResistance.projectedReduction = { [5] = 50 }
modifierState.targetResistance.projectedBy = "Modifier Curse"
local modifierEstimate = XelAssist.Combat.Resistance:Estimate(shadowBolt, "target",
    { school = 5 }, modifierState)
assert(modifierEstimate.samples == 1 and modifierEstimate.mitigationOnLand < 1,
    "the matching projected state must reuse its modifier-specific mitigation evidence")
activeShadowReduction = 0
local modifierChannel = { name = "Modifier channel", spellId = 778, actor = "player",
    facts = { kind = "damage", channel = true } }
XelAssist.Combat.Resistance:Submitted(modifierChannel, "modifier-target")
activeShadowReduction = 50
XelAssist.Combat.Resistance:DamageEvent("modifier-target", "player-a", 778, 20,
    "0,0,5", 0, 5, "6,0,0,53")
assert(modifierProfile.contexts["5:player:l60:p0:r50:periodic"].samples == 1
    and modifierProfile.contexts["5:player:l60:p0:application"].landSamples == 1,
    "periodic mitigation must use tick-time modifiers while application proof uses the captured cast state")
local modifiedPeriodicSamples =
    modifierProfile.contexts["5:player:l60:p0:r50:periodic"].samples
local baselinePeriodic = modifierProfile.contexts["5:player:l60:p0:periodic"]
local baselinePeriodicSamples = baselinePeriodic and baselinePeriodic.samples or 0
modifierEncounterTarget = "other-target"
local offTargetTick = XelAssist.Combat.Resistance:DamageEvent(
    "modifier-target", "player-a", 778, 20, "0,0,5", 0, 5, "6,0,0,53")
baselinePeriodic = modifierProfile.contexts["5:player:l60:p0:periodic"]
assert(offTargetTick.modifierStateUnknown
    and (baselinePeriodic and baselinePeriodic.samples or 0) == baselinePeriodicSamples
    and modifierProfile.contexts["5:player:l60:p0:r50:periodic"].samples
        == modifiedPeriodicSamples,
    "an off-target tick with unknowable live modifiers must train neither the clean nor modified baseline")
assert(XelAssist.Combat.Resistance:Miss(116, "modifier-target", 2, "player-a") == 4
    and not modifierProfile.contexts["4:player:l60:p0:direct"],
    "an off-target binary reject with unknown modifiers must not pollute its clean context")
local physicalMechanicKey = "702:2:player:l60:p0:direct"
local physicalMechanicBefore = modifierProfile.spells[physicalMechanicKey]
    and modifierProfile.spells[physicalMechanicKey].resistanceRejects or 0
assert(XelAssist.Combat.Resistance:Miss(702, "modifier-target", 2, "player-a") == 2
    and modifierProfile.spells[physicalMechanicKey]
    and modifierProfile.spells[physicalMechanicKey].resistanceRejects
        == physicalMechanicBefore + 1,
    "an elemental physical mechanic reject must remain usable off-target because it is independent of school-resistance modifiers")
modifierEncounterTarget = "modifier-target"
XelAssist.Combat.Resistance:Submitted(shadowBolt, "modifier-target")
modifierEncounterTarget = "other-target"
local delayedDirect = XelAssist.Combat.Resistance:DamageEvent(
    "modifier-target", "player-a", 711, 40, "0,0,10", 0, 5, "2,0,0,0")
assert(not delayedDirect.modifierStateUnknown
    and modifierProfile.contexts["5:player:l60:p0:r50:direct"].samples == 2,
    "a delayed direct impact must retain the known modifier state captured at submission")
XelAssist.Combat.TargetModifiers, XelAssist.Game.Encounter = savedModifiers, savedEncounter
end

local hybridProfile = isolatedState("hybrid-target", 91003, 60,
    { [0] = 0, [1] = 0, [2] = 0, [3] = 0, [4] = 0, [5] = 0, [6] = 0 })
XelAssist.Combat.Resistance:Submitted(dotAction, "hybrid-target", { cast = 2 })
clock = clock + 2
local hybridDirect = XelAssist.Combat.Resistance:DamageEvent("hybrid-target", "player-a", 348, 40,
    "0,0,0", 0, 2, "2,6,0,0")
local hybridTick = XelAssist.Combat.Resistance:DamageEvent("hybrid-target", "player-a", 348, 20,
    "0,0,0", 0, 2, "2,6,0,0")
assert(not hybridDirect.periodic and hybridTick.periodic
    and hybridProfile.contexts["2:player:l60:p0:direct"].samples == 1
    and hybridProfile.contexts["2:player:l60:p0:periodic"].samples == 1,
    "DBC-known aura-less hybrids must classify their first impact and later ticks")

local directFirstProfile = isolatedState("direct-first-target", 91015, 60,
    { [0] = 0, [1] = 0, [2] = 0, [3] = 0, [4] = 0, [5] = 0, [6] = 0 })
XelAssist.Combat.Resistance:Submitted(dotAction, "direct-first-target",
    { directDamage = 40, periodicDamage = 60 })
XelAssist.Combat.Resistance:DamageEvent("direct-first-target", "player-a", 348, 40,
    "0,0,0", 0, 2, "2,6,0,0")
XelAssist.Combat.Resistance:AuraLanded("direct-first-target", 348, "player-a")
assert(directFirstProfile.deliveryContexts["player:l60:p0:direct"].samples == 1
    and directFirstProfile.deliveryContexts["player:l60:p0:application"].samples == 1,
    "hybrid direct-first order must retain one direct and one shared application observation")
local auraFirstProfile = isolatedState("aura-first-target", 91016, 60,
    { [0] = 0, [1] = 0, [2] = 0, [3] = 0, [4] = 0, [5] = 0, [6] = 0 })
XelAssist.Combat.Resistance:Submitted(dotAction, "aura-first-target",
    { directDamage = 40, periodicDamage = 60 })
XelAssist.Combat.Resistance:AuraLanded("aura-first-target", 348, "player-a")
XelAssist.Combat.Resistance:DamageEvent("aura-first-target", "player-a", 348, 40,
    "0,0,0", 0, 2, "2,6,0,0")
assert(auraFirstProfile.deliveryContexts["player:l60:p0:direct"].samples == 1
    and auraFirstProfile.deliveryContexts["player:l60:p0:application"].samples == 1,
    "hybrid aura-first order must deduplicate the same landing evidence by phase")
local multiPacketProfile = isolatedState("multipacket-target", 91017, 60,
    { [0] = 0, [1] = 0, [2] = 0, [3] = 0, [4] = 0, [5] = 0, [6] = 0 })
local multiPacketAction = { name = "Multi-packet", spellId = 712, actor = "player",
    facts = { kind = "damage" } }
XelAssist.Combat.Resistance:Submitted(multiPacketAction, "multipacket-target")
XelAssist.Combat.Resistance:DamageEvent("multipacket-target", "player-a", 712, 20,
    "0,0,0", 0, 2, "2,2,0,0")
XelAssist.Combat.Resistance:DamageEvent("multipacket-target", "player-a", 712, 20,
    "0,0,0", 0, 2, "2,2,0,0")
assert(multiPacketProfile.contexts["2:player:l60:p0:direct"].samples == 2
    and multiPacketProfile.contexts["2:player:l60:p0:direct"].landSamples == 1
    and multiPacketProfile.deliveryContexts["player:l60:p0:direct"].samples == 1,
    "multi-packet direct damage must learn both mitigation packets but one application delivery")
local hybridApplication = hybridProfile.contexts["2:player:l60:p0:application"]
local hybridApplicationBefore = hybridApplication and hybridApplication.landSamples or 0
XelAssist.Combat.Resistance:Submitted(dotAction, "hybrid-target", { cast = 2 }, true)
local earlyRefreshTick = XelAssist.Combat.Resistance:DamageEvent(
    "hybrid-target", "player-a", 348, 20, "0,0,0", 0, 2, "2,6,0,0")
hybridApplication = hybridProfile.contexts["2:player:l60:p0:application"]
assert(earlyRefreshTick.periodic
    and XelAssist.Combat.Resistance:Submission("hybrid-target", "player-a", 348)
    and (hybridApplication and hybridApplication.landSamples or 0) == hybridApplicationBefore,
    "an old aura-less tick before refresh impact must not prove the new application")
local refreshDirectSamples = hybridProfile.contexts["2:player:l60:p0:direct"].samples
local refreshPeriodicSamples = hybridProfile.contexts["2:player:l60:p0:periodic"].samples
clock = clock + 2.1
local ambiguousRefresh = XelAssist.Combat.Resistance:DamageEvent(
    "hybrid-target", "player-a", 348, 40, "0,0,0", 0, 2, "2,6,0,0")
assert(ambiguousRefresh.phaseUnknown
    and XelAssist.Combat.Resistance:Submission("hybrid-target", "player-a", 348)
    and hybridProfile.contexts["2:player:l60:p0:direct"].samples == refreshDirectSamples
    and hybridProfile.contexts["2:player:l60:p0:periodic"].samples == refreshPeriodicSamples,
    "an aura-less refresh packet after cast time must not poison either phase")
assert(XelAssist.Combat.Resistance:AuraLanded("hybrid-target", 348, "player-a") == 2,
    "an exact refresh aura must resolve the ambiguous packet")
local postRefreshTick = XelAssist.Combat.Resistance:DamageEvent(
    "hybrid-target", "player-a", 348, 20, "0,0,0", 0, 2, "2,6,0,0")
assert(postRefreshTick.phaseUnknown,
    "an exact aura must not fabricate the unresolved refresh packet's damage phase")

local physicalHybridProfile = isolatedState("physical-hybrid-target", 91010, 60,
    { [0] = 5500, [1] = 0, [2] = 0, [3] = 0, [4] = 0, [5] = 0, [6] = 0 })
local physicalHybridAction = { name = "Physical Hybrid", spellId = 704,
    actor = "player", facts = { kind = "dot", melee = true } }
assert(XelAssist.Combat.Resistance:SpellFacts(704).directDamage
    and XelAssist.Combat.Resistance:SpellFacts(704).periodic,
    "physical DBC records must retain both direct and periodic effect semantics")
XelAssist.Combat.Resistance:Submitted(physicalHybridAction, "physical-hybrid-target")
local physicalHybridDirect = XelAssist.Combat.Resistance:DamageEvent(
    "physical-hybrid-target", "player-a", 704, 40, "0,0,0", 0, 0, "2,6,0,0")
local physicalHybridTick = XelAssist.Combat.Resistance:DamageEvent(
    "physical-hybrid-target", "player-a", 704, 20, "0,0,0", 0, 0, "2,6,0,0")
assert(not physicalHybridDirect.periodic and physicalHybridTick.periodic
    and physicalHybridProfile.contexts["0:player:l60:p0:direct"].landHits == 1
    and deliveryByPrefix(physicalHybridProfile,
        "physical-melee:player:l60:p-:w").samples == 1,
    "an aura-less physical hybrid must not train every tick as direct delivery")
XelAssist.Combat.Resistance:CancelSubmission(704, "player-a", "physical-hybrid-target")

local cappedProfile = isolatedState("capped-target", 91004, 60,
    { [0] = 0, [1] = 0, [2] = 0, [3] = 0, [4] = 0, [5] = 0, [6] = 0 })
XelAssist.Combat.Resistance:Submitted(dotAction, "capped-target", { cast = 2 })
assert(XelAssist.Combat.Resistance:MarkApplicationUncertain(
    "capped-target", 348, "player-a", "target debuff bar full"),
    "debuff-cap evidence must mark the exact application uncertain")
clock = clock + 2
local cappedDirect = XelAssist.Combat.Resistance:DamageEvent(
    "capped-target", "player-a", 348, 40, "0,0,0", 0, 2, "2,6,0,0")
assert(not cappedDirect.periodic
    and XelAssist.Combat.Resistance:Submission("capped-target", "player-a", 348)
    and not cappedProfile.contexts["2:player:l60:p0:application"],
    "a capped hybrid direct hit must not consume or confirm its DoT application")
assert(cappedProfile.contexts["2:player:l60:p0:direct"].landHits == 1,
    "a capped hybrid's exact direct hit should remain usable delivery evidence")
local cappedTick = XelAssist.Combat.Resistance:DamageEvent(
    "capped-target", "player-a", 348, 20, "0,0,0", 0, 2, "2,6,0,0")
assert(cappedTick.periodic
    and cappedProfile.contexts["2:player:l60:p0:direct"].landHits == 1
    and cappedProfile.contexts["2:player:l60:p0:periodic"].samples == 1,
    "ticks after a capped hybrid direct packet must not retrain direct delivery")
XelAssist.Combat.Resistance:CancelSubmission(348, "player-a", "capped-target")

local oldPetProfile = isolatedState("old-pet-target", 91005, 60,
    { [0] = 0, [1] = 0, [2] = 0, [3] = 0, [4] = 0, [5] = 0, [6] = 0 })
unitGuids.pet = "old-pet"
local petBolt = { name = "Firebolt", spellId = 133, actor = "pet",
    facts = { kind = "damage" } }
XelAssist.Combat.Resistance:Submitted(petBolt, "old-pet-target", { cast = 1 })
unitGuids.pet = "replacement-pet"
clock = clock + 1
XelAssist.Combat.Resistance:DamageEvent("old-pet-target", "old-pet", 133, 30,
    "0,0,0", 0, 2, "2,0,0,0")
assert(oldPetProfile.contexts["2:pet:l60:p?:direct"].samples == 1,
    "delayed events from a replaced owned pet must retain pet attribution")
unitGuids.pet = "pet-a"

local inferredProfile, inferredState = isolatedState("inferred-target", 91006, 60,
    nil)
inferredState.targetResistance.live = nil
local inferredContext = { key = "player:l60:p0", level = 60,
    penetration = 0, penetrationKnown = true }
local inferredIndex
for inferredIndex = 1, 7 do
    XelAssist.Combat.Resistance:ObserveInferredRaw(
        inferredProfile, 2, 0.25, inferredContext, 60)
end
local insufficientRaw = XelAssist.Combat.Resistance:Estimate(action, "target", { school = 2 },
    inferredState)
assert(insufficientRaw.raw == nil and insufficientRaw.unknown,
    "fewer than eight partial outcomes must not fabricate a raw resistance value")
XelAssist.Combat.Resistance:ObserveInferredRaw(inferredProfile, 2, 0.25, inferredContext, 60)
local inferredRaw = XelAssist.Combat.Resistance:Estimate(action, "target", { school = 2 },
    inferredState)
close(inferredRaw.raw, 100,
    "aggregated partial outcomes must invert to a bounded context resistance prior")
assert(string.find(inferredRaw.source, "inferred resistance", 1, true),
    "inferred raw resistance must retain explicit provenance")

local bossProfile, bossState = isolatedState("boss-inferred-target", 91008, -1, nil)
bossState.targetResistance.live = nil
for inferredIndex = 1, 8 do
    XelAssist.Combat.Resistance:ObserveInferredRaw(
        bossProfile, 2, 0.25, inferredContext, -1)
end
local bossRaw = XelAssist.Combat.Resistance:Estimate(action, "target", { school = 2 }, bossState)
close(bossRaw.raw, 78,
    "boss-level raw inference must use the same attacker-plus-three level estimate")
assert(bossRaw.targetLevelEstimated,
    "boss-level resistance inference must expose its estimated level provenance")

local learnedProjectionProfile, learnedProjectionState = isolatedState(
    "learned-projection-target", 91014, 60, nil)
learnedProjectionState.targetResistance.live = nil
learnedProjectionProfile.contexts["2:player:l60:p0:direct"] = {
    samples = 4, delivered = 3, lastSeen = wallClock }
local learnedBaseline = XelAssist.Combat.Resistance:Estimate(action, "target", { school = 2 },
    learnedProjectionState)
local baselineDelivered = learnedProjectionProfile.contexts[
    "2:player:l60:p0:direct"].delivered
learnedProjectionState.targetResistance.projectedReduction = { [2] = 50 }
learnedProjectionState.targetResistance.projectedBy = "learned-only reduction"
local learnedProjected = XelAssist.Combat.Resistance:Estimate(action, "target", { school = 2 },
    learnedProjectionState)
assert(learnedProjected.multiplier > learnedBaseline.multiplier
    and learnedProjected.mitigationOnLand <= 1
    and learnedProjected.projectedReduction == 50,
    "a projected reduction must conservatively improve learned-only mitigation")
assert(learnedProjectionProfile.contexts["2:player:l60:p0:direct"].delivered
        == baselineDelivered
    and not learnedProjectionProfile.contexts["2:player:l60:p0:r50:direct"]
    and string.find(learnedProjected.source, "learned-only reduction", 1, true),
    "learned-only projection must not mutate or pollute baseline evidence contexts")
local learnedArmorProfile, learnedArmorState = isolatedState(
    "learned-armor-target", 91018, 60, nil)
learnedArmorState.targetResistance.live = nil
learnedArmorProfile.contexts["0:player:l60:p0:direct"] = {
    samples = 4, delivered = 2, lastSeen = wallClock }
local armorAction = { name = "Armor strike", actor = "player",
    facts = { kind = "damage", school = 0, melee = true } }
local learnedArmorBaseline = XelAssist.Combat.Resistance:Estimate(armorAction, "target",
    { school = 0 }, learnedArmorState)
learnedArmorState.targetResistance.projectedReduction = { [0] = 1000 }
learnedArmorState.targetResistance.projectedBy = "learned armor reduction"
local learnedArmorProjected = XelAssist.Combat.Resistance:Estimate(armorAction, "target",
    { school = 0 }, learnedArmorState)
assert(learnedArmorProjected.multiplier > learnedArmorBaseline.multiplier
    and learnedArmorProjected.mitigationOnLand <= 1
    and not learnedArmorProfile.contexts["0:player:l60:p0:r1000:direct"],
    "learned-only Armor projection must use the Armor curve without polluting baseline evidence")

local ignoredProfile = isolatedState("ignored-inference-target", 91009, 60, nil)
for inferredIndex = 1, 8 do
    XelAssist.Combat.Resistance:Submitted(
        { name = "Ignore", spellId = 999, actor = "player", facts = { kind = "damage" } },
        "ignored-inference-target")
    XelAssist.Combat.Resistance:DamageEvent(
        "ignored-inference-target", "player-a", 999, 50, "0,0,0", 0, 5, "2,0,0,0")
end
assert(not ignoredProfile.inferredRawContexts["5:player:l60:p0"],
    "unresistable spell outcomes must never fabricate a zero-resistance prior")

XelAssist.Combat.Resistance.submissions["stale-submission"] = { at = clock - 31 }
XelAssist.Combat.Resistance.recentSubmissions["stale-recent"] = {
    at = clock - 10, consumedAt = clock - 10, duration = 0 }
XelAssist.Combat.Resistance:SweepSubmissions()
assert(not XelAssist.Combat.Resistance.submissions["stale-submission"]
    and not XelAssist.Combat.Resistance.recentSubmissions["stale-recent"],
    "abandoned active and recent evidence reservations must be pruned")

assert(XelAssist.Combat.Resistance:SpellFacts(116).binary,
    "DBC control aura should mark a binary spell")
local normalRangedFacts = XelAssist.Combat.Resistance:SpellFacts(705)
assert(normalRangedFacts.normalRanged and normalRangedFacts.deliveryModel == "physical"
    and normalRangedFacts.deliverySubtype == "ranged",
    "NORMAL_RANGED_ATTACK 0x8000 must select physical ranged delivery")
assert(XelAssist.Combat.Resistance:SpellFacts(709).deliveryModel == "magic",
    "the unrelated 0x4000 attribute must not masquerade as NORMAL_RANGED_ATTACK")
assert(XelAssist.Combat.Resistance:SpellFacts(706).alwaysHit,
    "ALWAYS_HIT 0x40000 must be retained from DBC metadata")
local flagProfile, flagState = isolatedState("flag-target", 91011, 60,
    { [0] = 5500, [1] = 0, [2] = 0, [3] = 300, [4] = 300, [5] = 0, [6] = 0 })
local normalRangedEstimate = XelAssist.Combat.Resistance:Estimate(
    { name = "Normal ranged magic school", spellId = 705, actor = "player",
        facts = { kind = "damage" } }, "target", { school = 6 }, flagState)
close(normalRangedEstimate.landChance, 0.95,
    "NORMAL_RANGED_ATTACK must use the weapon-delivery prior")
assert(normalRangedEstimate.deliveryModel == "physical"
    and normalRangedEstimate.deliverySubtype == "ranged",
    "NORMAL_RANGED_ATTACK delivery provenance must remain visible")
local alwaysMagic = XelAssist.Combat.Resistance:Estimate(
    { name = "Always-hit Nature", spellId = 706, actor = "player",
        facts = { kind = "damage" } }, "target", { school = 3 }, flagState)
close(alwaysMagic.landChance, 1,
    "magic ALWAYS_HIT must bypass the ordinary delivery roll")
close(alwaysMagic.mitigationOnLand, 0.3125,
    "nonbinary ALWAYS_HIT magic damage must still be partially resisted")
local alwaysBinary = XelAssist.Combat.Resistance:Estimate(
    { name = "Always-hit Binary", spellId = 707, actor = "player",
        facts = { kind = "damage" } }, "target", { school = 4 }, flagState)
close(alwaysBinary.landChance, 1,
    "binary magic ALWAYS_HIT must bypass its combined hit/resistance roll")
close(alwaysBinary.mitigationOnLand, 1,
    "positive resistance must not partially mitigate landed binary damage")
local alwaysPhysical = XelAssist.Combat.Resistance:Estimate(
    { name = "Always-hit Weapon", spellId = 710, actor = "player",
        facts = { kind = "damage", melee = true } }, "target", { school = 0 }, flagState)
close(alwaysPhysical.landChance, 0.95,
    "physical ALWAYS_HIT must retain dodge/parry/mechanic delivery uncertainty")
local alwaysPhysicalAction = { name = "Always-hit Weapon", spellId = 710,
    actor = "player", facts = { kind = "damage", melee = true } }
XelAssist.Combat.Resistance:Submitted(alwaysPhysicalAction, "flag-target")
XelAssist.Combat.Resistance:DamageEvent("flag-target", "player-a", 710, 20,
    "0,0,0", 0, 0, "2,0,0,0")
alwaysPhysical = XelAssist.Combat.Resistance:Estimate(alwaysPhysicalAction,
    "target", { school = 0 }, flagState)
local ordinaryAfterAlways = XelAssist.Combat.Resistance:Estimate(
    { name = "Ordinary Weapon", spellId = 700, actor = "player",
        facts = { kind = "damage", melee = true } },
    "target", { school = 0 }, flagState)
assert(alwaysPhysical.deliverySamples == 1 and ordinaryAfterAlways.deliverySamples == 0,
    "physical ALWAYS_HIT outcomes must not leak into an ordinary weapon hit table")
assert(flagProfile and normalRangedFacts,
    "flag fixtures must create an isolated evidence profile")
flagProfile.contexts["5:player:l60:p0:direct"] = {
    samples = 8, delivered = 4, lastSeen = wallClock }
local ignoredAgainstLearnedPartial = XelAssist.Combat.Resistance:Estimate(
    { name = "Ignore learned partial", spellId = 999, actor = "player",
        facts = { kind = "damage" } }, "target", { school = 5 }, flagState)
close(ignoredAgainstLearnedPartial.mitigationOnLand, 1,
    "positive partial-resist evidence from other spells must not leak through ignore-resistance")
flagProfile.contexts["4:player:l60:p0:direct"] = {
    samples = 8, delivered = 4, lastSeen = wallClock }
alwaysBinary = XelAssist.Combat.Resistance:Estimate(
    { name = "Always-hit Binary", spellId = 707, actor = "player",
        facts = { kind = "damage" } }, "target", { school = 4 }, flagState)
close(alwaysBinary.mitigationOnLand, 1,
    "nonbinary partial-resist evidence must not partially mitigate binary damage")
local ignored = XelAssist.Combat.Resistance:Estimate(
    { name = "Ignore", spellId = 999, actor = "player", facts = { kind = "damage" } },
    "target", { school = 5 }, state)
assert(ignored.multiplier == 1 and ignored.mode == "ignore-resistance",
    "DBC ignore-resistance attribute was not honored")
local ignoredVulnerabilityProfile, ignoredVulnerabilityState = isolatedState(
    "ignored-vulnerability-target", 91012, 60,
    { [0] = 0, [1] = 0, [2] = -50, [3] = 0, [4] = 0, [5] = -50, [6] = 0 })
local ignoredVulnerability = XelAssist.Combat.Resistance:Estimate(
    { name = "Ignore vulnerable", spellId = 999, actor = "player",
        facts = { kind = "damage" } }, "target", { school = 5 },
    ignoredVulnerabilityState)
close(ignoredVulnerability.landChance, 1,
    "magic ignore-resistance must still guarantee its delivery roll")
close(ignoredVulnerability.mitigationOnLand, 1.1636111111,
    "ignore-resistance must retain negative-resistance vulnerability")
local ignoredPhysicalVulnerability = XelAssist.Combat.Resistance:Estimate(
    { name = "Physical-delivery vulnerable", spellId = 702, actor = "player",
        facts = { kind = "damage", melee = true } }, "target", { school = 2 },
    ignoredVulnerabilityState)
close(ignoredPhysicalVulnerability.landChance, 0.95,
    "ignore-resistance must retain physical delivery uncertainty")
close(ignoredPhysicalVulnerability.mitigationOnLand, 1.1636111111,
    "physical delivery must not discard negative-resistance vulnerability")
assert(ignoredVulnerabilityProfile and ignoredVulnerability.mode == "ignore-resistance",
    "ignore-resistance vulnerability fixture must retain its mode")

local wandAction = { name = "Shoot", spellId = 501, actor = "player",
    facts = { kind = "damage", dynamicSchool = "equippedWand" } }
XelAssist.Combat.Resistance:Submitted(wandAction, targetGuid)
XelAssist.Combat.Resistance:DamageEvent(targetGuid, "player-a", 501, 50, "0,0,0", 0, 6,
    "2,0,0,0")
local wand = XelAssist.Combat.Resistance:Estimate(wandAction,
    "target", {}, state)
assert(wand.school == 6, "dynamic wand school must come from its observed damage event")
rangedItemLink = "|Hitem:112:0:0:0|h[Changed Wand]|h"
local changedWand = XelAssist.Combat.Resistance:Estimate(wandAction, "target", {}, state)
assert(changedWand.school == nil and changedWand.unknown,
    "a changed dynamic-school source must not reuse stale wand observations")
rangedItemLink = "|Hitem:111:0:0:0|h[Test Wand]|h"

local judgementAction = { name = "Judgement", spellId = 20271, actor = "player",
    facts = { kind = "damage", dynamicSchool = "activeSeal" } }
local judgementContext = profile.contexts["2:player:l60:p0:direct"] or {}
local judgementLandBefore = judgementContext.landSamples or 0
local judgementDelivery = profile.deliveryContexts["player:l60:p0:direct"] or {}
local judgementDeliveryBefore = judgementDelivery.samples or 0
local judgementSpellContext = profile.spells["20271:2:player:l60:p0:direct"] or {}
local judgementSpellLandBefore = judgementSpellContext.landSamples or 0
XelAssist.Combat.Resistance:Submitted(judgementAction, targetGuid, { directDamage = 50 })
assert(XelAssist.Combat.Resistance:AuraLanded(targetGuid, 20271, "player-a") == 2,
    "aura-first dynamic casts should confirm their application")
XelAssist.Combat.Resistance:DamageEvent(targetGuid, "player-a", 20271, 50,
    "0,0,0", 0, 2, "2,6,0,0")
assert(profile.contexts["2:player:l60:p0:direct"].landSamples == judgementLandBefore + 1
    and profile.deliveryContexts["player:l60:p0:direct"].samples
        == judgementDeliveryBefore
    and profile.spells["20271:2:player:l60:p0:direct"].landSamples
        == judgementSpellLandBefore + 1,
    "an aura-first damaging cast must contribute exactly one delivery observation: land "
        .. tostring(profile.contexts["2:player:l60:p0:direct"].landSamples)
        .. "/" .. tostring(judgementLandBefore + 1) .. ", delivery "
        .. tostring(profile.deliveryContexts["player:l60:p0:direct"].samples)
        .. "/" .. tostring(judgementDeliveryBefore) .. ", combined "
        .. tostring(profile.spells["20271:2:player:l60:p0:direct"].landSamples)
        .. "/" .. tostring(judgementSpellLandBefore + 1))
local judgement = XelAssist.Combat.Resistance:Estimate(judgementAction, "target", {}, state)
assert(judgement.school == 2
    and XelAssist.Combat.Resistance.spellSchools[20271].byContext["activeSeal:9001"],
    "aura-first damage must retain the submitted dynamic source context")
activeSealId = 9002
assert(XelAssist.Combat.Resistance:Estimate(judgementAction, "target", {}, state).unknown,
    "a changed active seal must not reuse another seal's learned school")
activeSealId = 9001

liveValues[0], liveValues[3] = 5500, 0
snapshot = XelAssist.Combat.Resistance:Snapshot("target", encounter())
state.targetResistance = snapshot
local savedDeliveryContexts = profile.deliveryContexts
profile.deliveryContexts = {}
local mixed = XelAssist.Combat.Resistance:Estimate({ name = "Lightning Strike", actor = "player",
    facts = { kind = "damage", mixedDamage = true, melee = true,
        usesWeaponSkill = true,
        damageComponents = {
        { school = 0, mitigation = "armor", weaponMultiplier = 0.60 },
        { school = 3, mitigation = "resistance", weaponMultiplier = 0.20 },
    } } }, "target", {}, state)
close(mixed.multiplier, 0.59375,
    "all components of a weapon-delivered mixed strike must share its physical delivery prior")
local noMitigation = XelAssist.Combat.Resistance:Estimate({ name = "Unresistable Component",
    actor = "player", facts = { kind = "damage", mixedDamage = true,
        deliveryModel = "magic",
        damageComponents = { { school = 2, mitigation = "none", weight = 1 } } } },
    "target", {}, state)
close(noMitigation.multiplier, 0.96,
    "a magical no-mitigation component still requires ordinary spell delivery")
assert(not noMitigation.unknown,
    "a magical no-mitigation component must bypass landed-hit resistance")
penetration = { spell = 0, armor = 0, known = false }
snapshot = XelAssist.Combat.Resistance:Snapshot("target", encounter())
state.targetResistance = snapshot
local mixedUnknownPenetration = XelAssist.Combat.Resistance:Estimate({ name = "Lightning Strike",
    actor = "player", facts = { kind = "damage", melee = true,
        usesWeaponSkill = true,
        damageComponents = {
        { school = 0, mitigation = "armor", weight = 0.5 },
        { school = 3, mitigation = "resistance", weight = 0.5 },
    } } }, "target", {}, state)
assert(mixedUnknownPenetration.penetrationUnknown and mixedUnknownPenetration.unknown
    and mixedUnknownPenetration.confidence == "partial",
    "mixed aggregates must expose penetration uncertainty and an incomplete physical delivery prior")
profile.deliveryContexts = savedDeliveryContexts
penetration = { spell = 0, armor = 0, known = true }
snapshot = XelAssist.Combat.Resistance:Snapshot("target", encounter())
state.targetResistance = snapshot

local confidenceUnitResistance, confidenceUnitField = UnitResistance, GetUnitField
local confidenceRaw, confidenceContexts = profile.raw, profile.contexts
UnitResistance, GetUnitField = nil, nil
profile.raw = {}
profile.contexts = {
    ["2:player:l60:p0:direct"] = { samples = 1, delivered = 0.8,
        landSamples = 1, landHits = 1, lastSeen = wallClock },
    ["3:player:l60:p0:direct"] = { samples = 1, delivered = 0.9,
        landSamples = 1, landHits = 1, lastSeen = wallClock },
}
XelAssist.Combat.Resistance.unitResistanceProven = false
XelAssist.Combat.Resistance.nampowerResistanceProven = false
snapshot = XelAssist.Combat.Resistance:Snapshot("target", encounter())
state.targetResistance = snapshot
local limitedMixed = XelAssist.Combat.Resistance:Estimate({ name = "Limited mixed", actor = "player",
    facts = { kind = "damage", deliveryModel = "magic", damageComponents = {
        { school = 2, mitigation = "resistance", weight = 0.5 },
        { school = 3, mitigation = "resistance", weight = 0.5 },
    } } }, "target", {}, state)
assert(limitedMixed.confidence == "limited samples" and not limitedMixed.unknown,
    "mixed aggregates must preserve their weakest component confidence")
profile.raw, profile.contexts = confidenceRaw, confidenceContexts
UnitResistance, GetUnitField = confidenceUnitResistance, confidenceUnitField
XelAssist.Combat.Resistance.unitResistanceProven = true
snapshot = XelAssist.Combat.Resistance:Snapshot("target", encounter())
state.targetResistance = snapshot

local savedUnitResistance, savedGetUnitField = UnitResistance, GetUnitField
local savedContexts = profile.contexts
local savedCachedDelivery = profile.deliveryContexts
local savedSpellDelivery = profile.spellDeliveryContexts
profile.contexts = {}
profile.deliveryContexts = {}
profile.spellDeliveryContexts = {}
UnitResistance, GetUnitField = nil, nil
XelAssist.Combat.Resistance.unitResistanceProven = false
snapshot = XelAssist.Combat.Resistance:Snapshot("target", encounter())
state.targetResistance = snapshot
fire = XelAssist.Combat.Resistance:Estimate(action, "target", { school = 2 }, state)
close(fire.multiplier, 0.6064, "saved Turtle base resistance should remain a usable prior")
assert(fire.source == "cached Turtle base resistance", "cached base provenance missing")
profile.contexts = savedContexts
profile.deliveryContexts = savedCachedDelivery
profile.spellDeliveryContexts = savedSpellDelivery
UnitResistance, GetUnitField = nil, savedGetUnitField
liveValues[0], liveValues[2] = 5500, 4294967246
XelAssist.Combat.Resistance.nampowerResistanceProven = false
snapshot = XelAssist.Combat.Resistance:Snapshot("target", encounter())
state.targetResistance = snapshot
local signedRaw = XelAssist.Combat.Resistance:Estimate(action, "target", { school = 2 }, state)
assert(signedRaw.raw == -50 and signedRaw.mitigationOnLand > 1,
    "unsigned Nampower field must decode signed landed-hit vulnerability")
UnitResistance, GetUnitField = savedUnitResistance, savedGetUnitField
liveValues[0], liveValues[2] = 5500, 150
snapshot = XelAssist.Combat.Resistance:Snapshot("target", encounter())
state.targetResistance = snapshot

XelAssist.Combat.Resistance.unitResistanceProven = false
XelAssist.Combat.Resistance.nampowerResistanceProven = false
for school = 0, 6 do liveValues[school] = 0 end
snapshot = XelAssist.Combat.Resistance:Snapshot("target", encounter())
assert(not snapshot.liveTrusted and snapshot.live == nil,
    "an all-zero hostile vector must remain unproven")
local beastLore = encounter()
beastLore.targetHarmful.list = { { spellId = 1462, mine = true, name = "Beast Lore" } }
snapshot = XelAssist.Combat.Resistance:Snapshot("target", beastLore)
assert(snapshot.liveTrusted and snapshot.live[0] == 0,
    "own Beast Lore should make even an all-zero vector authoritative")

local persisted = XelAssist.Combat.Resistance:Profile(identity, false)
targetGuid = "target-b"
local secondIdentity = XelAssist.Combat.Resistance:Identity("target", encounter())
assert(XelAssist.Combat.Resistance:Profile(secondIdentity, false) == persisted,
    "stable creature ID/level/context must reuse learned knowledge across GUIDs")
local persistedCount = 0
for _ in pairs(XelAssist.Combat.Resistance:Store().profiles) do persistedCount = persistedCount + 1 end
targetGuid, targetCreature, targetIsPlayer = "player-target", nil, true
local playerIdentity = XelAssist.Combat.Resistance:Identity("target", encounter())
XelAssist.Combat.Resistance:Profile(playerIdentity, true)
local afterPlayerCount = 0
for _ in pairs(XelAssist.Combat.Resistance:Store().profiles) do afterPlayerCount = afterPlayerCount + 1 end
assert(afterPlayerCount == persistedCount and XelAssist.Combat.Resistance.sessionProfiles["player-target"],
    "player identity must stay session-only and out of SavedVariables")

local opaqueTarget, opaquePet = {}, {}
XelAssist.Combat.Resistance:Submitted(action, opaqueTarget)
assert(XelAssist.Combat.Resistance:Submission(opaqueTarget, "player-a", 133),
    "submission correlation must accept an opaque SuperWoW target identity")
XelAssist.Combat.Resistance:MarkNumeric(opaqueTarget, 133)
assert(XelAssist.Combat.Resistance.numericEvidence[opaqueTarget]
    and XelAssist.Combat.Resistance.numericEvidence[opaqueTarget][133],
    "numeric-event correlation must preserve opaque target identity")
assert(XelAssist.Combat.Resistance:CancelSubmission(133, "player-a", opaqueTarget) == 1
    and not XelAssist.Combat.Resistance:Submission(opaqueTarget, "player-a", 133),
    "opaque submission identity must remain removable without stringification")
local savedPetGuid = unitGuids.pet
unitGuids.pet = opaquePet
local opaquePetAction = { name = "Opaque Pet Firebolt", spellId = 133, actor = "pet",
    facts = { kind = "damage" } }
XelAssist.Combat.Resistance:Submitted(opaquePetAction, opaqueTarget)
assert(XelAssist.Combat.Resistance:Submission(opaqueTarget, opaquePet, 133),
    "submission correlation must preserve opaque target and caster identities together")
assert(XelAssist.Combat.Resistance:CancelSubmission(133, opaquePet, opaqueTarget) == 1,
    "opaque caster identity must remain removable without stringification")
assert(XelAssist.Combat.Resistance:DynamicContext("petResult") == opaquePet,
    "dynamic pet-school context must keep the opaque pet identity")
unitGuids.pet = savedPetGuid

assert(not XelAssist.Combat.Resistance:ShouldTrainChat("x", 1),
    "enabled numeric events must suppress duplicate chat learning")
print("ok: live, learned, binary, mixed and privacy-safe target resistance model")
