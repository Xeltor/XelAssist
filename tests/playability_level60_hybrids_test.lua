-- Level-60 hybrid proof over the production graph. Catalogues are discovered
-- sets, never rotations, and every phase must survive reverse and rotation.
XelAssistGraphScenarioSetupOnly = true
local Fixture = dofile("tests/graph_scenarios.lua")
XelAssistGraphScenarioSetupOnly = nil

local function reverse(v)
    local o, i = {}, nil
    for i = table.getn(v), 1, -1 do table.insert(o, v[i]) end
    return o
end

local function rotate(v)
    local o, i = {}, nil
    for i = 2, table.getn(v) do table.insert(o, v[i]) end
    if v[1] then table.insert(o, v[1]) end
    return o
end

local function evaluate(state, actions, role)
    Fixture:Use(state, actions)
    XelAssistCharDB.graphDepth, XelAssistCharDB.role = 2, role or "damage"
    return XelAssist.Graph:Evaluate("smart", true)
end

local function signature(plan)
    local first = plan and plan.path and plan.path[1]
    return plan and table.concat({ tostring(plan.action and plan.action.name),
        tostring(plan.action and plan.action.rank),
        tostring(first and (first.targetKey or first.target) or ""),
        string.format("%.3f", tonumber(plan.wait) or 0) }, "|") or "nil"
end

local function independent(label, state, actions, role)
    local a, ar = evaluate(state, actions, role)
    local b, br = evaluate(state, reverse(actions), role)
    local c, cr = evaluate(state, rotate(actions), role)
    assert(a and b and c, label .. ": " .. tostring(ar or br or cr))
    assert(signature(a) == signature(b) and signature(a) == signature(c),
        label .. " catalogue order changed the result")
    return a
end

local function manaClock()
    return { verified = true, phaseKnown = true,
        externalEnergizeExcluded = true, resourceType = 0,
        amount = 30, interval = 2, nextIn = 1,
        source = "deterministic level-60 passive mana fixture" }
end

local function exactWeapon(state)
    state.inventory = {
        mainHand = { classificationKnown = true, classID = 2,
            subClassID = 7, inventoryType = 13, empty = false, broken = false },
        offHand = { classificationKnown = true, empty = true },
        ranged = { classificationKnown = true, empty = true },
    }
end

local function weaponFacts(extra)
    extra.testEquippedItemClass = 2
    extra.testEquippedItemSubClassMask = 2 ^ 7
    extra.testEquippedItemInventoryTypeMask = 2 ^ 13
    return extra
end

local CASES = {
    { class = "SHAMAN", setup = "Lightning Shield", instant = "Earth Shock",
      heal = "Healing Wave", tank = false,
      actions = function() return {
        Fixture.Action("Lightning Bolt", 10, "damage", 420, 230,
            { cast = 2.5, ranged = true, testMaxRange = 30, testSchool = 3 }),
        Fixture.Action("Earth Shock", 7, "damage", 300, 185,
            { ranged = true, testMaxRange = 20, testSchool = 3,
              testCooldown = 6 }),
        Fixture.Action("Lightning Bolt", 8, "damage", 290, 150,
            { cast = 2.5, ranged = true, testMaxRange = 30, testSchool = 3 }),
        Fixture.Action("Attack", 1, "damage", 80, 0,
            weaponFacts({ melee = true, testMaxRange = 5, testSchool = 0 })),
      } end,
      healAction = function() return Fixture.Action("Healing Wave", 10, "heal",
          1050, 260, { cast = 2.5, testMaxRange = 40, testSchool = 3 }) end },
    { class = "PALADIN", setup = "Devotion Aura", instant = "Holy Shock",
      heal = "Holy Light", tank = true,
      actions = function() return {
        Fixture.Action("Holy Shock", 4, "damage", 390, 210,
            { ranged = true, testMaxRange = 20, testSchool = 1,
              testCooldown = 30 }),
        Fixture.Action("Judgement", 1, "damage", 250, 130,
            { ranged = true, testMaxRange = 10, testSchool = 1,
              testCooldown = 10 }),
        Fixture.Action("Holy Shock", 2, "damage", 240, 140,
            { ranged = true, testMaxRange = 20, testSchool = 1,
              testCooldown = 30 }),
        Fixture.Action("Attack", 1, "damage", 90, 0,
            weaponFacts({ melee = true, testMaxRange = 5, testSchool = 0 })),
      } end,
      healAction = function() return Fixture.Action("Holy Light", 9, "heal",
          1100, 285, { cast = 2.5, testMaxRange = 40, testSchool = 1 }) end },
    { class = "DRUID", setup = "Mark of the Wild", instant = "Moonfire",
      heal = "Healing Touch", tank = true,
      actions = function() return {
        Fixture.Action("Wrath", 9, "damage", 410, 220,
            { cast = 2, ranged = true, testMaxRange = 30, testSchool = 3 }),
        Fixture.Action("Moonfire", 10, "damage", 285, 180,
            { ranged = true, testMaxRange = 30, testSchool = 6 }),
        Fixture.Action("Wrath", 7, "damage", 280, 145,
            { cast = 2, ranged = true, testMaxRange = 30, testSchool = 3 }),
        Fixture.Action("Attack", 1, "damage", 75, 0,
            weaponFacts({ melee = true, testMaxRange = 5, testSchool = 0 })),
      } end,
      healAction = function() return Fixture.Action("Healing Touch", 11, "heal",
          1250, 300, { cast = 3, testMaxRange = 40, testSchool = 3 }) end },
}

