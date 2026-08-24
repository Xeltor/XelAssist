XelAssistGraph = {}
local G = XelAssistGraph

local MAX_STATES = 80
local MAX_MS = 3
local WIDTH = 4
local MAX_DEPTH = 5

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

function G:Snapshot(mode)
    local actors = XelAssistActors:Snapshot()
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
    return {
        mode = mode, hostile = hostile, healUnit = healUnit,
        health = UnitHealth("player") or 0, healthMax = UnitHealthMax("player") or 0,
        healHealth = healHealth, healMax = healMax,
        targetHealth = targetHealth, targetMax = targetMax, targetHealthExact = targetHealthExact,
        targetCreatureType = hostile and UnitCreatureType and UnitCreatureType("target") or nil,
        targetResistances = hostile and XelAssistObservations
            and XelAssistObservations:LiveResistances("target") or nil,
        playerLevel = UnitLevel and UnitLevel("player") or nil,
        inCombat = UnitAffectingCombat and UnitAffectingCombat("player") and true or false,
        resource = UnitMana("player") or 0, resourceMax = UnitManaMax("player") or 0,
        resourceType = UnitPowerType and UnitPowerType("player") or nil,
        combo = GetComboPoints and GetComboPoints() or 0,
        moving = PlayerIsMoving and PlayerIsMoving() or false,
        pet = actors.pet ~= nil, actors = actors, inventory = inventory,
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
        auras = {}, absorbs = {}, readyAt = {}, time = 0,
        actorReadyAt = { player = math.max(castRemaining or 0,
            gcdRemaining or 0, XelAssistCapabilities:GCDRemaining()), pet = 0 },
    }
end

local function copyState(s)
    local out, key, value = {}, nil, nil
    for key, value in pairs(s) do out[key] = value end
    out.auras = {}; for key, value in pairs(s.auras) do out.auras[key] = value end
    out.absorbs = {}; for key, value in pairs(s.absorbs or {}) do out.absorbs[key] = value end
    out.readyAt = {}; for key, value in pairs(s.readyAt) do out.readyAt[key] = value end
    out.actorReadyAt = {}; for key, value in pairs(s.actorReadyAt or {}) do out.actorReadyAt[key] = value end
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
    if (kind == "dot" or kind == "debuff") and (s.auras[action.name] or XelAssistCapabilities:TargetHasDebuff(action.name)) then return false, "already active" end
    if (kind == "dot" or kind == "debuff" or kind == "crowdControl")
        and XelAssist and XelAssist.IsAuraPending and XelAssist:IsAuraPending(action.name) then
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
    if action.facts.kind == "damage" or action.facts.kind == "dot" then
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

    if kind == "damage" or kind == "builder" then
        local effective = s.targetHealthExact and s.targetHealth > 0 and math.min(power, s.targetHealth) or power
        value = 250 + effective * 4 / math.max(0.5, downtime)
        if s.targetHealthExact and s.targetHealth > 0 and power >= s.targetHealth then value, reason = value + 700, "finishes the target"
        elseif facts.recovery then
            value = value + ((s.resourceMax > 0 and (1 - s.resource / s.resourceMax) * 300) or 0)
            reason = "preserves resources"
        elseif cast > 0 then reason = "best value after cast time"
        else reason = "best immediate value" end
        if s.role == "damage" then value = value * 1.15
        elseif s.role == "healer" then value = value * 0.85 end
    elseif kind == "dot" then
        local effective, fraction = power, 1
        if s.targetHealthExact and s.targetHealth > 0 then
            effective = math.min(power, s.targetHealth)
            fraction = math.min(1, s.targetHealth / math.max(1, power))
        end
        value = effective * 4 / math.max(1, downtime) + effective / math.max(1, cost) * 45
        if fraction < 1 then value = value - (power - effective) * 3 end
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
        value = s.targetCasting and 5000 or -1000
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
    elseif kind == "buff" or kind == "debuff" then value, reason = 500 + (tooltip.duration or 0) * 4, "adds missing utility"
    elseif kind == "modifier" then
        local missing = math.max(0, s.healMax - s.healHealth)
        value = (facts.nextInstant and (s.moving or missing > s.healMax * 0.45)) and 1500 or 250
        reason = facts.nextInstant and "makes the next cast instant" or "improves the next action"
    end

    if facts.aoe then value = value * (s.mode == "aoe" and 1.8 or 0.55) end
    if (kind == "damage" or kind == "dot" or kind == "builder") and XelAssistObservations then
        local resistance, resistanceSource = XelAssistObservations:ResistanceMultiplier(action, target, tooltip, s)
        if resistance < 1 then
            value = value * resistance
            if resistance <= 0.85 then reason = (resistanceSource or "observed resistance") .. " lowers expected damage" end
        end
    end
    if facts.interrupt and s.targetCasting then value, reason = value + 4500, "stops the current cast" end
    if facts.execute and s.targetMax > 0 and s.targetHealth * 100 / s.targetMax <= facts.execute then value = value + 900 end
    if facts.leech and s.healthMax > 0 then value = value + (1 - s.health / s.healthMax) * 500 end
    local threat = power * (facts.threat or (kind == "heal" and 0.5 or 1))
    if action.actor == "pet" then threat = threat * 0.9 end
    if action.actor == "pet" then
        local petTank = XelAssistCharDB.petThreat == "tank"
            or (XelAssistCharDB.petThreat ~= "avoid" and s.groupSize == 0)
        if petTank then value = value + threat * 0.4
        elseif s.groupSize > 0 then value = value - threat * 0.25 end
    elseif s.tank and threat > power then
        value = value + (threat - power) * 0.5
        reason = "builds threat"
    elseif (s.groupSize > 0 or s.pet) and not s.tank then
        value = value - threat * (s.hasAggro and 3 or 0.25)
        if s.hasAggro then reason = "limits additional threat"
        elseif threat > power * 1.2 then reason = "lower threat for the group" end
    end
    if cost > 0 and s.resourceMax > 0 then value = value - cost / s.resourceMax * 240 end
    if facts.inferred then estimated = true end
    if estimated then value = value * 0.88 end
    return { action = action, value = value, reason = reason, target = target,
        cost = cost, cast = cast, downtime = downtime, threat = threat,
        estimated = estimated, tooltip = tooltip, power = power,
        wait = wait, occupancy = occupancy, actionStart = actionStart }
