table.getn = table.getn or function(value)
    local count = 0
    while value[count + 1] ~= nil do count = count + 1 end
    return count
end
dofile("XelAssist_Actions.lua")
dofile("XelAssist_Capabilities.lua")
dofile("XelAssist_Actors.lua")
dofile("XelAssist_TargetModifiers.lua")
dofile("XelAssist_Graph.lua")

XelAssist = {}
local pendingAura
XelAssist.IsAuraPending = function(_, name) return pendingAura == name end
XelAssistObservations = {
    Blocker = function() return nil end,
    ResistanceMultiplier = function(_, _, target, tooltip, s)
        local raw = target == "target" and s.targetResistances
            and tooltip.school and s.targetResistances[tooltip.school + 1]
        if raw and s.playerLevel then
            local ratio = math.min(1, raw / (math.max(20, s.playerLevel) * 5))
            local mitigation = 0.75 * ratio - (3 / 16) * math.max(0, ratio - 2 / 3)
            return 1 - mitigation, "live resistance"
        end
        return 1
    end
}
XelAssistResistance = nil
local scenarioItems = {}
XelAssistInventory = {
    Actions = function() return scenarioItems end,
    Blocker = function() return nil end,
    Cooldown = function() return 0 end
}
XelAssistCharDB = { toggles = { cooldowns = true, reagents = true, petActions = true, petControl = false },
    graphDepth = 1, role = "damage", allowAoe = false }
GetTime = function() return 0 end

local scenarioActions = {}
XelAssistCapabilities.Actions = function() return scenarioActions end
XelAssistActors.Actions = function() return scenarioActions end
XelAssistCapabilities.Facts = function(_, action) return action.mock end
XelAssistActors.Facts = function(_, action) return action.mock end
XelAssistActors.PetCooldown = function() return 0 end
local reagentAvailable = true
XelAssistActors.HasReagent = function() return reagentAvailable end
local dispelTarget
XelAssistActors.DispelTarget = function() return dispelTarget end
XelAssistCapabilities.IsReady = function() return true end
XelAssistCapabilities.InRange = function(_, _, unit)
    if unit == "target" and XelAssistGraph.testRangeBlocked then return false end
    if XelAssistGraph.testRangeUnknown then return nil end
    return true
end
XelAssistCapabilities.TargetHasDebuff = function() return false end
XelAssistCapabilities.UnitHasBuff = function() return false end
XelAssistCapabilities.WeaponDamage = function() return nil end
XelAssistCapabilities.RangedDamage = function() return nil end
XelAssistCapabilities.BonusDamage = function() return 0 end

local function state(mode)
    local actors = { player = { resource = 1000, resourceMax = 1000 } }
    return { mode = mode or "smart", hostile = true, healUnit = "party1",
        health = 1000, healthMax = 1000, healHealth = 500, healMax = 1000,
        targetHealth = 1000, targetMax = 1000, targetHealthExact = true,
        resource = 1000, resourceMax = 1000,
        combo = 5, moving = false, pet = true, targetCasting = false,
        playerCasting = false, castRemaining = 0, groupSize = 0, hasAggro = false,
        tank = false, role = "auto", instantNext = false, distance = nil, actors = actors,
        auras = {}, readyAt = {}, time = 0 }
end

local currentState
XelAssistGraph.Snapshot = function() return currentState end

local function action(name, rank, kind, power, cost, extra)
    local facts = { kind = kind }
    if extra then for key, value in pairs(extra) do facts[key] = value end end
    return { name = name, rank = rank, rankText = "Rank " .. rank, slot = rank,
        facts = facts, mock = { average = power, cost = cost or 0,
            cast = facts.cast or 0, cooldown = facts.testCooldown,
            cooldownGroup = facts.testGroup, categoryCooldown = facts.testCategoryCooldown,
            minRange = facts.testMinRange, maxRange = facts.testMaxRange, school = facts.testSchool,
            duration = facts.testDuration,
            directDamage = facts.testDirectDamage, periodicDamage = facts.testPeriodicDamage,
            targetArmorReduction = facts.testArmorReduction,
            targetArmorPerCombo = facts.testArmorPerCombo,
            targetResistanceReduction = facts.testResistanceReduction,
            targetDamageTaken = facts.testDamageTaken } }
end

local function petAction(name, kind, power, cost, extra)
    local value = action(name, 1, kind, power, cost, extra)
    value.actor = "pet"; value.executor = "petAbility"; value.actionSlot = 4
    value.facts.petAbility = true
    return value
end

local function itemAction(name, kind, power, extra)
    local value = action(name, 1, kind, power, 0, extra)
    value.actor = "player"; value.executor = "item"; value.bag = 0; value.bagSlot = 1
    value.itemId = 13446; value.count = 1
    value.facts.consumable = true; value.facts.self = true
    value.mock.cooldown = 120
    return value
end

local function expect(name, wanted)
    local plan, err = XelAssistGraph:Evaluate(currentState.mode, true)
    assert(plan, name .. ": " .. tostring(err))
    assert(plan.action.name == wanted, name .. ": got " .. plan.action.name .. ", wanted " .. wanted)
    return plan
end

scenarioActions = {
    action("Curse of Elements", 1, "debuff", 0, 0,
        { resistanceDebuff = true, testResistanceReduction = { [2] = 45 },
            testDamageTaken = { [2] = 0.06 }, modifierGroup = "curseElements" }),
    action("Sunder Armor", 1, "debuff", 0, 0,
        { armorDebuff = true, stackable = 5, modifierGroup = "majorArmor",
            testArmorReduction = 300 }),
}
local modifierEncounter = { targetHarmful = { list = {
    { name = "Curse of Elements", mine = false, sourceUnit = "party1", remaining = 200 },
    { name = "Sunder Armor", playerOrPet = true, stacks = 3, remaining = 20 },
} } }
local activeReduction, activeTaken, activeSource, activeEffects, activeAuras =
    XelAssistGraph:ActiveTargetModifiers(
    modifierEncounter, { live = nil })
assert(activeReduction[2] == 45 and activeReduction[0] == 900
    and activeTaken[2] == 0.06 and string.find(activeSource, "Curse of Elements", 1, true)
    and activeEffects["Curse of Elements"].resistanceReduction[2] == 45
    and activeAuras["Sunder Armor"].remaining == 20,
    "active group resistance modifiers must seed the root graph state")
local effectiveReduction, effectiveTaken = XelAssistGraph:ActiveTargetModifiers(
    modifierEncounter, { live = { [0] = 1000, [2] = 50 } })
