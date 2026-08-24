XelAssistGraph = {}
local G = XelAssistGraph

local MAX_STATES = 80
local MAX_MS = 3
local WIDTH = 4
local MAX_DEPTH = 5
local APPLICATION_BLOCK_THRESHOLD = 0.75

local function pct(unit)
    local maximum = UnitHealthMax(unit) or 0
    if maximum <= 0 then return 100 end
    return (UnitHealth(unit) or 0) * 100 / maximum
end

local function bestFriendly()
    if UnitExists("mouseover") and UnitCanAssist("player", "mouseover") and not UnitIsDead("mouseover") then
        return "mouseover", UnitHealth("mouseover") or 0, UnitHealthMax("mouseover") or 0
    end
    if UnitExists("target") and UnitCanAssist("player", "target") and not UnitIsDead("target") then
        return "target", UnitHealth("target") or 0, UnitHealthMax("target") or 0
    end
    local best, health, maximum = "player", UnitHealth("player") or 0, UnitHealthMax("player") or 0
    local raid = GetNumRaidMembers and GetNumRaidMembers() or 0
    local party = GetNumPartyMembers and GetNumPartyMembers() or 0
    local i
    if raid > 0 then
        for i = 1, raid do
            local unit = "raid" .. i
            if UnitExists(unit) and not UnitIsDead(unit) and pct(unit) < pct(best) then
                best, health, maximum = unit, UnitHealth(unit) or 0, UnitHealthMax(unit) or 0
            end
        end
    else
        for i = 1, party do
            local unit = "party" .. i
            if UnitExists(unit) and not UnitIsDead(unit) and pct(unit) < pct(best) then
                best, health, maximum = unit, UnitHealth(unit) or 0, UnitHealthMax(unit) or 0
            end
        end
    end
    return best, health, maximum
end

local function inferredTank()
    local _, class = UnitClass("player")
    local form = GetShapeshiftForm and GetShapeshiftForm() or 0
    if class == "WARRIOR" and form == 2 then return true end
    if class == "DRUID" and form == 1 then return true end
    if class == "PALADIN" and XelAssistCapabilities:UnitHasBuff("player", "Righteous Fury") then return true end
    return false
end

local function aggregateModifierReductions(effects)
    return XelAssistTargetModifiers:AggregateReductions(effects)
end

local function aggregateDamageTakenModifiers(effects, base)
    return XelAssistTargetModifiers:AggregateDamageTaken(effects, base)
end

-- Compatibility surface for diagnostics/tests; resistance observations call
-- the shared module directly and no longer depend back on the graph.
function G:ActiveTargetModifiers(encounter, targetResistance)
    return XelAssistTargetModifiers:Active(encounter, targetResistance)
end

local function targetAuraState(encounter)
    local observed = encounter and encounter.targetHarmful
        and encounter.targetHarmful.byName or {}
    local families, actions, i = {}, XelAssistActors and XelAssistActors:Actions() or {}, nil
    for i = 1, table.getn(actions) do
        local action = actions[i]
        if action and action.name and action.facts and action.facts.exclusiveFamily then
            families[action.name] = action.facts.exclusiveFamily
        end
    end
    local out, name, aura = {}, nil, nil
    for name, aura in pairs(observed) do
        if type(aura) == "table" then
            local copy, key, value = {}, nil, nil
            for key, value in pairs(aura) do copy[key] = value end
            copy.exclusiveFamily = copy.exclusiveFamily or families[name]
            out[name] = copy
        else out[name] = aura end
    end
    return out
end

function G:Snapshot(mode)
    local actors = XelAssistActors:Snapshot()
    local encounter = XelAssistEncounter and XelAssistEncounter:Snapshot() or nil
    local inventory = XelAssistInventory and XelAssistInventory:Snapshot() or nil
    local healUnit, healHealth, healMax = bestFriendly()
    local castName, castRemaining, casting, gcdRemaining = XelAssistCapabilities:CurrentCast()
    if not casting and XelAssist and XelAssist.playerCastUntil and XelAssist.playerCastUntil > GetTime() then
        castName, castRemaining, casting = XelAssist.playerCastName,
            XelAssist.playerCastUntil - GetTime(), true
    end
    local hostile = UnitExists("target") and not UnitIsDead("target") and UnitCanAttack("player", "target")
    local targetHealth, targetMax, targetHealthExact = 0, 0, false
    if hostile then targetHealth, targetMax, targetHealthExact = XelAssistCapabilities:Health("target") end
    local role = XelAssistCharDB.role or "auto"
    local targetDistance, targetDistanceKind = XelAssistCapabilities:Distance(hostile and "target" or nil)
    local healDistance, healDistanceKind = XelAssistCapabilities:Distance(healUnit)
    local distance = hostile and targetDistance or healDistance
    local distanceKind = hostile and targetDistanceKind or healDistanceKind
    local targetGeometry = XelAssistCapabilities:Geometry("player", "target")
    local _, currentTargetGUID = UnitExists("target")
    local targetCasting = XelAssist and XelAssist.targetCastUntil
        and XelAssist.targetCastUntil > GetTime()
        and XelAssist.targetCastGUID == currentTargetGUID
    local targetResistance = hostile and XelAssistResistance
        and XelAssistResistance:Snapshot("target", encounter) or nil
    if targetResistance then targetResistance.baseProjectedReduction = {} end
    local activeReduction, targetDamageTaken, activeModifierSource,
        activeModifierEffects, rootModifierAuras =
        self:ActiveTargetModifiers(encounter, targetResistance)
    if targetResistance and activeReduction then
        targetResistance.rootModifierReduction = activeReduction
        if not targetResistance.live then
            targetResistance.projectedReduction = activeReduction
            targetResistance.projectedBy = "active "
                .. tostring(activeModifierSource or "target debuff")
        end
    end
    return {
        mode = mode, hostile = hostile, healUnit = healUnit,
        health = UnitHealth("player") or 0, healthMax = UnitHealthMax("player") or 0,
        healHealth = healHealth, healMax = healMax,
        targetHealth = targetHealth, targetMax = targetMax, targetHealthExact = targetHealthExact,
        targetCreatureType = hostile and UnitCreatureType and UnitCreatureType("target") or nil,
        targetResistances = targetResistance and targetResistance.live or nil,
        targetResistance = targetResistance,
        targetDamageTaken = targetDamageTaken,
        baseTargetDamageTaken = activeModifierEffects and {} or nil,
        targetModifierEffects = activeModifierEffects,
        activeModifierSource = activeModifierSource,
        playerLevel = UnitLevel and UnitLevel("player") or nil,
        inCombat = UnitAffectingCombat and UnitAffectingCombat("player") and true or false,
        resource = UnitMana("player") or 0, resourceMax = UnitManaMax("player") or 0,
        resourceType = UnitPowerType and UnitPowerType("player") or nil,
        combo = GetComboPoints and GetComboPoints() or 0,
        moving = PlayerIsMoving and PlayerIsMoving() or false,
        pet = actors.pet ~= nil, actors = actors, inventory = inventory, encounter = encounter,
        targetAuras = targetAuraState(encounter),
        targetCasting = targetCasting and true or false,
        targetCastRemaining = targetCasting and (XelAssist.targetCastUntil - GetTime()) or 0,
        playerCasting = casting, playerCastName = castName, castRemaining = castRemaining or 0,
        groupSize = (GetNumRaidMembers and GetNumRaidMembers() or 0) + (GetNumPartyMembers and GetNumPartyMembers() or 0),
        hasAggro = hostile and UnitExists("targettarget") and UnitIsUnit("targettarget", "player"),
        tank = role == "tank" or (role == "auto" and inferredTank()), role = role,
        distance = distance, distanceKind = distanceKind,
        targetDistance = targetDistance, targetDistanceKind = targetDistanceKind,
        targetLineOfSight = targetGeometry.lineOfSight,
        playerBehindTarget = targetGeometry.behind,
        healDistance = healDistance, healDistanceKind = healDistanceKind,
        talentPoints = XelAssistCapabilities:TalentPoints(),
        instantNext = XelAssistCapabilities:UnitHasBuff("player", "Nature's Swiftness")
            or XelAssistCapabilities:UnitHasBuff("player", "Presence of Mind"),
        auras = rootModifierAuras or {}, absorbs = {}, readyAt = {}, time = 0,
        actorReadyAt = { player = math.max(castRemaining or 0,
            gcdRemaining or 0, XelAssistCapabilities:GCDRemaining()),
            pet = actors.pet and (actors.pet.castRemaining or 0) or 0 },
    }
end

local function copyNested(value, depth)
    if type(value) ~= "table" or depth <= 0 then return value end
    local out, key, entry = {}, nil, nil
    for key, entry in pairs(value) do out[key] = copyNested(entry, depth - 1) end
    return out
end

