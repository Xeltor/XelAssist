XelAssist.Graph.Targets = {}
local T = XelAssist.Graph.Targets
local S = XelAssist.Graph.State
local Selection = XelAssist.Graph.TargetSelection
local Admission = XelAssist.Graph.ActionAdmission

local APPLICATION_BLOCK_THRESHOLD = 0.75

function T:VariableFriendlyAction(action)
    return Selection:VariableFriendlyAction(action)
end

function T:Targets(action, state)
    return Selection:Targets(action, state)
end
local function friendlyAuraActive(action, state, descriptor)
    local record = descriptor and descriptor.record
        or descriptor and S:FriendlyByKey(state, descriptor.key)
    if not record then return false end
    local aura = record.auras and record.auras[action.name]
    if not aura and record.absorbs and record.absorbs[action.name] then
        aura = record.absorbs[action.name]
    end
    if aura then
        if type(aura) ~= "table" then return true end
        local probability = tonumber(aura.applicationProbability) or 1
        local refresh = math.max(1.5, (tonumber(aura.duration) or 0) * 0.2)
        if probability >= APPLICATION_BLOCK_THRESHOLD
            and (aura.remaining == nil or aura.remaining > refresh) then
            return true
        end
    end
    if (state.time or 0) <= 0 and XelAssist.Game.Capabilities.UnitHasBuff then
        return XelAssist.Game.Capabilities:UnitHasBuff(descriptor.unit, action.name)
    end
    return false
end

function T:AuraActive(action, state, descriptor)
    if descriptor and descriptor.relation ~= "hostile" then
        return friendlyAuraActive(action, state, descriptor)
    end
    local future = state.auras[action.name]
    if action.facts.stackable then
        local futureProbability = type(future) == "table"
            and tonumber(future.applicationProbability) or 1
        local stacks = futureProbability >= APPLICATION_BLOCK_THRESHOLD
            and type(future) == "table"
            and tonumber(future.expectedStacks or future.stacks) or 0
        local live = state.targetAuras and state.targetAuras[action.name]
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
            and (future.remaining == nil or future.remaining > refresh) then
            return true
        end
    end
    local aura = state.targetAuras and state.targetAuras[action.name]
    if not aura then return XelAssist.Game.Capabilities:TargetHasDebuff(action.name) end
    if (tonumber(aura.applicationProbability) or 1) < APPLICATION_BLOCK_THRESHOLD then
        return false
    end
    if action.facts.kind == "dot" and aura.mine == false then return false end
    local refresh = math.max(1.5, (aura.duration or 0) * 0.2)
    if aura.remaining ~= nil and aura.remaining <= refresh then return false end
    return true
end

function T:Relevant(action, state, descriptor)
    local kind = action.facts.kind
    local friendly = descriptor and descriptor.relation ~= "hostile"
        and (descriptor.record or S:FriendlyByKey(state, descriptor.key)) or nil
    if action.facts.consumable then
        if not state.inCombat then return false end
        local current, maximum = state.resource, state.resourceMax
        if kind == "heal" then current, maximum = state.health, state.healthMax end
        local missing = math.max(0, (maximum or 0) - (current or 0))
        local expected = action.itemFacts and action.itemFacts.average or 0
        return missing > 0 and (expected <= 0 or missing >= expected * 0.5)
    end
    if action.actor == "pet" and kind == "command" then
        local pet = state.actors and state.actors.pet
        if action.command == "attack" then
            return state.hostile and pet and (not pet.targetsCurrent
                or pet.attackActiveKnown == true and pet.attackActive ~= true)
        end
        if action.command == "passive" then
            return pet and pet.stance ~= "passive" and pet.healthMax > 0
                and pet.health / pet.healthMax < 0.25
        end
        return pet and pet.targetExists
            and ((pet.healthMax > 0 and pet.health / pet.healthMax < 0.25)
                or not pet.targetsCurrent)
    end
    local support = kind == "heal" or kind == "hot" or kind == "absorb" or kind == "buff"
        or kind == "defensive" or kind == "resource" or kind == "threatDrop"
        or kind == "modifier" or kind == "summon" or kind == "petHeal"
    if state.mode == "buff" then return kind == "buff" end
    if state.mode == "support" then return support end
    if state.mode == "single" or state.mode == "aoe" then return not support end
    if state.targetCasting and (kind == "interrupt" or action.facts.interrupt) then
        return true
    end
    if state.hasAggro and not state.tank
        and (kind == "threatDrop" or kind == "defensive") then
        return true
    end
    if state.healthMax > 0 and state.health / state.healthMax < 0.35
        and (kind == "defensive" or (kind == "heal" and action.facts.self)) then
        return true
    end
    if friendly and (tonumber(friendly.healthMax) or 0) > 0
        and (tonumber(friendly.health) or 0) / friendly.healthMax < 0.45
        and (kind == "heal" or kind == "hot" or kind == "absorb") then
        return true
    end
    if state.hostile then
        return kind ~= "buff" or action.facts.self or action.facts.combatBuff
    end
    return support