end

local function advance(s, candidate)
    local out, action, facts = copyState(s), candidate.action, candidate.action.facts
    if action.actor == "pet" and out.actors and out.actors.pet then
        local actors, key, value = {}, nil, nil
        for key, value in pairs(out.actors) do actors[key] = value end
        local pet = {}; for key, value in pairs(out.actors.pet) do pet[key] = value end
        actors.pet, out.actors = pet, actors
        pet.resource = math.max(0, pet.resource - candidate.cost)
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
    out.time = out.time + candidate.downtime
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
    if (facts.kind == "damage" or facts.kind == "builder") and out.targetHealthExact then
        out.targetHealth = math.max(0, out.targetHealth - candidate.power)
    elseif facts.kind == "dot" and out.targetHealthExact then
        local fraction = math.min(1, candidate.downtime / (candidate.tooltip.duration or 12))
        out.targetHealth = math.max(0, out.targetHealth - candidate.power * fraction)
    elseif facts.kind == "heal" then
        if candidate.target == "player" then out.health = math.min(out.healthMax, out.health + candidate.power)
        else out.healHealth = math.min(out.healMax, out.healHealth + candidate.power) end
    elseif facts.kind == "absorb" and not facts.petSacrifice then
        out.absorbs[action.name] = candidate.power
    elseif facts.kind == "hot" then
        local fraction = math.min(1, candidate.downtime / (candidate.tooltip.duration or 12))
        out.healHealth = math.min(out.healMax, out.healHealth + candidate.power * fraction)
    elseif facts.kind == "threatDrop" then out.hasAggro = false
    elseif facts.kind == "interrupt" then out.targetCasting = false
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
        out.auras[action.name] = true
    end
    if facts.kind == "builder" then out.combo = math.min(5, (out.combo or 0) + 1)
    elseif facts.combo then out.combo = 0 end
    if out.targetHealthExact and out.targetHealth <= 0 then out.hostile = false end
    if facts.kind == "dot" or facts.kind == "debuff" or facts.kind == "buff" or facts.kind == "hot" or facts.kind == "absorb" or facts.kind == "resource" then
        out.auras[action.name] = true
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
    while table.getn(candidates) > WIDTH do table.remove(candidates) end
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
    return { action = best.action, follow = follow, reason = best.reason, target = best.target,
        actor = best.action.actor or "player",
        confidence = best.estimated and "estimated" or "client data", expanded = counter.count,
        elapsed = (GetTime() - started) * 1000, value = best.value,
        threat = best.threat, downtime = best.downtime, observed = observed,
        blockers = counter.blockers, path = bestPath.steps }, nil, false
end