assert(effectiveReduction[2] == 45 and effectiveReduction[0] == 900
    and effectiveTaken[2] == 0.06,
    "live modifiers must retain an expiry baseline without being subtracted twice")

scenarioActions = {
    action("Minor Fire Exposure", 1, "debuff", 0, 0,
        { resistanceDebuff = true, testDamageTaken = { [2] = 0.06 },
            modifierGroup = "sharedFireExposure" }),
    action("Major Fire Exposure", 1, "debuff", 0, 0,
        { resistanceDebuff = true, testDamageTaken = { [2] = 0.10 },
            modifierGroup = "sharedFireExposure" }),
    action("Independent Fire Exposure", 1, "debuff", 0, 0,
        { resistanceDebuff = true, testDamageTaken = { [2] = 0.15 },
            modifierGroup = "independentFireExposure" }),
}
local stackingEncounter = { targetHarmful = { list = {
    { name = "Minor Fire Exposure", remaining = 30 },
    { name = "Major Fire Exposure", remaining = 30 },
    { name = "Independent Fire Exposure", remaining = 30 },
} } }
local _, stackedTaken = XelAssistGraph:ActiveTargetModifiers(stackingEncounter, nil)
assert(math.abs(stackedTaken[2] - 0.265) < 0.0001,
    "damage-taken modifiers must keep the strongest shared-group effect and multiply independent groups")

currentState = state("support"); currentState.healHealth = 880
scenarioActions = { action("Heal", 1, "heal", 100, 20), action("Heal", 5, "heal", 500, 200) }
local plan = expect("downranked heal", "Heal")
assert(plan.action.rank == 1, "the efficient non-overhealing rank should win")

currentState = state("smart"); currentState.groupSize = 4; currentState.hasAggro = true
scenarioActions = { action("Threat Slam", 1, "damage", 500, 0, { threat = 2 }),
    action("Careful Strike", 1, "damage", 300, 0, { threat = 0.5 }) }
expect("aggro-aware damage", "Careful Strike")

currentState = state("smart"); currentState.groupSize = 4; currentState.hasAggro = true
scenarioActions = { action("Bolt", 1, "damage", 300, 30), action("Bolt", 5, "damage", 500, 100) }
plan = expect("threat downrank", "Bolt")
assert(plan.action.rank == 1, "unwanted aggro should make the lower-threat rank win")

currentState = state("smart"); currentState.targetCasting = true
scenarioActions = { action("Stop Cast", 1, "interrupt", 0, 0), action("Bolt", 1, "damage", 600, 0) }
expect("interrupt", "Stop Cast")

currentState = state("smart"); currentState.targetCasting = true; currentState.targetCastRemaining = 0.5
currentState.actorReadyAt = { player = 1.5, pet = 0 }
scenarioActions = { action("Late Kick", 1, "interrupt", 0, 0), action("Bolt", 1, "damage", 200, 0) }
expect("interrupt deadline", "Bolt")

currentState = state("smart"); currentState.role = "healer"
scenarioActions = { action("Helpful Heal", 1, "heal", 200, 100),
    action("Damage Bolt", 1, "damage", 300, 100) }
expect("healer role", "Helpful Heal")
currentState.role = "damage"
expect("damage role", "Damage Bolt")

currentState = state("smart"); currentState.moving = true
scenarioActions = { action("Long Cast", 1, "damage", 900, 0, { cast = 3 }),
    action("Instant", 1, "damage", 250, 0, { cast = 0 }) }
expect("movement downtime", "Instant")

currentState = state("smart")
scenarioActions = { action("Mind Flay", 1, "damage", 900, 100,
    { channel = true, testDuration = 5 }) }
plan = expect("channel occupancy", "Mind Flay")
assert(plan.downtime >= 5, "a channel must occupy its discovered duration")

currentState = state("support"); currentState.moving = true; XelAssistCharDB.graphDepth = 2
scenarioActions = { action("Nature's Swiftness", 1, "modifier", 0, 0,
        { cooldown = true, nextInstant = true, testCooldown = 120 }),
    action("Healing Wave", 1, "heal", 500, 200, { cast = 3 }) }
plan = expect("modifier edge", "Nature's Swiftness")
assert(plan.follow[1] and plan.follow[1].name == "Healing Wave", "instant modifier should unlock the moving cast")

currentState = state("smart"); currentState.targetHealth = 50; currentState.targetMax = 100
currentState.targetHealthExact = false
scenarioActions = { action("Unknown Health Bolt", 1, "damage", 500, 0) }
plan = expect("percentage health safety", "Unknown Health Bolt")
assert(plan.reason ~= "finishes the target", "percentage-scaled hostile health must not drive finisher math")
assert(plan.confidence == "partial data" and table.getn(plan.unknowns) > 0,
    "exact potency with unknown range/health must expose partial confidence")

currentState = state("smart"); XelAssistGraph.testRangeBlocked = true
scenarioActions = { action("Out There", 1, "damage", 900, 0) }
local missing = XelAssistGraph:Evaluate("smart", true)
assert(missing == nil, "out-of-range action must not be recommended")
XelAssistGraph.testRangeBlocked = false

currentState = state("smart"); currentState.distance = 4; XelAssistGraph.testRangeUnknown = true
scenarioActions = { action("Dead Zone Shot", 1, "damage", 900, 0,
    { testMinRange = 8, testMaxRange = 35 }) }
local tooClose, tooCloseReason = XelAssistGraph:Evaluate("smart", true)
assert(tooClose == nil and tooCloseReason == "Move farther away", "minimum range must block too-close actions")
currentState.distance = 40
local tooFar, tooFarReason = XelAssistGraph:Evaluate("smart", true)
assert(tooFar == nil and tooFarReason == "Move into range", "maximum range must block too-far actions")
XelAssistGraph.testRangeUnknown = false

currentState = state("smart"); XelAssistCharDB.toggles.cooldowns = false
scenarioActions = { action("Unknown Long Cooldown", 1, "damage", 2000, 0, { testCooldown = 60 }),
    action("Normal Filler", 1, "damage", 200, 0) }
expect("live major cooldown policy", "Normal Filler")
XelAssistCharDB.toggles.cooldowns = true

currentState = state("smart"); XelAssistCharDB.graphDepth = 2
scenarioActions = { action("Burn", 1, "dot", 500, 40), action("Bolt", 1, "damage", 200, 20) }
plan = expect("future aura state", "Burn")
assert(plan.follow[1] and plan.follow[1].name == "Bolt", "future action should respect the applied aura")