local function copyState(s)
    local out, key, value = {}, nil, nil
    for key, value in pairs(s) do out[key] = value end
    out.auras = {}
    for key, value in pairs(s.auras) do
        if type(value) == "table" then
            local auraCopy, auraKey, auraValue = {}, nil, nil
            for auraKey, auraValue in pairs(value) do auraCopy[auraKey] = auraValue end
            out.auras[key] = auraCopy
        else out.auras[key] = value end
    end
    out.absorbs = {}; for key, value in pairs(s.absorbs or {}) do out.absorbs[key] = value end
    out.readyAt = {}; for key, value in pairs(s.readyAt) do out.readyAt[key] = value end
    out.actorReadyAt = {}; for key, value in pairs(s.actorReadyAt or {}) do out.actorReadyAt[key] = value end
    if s.actors then out.actors = copyNested(s.actors, 4) end
    if s.targetAuras then out.targetAuras = copyNested(s.targetAuras, 3) end
    if s.targetResistance then out.targetResistance = copyNested(s.targetResistance, 4) end
    if s.targetDamageTaken then out.targetDamageTaken = copyNested(s.targetDamageTaken, 2) end
    if s.baseTargetDamageTaken then
        out.baseTargetDamageTaken = copyNested(s.baseTargetDamageTaken, 2)
    end
    if s.targetModifierEffects then
        out.targetModifierEffects = copyNested(s.targetModifierEffects, 4)
    end
    if s.inventory then
        out.inventory = {}; for key, value in pairs(s.inventory) do out.inventory[key] = value end
        if s.inventory.itemCounts then
            out.inventory.itemCounts = {}
            for key, value in pairs(s.inventory.itemCounts) do out.inventory.itemCounts[key] = value end
        end
        if s.inventory.reagentCounts then
            out.inventory.reagentCounts = {}
            for key, value in pairs(s.inventory.reagentCounts) do out.inventory.reagentCounts[key] = value end
        end
    end
    return out
end

local stateAtImpact
local resistanceOverWindow

local function actionTarget(action, s)
    local kind = action.facts.kind
    if action.actor == "pet" then
        if kind == "petHeal" then return "pet" end
        if action.facts.petSacrifice then return "player" end
        if kind == "buff" or kind == "absorb" then return action.facts.self and "pet" or s.healUnit end
        if kind == "command" then return action.command == "attack" and "target" or "pet" end
        if kind == "dispel" then return XelAssistActors:DispelTarget(s) end
        return "target"
    end
    if kind == "summon" then return "player" end
    if action.facts.self then return "player" end
    if kind == "heal" or kind == "hot" or kind == "absorb" or kind == "buff" then return s.healUnit end
    if kind == "defensive" or kind == "resource" or kind == "threatDrop" or kind == "modifier" then return "player" end
    return "target"
end

local function auraActive(action, s)
    local future = s.auras[action.name]
    if action.facts.stackable then
        local futureProbability = type(future) == "table"
            and tonumber(future.applicationProbability) or 1
        local stacks = futureProbability >= APPLICATION_BLOCK_THRESHOLD
            and type(future) == "table"
            and tonumber(future.expectedStacks or future.stacks) or 0
        local live = s.targetAuras and s.targetAuras[action.name]
        local liveProbability = live and (tonumber(live.applicationProbability) or 1) or 0
        stacks = math.max(stacks or 0, liveProbability >= APPLICATION_BLOCK_THRESHOLD
            and (tonumber(live.stacks) or 1) or 0)
        return stacks >= action.facts.stackable
    end
    if future then
        if type(future) ~= "table" then return true end
        local probability = tonumber(future.applicationProbability) or 1
        local refresh = math.max(1.5, (future.duration or 0) * 0.2)
        if probability >= APPLICATION_BLOCK_THRESHOLD
            and (future.remaining == nil or future.remaining > refresh) then return true end
    end
    local aura = s.targetAuras and s.targetAuras[action.name]
    if not aura then return XelAssistCapabilities:TargetHasDebuff(action.name) end
    if (tonumber(aura.applicationProbability) or 1) < APPLICATION_BLOCK_THRESHOLD then
        return false
    end
    if action.facts.kind == "dot" and aura.mine == false then return false end
    local refresh = math.max(1.5, (aura.duration or 0) * 0.2)
    if aura.remaining ~= nil and aura.remaining <= refresh then return false end
    return true
end

local function relevant(action, s)
    local kind = action.facts.kind
    if action.facts.consumable then
        if not s.inCombat then return false end
        local current, maximum = s.resource, s.resourceMax
        if kind == "heal" then current, maximum = s.health, s.healthMax end
        local missing = math.max(0, (maximum or 0) - (current or 0))
        local expected = action.itemFacts and action.itemFacts.average or 0
        return missing > 0 and (expected <= 0 or missing >= expected * 0.5)
    end
    if action.actor == "pet" and kind == "command" then
        local pet = s.actors and s.actors.pet
        if action.command == "attack" then return s.hostile and pet and not pet.targetsCurrent end
        if action.command == "passive" then
            return pet and pet.stance ~= "passive" and pet.healthMax > 0
                and pet.health / pet.healthMax < 0.25
        end
        return pet and pet.targetExists and ((pet.healthMax > 0 and pet.health / pet.healthMax < 0.25)
            or not pet.targetsCurrent)
    end
    local support = kind == "heal" or kind == "hot" or kind == "absorb" or kind == "buff"
        or kind == "defensive" or kind == "resource" or kind == "threatDrop" or kind == "modifier"
        or kind == "summon"
    if s.mode == "buff" then return kind == "buff" end
    if s.mode == "support" then return support end
    if s.mode == "single" or s.mode == "aoe" then return not support end
    if s.targetCasting and (kind == "interrupt" or action.facts.interrupt) then return true end
    if s.hasAggro and not s.tank and (kind == "threatDrop" or kind == "defensive") then return true end
    if s.healthMax > 0 and s.health / s.healthMax < 0.35 and (kind == "defensive" or (kind == "heal" and action.facts.self)) then return true end
    if s.healMax > 0 and s.healHealth / s.healMax < 0.45 and (kind == "heal" or kind == "hot" or kind == "absorb") then return true end
    if s.hostile then return kind ~= "buff" or action.facts.self end
    return support
end

local function legal(action, s)
    local facts, kind = action.facts, action.facts.kind
    if not relevant(action, s) then return false, "intent" end
    if action.actor == "pet" and not XelAssistCharDB.toggles.petActions then return false, "companion policy" end
    if facts.consumable and not XelAssistCharDB.toggles.consumables then return false, "consumable policy" end
    if (facts.pet or action.actor == "pet") and not s.pet then return false, "pet" end
    if action.autocastEnabled then return false, "autocast active" end
    if facts.reagent and not XelAssistCharDB.toggles.reagents then return false, "reagent" end
    if facts.reagentName then
        local count = s.inventory and s.inventory.reagentCounts
            and s.inventory.reagentCounts[facts.reagentName]
        if count == nil then
            local available = XelAssistActors:HasReagent(facts.reagentName)
            if available == false then return false, "missing " .. facts.reagentName end
        elseif count <= 0 then return false, "missing " .. facts.reagentName end
    end
    if facts.resourceType == "mana" and s.resourceType ~= nil and s.resourceType ~= 0 then
        return false, "resource type"
    end
    if facts.combo and s.combo <= 0 then return false, "combo points" end
    if facts.execute and s.targetMax > 0 and s.targetHealth * 100 / s.targetMax > facts.execute then return false, "execute range" end
    local target, tooltip = actionTarget(action, s), XelAssistActors:Facts(action)
    if action.actor == "pet" and target ~= "target" and target ~= "pet" and target ~= "player" then
        return false, "companion cannot address that unit"
    end
    if target == "target" and s.targetHealthExact and s.targetHealth <= 0 then
        return false, "target defeated"
    end
    local inventoryBlocker = XelAssistInventory and XelAssistInventory:Blocker(action, s)
    if inventoryBlocker then return false, inventoryBlocker end
    local observedBlocker = XelAssistObservations and XelAssistObservations:Blocker(action, target)
    if observedBlocker then return false, observedBlocker end
    if not facts.consumable and (facts.cooldown or (tooltip.cooldown and tooltip.cooldown >= 30))
        and not XelAssistCharDB.toggles.cooldowns then return false, "cooldown policy" end
    local usable, usableReason
    if action.actor == "pet" then
        if GetPetActionsUsable then
            local ok, value = pcall(GetPetActionsUsable)
            if ok and (value == false or value == 0) then usable, usableReason = false, "pet state" end
        end
    elseif action.executor ~= "item" then
        usable, usableReason = XelAssistCapabilities:Usable(action)
    end
    if facts.reactive and usable ~= true then return false, "proc unknown" end
    if usable == false and target == "target" then return false, usableReason or "state" end
    if target == "target" and not s.hostile then return false, "target" end
    if kind == "dispel" and not target then return false, "nothing to dispel" end
    local actorLineOfSight = s.targetLineOfSight
    if action.actor == "pet" and s.actors and s.actors.pet then
        actorLineOfSight = s.actors.pet.lineOfSight
    end
    if target == "target" and actorLineOfSight == false then return false, "line of sight" end
    local actorBehind = s.playerBehindTarget
    if action.actor == "pet" and s.actors and s.actors.pet then actorBehind = s.actors.pet.behind end
    if facts.behind and actorBehind == false then return false, "must be behind target" end
    if facts.outOfCombat and s.inCombat then return false, "combat state" end
    if facts.combatOnly and not s.inCombat then return false, "combat state" end
    if kind == "summon" then
        if s.pet then return false, "companion already active" end
        if s.inCombat then return false, "unsafe summon" end
    end
    local cast = facts.cast
    if cast == nil then cast = tooltip.cast end
    if facts.channel and (not cast or cast <= 0) then cast = tooltip.duration or 3 end
    if s.instantNext and cast and cast > 0 then cast = 0 end
    if s.moving and cast and cast > 0 then return false, "moving" end
    local actor = action.actor or "player"
    local actionStart = math.max(s.time or 0, (s.actorReadyAt and s.actorReadyAt[actor]) or 0)
    if actor == "pet" and kind ~= "command" and actionStart > (s.time or 0) then
        return false, "companion casting"
    end
    local resource = s.resource
    if action.actor == "pet" and s.actors and s.actors.pet then resource = s.actors.pet.resource end
    if resource < (tooltip.cost or 0) then return false, action.actor == "pet" and "pet resource" or "resource" end
    if action.executor == "item" then
        local remaining = XelAssistInventory:Cooldown(action)
        if remaining and remaining > actionStart then return false, "item cooldown" end
    elseif action.actor == "pet" then
        local remaining = XelAssistActors:PetCooldown(action)
        if remaining and remaining > actionStart then return false, "pet cooldown" end
    elseif not XelAssistCapabilities:IsReady(action.name, actionStart) then return false, "cooldown" end
    if s.readyAt[actor .. ":" .. action.name] and s.readyAt[actor .. ":" .. action.name] > actionStart then return false, "future cooldown" end
    local cooldownGroup = facts.cooldownGroup or tooltip.cooldownGroup
    if cooldownGroup and s.readyAt["group:" .. cooldownGroup]
        and s.readyAt["group:" .. cooldownGroup] > actionStart then return false, "shared cooldown" end
    local liveRange
    if action.actor ~= "pet" and action.executor ~= "item" then
        liveRange = XelAssistCapabilities:InRange(action.name, target)
    end
    if liveRange == false then return false, "range" end
    -- When the client cannot give a direct spell-range verdict, use the
    -- discovered numeric band. Unknown distance remains unknown, never false.
    local rangeDistance = s.distance
    if action.actor == "pet" and s.actors and s.actors.pet then
        rangeDistance = s.actors.pet.distance
    elseif target == "target" and s.targetDistance ~= nil then rangeDistance = s.targetDistance
    elseif target == s.healUnit and s.healDistance ~= nil then rangeDistance = s.healDistance
    elseif target == "player" then rangeDistance = 0 end
    if liveRange == nil and rangeDistance then
        if tooltip.minRange and rangeDistance < tooltip.minRange then return false, "minimum range" end
        if tooltip.maxRange and tooltip.maxRange > 0 and rangeDistance > tooltip.maxRange then return false, "range" end
    end
    if (kind == "dot" or kind == "debuff") and auraActive(action, s) then return false, "already active" end
    if (kind == "dot" or kind == "debuff" or kind == "crowdControl"
        or kind == "buff" or kind == "hot" or kind == "absorb" or kind == "resource")
        and XelAssist and XelAssist.IsAuraPending
        and XelAssist:IsAuraPending(action.name, action.actor, target) then
        return false, "application pending"
    end
    if (kind == "buff" or kind == "hot" or kind == "absorb" or kind == "resource") and
        (s.auras[action.name] or XelAssistCapabilities:UnitHasBuff(target, action.name)) then return false, "already active" end
    if kind == "interrupt" and not s.targetCasting then return false, "not casting" end
    if kind == "interrupt" and s.targetCastRemaining
        and actionStart >= s.targetCastRemaining then return false, "interrupt too late" end
    if kind == "taunt" then
        local petTank = XelAssistCharDB.petThreat == "tank"
            or (XelAssistCharDB.petThreat ~= "avoid" and s.groupSize == 0)
        if not petTank or (s.actors.pet and s.actors.pet.hasAggro) then return false, "pet threat policy" end
    end
    if kind == "crowdControl" and not XelAssistCharDB.toggles.petControl then
        return false, "pet control policy"
    end
    if facts.requiresCreature and s.targetCreatureType
        and facts.requiresCreature ~= s.targetCreatureType then return false, "creature immunity" end
    if kind == "crowdControl" and XelAssistCapabilities:TargetHasDebuff(action.name) then
        return false, "already controlled"
    end
    if facts.aoe and s.mode ~= "aoe" and not XelAssistCharDB.allowAoe then return false, "area policy" end
    return true, nil, tooltip, target, actionStart
