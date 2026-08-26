-- Level-60 physical-class proof uses learned (therefore talent-sensitive),
-- rank-heavy unordered catalogues.  It exercises the production graph rather
-- than encoding a rotation or bypassing class legality/state transitions.
XelAssistGraphScenarioSetupOnly = true
local F = dofile("tests/graph_scenarios.lua")
XelAssistGraphScenarioSetupOnly = nil

local function reverse(t)
    local out, i = {}, nil
    for i = table.getn(t), 1, -1 do table.insert(out, t[i]) end
    return out
end
local function rotate(t)
    local out, i = {}, nil
    for i = 2, table.getn(t) do table.insert(out, t[i]) end
    if t[1] then table.insert(out, t[1]) end
    return out
end
local function evaluate(s, actions, role)
    F:Use(s, actions)
    XelAssistCharDB.graphDepth, XelAssistCharDB.role = 3, role or "damage"
    return XelAssist.Graph:Evaluate("smart", true)
end
local function expect(label, s, actions, wanted, role)
    local orders = { actions, reverse(actions), rotate(actions) }
    local i, plan, reason
    for i = 1, table.getn(orders) do
        plan, reason = evaluate(s, orders[i], role)
        assert(plan and plan.action.name == wanted,
            label .. " permutation " .. i .. " got "
                .. tostring(plan and plan.action.name or reason)
                .. ", wanted " .. wanted)
    end
    return plan
end
local function expectNone(label, s, actions, role)
    assert(evaluate(s, actions, role) == nil
        and evaluate(s, reverse(actions), role) == nil
        and evaluate(s, rotate(actions), role) == nil,
        label .. " death gate depended on catalogue order")
end
local function expectBlocked(label, s, actions, wantedReason, role)
    local orders = { actions, reverse(actions), rotate(actions) }
    local i, plan, reason
    for i = 1, table.getn(orders) do
        plan, reason = evaluate(s, orders[i], role)
        assert(plan == nil and reason == wantedReason,
            label .. " permutation " .. i .. " got "
                .. tostring(plan and plan.action.name or reason))
    end
end

local function weapon(classId, subclass, inventoryType)
    return { classificationKnown = true, empty = false, broken = false,
        classID = classId, subClassID = subclass,
        inventoryType = inventoryType }
end
local function state(class, powerType, power, distance)
    local s = F.State("smart")
    s.classMechanicClass, s.playerLevel = class, 60
    s.resourceType, s.resource, s.resourceMax = powerType, power, 100
    s.playerResourceExact = true
    s.distance, s.targetDistance = distance, distance
    s.distanceKind, s.targetDistanceKind = "hitbox", "hitbox"
    s.combo = 0; s.pet = false
    s.inventory = { mainHand = weapon(2, 7, 13),
        offHand = weapon(2, 15, 13), ranged = weapon(2, 2, 15) }
    s.playerAttack = { supported = true, active = false,
        activeKnown = true, pending = false, clockKnown = true }
    return s
end
local function setup(class, powerType)
    local s = state(class, powerType, 100, 0)
    s.hostile, s.targetHealth, s.targetMax = false, 0, 0
    return s
end
local function dead(class, powerType)
    local s = state(class, powerType, 100, 4)
    s.targetHealth, s.targetMax, s.targetHealthExact = 0, 100, true
    return s
end
local weaponFacts = { melee = true, testMaxRange = 5,
    testEquippedItemClass = 2, testEquippedItemSubClassMask = 173555 }
local attack = F.Action("Attack", 1, "damage", 45, 0, weaponFacts)

-- Hunter: learned Trueshot Aura and Aimed Shot in this discovered catalogue
-- are the talent evidence; the graph does not reread or infer a talent build.
local trueshot = F.Action("Trueshot Aura", 3, "buff", 0, 0,
    { self = true, testDuration = 1800 })
local aimed3 = F.Action("Aimed Shot", 3, "damage", 240, 75,
    { cast = 3, ranged = true, testMinRange = 8, testMaxRange = 35,
      testCooldown = 6, testEquippedItemClass = 2,
      testEquippedItemSubClassMask = 4 })