local _, case
for _, case in pairs(CASES) do
    local setup = Fixture.State("smart")
    setup.classMechanicClass, setup.playerLevel = case.class, 60
    setup.hostile, setup.targetHealth, setup.targetMax = false, 0, 0
    setup.talentPoints = 51
    local buff = Fixture.Action(case.setup, 1, "buff", 0, 0,
        { self = true, testDuration = 1800 })
    assert(independent(case.class .. " setup", setup, { buff }).action.name
        == case.setup)

    local engage = Fixture.State("smart")
    engage.classMechanicClass, engage.playerLevel = case.class, 60
    engage.resourceType, engage.resource, engage.resourceMax = 0, 1000, 1000
    engage.playerResourceExact, engage.distance = true, 18
    engage.talentPoints = 51
    exactWeapon(engage)
    assert(independent(case.class .. " engage", engage, case.actions()).action)

    local starved = Fixture.State("smart")
    starved.classMechanicClass, starved.playerLevel = case.class, 60
    starved.inCombat, starved.resourceType = true, 0
    starved.resource, starved.resourceMax = 0, 1000
    starved.playerResourceExact, starved.distance = true, 18
    starved.playerResourceClock = manaClock()
    local manaOnly, i = {}, nil
    for i = 1, table.getn(case.actions()) do
        local action = case.actions()[i]
        if action.mock.cost > 0 then table.insert(manaOnly, action) end
    end
    local blocked, reason = evaluate(starved, manaOnly)
    assert(not blocked and reason == "Not enough resources")
    XelAssist.Game.Player.Resources:Advance(starved, 9)
    assert(starved.resource == 150)
    assert(independent(case.class .. " recovery", starved, manaOnly).action)

    local disrupted = Fixture.State("smart")
    disrupted.classMechanicClass, disrupted.playerLevel = case.class, 60
    disrupted.moving, disrupted.inCombat, disrupted.distance = true, true, 18
    disrupted.resourceType, disrupted.resource, disrupted.resourceMax = 0, 1000, 1000
    disrupted.playerResourceExact = true
    disrupted.targetResistances = { 0, 0, 0, 300, 0, 0, 0 }
    assert(independent(case.class .. " disruption", disrupted,
        case.actions()).action.name == case.instant)

    local healer = Fixture.State("smart")
    healer.classMechanicClass, healer.playerLevel = case.class, 60
    healer.resourceType, healer.resource, healer.resourceMax = 0, 1000, 1000
    healer.playerResourceExact, healer.inCombat = true, true
    local ally = healer.friendlies.byKey[healer.friendlies.byUnit.party1]
    ally.health, ally.healthMax, ally.healthExact = 1, 1000, true
    healer.healUnit, healer.healHealth, healer.healMax = "party1", 1, 1000
    assert(independent(case.class .. " healer pressure", healer,
        { case.healAction() }, "healer").action.name == case.heal)

    if case.tank then
        local tank = Fixture.State("smart")
        tank.classMechanicClass, tank.playerLevel = case.class, 60
        tank.inCombat, tank.tank, tank.hasAggro = true, true, false
        tank.resourceType, tank.resource, tank.resourceMax = 0, 1000, 1000
        tank.playerResourceExact, tank.distance = true, 4
        exactWeapon(tank)
        assert(independent(case.class .. " tank threat pressure", tank,
            case.actions(), "tank").action)
    end

    local dead = Fixture.State("smart")
    dead.classMechanicClass, dead.playerLevel = case.class, 60
    dead.targetHealth, dead.targetMax, dead.targetHealthExact = 0, 1000, true
    assert(evaluate(dead, case.actions()) == nil)
    assert(evaluate(dead, reverse(case.actions())) == nil)

    local after = Fixture.State("smart")
    after.classMechanicClass, after.playerLevel = case.class, 60
    after.hostile, after.inCombat = false, false
    after.targetHealth, after.targetMax = 0, 0
    assert(independent(case.class .. " post-kill", after, { buff }).action.name
        == case.setup)