end

local function potency(action, tooltip, s)
    local combo = action.facts.combo and (tooltip.comboBonus or 0) * s.combo or 0
    local base, estimated = nil, nil
    if tooltip.average then base, estimated = tooltip.average + combo, false end
    if tooltip.dbcAverage then
        local weapon = action.facts.melee and XelAssistCapabilities:WeaponDamage() or 0
        if action.facts.ranged and tooltip.school == 0 then weapon = XelAssistCapabilities:RangedDamage() or weapon end
        if not base then base, estimated = tooltip.dbcAverage + combo + (weapon or 0), true end
    end
    if not base then base, estimated = math.max(10, action.rank * 24 + (tooltip.cost or 0) * 0.8), true end
    if (action.facts.kind == "damage" or action.facts.kind == "dot") and action.actor ~= "pet" then
        local bonus = XelAssistCapabilities:BonusDamage(tooltip.school)
        if bonus > 0 then
            local coefficient
            if action.facts.kind == "dot" then coefficient = math.min(1, (tooltip.duration or 15) / 15)
            else coefficient = math.min(1, math.max(1.5, tooltip.cast or 0) / 3.5) end
            if action.facts.aoe then coefficient = coefficient * 0.5 end
            base, estimated = base + bonus * coefficient, true
        end
    end
    return base, estimated
end

local function resistanceDecision(resistance, state, damageKind)
    if not resistance then return 1, 1 end
    if not damageKind then
        resistance.uncertaintyMultiplier = resistance.unknown and 0.90 or 1
        local delivery = (resistance.landChance or 1)
            * resistance.uncertaintyMultiplier
        resistance.damageTakenMultiplier = 1
        resistance.decisionMultiplier = delivery
        return delivery, delivery
    end

    local damageTakenMultiplier, decisionMultiplier = 1, nil
    if resistance.components then
        local expectedWeighted, decisionWeighted, baseWeighted, totalWeight, i = 0, 0, 0, 0, nil
        for i = 1, table.getn(resistance.components) do
            local component = resistance.components[i]
            local weight = tonumber(component.componentWeight) or 0
            local base = weight * (component.multiplier or 1)
            local vulnerability = 1 + (state.targetDamageTaken
                and state.targetDamageTaken[component.school] or 0)
            local reserve = component.unknown and 0.90 or 1
            component.uncertaintyMultiplier = reserve
            component.expectedWeight = base * vulnerability
            component.decisionWeight = component.expectedWeight * reserve
            baseWeighted = baseWeighted + base
            expectedWeighted = expectedWeighted + component.expectedWeight
            decisionWeighted = decisionWeighted + component.decisionWeight
            totalWeight = totalWeight + weight
        end
        if totalWeight > 0 then
            local baseMultiplier = baseWeighted / totalWeight
            local expectedMultiplier = expectedWeighted / totalWeight
            decisionMultiplier = decisionWeighted / totalWeight
            damageTakenMultiplier = baseMultiplier > 0
                and expectedMultiplier / baseMultiplier or 1
            resistance.uncertaintyMultiplier = expectedMultiplier > 0
                and decisionMultiplier / expectedMultiplier or 1
            if decisionWeighted > 0 then
                for i = 1, table.getn(resistance.components) do
                    local component = resistance.components[i]
                    component.decisionShare = component.decisionWeight / decisionWeighted
                end
            end
        end
    elseif state.targetDamageTaken and resistance.school then
        damageTakenMultiplier = 1 + (state.targetDamageTaken[resistance.school] or 0)
    end
    if not resistance.uncertaintyMultiplier then
        resistance.uncertaintyMultiplier = resistance.unknown and 0.90 or 1
    end
    resistance.damageTakenMultiplier = damageTakenMultiplier
    resistance.decisionMultiplier = decisionMultiplier or (resistance.multiplier or 1)
        * resistance.uncertaintyMultiplier * damageTakenMultiplier
    local delivery = (resistance.landChance or 1)
        * (resistance.uncertaintyMultiplier or 1)
    return resistance.decisionMultiplier, delivery
end

local function resistancePhaseFactor(resistance, phase, conditionalOnApplication)
    local weighted, total, i = 0, 0, nil
    for i = 1, table.getn(resistance and resistance.components or {}) do
        local component = resistance.components[i]
        if component.componentPhase == phase then
            local weight = tonumber(component.componentWeight) or 0
            local decision = weight > 0 and (component.decisionWeight or 0) / weight or 0
            if conditionalOnApplication then
                local delivery = (component.landChance or resistance.landChance or 1)
                    * (component.uncertaintyMultiplier or 1)
                decision = delivery > 0 and decision / delivery or 0
            end
            weighted, total = weighted + decision * weight, total + weight
        end
    end
    if total > 0 then return weighted / total end
    local decision = resistance and resistance.decisionMultiplier or 1
    if conditionalOnApplication then
        local delivery = (resistance and resistance.landChance or 1)
            * (resistance and resistance.uncertaintyMultiplier or 1)
        return delivery > 0 and decision / delivery or 0
    end
    return decision
end