currentState = state("smart")
currentState.targetAuras = { Immolate = { mine = true, duration = 15, remaining = 10 } }
scenarioActions = { action("Immolate", 1, "dot", 700, 100, { testDuration = 15 }),
    action("Shadow Bolt", 1, "damage", 200, 100) }
expect("owned dot not clipped", "Shadow Bolt")
currentState.targetAuras.Immolate.remaining = 1
expect("owned dot refresh window", "Immolate")

currentState = state("smart"); currentState.targetHealth = 100; currentState.targetMax = 100
currentState.targetHealthExact = true; XelAssistCharDB.graphDepth = 2
scenarioActions = { action("Lethal Bolt", 1, "damage", 500, 0) }
plan = expect("terminal defeated target", "Lethal Bolt")
assert(not plan.follow[1], "a defeated projected target must not receive another damage action")

currentState = state("smart"); pendingAura = "Immolate"
scenarioActions = { action("Immolate", 1, "dot", 500, 100),
    action("Shoot", 1, "damage", 100, 0, { recovery = true }) }
expect("pending dot application", "Shoot")
pendingAura = nil

currentState = state("smart"); currentState.targetHealth = 100; currentState.targetMax = 1000
scenarioActions = { action("Immolate", 1, "dot", 500, 100),
    action("Shoot", 1, "damage", 80, 0, { recovery = true }) }
plan = expect("dot target lifetime", "Shoot")
assert(plan.reason == "preserves resources", "a dying target should favor the zero-mana finisher over wasted ticks")

currentState = state("smart"); currentState.playerLevel = 60
currentState.targetResistances = { 0, 0, 240, 0, 0, 0, 0 }
XelAssistResistance = {
    Estimate = function(_, _, target, tooltip, s)
        local school = tooltip.school
        local raw = target == "target" and school and s.targetResistances[school + 1]
        if raw then
            local ratio = math.min(1, raw / (math.max(20, s.playerLevel) * 5))
            local mitigation = 0.75 * ratio - (3 / 16) * math.max(0, ratio - 2 / 3)
            return { school = school, schoolName = school == 2 and "Fire" or "Shadow",
                multiplier = 1 - mitigation, source = "test target data", unknown = false }
        end
        return { school = school, schoolName = school == 2 and "Fire" or "Shadow",
            multiplier = 1, source = "test target data", unknown = false }
    end,
    Contrast = function(_, _, chosen)
        if chosen.school == 5 then return "uses Shadow against elevated Fire resistance" end
    end,
}
scenarioActions = { action("Fireball", 1, "damage", 600, 100, { testSchool = 2 }),
    action("Shadow Bolt", 1, "damage", 430, 100, { testSchool = 5 }) }
plan = expect("pre-cast school resistance", "Shadow Bolt")
assert(plan.resistance and plan.resistance.school == 5
    and plan.reason == "uses Shadow against elevated Fire resistance",
    "the plan must expose why the better school won")
XelAssistResistance = nil

currentState = state("smart")
XelAssistResistance = {
    Estimate = function(_, candidate)
        if candidate.name == "Mystery Bolt" then
            return { school = nil, schoolName = "Unknown", multiplier = 1,
                source = "damage school unknown", unknown = true }
        end
        return { school = 5, schoolName = "Shadow", multiplier = 1,
            source = "known target data", unknown = false }
    end,
    Contrast = function() return nil end,
}
scenarioActions = { action("Mystery Bolt", 1, "damage", 100, 20),
    action("Known Bolt", 1, "damage", 95, 20, { testSchool = 5 }) }
expect("unknown resistance reserve", "Known Bolt")
XelAssistResistance = nil

currentState = state("smart")
XelAssistResistance = {
    Estimate = function()
        return { school = 5, schoolName = "Shadow", multiplier = 0.8,
            source = "1 context outcome", confidence = "limited samples",
            samples = 1, unknown = false }
    end,
    Contrast = function() return nil end,
}
scenarioActions = { action("Thin Evidence Bolt", 1, "damage", 100, 0,
    { testSchool = 5 }) }
plan = expect("limited resistance plan confidence", "Thin Evidence Bolt")
assert(plan.confidence == "partial data"
    and table.concat(plan.unknowns, ","):find("limited resistance evidence", 1, true),
    "limited learned resistance must not be labeled as complete client data")
XelAssistResistance = nil

currentState = state("smart"); currentState.targetCasting = true
XelAssistResistance = {
    Estimate = function(_, candidate)
        if candidate.name == "Unreliable Lock" then
            return { school = 5, schoolName = "Shadow", multiplier = 0.1,
                landChance = 0.1, source = "learned delivery", unknown = false }
        end
        return { school = 5, schoolName = "Shadow", multiplier = 1,
            landChance = 1, source = "known target data", unknown = false }
    end,
    Contrast = function() return nil end,
}
scenarioActions = { action("Unreliable Lock", 1, "interrupt", 0, 0, { testSchool = 5 }),
    action("Known Bolt", 1, "damage", 400, 20, { testSchool = 5 }) }
expect("resistance-aware effect delivery", "Known Bolt")
scenarioActions = { action("Earth Shock", 1, "damage", 100, 0,
        { testSchool = 5, interrupt = true }),
    action("Known Bolt", 1, "damage", 400, 20, { testSchool = 5 }) }
XelAssistResistance.Estimate = function(_, candidate)
    if candidate.name == "Earth Shock" then
        return { school = 5, schoolName = "Shadow", multiplier = 0.1,
            landChance = 0.1, source = "learned delivery", unknown = false }
    end
    return { school = 5, schoolName = "Shadow", multiplier = 1,
        landChance = 1, source = "known target data", unknown = false }
end
expect("damage interrupt delivery", "Known Bolt")
XelAssistResistance = nil

currentState = state("smart"); currentState.targetHealth = 10000; currentState.targetMax = 10000
currentState.targetDamageTaken = { [3] = 1 }
XelAssistResistance = {
    Estimate = function()
        return { school = nil, schoolName = "Mixed", multiplier = 0.75,
            source = "component test", unknown = false, mode = "mixed", components = {
                { school = 0, multiplier = 0.5, componentWeight = 0.5, unknown = false },
                { school = 3, multiplier = 1, componentWeight = 0.5, unknown = false },
            } }
    end,
    Contrast = function() return nil end,
}
scenarioActions = { action("Mixed Strike", 1, "damage", 100, 0) }
plan = expect("component resistance vulnerability product", "Mixed Strike")
assert(math.abs(plan.path[1].power - 125) < 0.0001,
    "mixed damage must sum each component's resistance times vulnerability")