end

local function policyBlocker(action, state)
    local facts = action.facts
    if action.actor == "pet" and not XelAssistCharDB.toggles.petActions then
        return "companion policy"
    end
    if facts.consumable and not XelAssistCharDB.toggles.consumables then
        return "consumable policy"
    end
    if facts.playerAttack then
        if not (XelAssist.Game.PlayerAttack
            and XelAssist.Game.PlayerAttack.CanStart)
            or not state.playerAttack then
            return "player Attack state unavailable"
        end
        local allowed, reason = XelAssist.Game.PlayerAttack:CanStart(
            state.playerAttack)
        if not allowed then return reason or "player Attack state uncertain" end
    end
    if facts.autoRepeat and state.autoShot and state.autoShot.active then
        return "already active"
    end
    if facts.petCombatBuff then
        local pet = state.actors and state.actors.pet
        if not state.inCombat then return "companion combat buff out of combat" end
        if not (pet and pet.targetExists and pet.targetsCurrent) then
            return "companion not engaged"
        end
    end
    local petBlocker = XelAssist.Game.Pets and XelAssist.Game.Pets.Actions
        and XelAssist.Game.Pets.Actions:Blocker(action, state)
    if petBlocker then return petBlocker end
    local threatBlocker = XelAssist.Graph.CompanionThreat
        and XelAssist.Graph.CompanionThreat:Block(state, action)
    if threatBlocker then return threatBlocker end
    if (facts.pet or action.actor == "pet") and not state.pet then return "pet" end
    if action.autocastEnabled then return "autocast active" end
    if facts.reagent and not XelAssistCharDB.toggles.reagents then
        return "reagent"
    end
    if facts.reagentName then
        local count = state.inventory and state.inventory.reagentCounts
            and state.inventory.reagentCounts[facts.reagentName]
        if count == nil then
            local available = XelAssist.Game.Actors:HasReagent(facts.reagentName)
            if available == false then return "missing " .. facts.reagentName end
        elseif count <= 0 then return "missing " .. facts.reagentName end
    end
    if facts.resourceType == "mana" and state.resourceType ~= nil
        and state.resourceType ~= 0 then
        return "resource type"
    end
    if facts.combo and state.combo <= 0 then return "combo points" end
    if facts.execute and state.targetMax > 0
        and state.targetHealth * 100 / state.targetMax > facts.execute then
        return "execute range"
    end
    return nil
end

local function targetBlocker(action, state, descriptor, target)
    if action.actor == "pet" and action.executor == "petAbility"
        and descriptor.relation == "hostile" then
        local pet = state.actors and state.actors.pet
        if not (pet and pet.targetExists) then return "companion has no target" end
        if not pet.targetsCurrent then return "companion targets another enemy" end
    end
    if action.actor == "pet" and target ~= "target" then
        local facts, kind = action.facts, action.facts.kind
        if kind ~= "command" and kind ~= "petHeal"
            and not facts.petSacrifice and not facts.self then
            return "companion recipient must be selected" end
    end
    if descriptor.relation == "hostile" and state.targetHealthExact
        and state.targetHealth <= 0 then
        return "target defeated"
    end
    local inventoryBlocker = XelAssist.Game.Inventory and XelAssist.Game.Inventory:Blocker(action, state)
    if inventoryBlocker then return inventoryBlocker end
    local observedBlocker = descriptor.relation == "hostile" and XelAssist.Combat.Observations
        and XelAssist.Combat.Observations:Blocker(action, target)
    return observedBlocker