local function evaluate(action, s)
    local allowed, blocker, tooltip, target, actionStart = legal(action, s)
    if not allowed then return nil, blocker end
    local facts, kind, power = action.facts, action.facts.kind, nil
    local estimated
    power, estimated = potency(action, tooltip, s)
    local cast = facts.cast
    if cast == nil then cast = tooltip.cast or (facts.channel and 3 or 0) end
    if facts.channel and cast <= 0 then cast = tooltip.duration or 3 end
    if s.instantNext and cast > 0 then cast = 0 end
    local defaultGCD = action.actor == "pet" and 0.1 or 1.5
    local occupancy = math.max(0.05, facts.gcd or tooltip.gcd or defaultGCD, cast)
    local wait = math.max(0, (actionStart or s.time) - s.time)
    local downtime = wait + occupancy
    local cost, value, reason = tooltip.cost or 0, 0, kind
    local resistance, expectedPower = nil, power
    local dotRawDirectPower, dotRawPeriodicPower, dotPeriodicExpectedPower
    local damageKind = kind == "damage" or kind == "dot" or kind == "builder"
    local targetEffect = damageKind or kind == "debuff" or kind == "crowdControl"
        or kind == "interrupt" or kind == "taunt"
    local effectDelivery = 1
    local resistanceState = s
    if targetEffect and stateAtImpact and wait + cast > 0 then
        resistanceState = stateAtImpact(s, wait + cast)
    end
    if targetEffect then
        if XelAssistResistance then
            resistance = XelAssistResistance:Estimate(action, target, tooltip, resistanceState)
        elseif XelAssistObservations then
            local multiplier, source, estimate = XelAssistObservations:ResistanceMultiplier(action,
                target, tooltip, s)
            resistance = estimate or { multiplier = multiplier or 1, source = source or "unknown",
                unknown = multiplier == nil }
        end
        if resistance then
            local decision
            decision, effectDelivery = resistanceDecision(
                resistance, resistanceState, damageKind)
            if damageKind then expectedPower = power * decision end
        end
    end

    if XelAssistResistance and resistance and resistanceOverWindow then
        if kind == "dot" then
            local directWeight = tonumber(tooltip.directDamage) or 0
            local periodicWeight = tonumber(tooltip.periodicDamage) or 0
            if directWeight > 0 and periodicWeight > 0 then
                local total = directWeight + periodicWeight
                dotRawDirectPower = power * directWeight / total
                dotRawPeriodicPower = power * periodicWeight / total
            else
                dotRawDirectPower, dotRawPeriodicPower = 0, power
            end
            local duration = math.max(1, tonumber(tooltip.duration) or 12)
            local periodicConditional = resistanceOverWindow(action, target, tooltip, s,
                wait + cast, duration, "periodic", true)
            if periodicConditional then
                local directPower = dotRawDirectPower
                    * resistancePhaseFactor(resistance, "direct", false)
                dotPeriodicExpectedPower = dotRawPeriodicPower
                    * effectDelivery * periodicConditional
                expectedPower = directPower + dotPeriodicExpectedPower
                resistance.decisionMultiplier = power > 0 and expectedPower / power or 0
            end
        elseif facts.channel and cast > 0 then
            local periodicConditional, applicationDelivery = resistanceOverWindow(
                action, target, tooltip, s, wait, cast, "periodic", true)
            if periodicConditional then
                effectDelivery = applicationDelivery
                expectedPower = power * effectDelivery * periodicConditional
                resistance.decisionMultiplier = power > 0 and expectedPower / power or 0
            end
        end
    end

    if kind == "damage" or kind == "builder" then
        local effective = s.targetHealthExact and s.targetHealth > 0
            and math.min(expectedPower, s.targetHealth) or expectedPower
        value = 250 + effective * 4 / math.max(0.5, downtime)
        if s.targetHealthExact and s.targetHealth > 0 and expectedPower >= s.targetHealth then value, reason = value + 700, "finishes the target"
        elseif facts.recovery then
            value = value + ((s.resourceMax > 0 and (1 - s.resource / s.resourceMax) * 300) or 0)
            reason = "preserves resources"
        elseif cast > 0 then reason = "best value after cast time"
        else reason = "best immediate value" end
        if s.role == "damage" then value = value * 1.15
        elseif s.role == "healer" then value = value * 0.85 end
    elseif kind == "dot" then
        local effective, fraction = expectedPower, 1
        if s.targetHealthExact and s.targetHealth > 0 then
            effective = math.min(expectedPower, s.targetHealth)
            fraction = math.min(1, s.targetHealth / math.max(1, expectedPower))
        end
        value = effective * 4 / math.max(1, downtime) + effective / math.max(1, cost) * 45
        if fraction < 1 then value = value - (expectedPower - effective) * 3 end
        reason = fraction < 0.75 and "target may die before the effect pays back" or "adds efficient lasting damage"
    elseif kind == "heal" or kind == "hot" then
        local selfTarget = target == "player"
        local missing = selfTarget and math.max(0, s.healthMax - s.health)
            or math.max(0, s.healMax - s.healHealth)
        local effective = math.min(power, missing)
        if facts.consumable then
            value = effective * 5 / math.max(0.5, downtime) - 1200 / math.max(1, action.count or 1)
        else
            value = effective * 5 / math.max(0.5, downtime) + effective / math.max(1, cost) * 80
        end
        if power > missing * 1.35 then value = value - (power - missing) * 2 end
        if missing <= 0 then value = value - 1000 end
        reason = power > missing * 1.35 and "avoids excess healing" or "best healing per resource"
        if s.role == "healer" then value = value * 1.25
        elseif s.role == "damage" then value = value * 0.85 end
    elseif kind == "absorb" then
        value = power * 3 / math.max(0.5, downtime) + (s.hasAggro and 900 or 0)
        reason = s.hasAggro and "absorbs expected incoming damage" or "adds a protective buffer"
    elseif kind == "interrupt" then
        local castProbability = s.targetCastProbability
        if castProbability == nil then castProbability = s.targetCasting and 1 or 0 end
        value = s.targetCasting and 5000 * castProbability or -1000
        reason = action.actor == "pet" and "companion stops the current cast" or "stops the current cast"
    elseif kind == "taunt" then
        value, reason = s.hasAggro and not s.tank and 3800 or 900, "companion takes unwanted aggro"
    elseif kind == "petHeal" then
        local pet = s.actors and s.actors.pet
        local missing = pet and math.max(0, pet.healthMax - pet.health) or 0
        local effective = math.min(power, missing)
        value, reason = effective * 4 / math.max(0.5, downtime), "restores the companion"
        if missing <= 0 then value = -1000 end
    elseif kind == "crowdControl" then
        value, reason = s.hasAggro and not s.tank and 2200 or 650, "controls a dangerous target"
    elseif kind == "dispel" then
        value, reason = 700, "removes a harmful combat effect"
    elseif kind == "summon" then
        value, reason = 850, "restores a missing companion"
        if facts.summonRole == "tank" and s.groupSize == 0 then
            value, reason = 1250, "brings a companion that can hold solo threat"
        elseif facts.summonRole == "interrupt" and s.targetCasting then
            value, reason = 1800, "brings a companion with an interrupt"
        elseif facts.summonRole == "control" and XelAssistCharDB.toggles.petControl then
            value, reason = 1050, "brings a companion with crowd control"
        elseif facts.summonRole == "support" and s.groupSize > 0 then
            value, reason = 1100, "brings group support"
        end
    elseif kind == "command" then
        local pet = s.actors and s.actors.pet
        if action.command == "attack" then
            value, reason = 850, "sends the companion to the current target"
        elseif action.command == "passive" then
            value, reason = 2900, "stops the endangered companion from re-engaging"
        else
            local low = pet and pet.healthMax > 0 and pet.health / pet.healthMax < 0.25
            value = low and 2600 or 1000
            reason = low and "retreats the endangered companion" or "recalls the companion from another target"
        end
    elseif kind == "defensive" then
        local hp = s.healthMax > 0 and s.health / s.healthMax or 1
        value, reason = (1 - hp) * 1800 + (s.hasAggro and 500 or 0), "reduces immediate danger"
    elseif kind == "threatDrop" then value, reason = (s.hasAggro and not s.tank) and 4200 or -500, "drops unwanted aggro"
    elseif kind == "resource" then
        local missing = math.max(0, s.resourceMax - s.resource)
        if facts.consumable then
            local effective = math.min(power, missing)
            value = effective * 4 / math.max(0.5, downtime) - 1200 / math.max(1, action.count or 1)
            if power > missing * 1.35 then value = value - (power - missing) * 2 end
            if missing <= 0 then value = -1000 end
            reason = power > missing * 1.35 and "avoids wasting a resource consumable"
                or "restores needed combat resources"
        else
            value, reason = (s.resourceMax > 0 and (1 - s.resource / s.resourceMax) * 1200 or 0),
                "recovers combat resources"
        end
    elseif kind == "buff" then
        value, reason = 500 + (tooltip.duration or 0) * 4, "adds missing utility"
    elseif kind == "debuff" then
        if tooltip.targetArmorReduction
            or tooltip.targetResistanceReduction or tooltip.targetDamageTaken then
            value, reason = 120, "opens a stronger damage path"
        else
            value, reason = 200 + math.min(10, tooltip.duration or 0) * 4,
                "adds missing utility"
        end
    elseif kind == "modifier" then
        local missing = math.max(0, s.healMax - s.healHealth)
        value = (facts.nextInstant and (s.moving or missing > s.healMax * 0.45)) and 1500 or 250
        reason = facts.nextInstant and "makes the next cast instant" or "improves the next action"
    end

    if resistance and targetEffect and not damageKind then
        value = value * effectDelivery
    end

    if facts.aoe then value = value * (s.mode == "aoe" and 1.8 or 0.55) end
    if facts.interrupt and s.targetCasting then
        local castProbability = s.targetCastProbability
        if castProbability == nil then castProbability = 1 end
        value, reason = value + 4500 * castProbability * effectDelivery, "stops the current cast"
    end
    if facts.execute and s.targetMax > 0 and s.targetHealth * 100 / s.targetMax <= facts.execute then value = value + 900 end
    if facts.leech and s.healthMax > 0 then
        local delivered = power > 0 and expectedPower / power or effectDelivery
        value = value + (1 - s.health / s.healthMax) * 500 * math.max(0, delivered)
    end
    local threatPower = (kind == "damage" or kind == "dot" or kind == "builder")
        and expectedPower or power
    local threat = threatPower * (facts.threat or (kind == "heal" and 0.5 or 1))
    local damageActor = facts.damageActor or action.actor
    if damageActor == "pet" then threat = threat * 0.9 end
    if damageActor == "pet" then
        local petTank = XelAssistCharDB.petThreat == "tank"
            or (XelAssistCharDB.petThreat ~= "avoid" and s.groupSize == 0)
        if petTank then value = value + threat * 0.4
        elseif s.groupSize > 0 then value = value - threat * 0.25 end
    elseif s.tank and threat > threatPower then
        value = value + (threat - threatPower) * 0.5
        reason = "builds threat"
    elseif (s.groupSize > 0 or s.pet) and not s.tank then
        value = value - threat * (s.hasAggro and 3 or 0.25)
        if s.hasAggro then reason = "limits additional threat"
        elseif threat > threatPower * 1.2 then reason = "lower threat for the group" end
    end
    if cost > 0 and s.resourceMax > 0 then value = value - cost / s.resourceMax * 240 end
    if facts.inferred then estimated = true end
    if estimated then value = value * 0.88 end
    return { action = action, value = value, reason = reason, target = target,
        cost = cost, cast = cast, downtime = downtime, threat = threat,
        estimated = estimated, tooltip = tooltip, power = expectedPower, rawPower = power,
        resistance = resistance, effectDelivery = effectDelivery,
        dotRawDirectPower = dotRawDirectPower,
        dotRawPeriodicPower = dotRawPeriodicPower,
        dotPeriodicExpectedPower = dotPeriodicExpectedPower,
        wait = wait, occupancy = occupancy, actionStart = actionStart }