end

-- Genuine production state machines: exact represented consequences only.
math.huge = math.huge or (1 / 0)
dofile("Game/Player/TotemState.lua")
local Totem = XelAssist.Game.Player.TotemState
local shaman = { time = 12, totems = { available = true,
    playerGUID = "player-guid", bySlot = { [3] = { slot = 3,
        element = "water", haveTool = true, active = false,
        remaining = 0, exact = true } } } }
local water = { kind = "totemPlacement", playerGUID = "player-guid",
    slot = 3, element = "water", action = { spellId = 10497,
        name = "Mana Spring Totem" }, downstreamSpellId = 10497,
    downstreamElement = "water", duration = 60,
    lifetime = { exact = true }, admissible = true,
    effect = { exact = true, kind = "periodicMana", amount = 10, period = 2 },
    range = { exact = true, center = "totem", minimum = 0, maximum = 20 },
    recipients = { exact = true, center = "totem", relation = "self",
        shape = "single" }, source = "installed rank 4 Mana Spring contract" }
assert(Totem:Apply(shaman, water) and shaman.totems.bySlot[3].active)
assert(Totem:Advance(shaman, 59) == 0 and shaman.totems.bySlot[3].remaining == 1)
assert(Totem:Advance(shaman, 1) == 1 and not shaman.totems.bySlot[3].active)

dofile("Game/Player/PaladinAuraState.lua")
local Aura = XelAssist.Game.Player.PaladinAuraState
local paladin = { available = true, guid = "player-guid",
    playerGUID = "player-guid", recipientRelation = "self" }
local sealAction = { spellId = 20375, name = "Seal of Command" }
local sealClass = { exact = true, spellId = 20375,
    family = Aura.PALADIN_FAMILY, kind = "seal",
    exclusiveFamily = "paladinSeal" }
local seal = assert(Aura:PrepareSeal(sealAction, paladin, sealClass))
assert(Aura:ApplySeal(paladin, seal) and paladin.activeSeal.spellId == 20375)
local judgementAction = { spellId = 20271, name = "Judgement" }
local judgementClass = { exact = true, spellId = 20271,
    family = Aura.PALADIN_FAMILY, kind = "judgement" }
local target = { exact = true, guid = "target-guid", relation = "hostile" }
local outcome = { exact = true, representable = true,
    sourceSealSpellId = 20375, recipientGUID = "target-guid",
    recipientRelation = "hostile",
    effect = { exact = true, kind = "directDamage" } }
local judgement = assert(Aura:PrepareJudgement(judgementAction, paladin,
    target, outcome, judgementClass))
assert(Aura:ApplyJudgement(paladin, judgement) and not paladin.activeSeal
    and paladin.lastJudgement.sourceSealSpellId == 20375)

dofile("Game/Player/DruidFormState.lua")
local Forms = XelAssist.Game.Player.DruidFormState
local druid = { available = true, formID = 0, primaryType = 0, powers = {
    [0] = { current = 1000, maximum = 2000,
        currentKnown = true, maximumKnown = true },
    [1] = { current = 0, maximum = 100,
        currentKnown = true, maximumKnown = true },
    [3] = { current = 0, maximum = 100,
        currentKnown = true, maximumKnown = true },
} }
local shift = assert(Forms:PrepareShift({ spellId = 9634 }, druid,
    { recognized = true, valid = true, targetForm = 8,
      semanticsComplete = true, cost = { type = 0, cost = 250 } }))
assert(not shift.destinationPowerKnown and Forms:Spend(druid, shift)
    and druid.powers[0].current == 750)
assert(Forms:Apply(druid, shift, true) and druid.formID == 8
    and druid.primaryType == 1 and not druid.powers[1].currentKnown)
CancelShapeshiftForm = function() end
local cancel = assert(Forms:PrepareCancel(druid))
assert(Forms:Apply(druid, cancel) and druid.formID == 0
    and druid.primaryType == 0 and druid.powers[0].current == 750)

print("ok: level-60 hybrid graph and exact totem/seal/form states are deterministic")