XelAssistResistance.Estimate = function()
    return { school = nil, schoolName = "Mixed", multiplier = 0.55,
        source = "partial component test", unknown = true, mode = "mixed", components = {
            { school = 0, multiplier = 0.5, componentWeight = 0.9, unknown = false },
            { school = 3, multiplier = 1, componentWeight = 0.1, unknown = true },
        } }
end
currentState.targetDamageTaken = nil
plan = expect("component-local uncertainty reserve", "Mixed Strike")
assert(math.abs(plan.path[1].power - 54) < 0.0001,
    "unknown reserve must apply only to the unresolved mixed component")
XelAssistResistance = nil

currentState = state("smart"); currentState.targetHealth = 300; currentState.targetMax = 300
XelAssistCharDB.graphDepth = 3
scenarioActions = { action("Burn", 1, "dot", 300, 20, { testDuration = 6 }),
    action("Filler", 1, "damage", 30, 0),
    action("Execute", 1, "damage", 20, 0, { execute = 50 }) }
plan = expect("future periodic transitions", "Burn")
assert(plan.follow[1] and plan.follow[1].name == "Filler"
    and plan.follow[2] and plan.follow[2].name == "Execute",
    "active periodic damage must change later health-gated graph actions")

currentState = state("smart"); currentState.targetHealth = 60; currentState.targetMax = 100
XelAssistCharDB.graphDepth = 2
XelAssistResistance = {
    Estimate = function(_, candidate)
        if candidate.name == "Immolate" then
            return { school = 2, schoolName = "Fire", multiplier = 0.8275,
                source = "hybrid test", unknown = false, mode = "hybrid", components = {
                    { school = 2, multiplier = 0.625, componentWeight = 40,
                        componentPhase = "direct", unknown = false },
                    { school = 2, multiplier = 0.9625, componentWeight = 60,
                        componentPhase = "periodic", unknown = false },
                } }
        end
        return { school = 5, schoolName = "Shadow", multiplier = 1,
            source = "known target data", unknown = false }
    end,
    Contrast = function() return nil end,
}
scenarioActions = { action("Immolate", 1, "dot", 100, 10,
        { testSchool = 2, testDuration = 15, testDirectDamage = 40,
            testPeriodicDamage = 60 }),
    action("Execute", 1, "damage", 20, 0, { testSchool = 5, execute = 50 }) }
plan = expect("hybrid immediate direct transition", "Immolate")
assert(plan.follow[1] and plan.follow[1].name == "Execute",
    "hybrid direct damage and first periodic window must advance separately")
XelAssistResistance = nil; XelAssistCharDB.graphDepth = 1

currentState = state("smart"); XelAssistCharDB.graphDepth = 2
currentState.targetResistance = { projectedReduction = {} }
XelAssistResistance = {
    Estimate = function(_, _, actionTarget, tooltip, s)
        local reduction = s.targetResistance and s.targetResistance.projectedReduction
            and s.targetResistance.projectedReduction[2] or 0
        return { school = tooltip.school, schoolName = "Fire",
            multiplier = reduction >= 80 and 1 or 0.1,
            landChance = actionTarget == "target" and 0.8 or 1,
            source = reduction >= 80 and "projected resistance debuff" or "test resistance",
            unknown = false }
    end,
    Contrast = function() return nil end,
}
scenarioActions = {
    action("Curse of Elements", 1, "debuff", 0, 50,
        { ranged = true, testDuration = 300, testResistanceReduction = { [2] = 100 },
            testDamageTaken = { [2] = 0.06 } }),
    action("Fireball", 1, "damage", 600, 100, { testSchool = 2 }),
}
XelAssistCharDB.graphDepth = 1
expect("resistance debuff needs future value", "Fireball")
XelAssistCharDB.graphDepth = 2
plan = expect("projected resistance debuff cycle", "Curse of Elements")
assert(plan.follow[1] and plan.follow[1].name == "Fireball",
    "the future path must exploit its projected resistance reduction")
assert(math.abs(plan.path[2].resistance.damageTakenMultiplier - 1.048) < 0.0001,
    "the future path must probability-weight projected school vulnerability")
scenarioActions[1].mock.targetResistanceReduction = nil
scenarioActions[1].mock.targetDamageTaken = nil
expect("resistance debuff causal control", "Fireball")
scenarioActions[1].mock.targetResistanceReduction = { [2] = 100 }
scenarioActions[1].mock.targetDamageTaken = { [2] = 0.06 }
scenarioActions[1].mock.duration = 1
currentState.targetHealth, currentState.targetMax = 10000, 10000
XelAssistCharDB.graphDepth = 3
expect("modifier shorter than its GCD", "Fireball")
scenarioActions[1].mock.duration = 2
plan = expect("projected modifier expiry", "Curse of Elements")
assert(plan.path[2].resistance.multiplier == 1
    and plan.path[3].resistance.multiplier == 0.1
    and plan.path[3].resistance.damageTakenMultiplier == 1,
    "expired simulated debuffs must stop changing resistance and vulnerability")

currentState = state("smart"); currentState.targetHealth, currentState.targetMax = 10000, 10000
currentState.targetResistance = { live = { [2] = 55 }, projectedReduction = {} }
currentState.targetDamageTaken, currentState.baseTargetDamageTaken = { [2] = 0.06 }, {}
currentState.targetModifierEffects = { ["Curse of Elements"] = {
    resistanceReduction = { [2] = 45 }, damageTaken = { [2] = 0.06 },
    activeRoot = true, liveIncluded = true } }
currentState.auras = { ["Curse of Elements"] = { remaining = 1,
    target = "target", targetModifier = true } }
currentState.targetAuras = { ["Curse of Elements"] = { remaining = 1, mine = true } }
XelAssistCharDB.graphDepth = 2
XelAssistResistance.Estimate = function(_, _, _, tooltip, s)
    local delta = s.targetResistance and s.targetResistance.projectedReduction
        and s.targetResistance.projectedReduction[2] or 0
    return { school = tooltip.school, schoolName = "Fire",
        multiplier = delta < 0 and 0.5 or 1, source = "active expiry test", unknown = false }
end
scenarioActions = { action("Fireball", 1, "damage", 100, 0, { testSchool = 2 }) }
plan = expect("active live modifier expiry", "Fireball")
assert(plan.path[1].resistance.damageTakenMultiplier == 1.06
    and plan.path[2].resistance.multiplier == 0.5
    and plan.path[2].resistance.damageTakenMultiplier == 1,
    "an expiring active live modifier must restore resistance and remove vulnerability")