end
local function usabilityBlocker(action, state, descriptor, target, tooltip)
    local facts, kind = action.facts, action.facts.kind
    if not facts.consumable
        and (facts.cooldown or (tooltip.cooldown and tooltip.cooldown >= 30))
        and not XelAssistCharDB.toggles.cooldowns then
        return "cooldown policy"
    end
    local usable, usableReason
    if action.actor == "pet" then
        if GetPetActionsUsable then
            local ok, value = pcall(GetPetActionsUsable)
            if ok and (value == false or value == 0) then
                usable, usableReason = false, "pet state"
            end
        end
    elseif action.executor ~= "item" then
        usable, usableReason = XelAssist.Game.Capabilities:Usable(action)
    end
    local petBlocker = XelAssist.Game.Pets and XelAssist.Game.Pets.Actions
        and XelAssist.Game.Pets.Actions:UsabilityBlocker(action, usable, usableReason)
    if petBlocker then return petBlocker end
    if facts.reactive and usable ~= true then return "proc unknown" end
    if usable == false and descriptor.relation == "hostile" then
        return usableReason or "state"
    end
    if descriptor.relation == "hostile" and not state.hostile then return "target" end
    if kind == "dispel" and not target then return "nothing to dispel" end
    return nil
end

local function positionBlocker(action, state, descriptor)
    local facts, kind = action.facts, action.facts.kind
    if facts.autoRepeat and state.playerCasting
        and not state.playerChanneling then return "casting" end
    local actorLineOfSight
    if descriptor.relation == "hostile" then actorLineOfSight = state.targetLineOfSight end
    if descriptor.relation == "hostile" and (action.actor == "pet"
        or facts.effectActor == "pet" or facts.damageActor == "pet")
        and state.actors and state.actors.pet then
        actorLineOfSight = state.actors.pet.lineOfSight
    end
    if descriptor.record and descriptor.record.lineOfSight ~= nil then
        actorLineOfSight = descriptor.record.lineOfSight
    end
    if actorLineOfSight == false then return "line of sight" end
    local actorBehind
    if descriptor.relation == "hostile" then actorBehind = state.playerBehindTarget end
    if descriptor.relation == "hostile" and action.actor == "pet"
        and state.actors and state.actors.pet then
        actorBehind = state.actors.pet.behind
    end
    if facts.behind and actorBehind == false then return "must be behind target" end
    if facts.outOfCombat and state.inCombat then return "combat state" end
    if facts.combatOnly and not state.inCombat then return "combat state" end
    if kind == "summon" and not facts.petLifecycle then
        if state.pet then return "companion already active" end
        if state.inCombat then return "unsafe summon" end
    end
    return nil
end

local function rangeBlocker(action, state, descriptor, target, tooltip)
    local facts = action.facts
    if facts.autoRepeat then
        local auto = state.autoShot
        local expected = descriptor.guid or state.targetGUID
        if not auto or auto.rangeChecked ~= true
            or auto.rangeIdentityVerified ~= true
            or expected == nil or auto.rangeTargetGuid ~= expected
            or auto.rangeSpellId
                ~= XelAssist.Combat.AutoShotRange:CanonicalSpellId(
                    action.spellId) then
            return "Auto Shot target evidence changed"
        end
        if auto.rangeVerdict == false then return "range" end
        if auto.rangeVerdict ~= true then return "Auto Shot range unknown" end
        return nil
    end
    local liveRange
    local implicitPetTarget = XelAssist.Game.Pets and XelAssist.Game.Pets.Actions
        and XelAssist.Game.Pets.Actions:ImplicitTarget(action)
    if action.actor ~= "pet" and action.executor ~= "item" and not implicitPetTarget then
        liveRange = XelAssist.Game.Capabilities:InRange(
            XelAssist.Game.Capabilities:CastName(action), target)
    end
    if liveRange == false then return "range" end
    -- Unknown direct range remains unknown; only then use discovered geometry.
    local rangeDistance = descriptor.record and descriptor.record.distance or state.distance
    if (action.actor == "pet" or action.facts.effectActor == "pet"
        or action.facts.damageActor == "pet") and descriptor.relation == "hostile"
        and state.actors and state.actors.pet then
        rangeDistance = state.actors.pet.distance
    elseif descriptor.relation == "hostile" and state.targetDistance ~= nil then
        rangeDistance = state.targetDistance
    elseif target == "player" or target == "pet" and descriptor.relation ~= "hostile" then
        rangeDistance = 0
    end
    local minRange, maxRange = tooltip.minRange, tooltip.maxRange
    if descriptor.relation == "hostile" and facts.effectActor == "pet" then
        minRange = facts.effectMinRange or minRange
        maxRange = facts.effectMaxRange or maxRange
    end
    if liveRange == nil and rangeDistance then
        if minRange and rangeDistance < minRange then
            return "minimum range"
        end
        if maxRange and maxRange > 0 and rangeDistance > maxRange then
            return "range"
        end
    end
    if facts.commandMaxRange and state.targetDistance
        and state.targetDistance > facts.commandMaxRange then
        return "command range"
    end
    if facts.requiresPetMelee and rangeDistance == nil then
        return "companion melee range unknown"
    end
    return nil