local aimed6 = F.Action("Aimed Shot", 6, "damage", 800, 75,
    { cast = 3, ranged = true, testMinRange = 8, testMaxRange = 35,
      testCooldown = 6, testEquippedItemClass = 2,
      testEquippedItemSubClassMask = 4 })
local arcane4 = F.Action("Arcane Shot", 4, "damage", 125, 35,
    { ranged = true, testMinRange = 8, testMaxRange = 35 })
local arcane8 = F.Action("Arcane Shot", 8, "damage", 230, 35,
    { ranged = true, testMinRange = 8, testMaxRange = 35 })
local auto = F.Action("Auto Shot", 1, "damage", 65, 0,
    { ranged = true, testMinRange = 8, testMaxRange = 35 })
local multi = F.Action("Multi-Shot", 4, "damage", 420, 40,
    { ranged = true, testMinRange = 8, testMaxRange = 35,
      testCooldown = 10 })
local raptor = F.Action("Raptor Strike", 8, "damage", 160, 15, weaponFacts)
local bite = F.PetAction("Bite", "damage", 80, 35, { melee = true })
expect("Hunter setup", setup("HUNTER", 0), { trueshot }, "Trueshot Aura")
local hunter = state("HUNTER", 0, 100, 20)
hunter.pet = true
hunter.actors.pet = { lifecycle = "alive", health = 1200, healthMax = 1200,
    resource = 70, resourceMax = 100, readyAt = 0, distance = 4,
    distanceKind = "hitbox", targetGuid = hunter.targetGUID }
expect("Hunter engage", hunter,
    { arcane4, aimed3, bite, aimed6, arcane8, auto }, "Arcane Shot")
hunter.inCombat, hunter.resource = true, 40
expect("Hunter sustained ranks", hunter,
    { arcane4, aimed3, arcane8, auto }, "Arcane Shot")
hunter.resource = 0
expect("Hunter starvation", hunter, { bite, arcane8, auto }, "Auto Shot")
hunter.resource = 80
expect("Hunter recovery cooldown", hunter, { aimed6, multi, auto }, "Multi-Shot")
hunter.distance, hunter.targetDistance = 4, 4
expect("Hunter dead-zone control", hunter, { aimed6, arcane8, raptor },
    "Raptor Strike")
expectNone("Hunter", dead("HUNTER", 0), { aimed6, arcane8, auto })
expect("Hunter post-combat recovery", setup("HUNTER", 0), { trueshot },
    "Trueshot Aura")

-- Rogue: learned Hemorrhage is represented only by catalogue membership;
-- combo, stealth, energy, equipment and threat pressure remain graph state.
local stealth = F.Action("Stealth", 4, "buff", 0, 0,
    { self = true, testAppliesStealth = true })
local ambush4 = F.Action("Ambush", 4, "builder", 260, 60,
    { melee = true, behind = true, comboBuild = 1,
      testRequiresStealth = true, testInitiatesCombat = true,
      testEquippedItemClass = 2, testEquippedItemSubClassMask = 32768 })
local ambush6 = F.Action("Ambush", 6, "builder", 390, 60,
    { melee = true, behind = true, comboBuild = 1,
      testRequiresStealth = true, testInitiatesCombat = true,
      testEquippedItemClass = 2, testEquippedItemSubClassMask = 32768 })
local sinister6 = F.Action("Sinister Strike", 6, "builder", 145, 45,
    { melee = true, comboBuild = 1, testInitiatesCombat = true })
local sinister8 = F.Action("Sinister Strike", 8, "builder", 205, 45,
    { melee = true, comboBuild = 1, testInitiatesCombat = true })
local hemorrhage = F.Action("Hemorrhage", 3, "builder", 175, 35,
    { melee = true, comboBuild = 1, testInitiatesCombat = true })
local eviscerate = F.Action("Eviscerate", 8, "damage", 900, 35,
    { melee = true, combo = true, comboSpend = true, testComboBonus = 130 })