XelAssistResistance = nil; XelAssistCharDB.graphDepth = 1

currentState = state("smart"); currentState.targetHealth, currentState.targetMax = 10000, 10000
currentState.targetDamageTaken, currentState.baseTargetDamageTaken = { [2] = 0.265 }, {}
currentState.targetModifierEffects = {
    ["Minor Fire Exposure"] = { name = "Minor Fire Exposure",
        group = "sharedFireExposure", damageTaken = { [2] = 0.06 } },
    ["Major Fire Exposure"] = { name = "Major Fire Exposure",
        group = "sharedFireExposure", damageTaken = { [2] = 0.10 } },
    ["Independent Fire Exposure"] = { name = "Independent Fire Exposure",
        group = "independentFireExposure", damageTaken = { [2] = 0.15 } },
}
currentState.auras = {
    ["Minor Fire Exposure"] = { remaining = 5, targetModifier = true },
    ["Major Fire Exposure"] = { remaining = 1, targetModifier = true },
    ["Independent Fire Exposure"] = { remaining = 5, targetModifier = true },
}
XelAssistResistance = {
    Estimate = function()
        return { school = 2, schoolName = "Fire", multiplier = 1,
            source = "impact stacking test", unknown = false }
    end,
    Contrast = function() return nil end,
}
scenarioActions = { action("Slow Fireball", 1, "damage", 100, 0,
    { testSchool = 2, cast = 2 }) }
plan = expect("damage modifier expiry at impact", "Slow Fireball")
assert(math.abs(plan.path[1].resistance.damageTakenMultiplier - 1.219) < 0.0001,
    "impact state must drop an expired stronger shared-group modifier while preserving independent stacking")
XelAssistResistance = nil

currentState = state("smart"); currentState.targetHealth, currentState.targetMax = 10000, 10000
currentState.targetResistance = { projectedReduction = {} }
XelAssistCharDB.graphDepth = 2
XelAssistResistance = {
    Estimate = function(_, _, _, tooltip, s)
        local reduction = s.targetResistance and s.targetResistance.projectedReduction
            and s.targetResistance.projectedReduction[2] or 0
        return { school = tooltip.school, schoolName = "Fire",
            multiplier = reduction >= 100 and 1 or 0.1,
            landChance = 1, source = "beam setup test", unknown = false }
    end,
    Contrast = function() return nil end,
}
scenarioActions = {
    action("Expose Fire", 1, "debuff", 0, 0,
        { resistanceDebuff = true, testDuration = 30,
            testResistanceReduction = { [2] = 100 } }),
}
local fillerIndex
for fillerIndex = 1, 6 do
    table.insert(scenarioActions, action("Fire " .. fillerIndex, 1,
        "damage", 600, 0, { testSchool = 2 }))
end
plan = expect("beam preserves resistance setup", "Expose Fire")
assert(plan.follow[1] and string.find(plan.follow[1].name, "Fire ", 1, true) == 1,
    "WIDTH pruning must retain a useful target-modifier branch long enough to exploit it")

currentState = state("smart"); XelAssistCharDB.graphDepth = 2
XelAssistResistance.Estimate = function()
    return { school = 5, schoolName = "Shadow", multiplier = 0.1,
        landChance = 0.1, source = "uncertain application test", unknown = false }
end
scenarioActions = { action("Unreliable Hex", 1, "debuff", 0, 0,
    { testSchool = 5, testDuration = 10 }) }
plan = expect("uncertain application retry", "Unreliable Hex")
assert(plan.follow[1] and plan.follow[1].name == "Unreliable Hex",
    "a ten-percent projected debuff application must not become certainly active in next-X")

currentState = state("smart"); currentState.targetHealth, currentState.targetMax = 10000, 10000
currentState.actorReadyAt = { player = 0, pet = 1 }
currentState.actors.pet = { health = 1000, healthMax = 1000,
    resource = 300, resourceMax = 300, targetExists = true,
    targetsCurrent = true, hasAggro = false, distance = 20 }
currentState.targetDamageTaken, currentState.baseTargetDamageTaken = { [2] = 0.5 }, {}
currentState.targetModifierEffects = { ["Uncertain Exposure"] = {
    name = "Uncertain Exposure", group = "Uncertain Exposure",
    damageTaken = { [2] = 0.5 }, resistanceReduction = {}, activeRoot = true } }
currentState.auras = { ["Uncertain Exposure"] = { remaining = 4, duration = 20,
    mine = true, target = "target", targetModifier = true } }
currentState.targetAuras = { ["Uncertain Exposure"] = {
    remaining = 4, duration = 20, mine = true } }
XelAssistResistance.Estimate = function(_, _, _, tooltip)
    if tooltip.targetDamageTaken then
        return { school = 2, schoolName = "Fire", multiplier = 1,
            landChance = 0.1, source = "uncertain refresh test", unknown = false }
    end
    return { school = tooltip.school, schoolName = "Fire", multiplier = 1,
        landChance = 1, source = "uncertain refresh test", unknown = false }
end
scenarioActions = {
    action("Uncertain Exposure", 1, "debuff", 0, 0,
        { testSchool = 2, testDuration = 20, testDamageTaken = { [2] = 0.5 } }),
    petAction("Pet Firebolt", "damage", 100, 0, { testSchool = 2, ranged = true }),
}
plan = expect("uncertain modifier refresh", "Uncertain Exposure")
assert(plan.follow[1] and plan.follow[1].name == "Pet Firebolt"
    and math.abs(plan.path[2].resistance.damageTakenMultiplier - 1.5) < 0.0001,
    "a failed uncertain refresh branch must preserve the still-active prior modifier")

currentState = state("smart"); currentState.targetHealth, currentState.targetMax = 80, 100
currentState.targetDamageTaken, currentState.baseTargetDamageTaken = { [2] = 1 }, {}
currentState.targetModifierEffects = { ["Short Fire Exposure"] = {
    name = "Short Fire Exposure", group = "Short Fire Exposure",
    damageTaken = { [2] = 1 }, resistanceReduction = {} } }
currentState.auras = { ["Short Fire Exposure"] = { remaining = 1,
    duration = 10, target = "target", targetModifier = true } }
XelAssistCharDB.graphDepth = 3
XelAssistResistance.Estimate = function(_, _, _, tooltip)
    return { school = tooltip.school, schoolName = "Fire", multiplier = 1,
        landChance = 1, source = "periodic overlap test", unknown = false }