end

local function dotPowerSplit(candidate)
    local resistance = candidate.resistance
    if not (resistance and resistance.mode == "hybrid"
        and type(resistance.components) == "table") then return 0, candidate.power end
    local direct, periodic, unassigned, total = 0, 0, 0, 0
    local i
    for i = 1, table.getn(resistance.components) do
        local component = resistance.components[i]
        local share = tonumber(component.decisionShare) or 0
        total = total + share
        if component.componentPhase == "direct" then direct = direct + share
        elseif component.componentPhase == "periodic" then periodic = periodic + share
        else unassigned = unassigned + share end
    end
    if total <= 0 then return 0, candidate.power end
    periodic = periodic + unassigned
    return candidate.power * direct / total, candidate.power * periodic / total
end

local function copyNumbers(values)
    if type(values) ~= "table" then return nil end
    local out, key, value = {}, nil, nil
    for key, value in pairs(values) do out[key] = value end
    return out
end

local function rebuildDamageTaken(state)
    state.targetDamageTaken = aggregateDamageTakenModifiers(
        state.targetModifierEffects, state.baseTargetDamageTaken)
end

local function rebuildProjectedResistance(state)
    local targetResistance = state.targetResistance
    if not targetResistance then return end
    if targetResistance.baseProjectedReduction == nil then
        targetResistance.baseProjectedReduction = copyNumbers(
            targetResistance.projectedReduction) or {}
    end
    if targetResistance.live and targetResistance.rootModifierReduction == nil then
        local rootEffects, name, effect = {}, nil, nil
        for name, effect in pairs(state.targetModifierEffects or {}) do
            if effect.activeRoot then rootEffects[name] = effect end
        end
        targetResistance.rootModifierReduction = aggregateModifierReductions(rootEffects) or {}
        targetResistance.baseProjectedReduction = {}
    end
    local current = aggregateModifierReductions(state.targetModifierEffects) or {}
    local root = targetResistance.rootModifierReduction or {}
    local projected, schools, school = {}, {}, nil
    for school in pairs(targetResistance.baseProjectedReduction or {}) do schools[school] = true end
    for school in pairs(current) do schools[school] = true end
    for school in pairs(root) do schools[school] = true end
    local count = 0
    for school in pairs(schools) do
        local value = (targetResistance.baseProjectedReduction[school] or 0)
        if targetResistance.live then value = value + (current[school] or 0) - (root[school] or 0)
        else value = value + (current[school] or 0) end
        if math.abs(value) >= 0.0001 then projected[school], count = value, count + 1 end
    end
    targetResistance.projectedReduction = count > 0 and projected or nil
    local names, name = {}, nil
    for name in pairs(state.targetModifierEffects or {}) do table.insert(names, name) end
    targetResistance.projectedBy = table.getn(names) > 0 and table.concat(names, ", ") or nil
end

local function removeTargetModifier(state, name)
    local effects = state.targetModifierEffects
    local effect = effects and effects[name]
    if not effect then return end
    if state.targetResistance and state.targetResistance.live
        and state.targetResistance.rootModifierReduction == nil then
        local rootEffects, rootName, rootEffect = {}, nil, nil
        for rootName, rootEffect in pairs(effects) do
            if rootEffect.activeRoot then rootEffects[rootName] = rootEffect end
        end
        state.targetResistance.rootModifierReduction =
            aggregateModifierReductions(rootEffects) or {}
        state.targetResistance.baseProjectedReduction = {}
    end
    effects[name] = nil
    rebuildDamageTaken(state)
    rebuildProjectedResistance(state)
end

local function blendModifierValues(success, failure, probability)
    local out, keys, school = {}, {}, nil
    for school in pairs(success or {}) do keys[school] = true end
    for school in pairs(failure or {}) do keys[school] = true end
    for school in pairs(keys) do
        local amount = probability * ((success and success[school]) or 0)
            + (1 - probability) * ((failure and failure[school]) or 0)
        if math.abs(amount) >= 0.0001 then out[school] = amount end
    end
    return out
end

local function refreshExpectedModifier(effect, keepFailure)
    local probability = math.max(0, math.min(1,
        tonumber(effect.deliveryProbability) or 1))
    local failureReduction = keepFailure and effect.failureResistanceReduction or nil
    local failureTaken = keepFailure and effect.failureDamageTaken or nil
    effect.resistanceReduction = blendModifierValues(
        effect.successResistanceReduction, failureReduction, probability)
    effect.damageTaken = blendModifierValues(
        effect.successDamageTaken, failureTaken, probability)
    if not keepFailure then
        effect.failureResistanceReduction = nil
        effect.failureDamageTaken = nil
        effect.fallbackRemaining = nil
        effect.activeRoot = nil
    end
end

local function advanceModifierFallbacks(state, elapsed)
    if not state.targetModifierEffects or not elapsed or elapsed <= 0 then return end
    local changed, _, effect = false, nil, nil
    for _, effect in pairs(state.targetModifierEffects) do
        if effect.fallbackRemaining then
            if effect.fallbackRemaining <= elapsed then
                refreshExpectedModifier(effect, false)
                changed = true
            else effect.fallbackRemaining = effect.fallbackRemaining - elapsed end
        end
    end
    if changed then
        rebuildDamageTaken(state)
        rebuildProjectedResistance(state)
    end
end

stateAtImpact = function(state, elapsed)
    if not elapsed or elapsed <= 0 or not state.targetModifierEffects then return state end
    local out = copyState(state)
    local expired, name, aura = {}, nil, nil
    for name, aura in pairs(out.auras or {}) do
        if type(aura) == "table" and aura.targetModifier and aura.remaining then
            if aura.remaining <= elapsed then table.insert(expired, name)
            else aura.remaining = aura.remaining - elapsed end
        end
    end
    local i
    for i = 1, table.getn(expired) do
        removeTargetModifier(out, expired[i])
        out.auras[expired[i]] = nil
    end
    advanceModifierFallbacks(out, elapsed)
    return out
end

local function applyTargetModifier(state, action, targetFacts, sourceState, delivery,
    priorEffect, fallbackRemaining)
    if not state.targetModifierEffects then state.targetModifierEffects = {} end
    if state.baseTargetDamageTaken == nil then
        state.baseTargetDamageTaken = copyNumbers(state.targetDamageTaken) or {}
    end
    priorEffect = priorEffect or state.targetModifierEffects[action.name]
    delivery = math.max(0, math.min(1, tonumber(delivery) or 1))
    local effect = { name = action.name,
        group = action.facts.modifierGroup or action.name,
        exclusiveFamily = action.facts.exclusiveFamily,
        mine = true,
        resistanceReduction = {}, damageTaken = {},
        successResistanceReduction = {}, successDamageTaken = {},
        failureResistanceReduction = copyNumbers(
            priorEffect and priorEffect.resistanceReduction) or {},
        failureDamageTaken = copyNumbers(priorEffect and priorEffect.damageTaken) or {},
        deliveryProbability = delivery,
        fallbackRemaining = priorEffect and (fallbackRemaining or math.huge) or nil,
        activeRoot = priorEffect and priorEffect.activeRoot or nil }
    if not state.targetResistance then state.targetResistance = {} end
    local armor = tonumber(targetFacts.targetArmorReduction)
    if armor then
        if targetFacts.targetArmorPerCombo then armor = armor * (sourceState.combo or 0) end
        if action.facts.stackable and priorEffect then
            armor = (priorEffect.resistanceReduction[0] or 0) + armor
        end
        effect.successResistanceReduction[0] = armor
    end
    local school, amount
    for school, amount in pairs(targetFacts.targetResistanceReduction or {}) do
        local value = tonumber(amount) or 0
        if action.facts.stackable and priorEffect then
            value = (priorEffect.resistanceReduction[school] or 0) + value
        end
        effect.successResistanceReduction[school] = value
    end
    for school, amount in pairs(targetFacts.targetDamageTaken or {}) do
        local value = tonumber(amount) or 0
        if action.facts.stackable and priorEffect then
            value = (priorEffect.damageTaken[school] or 0) + value
        end
        effect.successDamageTaken[school] = value
    end
    refreshExpectedModifier(effect, effect.fallbackRemaining and delivery < 1)
    state.targetModifierEffects[action.name] = effect
    rebuildDamageTaken(state)
    rebuildProjectedResistance(state)