end

local function effectBlocker(owner, action, state, descriptor, target,
    actionStart, tooltip)
    local facts, kind = action.facts, action.facts.kind
    if (kind == "dot" or kind == "debuff")
        and owner:AuraActive(action, state, descriptor) then
        return "already active"
    end
    local pendingTarget = (facts.deferredUntilPetMelee
        or facts.petCombatBuff or facts.petCombatEffects)
        and descriptor.castGuid or descriptor.guid or target
    if (kind == "dot" or kind == "debuff" or kind == "crowdControl"
        or kind == "buff" or kind == "hot" or kind == "absorb" or kind == "resource")
        and XelAssist and XelAssist.IsAuraPending
        and XelAssist:IsAuraPending(action.name, action.actor,
            pendingTarget) then
        return "application pending"
    end
    local pet = state.actors and state.actors.pet
    if facts.deferredUntilPetMelee and pet and pet.pendingMeleeEffects
        and pet.pendingMeleeEffects[action.name] then
        return "companion proc already armed"
    end
    if facts.petCombatBuff and XelAssist.Game.Pets
        and XelAssist.Game.Pets.Effects
        and XelAssist.Game.Pets.Effects:Active(pet, action.name) then
        return "companion effect already active"
    end
    if (kind == "buff" or kind == "hot" or kind == "absorb" or kind == "resource")
        and owner:AuraActive(action, state, descriptor) then
        return "already active"
    end
    if kind == "interrupt" and not state.targetCasting then return "not casting" end
    if kind == "interrupt" and state.targetCastRemaining
        and actionStart >= state.targetCastRemaining then
        return "interrupt too late"
    end
    if kind == "taunt" then
        local petTank = XelAssistCharDB.petThreat == "tank"
            or (XelAssistCharDB.petThreat ~= "avoid" and state.groupSize == 0)
        if not petTank or (state.actors.pet and state.actors.pet.hasAggro) then
            return "pet threat policy"
        end
    end
    if kind == "crowdControl" and not XelAssistCharDB.toggles.petControl then
        return "pet control policy"
    end
    if facts.requiresCreature and state.targetCreatureType
        and facts.requiresCreature ~= state.targetCreatureType then
        return "creature immunity"
    end
    if kind == "crowdControl" and XelAssist.Game.Capabilities:TargetHasDebuff(action.name) then
        return "already controlled"
    end
    local friendlySupport = descriptor.relation ~= "hostile"
        and (kind == "heal" or kind == "hot" or kind == "absorb" or kind == "buff")
    local area = facts.aoe or tooltip and tooltip.topology
        and tooltip.topology.area
    if area and not friendlySupport and state.mode ~= "aoe"
        and not XelAssistCharDB.allowAoe then
        return "area policy"
    end
    return nil
end

function T:Legal(action, state, descriptor)
    if not descriptor or not descriptor.unit then return false, "target" end
    if not self:Relevant(action, state, descriptor) then return false, "intent" end
    local blocker = policyBlocker(action, state)
    if blocker then return false, blocker end
    local target, tooltip = descriptor.unit, XelAssist.Game.Actors:Facts(action)
    blocker = targetBlocker(action, state, descriptor, target)
    if blocker then return false, blocker end
    blocker = usabilityBlocker(action, state, descriptor, target, tooltip)
    if blocker then return false, blocker end
    blocker = positionBlocker(action, state, descriptor)
    if blocker then return false, blocker end
    local actionStart
    actionStart, blocker = Admission:Start(action, state, tooltip)
    if blocker then return false, blocker end
    blocker = Admission:Readiness(action, state, tooltip, actionStart)
    if blocker then return false, blocker end
    blocker = rangeBlocker(action, state, descriptor, target, tooltip)
    if blocker then return false, blocker end
    blocker = effectBlocker(self, action, state, descriptor, target,
        actionStart, tooltip)
    if blocker then return false, blocker end
    return true, nil, tooltip, target, actionStart, descriptor
end