end
scenarioActions = {
    action("Long Burn", 1, "dot", 100, 0, { testSchool = 2, testDuration = 10 }),
    action("Filler", 1, "damage", 1, 0, { testSchool = 2 }),
    action("Execute", 1, "damage", 1, 0, { testSchool = 2, execute = 50 }),
}
plan = expect("periodic modifier overlap", "Long Burn")
assert(math.abs(plan.path[1].power - 110) < 0.0001
    and plan.follow[1] and plan.follow[1].name == "Filler"
    and plan.follow[2] and plan.follow[2].name == "Execute",
    "an expiring target modifier must affect only overlapping DoT time, including stored future damage")

currentState = state("smart"); currentState.targetHealth, currentState.targetMax = 1000, 1000
currentState.targetDamageTaken, currentState.baseTargetDamageTaken = { [2] = 1 }, {}
currentState.targetModifierEffects = { ["Short Fire Exposure"] = {
    name = "Short Fire Exposure", group = "Short Fire Exposure",
    damageTaken = { [2] = 1 }, resistanceReduction = {} } }
currentState.auras = { ["Short Fire Exposure"] = { remaining = 1,
    duration = 10, target = "target", targetModifier = true } }
XelAssistCharDB.graphDepth = 1
scenarioActions = { action("Long Channel", 1, "damage", 100, 0,
    { channel = true, testSchool = 2, testDuration = 5 }) }
plan = expect("channel modifier overlap", "Long Channel")
assert(math.abs(plan.path[1].power - 120) < 0.0001,
    "a channel must integrate target modifiers across its occupied window")

currentState = state("smart"); currentState.targetHealth, currentState.targetMax = 100, 100
local lingeringDot = action("Lingering Dot", 1, "dot", 100, 0,
    { testSchool = 2, testDuration = 10 })
currentState.auras = { ["Lingering Dot"] = { remaining = 10, duration = 10,
    mine = true, target = "target", periodicRate = 10, periodicRawRate = 10,
    periodicAction = lingeringDot, periodicTooltip = { school = 2 },
    applicationProbability = 1 } }
XelAssistCharDB.graphDepth = 3
scenarioActions = {
    action("Fresh Fire Exposure", 1, "debuff", 0, 0,
        { testSchool = 2, testDuration = 10, testDamageTaken = { [2] = 1 } }),
    action("Filler", 1, "damage", 1, 0, { testSchool = 2 }),
    action("Execute", 1, "damage", 1, 0, { testSchool = 2, execute = 50 }),
}
plan = expect("new modifier changes stored ticks", "Fresh Fire Exposure")
assert(plan.follow[1] and plan.follow[1].name == "Filler"
    and plan.follow[2] and plan.follow[2].name == "Execute",
    "a newly applied modifier must affect subsequent damage from an already stored DoT")

XelAssistResistance = nil

local function ambientState(unknownAmbient, health)
    local value = state("smart")
    value.targetHealth, value.targetMax = health, 120
    value.actorReadyAt = { player = 0, pet = 1 }
    value.actors.pet = { health = 1000, healthMax = 1000,
        resource = 300, resourceMax = 300, targetExists = true,
        targetsCurrent = true, hasAggro = false, distance = 20,
        autocasts = { { name = "Ambient Firebolt", actor = "pet", kind = "damage",
            facts = { kind = "damage" }, power = 30, cost = 0,
            cooldown = 10, readyIn = 0.5, tooltip = { school = 2 },
            unknownTest = unknownAmbient } } }
    return value
end

XelAssistResistance = {
    Estimate = function(_, candidate, _, tooltip)
        local unknown = candidate.unknownTest and true or false
        return { school = tooltip.school or 2, schoolName = "Fire", multiplier = 1,
            landChance = 1, source = "ambient modifier test", unknown = unknown }
    end,
    Contrast = function() return nil end,
}
XelAssistCharDB.graphDepth = 2
scenarioActions = {
    action("Ambient Fire Exposure", 1, "debuff", 0, 0,
        { testSchool = 2, testDuration = 10, testDamageTaken = { [2] = 1 } }),
    petAction("Pet Execute", "damage", 1, 0, { testSchool = 2, execute = 50 }),
    petAction("Pet Filler", "damage", 1, 0, { testSchool = 2 }),
}
currentState = ambientState(false, 112)
plan = expect("ambient pet uses new modifier", "Ambient Fire Exposure")
assert(plan.follow[1] and plan.follow[1].name == "Pet Execute",
    "a modifier applied before an ambient pet event must affect that event's damage")
currentState = ambientState(true, 116)
plan = expect("ambient pet uncertainty reserve", "Ambient Fire Exposure")
assert(plan.follow[1] and plan.follow[1].name == "Pet Filler",
    "ambient pet damage must include the same uncertainty reserve as recommended actions")

currentState = state("smart"); currentState.targetHealth, currentState.targetMax = 10000, 10000
currentState.actorReadyAt = { player = 0, pet = 1 }
currentState.actors.pet = { health = 1000, healthMax = 1000,
    resource = 300, resourceMax = 300, targetExists = true,
    targetsCurrent = true, hasAggro = false, distance = 20 }
currentState.targetDamageTaken, currentState.baseTargetDamageTaken = {
    [2] = 1, [5] = 1 }, {}
currentState.targetModifierEffects = {
    ["Own Fire Curse"] = { name = "Own Fire Curse", group = "Own Fire Curse",
        exclusiveFamily = "warlockCurse", mine = true,
        damageTaken = { [2] = 1 }, resistanceReduction = {} },
    ["Party Shadow Curse"] = { name = "Party Shadow Curse", group = "Party Shadow Curse",
        exclusiveFamily = "warlockCurse", mine = false,
        damageTaken = { [5] = 1 }, resistanceReduction = {} },
}
currentState.auras = {
    ["Own Fire Curse"] = { remaining = 20, duration = 20, target = "target",
        targetModifier = true, exclusiveFamily = "warlockCurse", mine = true },
    ["Party Shadow Curse"] = { remaining = 20, duration = 20, target = "target",
        targetModifier = true, exclusiveFamily = "warlockCurse", mine = false },
}
currentState.targetAuras = {
    ["Own Fire Curse"] = { remaining = 20, duration = 20, mine = true },
    ["Party Shadow Curse"] = { remaining = 20, duration = 20, mine = false },
}
XelAssistCharDB.graphDepth = 2
scenarioActions = {
    action("Own Weakness Curse", 1, "debuff", 0, 0,
        { testDuration = 20, exclusiveFamily = "warlockCurse" }),
    petAction("Pet Fire", "damage", 100, 0, { testSchool = 2 }),
    petAction("Pet Shadow", "damage", 80, 0, { testSchool = 5 }),
}
plan = expect("exclusive own curse family", "Own Weakness Curse")
assert(plan.follow[1] and plan.follow[1].name == "Pet Shadow",
    "a new own curse must replace the prior own curse without erasing a party member's curse")