end

local function scaleModifierBranch(effect, probability)
    local fields = { "resistanceReduction", "damageTaken",
        "successResistanceReduction", "successDamageTaken",
        "failureResistanceReduction", "failureDamageTaken" }
    local i, field, school, amount
    for i = 1, table.getn(fields) do
        field = fields[i]
        for school, amount in pairs(effect[field] or {}) do
            effect[field][school] = amount * probability
        end
    end
end

local function applyExclusiveFamily(state, action, delivery)
    local family = action.facts and action.facts.exclusiveFamily
    if not family then return end
    delivery = math.max(0, math.min(1, tonumber(delivery) or 1))
    local affected, name, aura = {}, nil, nil
    for name, aura in pairs(state.auras or {}) do
        if name ~= action.name and type(aura) == "table"
            and aura.exclusiveFamily == family and aura.mine == true then
            affected[name] = true
        end
    end
    for name, aura in pairs(state.targetAuras or {}) do
        if name ~= action.name and type(aura) == "table"
            and aura.exclusiveFamily == family and aura.mine == true then
            affected[name] = true
        end
    end
    local effect
    for name, effect in pairs(state.targetModifierEffects or {}) do
        if name ~= action.name and effect.exclusiveFamily == family
            and effect.mine == true then affected[name] = true end
    end
    local changed = false
    for name in pairs(affected) do
        local oldAura = state.auras and state.auras[name]
        local liveAura = state.targetAuras and state.targetAuras[name]
        local oldEffect = state.targetModifierEffects and state.targetModifierEffects[name]
        if delivery >= 1 then
            if oldEffect then removeTargetModifier(state, name) end
            if state.auras then state.auras[name] = nil end
            if liveAura and liveAura.mine == true then state.targetAuras[name] = nil end
        else
            local failureProbability = 1 - delivery
            if oldAura then
                oldAura.applicationProbability = (tonumber(
                    oldAura.applicationProbability) or 1) * failureProbability
            end
            if liveAura and liveAura.mine == true then
                liveAura.applicationProbability = (tonumber(
                    liveAura.applicationProbability) or 1) * failureProbability
            end
            if oldEffect then
                scaleModifierBranch(oldEffect, failureProbability)
                changed = true
            end
        end
    end
    if changed then
        rebuildDamageTaken(state)
        rebuildProjectedResistance(state)
    end
end

local function phaseAction(action, phase)
    local copy, key, value = {}, nil, nil
    for key, value in pairs(action) do copy[key] = value end
    copy.facts = {}
    for key, value in pairs(action.facts or {}) do copy.facts[key] = value end
    copy.facts.resistancePhase = phase
    return copy
end

local function modifierBreakpoints(state, startAt, duration)
    local points, seen = { 0, duration }, { [0] = true, [duration] = true }
    local function add(remaining)
        remaining = tonumber(remaining)
        if not remaining then return end
        local offset = remaining - startAt
        if offset > 0 and offset < duration then
            local key = math.floor(offset * 10000 + 0.5)
            if not seen[key] then seen[key] = true; table.insert(points, offset) end
        end
    end
    local _, aura, effect
    for _, aura in pairs(state.auras or {}) do
        if type(aura) == "table" and aura.targetModifier then add(aura.remaining) end
    end
    for _, effect in pairs(state.targetModifierEffects or {}) do add(effect.fallbackRemaining) end
    table.sort(points)
    return points
end

resistanceOverWindow = function(action, target, tooltip, state, startAt, duration,
    phase, conditionalOnApplication)
    if not XelAssistResistance or not duration or duration <= 0 then return nil end
    startAt = math.max(0, tonumber(startAt) or 0)
    local projectedAction = phaseAction(action, phase or "periodic")
    local projectedTooltip = { school = tooltip and tooltip.school }
    local initialState = stateAtImpact(state, startAt)
    local initial = XelAssistResistance:Estimate(
        projectedAction, target, projectedTooltip, initialState)
    local _, initialDelivery = resistanceDecision(initial, initialState, true)
    local points = modifierBreakpoints(state, startAt, duration)
    local weighted, total, representative, i = 0, 0, initial, nil
    for i = 1, table.getn(points) - 1 do
        local left, right = points[i], points[i + 1]
        local span = right - left
        if span > 0 then
            local sampleState = stateAtImpact(state, startAt + left + span / 2)
            local estimate = XelAssistResistance:Estimate(
                projectedAction, target, projectedTooltip, sampleState)
            resistanceDecision(estimate, sampleState, true)
            local factor = resistancePhaseFactor(
                estimate, phase, conditionalOnApplication)
            weighted, total = weighted + factor * span, total + span
            representative = estimate
        end
    end
    return total > 0 and weighted / total or 0, initialDelivery, representative
end