local feint = F.Action("Feint", 5, "threatDrop", 0, 20,
    { melee = true, threatDropModel = "target-local-flat",
      threatDropAmount = 800, targetLocalThreatDrop = true })
local kick = F.Action("Kick", 4, "interrupt", 0, 25,
    { melee = true, testMaxRange = 5, testCooldown = 10 })
expect("Rogue setup", setup("ROGUE", 3), { stealth }, "Stealth")
local rogue = state("ROGUE", 3, 100, 4)
rogue.playerStealthed, rogue.playerStealthKnown = true, true
rogue.playerBehindTarget = true
expect("Rogue engage", rogue, { sinister6, ambush4, ambush6, attack }, "Ambush")
rogue.inCombat, rogue.playerStealthed, rogue.combo = true, false, 5
expect("Rogue sustained finisher", rogue,
    { sinister6, eviscerate, sinister8 }, "Eviscerate")
rogue.combo, rogue.resource = 0, 0
expect("Rogue starvation", rogue, { attack, sinister8 }, "Attack")
rogue.resource = 55
expect("Rogue recovery", rogue, { sinister6, sinister8, attack },
    "Sinister Strike")
rogue.targetCasting, rogue.targetCastRemaining = true, 1
expect("Rogue control", rogue, { hemorrhage, sinister8, kick }, "Kick")
rogue.targetCasting = false
rogue.hasAggro, rogue.groupSize, rogue.resource = true, 4, 40
expectBlocked("Rogue threat pressure fails closed", rogue, { feint },
    "No worthwhile action")
expectNone("Rogue", dead("ROGUE", 3), { attack, sinister8, eviscerate })
expect("Rogue post-combat recovery", setup("ROGUE", 3), { stealth }, "Stealth")

-- Warrior: Mortal Strike catalogue membership is learned talent evidence.
-- Tank pressure uses exact role/victim state and known Sunder threat semantics.
local shout = F.Action("Battle Shout", 7, "buff", 0, 10,
    { self = true, testDuration = 120 })
local mortal1 = F.Action("Mortal Strike", 1, "damage", 220, 30,
    { melee = true, testCooldown = 6 })
local mortal4 = F.Action("Mortal Strike", 4, "damage", 430, 30,
    { melee = true, testCooldown = 6 })
local sunder = F.Action("Sunder Armor", 5, "debuff", 0, 15,
    { melee = true, testMaxRange = 5, stackable = 5,
      testDuration = 30, testArmorReduction = 450,
      baseFlatThreat = 261, baseFlatThreatEstimated = true, tankOnly = true })
local bash = F.Action("Shield Bash", 3, "interrupt", 0, 10,
    { melee = true, testMaxRange = 5, testCooldown = 12,
      testEquippedItemClass = 4, testEquippedItemSubClassMask = 64 })
expect("Warrior setup", setup("WARRIOR", 1), { shout }, "Battle Shout")
local warrior = state("WARRIOR", 1, 100, 4)
expect("Warrior engage", warrior, { attack, mortal1, mortal4 }, "Mortal Strike")
warrior.inCombat, warrior.resource = true, 35
expect("Warrior sustained cooldown", warrior,
    { attack, mortal1, mortal4 }, "Mortal Strike")
warrior.resource = 0
expect("Warrior starvation", warrior, { attack, mortal4 }, "Attack")
warrior.resource = 35
expect("Warrior recovery", warrior, { attack, mortal1, mortal4 }, "Mortal Strike")
warrior.tank, warrior.role, warrior.groupSize = true, "tank", 4
warrior.hasAggro = false
expect("Warrior tank threat pressure", warrior, { sunder },
    "Sunder Armor", "tank")
warrior.targetCasting, warrior.targetCastRemaining = true, 1
warrior.inventory.offHand = weapon(4, 6, 14)
expect("Warrior tank control", warrior, { sunder, bash }, "Shield Bash", "tank")
expectNone("Warrior", dead("WARRIOR", 1), { attack, mortal4, sunder }, "tank")
expect("Warrior post-combat recovery", setup("WARRIOR", 1), { shout },
    "Battle Shout")

print("ok: level-60 physical catalogues are permutation-stable")