XelAssistResistance = nil

currentState = state("smart"); currentState.health = 150; currentState.healthMax = 1000
currentState.healHealth = 1000; currentState.healMax = 1000; currentState.inCombat = true
currentState.inventory = { itemCounts = { [13446] = 1 } }
XelAssistCharDB.toggles.consumables = true; XelAssistCharDB.graphDepth = 2
scenarioActions = { action("Shadow Bolt", 1, "damage", 200, 100) }
scenarioItems = { itemAction("Major Healing Potion", "heal", 700) }
plan = expect("effective self consumable", "Major Healing Potion")
assert(plan.target == "player", "a healing consumable must target the player")
assert(plan.follow[1] and plan.follow[1].name ~= "Major Healing Potion",
    "future graph state must put the consumed item on cooldown")
XelAssistCharDB.toggles.consumables = false; XelAssistCharDB.graphDepth = 1
expect("consumable opt-in", "Shadow Bolt")
scenarioItems = {}; XelAssistCharDB.graphDepth = 2

currentState = state("smart")
scenarioActions = { action("Burst", 1, "damage", 600, 40, { testCooldown = 10 }),
    action("Filler", 1, "damage", 250, 20) }
plan = expect("future cooldown", "Burst")
assert(plan.follow[1] and plan.follow[1].name == "Filler", "future action should respect own cooldown")

currentState = state("smart"); currentState.resource = 1000; currentState.resourceMax = 1000
scenarioActions = { action("All In", 1, "damage", 500, 1000),
    action("Sustainable", 1, "damage", 350, 500) }
plan = expect("path lookahead", "Sustainable")
assert(plan.follow[1] and plan.follow[1].name == "Sustainable", "beam should prefer the stronger complete path")

currentState = state("smart")
scenarioActions = { action("Shared One", 1, "damage", 600, 20,
        { testGroup = 7, testCategoryCooldown = 8 }),
    action("Shared Two", 1, "damage", 500, 20,
        { testGroup = 7, testCategoryCooldown = 8 }),
    action("Free Filler", 1, "damage", 200, 20) }
plan = expect("shared cooldown", "Shared One")
assert(plan.follow[1] and plan.follow[1].name == "Free Filler", "shared cooldown must block sibling actions")

-- Representative class mechanics still flow through the same evaluator.
XelAssistCharDB.graphDepth = 1
currentState = state("smart"); currentState.tank = true; currentState.role = "tank"; currentState.groupSize = 4
scenarioActions = { action("Shield Slam", 1, "damage", 300, 20, { threat = 2 }),
    action("Mortal Strike", 1, "damage", 350, 20, { threat = 1 }) }
expect("warrior tank threat", "Shield Slam")

currentState = state("smart"); currentState.targetCasting = true; currentState.pet = false
scenarioActions = { action("Spell Lock", 1, "interrupt", 0, 0, { pet = true }),
    action("Shadow Bolt", 1, "damage", 300, 20) }
expect("warlock missing pet", "Shadow Bolt")

currentState = state("smart"); currentState.combo = 0
scenarioActions = { action("Eviscerate", 1, "damage", 700, 35, { combo = true }),
    action("Sinister Strike", 1, "builder", 200, 45) }
expect("rogue combo prerequisite", "Sinister Strike")

currentState = state("smart"); currentState.combo = 5; XelAssistCharDB.graphDepth = 2
scenarioActions = { action("Eviscerate", 1, "damage", 700, 35, { combo = true }),
    action("Sinister Strike", 1, "builder", 100, 45) }
plan = expect("finisher consumes combo", "Eviscerate")
assert(plan.follow[1] and plan.follow[1].name == "Sinister Strike",
    "a finisher must consume combo points in future state")

currentState = state("smart"); XelAssistCharDB.toggles.reagents = false
scenarioActions = { action("Shadowburn", 1, "damage", 900, 100,
        { reagent = true, reagentName = "Soul Shard", execute = 20 }),
    action("Shadow Bolt", 1, "damage", 300, 100) }
expect("warlock reagent policy", "Shadow Bolt")
XelAssistCharDB.toggles.reagents = true
currentState.targetHealth = 100; currentState.targetMax = 1000
currentState.inventory = { reagentCounts = { ["Soul Shard"] = 0 } }
expect("warlock reagent count", "Shadow Bolt")

currentState = state("smart"); XelAssistCharDB.allowAoe = false
scenarioActions = { action("Blizzard", 1, "damage", 1200, 300, { aoe = true }),
    action("Frostbolt", 1, "damage", 300, 100) }
expect("mage smart area safety", "Frostbolt")

currentState = state("smart"); currentState.pet = true; currentState.targetCasting = true
currentState.actorReadyAt = { player = 3, pet = 0 }
currentState.actors.pet = { health = 1000, healthMax = 1000, resource = 300, resourceMax = 300,
    targetExists = true, targetsCurrent = true, hasAggro = false, distance = 20 }
scenarioActions = { petAction("Spell Lock", "interrupt", 0, 40, { ranged = true }),
    action("Shadow Bolt", 1, "damage", 600, 100) }
plan = expect("felhunter interrupt", "Spell Lock")
assert(plan.actor == "pet", "the graph must retain the independently acting companion")
assert(plan.downtime < 0.2, "pet interrupt must remain independent of the player's cast/GCD clock")

currentState.targetCasting = false; currentState.actors.pet.resource = 0
scenarioActions = { petAction("Firebolt", "damage", 800, 50, { ranged = true }),
    action("Shadow Bolt", 1, "damage", 250, 100) }
expect("pet resource isolation", "Shadow Bolt")

currentState = state("smart"); currentState.pet = true
currentState.actors.pet = { health = 1000, healthMax = 1000, resource = 300, resourceMax = 300,
    targetExists = false, targetsCurrent = false, hasAggro = false, distance = 5 }
scenarioActions = { { name = "Pet Attack", rank = 1, actor = "pet", executor = "petCommand",
        command = "attack", facts = { kind = "command", petCommand = true },
        mock = { cost = 0, cast = 0, gcd = 0 } },
    action("Shadow Bolt", 1, "damage", 100, 20) }