local function advance(s, candidate)
    local out, action, facts = copyState(s), candidate.action, candidate.action.facts
    if action.actor == "pet" and out.actors and out.actors.pet then
        out.actors.pet.resource = math.max(0, out.actors.pet.resource - candidate.cost)
    else
        out.resource = math.max(0, out.resource - candidate.cost)
    end
    if action.executor == "item" and action.itemId and out.inventory and out.inventory.itemCounts then
        out.inventory.itemCounts[action.itemId] = math.max(0,
            (out.inventory.itemCounts[action.itemId] or 0) - 1)
    end
    if facts.reagentName and out.inventory and out.inventory.reagentCounts then
        out.inventory.reagentCounts[facts.reagentName] = math.max(0,
            (out.inventory.reagentCounts[facts.reagentName] or 0) - 1)
    end
    local targetFacts = candidate.tooltip or {}
    local projectedDelivery = candidate.effectDelivery or (candidate.resistance
        and (candidate.resistance.landChance or 1)
            * (candidate.resistance.uncertaintyMultiplier or 1) or 1)
    local applicationElapsed = math.max(0, (candidate.occupancy or 0)
        - math.max(0, candidate.cast or 0))
    local applicationOffset = math.max(0, candidate.wait or 0)
        + math.max(0, candidate.cast or 0)
    local hasTargetModifier = candidate.target == "target" and (targetFacts.targetArmorReduction
        or targetFacts.targetResistanceReduction or targetFacts.targetDamageTaken)
    local targetModifierDuration = tonumber(candidate.tooltip.duration)
    local targetModifierRemaining = targetModifierDuration
        and math.max(0, targetModifierDuration - applicationElapsed) or nil
    local applicationState = (hasTargetModifier or facts.exclusiveFamily)
        and stateAtImpact(s, applicationOffset) or nil
    local function modifierPrior(elapsedAfterApplication)
        if not applicationState then return nil, nil end
        local prior = applicationState.targetModifierEffects
            and applicationState.targetModifierEffects[action.name]
        local priorAura = applicationState.auras and applicationState.auras[action.name]
        local remaining = type(priorAura) == "table" and priorAura.remaining or nil
        if remaining and remaining <= elapsedAfterApplication then return nil, nil end
        return prior, remaining and remaining - elapsedAfterApplication or nil
    end
    local function projectCurrentApplication(eventState, elapsedAfterApplication)
        applyExclusiveFamily(eventState, action, projectedDelivery)
        if hasTargetModifier and targetModifierDuration
            and targetModifierDuration > elapsedAfterApplication then
            local prior, fallback = modifierPrior(elapsedAfterApplication)
            applyTargetModifier(eventState, action, targetFacts, s,
                projectedDelivery, prior, fallback)
        end
    end
    out.time = out.time + candidate.downtime
    local ambientPet = out.actors and out.actors.pet
    if ambientPet and ambientPet.autocasts and ambientPet.targetExists and ambientPet.targetsCurrent then
        local acIndex
        for acIndex = 1, table.getn(ambientPet.autocasts) do
            local ambient = ambientPet.autocasts[acIndex]
            local ambientOffset = math.min(candidate.downtime,
                math.max(0, tonumber(ambient.readyIn) or 0))
            ambient.readyIn = math.max(0, (ambient.readyIn or 0) - candidate.downtime)
            if ambient.readyIn <= 0 and ambientPet.resource >= (ambient.cost or 0) then
                ambientPet.resource = ambientPet.resource - (ambient.cost or 0)
                ambient.readyIn = math.max(0.1, ambient.cooldown or 1.5)
                if ambient.kind == "damage" and out.targetHealthExact then
                    local ambientPower = ambient.power or 0
                    if XelAssistResistance then
                        local ambientState = stateAtImpact(s, ambientOffset)
                        if ambientOffset >= applicationOffset
                            and (hasTargetModifier or facts.exclusiveFamily) then
                            ambientState = copyState(ambientState)
                            projectCurrentApplication(ambientState,
                                ambientOffset - applicationOffset)
                        end
                        local estimate = XelAssistResistance:Estimate(ambient, "target",
                            ambient.tooltip or {}, ambientState)
                        local decision = resistanceDecision(estimate, ambientState, true)
                        ambientPower = ambientPower * decision
                    end
                    out.targetHealth = math.max(0, out.targetHealth - ambientPower)
                elseif ambient.kind == "taunt" then
                    local petTank = XelAssistCharDB.petThreat == "tank"
                        or (XelAssistCharDB.petThreat ~= "avoid" and out.groupSize == 0)
                    if petTank then out.hasAggro = false; ambientPet.hasAggro = true end
                end
            end
        end
    end
    local auraName, aura
    local periodicState = copyState(s)
    local function periodicDamageFor(auraValue, elapsed)
        local fallback = math.max(0, auraValue.periodicRate or 0) * elapsed
        if not (auraValue.periodicRawRate and auraValue.periodicAction
            and XelAssistResistance and elapsed > 0) then return fallback end
        local function segment(segmentState, span)
            if span <= 0 then return 0 end
            local conditional = resistanceOverWindow(auraValue.periodicAction, "target",
                auraValue.periodicTooltip or {}, segmentState, 0, span,
                "periodic", true)
            if not conditional then return math.max(0, auraValue.periodicRate or 0) * span end
            return math.max(0, auraValue.periodicRawRate) * span
                * (tonumber(auraValue.applicationProbability) or 1) * conditional
        end
        if (hasTargetModifier or facts.exclusiveFamily)
            and applicationOffset < elapsed then
            local before = math.max(0, applicationOffset)
            local afterState = copyState(stateAtImpact(s, applicationOffset))
            projectCurrentApplication(afterState, 0)
            if hasTargetModifier and targetModifierDuration
                and targetModifierDuration > 0 then
                afterState.auras[action.name] = { remaining = targetModifierDuration,
                    duration = targetModifierDuration, mine = true, target = "target",
                    targetModifier = true, applicationProbability = projectedDelivery,
                    exclusiveFamily = facts.exclusiveFamily }
            end
            return segment(periodicState, before)
                + segment(afterState, elapsed - before)
        end
        return segment(periodicState, elapsed)
    end
    for auraName, aura in pairs(out.auras) do
        if type(aura) == "table" and aura.remaining then
            local elapsed = math.min(aura.remaining, candidate.downtime)
            if aura.periodicRate and aura.target == "target" and out.targetHealthExact then
                local periodicDamage = periodicDamageFor(aura, elapsed)
                out.targetHealth = math.max(0, out.targetHealth - periodicDamage)
            end
            aura.remaining = math.max(0, aura.remaining - elapsed)
            if aura.remaining <= 0 then
                if aura.targetModifier then removeTargetModifier(out, auraName) end
                out.auras[auraName] = nil
            end
        end
    end
    advanceModifierFallbacks(out, candidate.downtime)
    for auraName, aura in pairs(out.targetAuras or {}) do
        if type(aura) == "table" and aura.remaining then
            aura.remaining = math.max(0, aura.remaining - candidate.downtime)
            if aura.remaining <= 0 then out.targetAuras[auraName] = nil end
        end
    end
    if facts.exclusiveFamily then applyExclusiveFamily(out, action, projectedDelivery) end
    if hasTargetModifier and targetModifierRemaining and targetModifierRemaining > 0 then
        local prior, fallback = modifierPrior(applicationElapsed)
        applyTargetModifier(out, action, targetFacts, s, projectedDelivery,
            prior, fallback)
    end
    out.actorReadyAt[action.actor or "player"] = out.time
    if candidate.tooltip.cooldown and candidate.tooltip.cooldown > 0 then
        out.readyAt[(action.actor or "player") .. ":" .. action.name]
            = candidate.actionStart + candidate.tooltip.cooldown
    end
    if facts.reactive then out.readyAt[(action.actor or "player") .. ":" .. action.name] = out.time + 60 end
    if facts.nextInstant then out.instantNext = true
    elseif facts.kind ~= "modifier" and out.instantNext then out.instantNext = false end
    local cooldownGroup = facts.cooldownGroup or candidate.tooltip.cooldownGroup
    local categoryCooldown = candidate.tooltip.categoryCooldown
    if cooldownGroup and categoryCooldown and categoryCooldown > 0 then
        out.readyAt["group:" .. cooldownGroup] = candidate.actionStart + categoryCooldown
    end
    local dotDirectPower, dotPeriodicPower, dotDuration, dotElapsed = 0, 0, nil, 0
    if facts.kind == "dot" then
        if candidate.dotRawPeriodicPower ~= nil then
            dotPeriodicPower = candidate.dotPeriodicExpectedPower or 0
            dotDirectPower = math.max(0, candidate.power - dotPeriodicPower)
        else dotDirectPower, dotPeriodicPower = dotPowerSplit(candidate) end
        dotDuration = math.max(1, tonumber(candidate.tooltip.duration) or 12)
        dotElapsed = math.min(dotDuration,
            math.max(0, (candidate.occupancy or 0) - math.max(0, candidate.cast or 0)))
    end
    if (facts.kind == "damage" or facts.kind == "builder") and out.targetHealthExact then
        out.targetHealth = math.max(0, out.targetHealth - candidate.power)
    elseif facts.kind == "dot" and out.targetHealthExact then
        local immediatePeriodic = dotPeriodicPower * dotElapsed / dotDuration
        if candidate.dotRawPeriodicPower and XelAssistResistance and dotElapsed > 0 then
            local conditional = resistanceOverWindow(action, candidate.target,
                candidate.tooltip, s, applicationOffset, dotElapsed,
                "periodic", true)
            if conditional then
                immediatePeriodic = candidate.dotRawPeriodicPower / dotDuration
                    * dotElapsed * projectedDelivery * conditional
            end
        end
        out.targetHealth = math.max(0,
            out.targetHealth - dotDirectPower - immediatePeriodic)
    elseif facts.kind == "heal" then
        if candidate.target == "player" then out.health = math.min(out.healthMax, out.health + candidate.power)
        else out.healHealth = math.min(out.healMax, out.healHealth + candidate.power) end
    elseif facts.kind == "absorb" and not facts.petSacrifice then
        out.absorbs[action.name] = candidate.power
    elseif facts.kind == "hot" then
        local fraction = math.min(1, candidate.downtime / (candidate.tooltip.duration or 12))
        out.healHealth = math.min(out.healMax, out.healHealth + candidate.power * fraction)
    elseif facts.kind == "threatDrop" then out.hasAggro = false
    elseif facts.kind == "petHeal" and out.actors and out.actors.pet then
        out.actors.pet.health = math.min(out.actors.pet.healthMax, out.actors.pet.health + candidate.power)
    elseif facts.kind == "taunt" and out.actors and out.actors.pet then
        out.hasAggro = false; out.actors.pet.hasAggro = true
    elseif facts.kind == "command" and out.actors and out.actors.pet then
        if action.command == "passive" then
            out.actors.pet.stance = "passive"
        else
            out.actors.pet.targetExists = action.command == "attack"
            out.actors.pet.targetsCurrent = action.command == "attack"
        end
    elseif facts.kind == "resource" and facts.consumable then
        out.resource = math.min(out.resourceMax, out.resource + candidate.power)
    elseif facts.kind == "dispel" then out.dispelled = true
    elseif facts.kind == "summon" then
        out.pet = true
        out.actors.pet = { id = "pet", unit = "pet", actorType = "controlled",
            family = facts.summonFamily, health = 1, healthMax = 1,
            resource = 0, resourceMax = 0, targetExists = false,
            targetsCurrent = false, hasAggro = false }
    elseif facts.petSacrifice then
        out.pet = false
        out.actors.pet = nil
    end
    if (facts.kind == "interrupt" or facts.interrupt) and out.targetCasting then
        local prior = out.targetCastProbability
        if prior == nil then prior = 1 end
        out.targetCastProbability = prior * (1 - math.max(0, math.min(1,
            candidate.effectDelivery or 1)))
        out.targetCasting = out.targetCastProbability > 0.05
    end
    if out.targetCasting and out.targetCastRemaining
        and out.time >= out.targetCastRemaining then
        out.targetCasting, out.targetCastProbability = false, 0
    end
    if facts.kind == "builder" then out.combo = math.min(5, (out.combo or 0) + 1)
    elseif facts.combo then out.combo = 0 end
    if out.targetHealthExact and out.targetHealth <= 0 then out.hostile = false end
    if facts.kind == "dot" or facts.kind == "debuff" or facts.kind == "buff"
        or facts.kind == "hot" or facts.kind == "absorb" or facts.kind == "resource"
        or hasTargetModifier then
        local priorAura = out.auras[action.name]
        local priorStacks = type(priorAura) == "table" and (priorAura.stacks or 0) or 0
        local liveAura = s.targetAuras and s.targetAuras[action.name]
        priorStacks = math.max(priorStacks, liveAura and (liveAura.stacks or 1) or 0)
        local duration = facts.kind == "dot" and dotDuration or candidate.tooltip.duration
        local remaining = duration
        if facts.kind == "dot" then remaining = math.max(0, dotDuration - dotElapsed)
        elseif duration then remaining = math.max(0, duration - applicationElapsed) end
        if (remaining == nil or remaining > 0)
            and (not hasTargetModifier or targetModifierRemaining
                and targetModifierRemaining > 0) then
            out.auras[action.name] = { remaining = remaining,
                duration = duration, mine = true, target = candidate.target,
                periodicRate = facts.kind == "dot" and dotPeriodicPower / dotDuration or nil,
                periodicRawRate = facts.kind == "dot" and candidate.dotRawPeriodicPower
                    and candidate.dotRawPeriodicPower / dotDuration or nil,
                periodicAction = facts.kind == "dot" and action or nil,
                periodicTooltip = facts.kind == "dot"
                    and { school = candidate.tooltip.school } or nil,
                applicationProbability = projectedDelivery,
                targetModifier = hasTargetModifier and targetModifierRemaining
                    and targetModifierRemaining > 0 and true or false,
                exclusiveFamily = facts.exclusiveFamily,
                stacks = facts.stackable and math.min(facts.stackable, priorStacks + 1) or nil,
                expectedStacks = facts.stackable and math.min(facts.stackable,
                    priorStacks + projectedDelivery) or nil }
        end
    end
    return out