expect("companion attack command", "Pet Attack")
currentState.actors.pet.targetExists = true; currentState.actors.pet.targetsCurrent = true
scenarioActions = { { name = "Pet Attack", rank = 1, actor = "pet", executor = "petCommand",
        command = "attack", facts = { kind = "command", petCommand = true },
        mock = { cost = 0, cast = 0, gcd = 0 } }, action("Shadow Bolt", 1, "damage", 100, 20) }
expect("no duplicate companion attack", "Shadow Bolt")

currentState.actors.pet.health = 100; currentState.actors.pet.targetExists = true
currentState.actors.pet.targetsCurrent = true
scenarioActions = { { name = "Pet Follow", rank = 1, actor = "pet", executor = "petCommand",
        command = "follow", facts = { kind = "command", petCommand = true },
        mock = { cost = 0, cast = 0, gcd = 0 } },
    action("Shadow Bolt", 1, "damage", 300, 20) }
expect("endangered companion retreat", "Pet Follow")

currentState.actors.pet.stance = "defensive"
scenarioActions = { { name = "Pet Passive", rank = 1, actor = "pet", executor = "petCommand",
        command = "passive", facts = { kind = "command", petCommand = true },
        mock = { cost = 0, cast = 0, gcd = 0 } },
    action("Shadow Bolt", 1, "damage", 300, 20) }
expect("endangered companion stance", "Pet Passive")

currentState = state("smart"); currentState.pet = true; currentState.hasAggro = true
currentState.actors.pet = { health = 1000, healthMax = 1000, resource = 300, resourceMax = 300,
    targetExists = true, targetsCurrent = true, hasAggro = false, distance = 3 }
XelAssistCharDB.petThreat = "auto"
scenarioActions = { petAction("Torment", "taunt", 0, 50, { melee = true, threat = 3 }),
    action("Shadow Bolt", 1, "damage", 200, 20) }
expect("solo voidwalker taunt", "Torment")
currentState.groupSize = 4
expect("group taunt avoidance", "Shadow Bolt")

currentState = state("smart"); currentState.playerBehindTarget = false
scenarioActions = { action("Backstab", 1, "builder", 900, 60, { behind = true }),
    action("Sinister Strike", 1, "builder", 200, 45) }
expect("positional prerequisite", "Sinister Strike")

currentState = state("smart"); currentState.targetDistance = 5
currentState.actors.pet = { health = 1000, healthMax = 1000, resource = 300, resourceMax = 300,
    targetExists = true, targetsCurrent = true, hasAggro = false, distance = 40 }
scenarioActions = { petAction("Firebolt", "damage", 800, 20,
        { ranged = true, testMaxRange = 30 }), action("Shadow Bolt", 1, "damage", 200, 20) }
expect("independent pet range far", "Shadow Bolt")
currentState.targetDistance = 40; currentState.actors.pet.distance = 5
scenarioActions = { petAction("Firebolt", "damage", 800, 20, { ranged = true, testMaxRange = 30 }) }
expect("independent pet range near", "Firebolt")

currentState = state("support"); currentState.health = 1000; currentState.healthMax = 1000
currentState.hasAggro = true
scenarioActions = { action("Power Word: Shield", 1, "absorb", 500, 100, { self = true }) }
plan = expect("absorb is not healing", "Power Word: Shield")
assert(plan.observed.health == 1000, "observed health remains unchanged by a projected absorb")

currentState = state("smart"); currentState.pet = true; currentState.health = 300
currentState.actors.pet = { health = 900, healthMax = 1000, resource = 300, resourceMax = 300,
    targetExists = true, targetsCurrent = true, hasAggro = true, distance = 3 }
XelAssistCharDB.graphDepth = 2
scenarioActions = { petAction("Sacrifice", "absorb", 700, 0, { petSacrifice = true }),
    action("Summon Voidwalker", 1, "summon", 0, 200,
        { summonRole = "tank", summonFamily = "Voidwalker", reagent = true, reagentName = "Soul Shard" }) }
plan = expect("voidwalker sacrifice", "Sacrifice")
assert(plan.target == "player", "Sacrifice must shield the player, not the demon")
assert(plan.follow[1] and plan.follow[1].name == "Summon Voidwalker",
    "the projected graph must remove the sacrificed demon before considering a replacement")

currentState = state("smart"); currentState.pet = false; currentState.actors.pet = nil
currentState.inCombat = false; XelAssistCharDB.graphDepth = 1
reagentAvailable = false
scenarioActions = { action("Summon Voidwalker", 1, "summon", 0, 200,
    { summonRole = "tank", summonFamily = "Voidwalker", reagent = true, reagentName = "Soul Shard" }) }
local noShard = XelAssistGraph:Evaluate("smart", true)
assert(noShard == nil, "a shard-costing demon must not be recommended without a Soul Shard")
reagentAvailable = true
expect("missing solo companion", "Summon Voidwalker")

currentState = state("smart"); currentState.pet = true; currentState.inCombat = true
currentState.actors.pet = { health = 100, healthMax = 1000, resource = 300, resourceMax = 300,
    targetExists = false, targetsCurrent = false, hasAggro = false, distance = 3 }
scenarioActions = { petAction("Consume Shadows", "petHeal", 700, 0,
        { channel = true, outOfCombat = true }), action("Shadow Bolt", 1, "damage", 200, 20) }
expect("consume shadows combat gate", "Shadow Bolt")

currentState = state("smart"); currentState.pet = true
currentState.actors.pet = { health = 1000, healthMax = 1000, resource = 300, resourceMax = 300,
    targetExists = true, targetsCurrent = true, hasAggro = false, distance = 20 }
dispelTarget = nil
scenarioActions = { petAction("Devour Magic", "dispel", 0, 60, { ranged = true }),
    action("Shadow Bolt", 1, "damage", 200, 20) }
expect("devour requires magic aura", "Shadow Bolt")
dispelTarget = "target"
scenarioActions = { petAction("Devour Magic", "dispel", 0, 60, { ranged = true }) }
expect("felhunter devour", "Devour Magic")
dispelTarget = "party1"
scenarioActions = { petAction("Devour Magic", "dispel", 0, 60, { ranged = true }),
    action("Shadow Bolt", 1, "damage", 200, 20) }
expect("pet friendly target safety", "Shadow Bolt")

print("ok: rank, aggro, interrupt, movement, range, aura, cooldown and beam scenarios")