end

local function topCandidates(s, started, counter)
    local candidates, byName, actions, i = {}, {}, {}, nil
    local actorActions = XelAssistActors:Actions()
    for i = 1, table.getn(actorActions) do table.insert(actions, actorActions[i]) end
    if XelAssistInventory then
        local items = XelAssistInventory:Actions()
        for i = 1, table.getn(items) do table.insert(actions, items[i]) end
    end
    for i = 1, table.getn(actions) do
        if (GetTime() - started) * 1000 > MAX_MS then return nil, "graph budget exceeded" end
        local candidate, blocker = evaluate(actions[i], s)
        if candidate then
            local key = (candidate.action.actor or "player") .. ":" .. candidate.action.name
            local prior = byName[key]
            if not prior or candidate.value > prior.value then byName[key] = candidate end
        elseif blocker then counter.blockers[blocker] = (counter.blockers[blocker] or 0) + 1 end
    end
    local _, candidate
    for _, candidate in pairs(byName) do table.insert(candidates, candidate) end
    table.sort(candidates, function(a, b)
        if a.value == b.value then return a.action.rank > b.action.rank end
        return a.value > b.value
    end)
    local bestSetup, bestSetupScore, school, amount = nil, 0, nil, nil
    for _, candidate in ipairs(candidates) do
        local tooltip = candidate.tooltip or {}
        local remaining = (tonumber(tooltip.duration) or 0)
            - math.max(0, (candidate.occupancy or 0) - (candidate.cast or 0))
        if candidate.target == "target" and remaining > 0
            and (candidate.effectDelivery or 1) > 0 then
            local score = math.max(0, tonumber(tooltip.targetArmorReduction) or 0)
            for school, amount in pairs(tooltip.targetResistanceReduction or {}) do
                score = score + math.max(0, tonumber(amount) or 0)
            end
            for school, amount in pairs(tooltip.targetDamageTaken or {}) do
                score = score + math.max(0, tonumber(amount) or 0) * 100
            end
            score = score * remaining * (candidate.effectDelivery or 1)
            if score > bestSetupScore then
                bestSetup, bestSetupScore = candidate, score
            end
        end
    end
    while table.getn(candidates) > WIDTH do table.remove(candidates) end
    if bestSetup then
        local retained, index = false, nil
        for index = 1, table.getn(candidates) do
            if candidates[index] == bestSetup then retained = true end
        end
        if not retained and table.getn(candidates) >= WIDTH then
            candidates[WIDTH] = bestSetup
            table.sort(candidates, function(a, b)
                if a.value == b.value then return a.action.rank > b.action.rank end
                return a.value > b.value
            end)
        end
    end
    counter.count = counter.count + table.getn(candidates)
    if counter.count > MAX_STATES then return nil, "graph budget exceeded" end
    return candidates
end

function G:Evaluate(mode, preview)
    local started, counter, state = GetTime(), { count = 0, blockers = {} }, self:Snapshot(mode)
    local observed = { health = state.health, healthMax = state.healthMax,
        targetHealth = state.targetHealth, targetMax = state.targetMax,
        targetHealthExact = state.targetHealthExact,
        resource = state.resource, resourceMax = state.resourceMax,
        moving = state.moving, hasAggro = state.hasAggro, tank = state.tank,
        distance = state.distance, distanceKind = state.distanceKind,
        talentPoints = state.talentPoints }
    local depth = tonumber(XelAssistCharDB.graphDepth) or 3
    if depth < 1 then depth = 1 end
    if depth > MAX_DEPTH then depth = MAX_DEPTH end
    local frontier = { { state = state, steps = {}, total = 0 } }
    local terminal, err, i = {}, nil, nil
    for i = 1, depth do
        local expanded = {}
        local p
        for p = 1, table.getn(frontier) do
            local path = frontier[p]
            local candidates
            candidates, err = topCandidates(path.state, started, counter)
            if not candidates then return nil, err, true end
            if table.getn(candidates) == 0 then table.insert(terminal, path) end
            local c
            for c = 1, table.getn(candidates) do
                local candidate = candidates[c]
                if candidate.value > 0 then
                    local steps, n = {}, nil
                    for n = 1, table.getn(path.steps) do steps[n] = path.steps[n] end
                    table.insert(steps, candidate)
                    table.insert(expanded, { state = advance(path.state, candidate), steps = steps,
                        total = path.total + candidate.value / i })
                end
            end
        end
        if table.getn(expanded) == 0 then break end
        table.sort(expanded, function(a, b) return a.total > b.total end)
        while table.getn(expanded) > WIDTH do table.remove(expanded) end
        frontier = expanded
    end
    local paths = {}
    for i = 1, table.getn(frontier) do table.insert(paths, frontier[i]) end
    for i = 1, table.getn(terminal) do table.insert(paths, terminal[i]) end
    table.sort(paths, function(a, b) return a.total > b.total end)
    local bestPath = paths[1]
    local best = bestPath and bestPath.steps[1]
    if not best then
        if counter.blockers["minimum range"] and counter.blockers["minimum range"] > 0 then return nil, "Move farther away", false end
        if counter.blockers.range and counter.blockers.range > 0 then return nil, "Move into range", false end
        if counter.blockers.moving and counter.blockers.moving > 0 then return nil, "Finish moving", false end
        if counter.blockers.resource and counter.blockers.resource > 0 then return nil, "Not enough resources", false end
        if counter.blockers.cooldown and counter.blockers.cooldown > 0 then return nil, "Waiting for cooldown", false end
        if not state.hostile and state.healHealth >= state.healMax then return nil, "Select a target or injured ally", false end
        return nil, "No worthwhile action", false
    end
    local follow = {}
    for i = 2, table.getn(bestPath.steps) do table.insert(follow, bestPath.steps[i].action) end
    if best.target == "target" then
        observed.distance, observed.distanceKind = state.targetDistance, state.targetDistanceKind
    elseif best.target == state.healUnit then
        observed.distance, observed.distanceKind = state.healDistance, state.healDistanceKind
    elseif best.target == "player" then
        observed.distance, observed.distanceKind = 0, "self"
    end
    local unknowns = {}
    local bestKind = best.action.facts.kind
    local bestDistance = state.targetDistance
    local bestLineOfSight = state.targetLineOfSight
    if best.action.actor == "pet" and state.actors.pet then
        bestDistance = state.actors.pet.distance
        bestLineOfSight = state.actors.pet.lineOfSight
    end
    if best.target == "target" and bestDistance == nil then table.insert(unknowns, "range") end
    if best.target == "target" and bestLineOfSight == nil then table.insert(unknowns, "line of sight") end
    if (bestKind == "damage" or bestKind == "dot" or bestKind == "builder")
        and not state.targetHealthExact then table.insert(unknowns, "exact target health") end
    if (bestKind == "damage" or bestKind == "dot" or bestKind == "builder"
        or bestKind == "debuff" or bestKind == "crowdControl" or bestKind == "interrupt"
        or bestKind == "taunt")
        and best.resistance then
        if best.resistance.school == nil and best.resistance.mode ~= "mixed" then
            table.insert(unknowns, (bestKind == "damage" or bestKind == "dot"
                or bestKind == "builder") and "damage school" or "effect delivery")
        elseif best.resistance.unknown then
            table.insert(unknowns, best.resistance.school == 0 and "target armor"
                or string.lower(best.resistance.schoolName or "school") .. " resistance")
        end
        if best.resistance.penetrationUnknown then table.insert(unknowns,
            (best.action.facts.damageActor == "pet" or best.action.actor == "pet")
                and "companion penetration" or "equipped penetration") end
        local resistanceConfidence = best.resistance.confidence
        if not best.resistance.unknown and (resistanceConfidence == "limited samples"
            or resistanceConfidence == "partial" or resistanceConfidence == "inferred field") then
            table.insert(unknowns, "limited resistance evidence")
        end
    end
    if XelAssistResistance and best.resistance
        and (bestKind == "damage" or bestKind == "dot" or bestKind == "builder") then
        local contrastState = stateAtImpact and stateAtImpact(state,
            (best.wait or 0) + (best.cast or 0)) or state
        local contrast = XelAssistResistance:Contrast(contrastState, best.resistance)
        if contrast then best.reason = contrast
        elseif not best.resistance.unknown and best.resistance.multiplier <= 0.85
            and best.reason ~= "finishes the target" then
            best.reason = "best expected value after " .. string.lower(best.resistance.schoolName or "target")
                .. " mitigation"
        end
    end
    local confidence = table.getn(unknowns) > 0 and "partial data"
        or (best.estimated and "estimated" or "client data")
    return { action = best.action, follow = follow, reason = best.reason, target = best.target,
        actor = best.action.actor or "player",
        confidence = confidence, unknowns = unknowns, expanded = counter.count,
        elapsed = (GetTime() - started) * 1000, value = best.value,
        threat = best.threat, downtime = best.downtime, observed = observed,
        resistance = best.resistance, tooltip = best.tooltip, wait = best.wait, cast = best.cast,
        blockers = counter.blockers, path = bestPath.steps }, nil, false
end
