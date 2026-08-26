XelAssist.Graph.Targets = {}
local T = XelAssist.Graph.Targets
local S, Selection = XelAssist.Graph.State, XelAssist.Graph.TargetSelection
local Admission, ContextPolicy = XelAssist.Graph.ActionAdmission, XelAssist.Graph.ActionContextPolicy
local TargetAuras = XelAssist.Graph.TargetAuras
function T:VariableFriendlyAction(action) return Selection:VariableFriendlyAction(action) end
function T:Targets(action, state) return Selection:Targets(action, state) end
local function observed(method, state, action, descriptor)
    local root = XelAssist.Graph.RootObservation
    if not root then return nil, "absent" end
    return root[method](root, state, action, descriptor) end
local function configFor(state)
    local root = XelAssist.Graph.RootObservation
    if not root then return XelAssistCharDB or {}, "known" end
    return root:ConfigOrLive(state) end
local function frozenAura(action, state, descriptor)
    return TargetAuras:Frozen(action, state, descriptor)
end
local function divergentTooltip(action, state, descriptor, tooltip)
    local blocker
    local mage = XelAssist.Graph.MageProcWindows
    if mage then tooltip, blocker = mage:PrepareLegal(action, state, tooltip) end
    if blocker then return nil, blocker end
    local nightfall = XelAssist.Graph.WarlockNightfall
    if nightfall then
        tooltip, blocker = nightfall:PrepareLegal(action, state, tooltip)
    end
    if blocker then return nil, blocker end
    local devastate = XelAssist.Graph.WarriorDevastate
    if devastate then
        tooltip, blocker = devastate:PrepareLegal(
            action, state, descriptor, tooltip)
    end
    return tooltip, blocker
end
function T:AuraActive(action, state, descriptor)
    return TargetAuras:Active(action, state, descriptor)
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
        local policy = XelAssist.Graph.CompanionCommandPolicy
        return policy and policy:Relevant(action, state) or false
    end
    local support = kind == "heal" or kind == "hot" or kind == "absorb" or kind == "buff"
        or kind == "defensive" or kind == "resource" or kind == "threatDrop" or kind == "modifier" or kind == "summon" or kind == "totem" or kind == "petHeal"
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
local function policyBlocker(action, state, tooltip, descriptor, config)
    local facts = action.facts
    local toggles = config.toggles or {}
    if action.actor == "pet" and not toggles.petActions then
        return "companion policy"
    end
    if facts.consumable and not toggles.consumables then
        return "consumable policy"
    end
    if facts.playerAttack then
        if state.playerStealthed == true then
            return "stealth opener protection"
        end
        if not (XelAssist.Game.PlayerAttack
            and XelAssist.Game.PlayerAttack.CanStart)
            or not state.playerAttack then
            return "player Attack state unavailable"
        end
        local allowed, reason = XelAssist.Game.PlayerAttack:CanStart(
            state.playerAttack)
        if not allowed then return reason or "player Attack state uncertain" end
    end
    if facts.wandRepeat then
        if not state.wand or state.wand.activeKnown ~= true then
            return "wand repeat state unknown"
        end
        if state.wand.active then return "wand repeat already active" end
        if state.wand.pending then return "wand repeat start pending" end
    elseif facts.autoRepeat and state.autoShot and state.autoShot.active then
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
    if facts.reagent and not toggles.reagents then
        return "reagent"
    end
    if facts.reagentName then
        local count = state.inventory and state.inventory.reagentCounts
            and state.inventory.reagentCounts[facts.reagentName]
        if count == nil then
            local reagent, status = observed("Reagent", state, action)
            if status ~= "absent" then
                if status ~= "known" or not reagent.known then return
                        "reagent availability unknown" end
                if not reagent.available then return
                    "missing " .. facts.reagentName end
            else
                local available = XelAssist.Game.Actors:HasReagent(facts.reagentName)
                if available == false then return "missing " .. facts.reagentName end
            end
        elseif count <= 0 then return "missing " .. facts.reagentName end
    end
    if facts.resourceType == "mana" and state.resourceType ~= nil
        and state.resourceType ~= 0 and not tooltip.druidFormTransition then
        return "resource type"
    end
    if facts.combo or tooltip and tooltip.comboSpendAll then
        local available = XelAssist.Graph.ComboState
            and XelAssist.Graph.ComboState:AvailabilityForAction(
                state, facts, tooltip, descriptor)
            or state.combo > 0 and 1 or 0
        if available <= 0 then return "combo points" end
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
    local observedBlocker
    if descriptor.relation == "hostile"
        and (tonumber(state.time) or 0) <= 0 then
        local evidence, status = observed(
            "ObservedBlocker", state, action, descriptor)
        if status ~= "absent" then
            if status ~= "known" then return "target evidence unknown" end
            observedBlocker = evidence
        elseif XelAssist.Combat.Observations then
            observedBlocker = XelAssist.Combat.Observations:Blocker(action, target)
        end
    end
    return observedBlocker
end
local function usabilityBlocker(action, state, descriptor, target, tooltip)
    local facts, kind = action.facts, action.facts.kind
    local future = (state.time or 0) > 0
    local config, configStatus = configFor(state)
    if configStatus ~= "known" then return "config evidence unknown" end
    local toggles = config.toggles or {}
    if not facts.consumable and not facts.routineResourceCooldown
        and (facts.cooldown or (tooltip.cooldown and tooltip.cooldown >= 30))
        and not toggles.cooldowns then
        return "cooldown policy"
    end
    local usable, usableReason
    if not future then
        local usability, status = observed("Usability", state, action)
        if status ~= "absent" then
            if status ~= "known" then return "usability evidence unknown" end
            usable, usableReason = usability.usable, usability.reason
        elseif action.actor == "pet" then
            if GetPetActionsUsable then
                local ok, value = pcall(GetPetActionsUsable)
                if ok and (value == false or value == 0) then
                    usable, usableReason = false, "pet state"
                end
            end
        elseif action.executor ~= "item" then
            usable, usableReason = XelAssist.Game.Capabilities:Usable(action)
        end
    end
    local petBlocker = XelAssist.Game.Pets and XelAssist.Game.Pets.Actions
        and XelAssist.Game.Pets.Actions:UsabilityBlocker(action, usable, usableReason)
    if petBlocker then return petBlocker end
    if facts.reactive and action.actor == "pet" and usable ~= true then return "proc unknown" end
    if usable == false and descriptor.relation == "hostile" then
        return usableReason or "state"
    end
    if descriptor.relation == "hostile" and not state.hostile then return "target" end
    if kind == "dispel" and not target then return "nothing to dispel" end
    return nil
end
local function effectBlocker(owner, action, state, descriptor, target,
    actionStart, tooltip, config)
    local facts, kind = action.facts, action.facts.kind
    local playerSwings = XelAssist.Graph.PlayerSwings
    local swingBlocker = playerSwings
        and playerSwings:Blocker(action, state, descriptor, tooltip)
    if swingBlocker then return swingBlocker end
    if tooltip.requiresStealth and state.playerStealthKnown == true
        and state.playerStealthed ~= true then return "requires stealth" end
    local persistent = XelAssist.Graph.CasterPersistentDamage
    local persistentBlocker = persistent and persistent:Blocker(
        action, state, descriptor, tooltip, actionStart)
    if persistentBlocker then return persistentBlocker end
    if kind == "dot" or kind == "debuff" then
        local active, reason = owner:AuraActive(action, state, descriptor)
        if active then return reason or "already active" end
    end
    local pendingTarget = (facts.deferredUntilPetMelee
        or facts.petCombatBuff or facts.petCombatEffects)
        and descriptor.castGuid or descriptor.guid or target
    if (facts.submissionGuarded or kind == "dot" or kind == "debuff"
        or kind == "crowdControl"
        or kind == "buff" or kind == "hot" or kind == "absorb"
        or kind == "resource" or kind == "petHeal")
        and (state.time or 0) <= 0 then
        local pending, status = observed("Pending", state, action, descriptor)
        if status ~= "absent" then
            if status ~= "known" then return "application evidence unknown" end
            if pending then return "application pending" end
        elseif XelAssist and XelAssist.IsAuraPending
            and XelAssist:IsAuraPending(action.name, action.actor,
                pendingTarget) then
            return "application pending"
        end
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
    if (kind == "buff" or kind == "hot" or kind == "absorb" or kind == "resource") and not facts.paladinAction and not facts.shamanAction then
        local active, reason = owner:AuraActive(action, state, descriptor)
        if active then return reason or "already active" end
    end
    local classBlocker = XelAssist.Graph.ClassMechanics and XelAssist.Graph.ClassMechanics:EvidenceBlocker(action, state, descriptor, tooltip, actionStart)
    if classBlocker then return classBlocker end
    if kind == "interrupt" and not state.targetCasting then return "not casting" end
    if kind == "interrupt" and state.targetCastRemaining
        and actionStart >= state.targetCastRemaining then
        return "interrupt too late"
    end
    if kind == "taunt" and not facts.playerTaunt then
        local petTank = config.petThreat == "tank"
            or (config.petThreat ~= "avoid" and state.groupSize == 0)
        if not petTank or (state.actors.pet and state.actors.pet.hasAggro) then
            return "pet threat policy"
        end
    end
    local toggles = config.toggles or {}
    if kind == "crowdControl" and not toggles.petControl then
        return "pet control policy"
    end
    local control = XelAssist.Graph.CrowdControl
    local controlBlocker, controlHandled
    if control then controlBlocker, controlHandled = control:Blocker(
        action, state, descriptor, tooltip, actionStart) end
    if controlHandled and controlBlocker then return controlBlocker end
    if facts.requiresCreature and state.targetCreatureType
        and facts.requiresCreature ~= state.targetCreatureType then
        return "creature immunity"
    end
    if kind == "crowdControl" and descriptor.unit == "target"
        and (state.time or 0) <= 0 then
        local active, reason = frozenAura(action, state, descriptor)
        if reason ~= "absent" then
            if active then return reason ~= "known" and reason
                or "already controlled" end
        elseif XelAssist.Game.Capabilities:TargetHasDebuff(action.name) then
            return "already controlled"
        end
    end
    local friendlySupport = descriptor.relation ~= "hostile"
        and (kind == "heal" or kind == "hot"
            or kind == "absorb" or kind == "buff")
    local area = facts.aoe or tooltip and tooltip.topology
        and tooltip.topology.area
    if area and not friendlySupport and state.mode ~= "aoe"
        and not config.allowAoe then
        return "area policy"
    end
    return nil
end
local function settleAdmission(action, state, tooltip)
    local actionStart, blocker
    local felDomination = XelAssist.Graph.WarlockFelDomination
    if felDomination and state.classMechanicClass == "WARLOCK" then
        actionStart, tooltip, blocker = felDomination:SettleAdmission(
            action, state, tooltip)
    else
        actionStart, blocker = Admission:Start(action, state, tooltip)
    end
    local rapidFire = XelAssist.Graph.HunterRapidFire
    if not blocker and rapidFire
        and state.classMechanicClass == "HUNTER" then
        tooltip, blocker = rapidFire:SettleAdmission(
            action, state, tooltip, actionStart)
    end
    return actionStart, tooltip, blocker
end
function T:Legal(action, state, descriptor)
    if not descriptor or not descriptor.unit then return false, "target" end
    if descriptor.relation == "hostile" and state.hostiles then
        local targeted
        if descriptor.source == "engaged" and descriptor.key ~= nil
            and S.HostileContext then
            targeted = S:HostileContext(state, descriptor.key)
        elseif state.targetContextKey ~= nil and S.SelectedHostileContext then
            targeted = S:SelectedHostileContext(state)
        end
        if targeted then state = targeted end
    end
    if not self:Relevant(action, state, descriptor) then return false, "intent" end
    local tooltip, factsStatus, blocker
    if XelAssist.Graph.RootObservation then tooltip, factsStatus =
        XelAssist.Graph.RootObservation:Facts(state, action) end
    if factsStatus == "absent" or not XelAssist.Graph.RootObservation then
        tooltip = XelAssist.Game.Actors:Facts(action)
    elseif factsStatus ~= "known" then return false, "action evidence unknown" end
    local forms = XelAssist.Graph.DruidForms
    if forms then tooltip, blocker = forms:PrepareLegal(action, state, tooltip) end
    if blocker then return false, blocker end
    if XelAssist.Graph.DruidClearcasting then
        tooltip, blocker = XelAssist.Graph.DruidClearcasting:PrepareLegal(
            action, state, tooltip)
    end
    if blocker then return false, blocker end
    if XelAssist.Graph.WarriorStances then tooltip, blocker = XelAssist.Graph.WarriorStances:PrepareLegal(action, state, tooltip) end
    if blocker then return false, blocker end
    if XelAssist.Graph.PriestShadowform then tooltip, blocker = XelAssist.Graph.PriestShadowform:PrepareLegal(action, state, tooltip) end
    if blocker then return false, blocker end
    if XelAssist.Graph.MageClearcasting then
        tooltip, blocker = XelAssist.Graph.MageClearcasting:PrepareLegal(
            action, state, tooltip)
    end
    if blocker then return false, blocker end
    if XelAssist.Graph.MagePresenceOfMind then
        tooltip, blocker = XelAssist.Graph.MagePresenceOfMind:PrepareLegal(
            action, state, tooltip)
    end
    if blocker then return false, blocker end
    if XelAssist.Graph.ShamanClearcasting then
        tooltip, blocker = XelAssist.Graph.ShamanClearcasting:PrepareLegal(
            action, state, tooltip)
    end
    if blocker then return false, blocker end
    if XelAssist.Graph.PriestInnerFocus then
        tooltip, blocker = XelAssist.Graph.PriestInnerFocus:PrepareLegal(
            action, state, tooltip)
    end
    if blocker then return false, blocker end
    tooltip, blocker = divergentTooltip(action, state, descriptor, tooltip)
    if blocker then return false, blocker end
    blocker = XelAssist.Graph.ClassMechanics
        and XelAssist.Graph.ClassMechanics:Blocker(
            action, state, descriptor, tooltip)
    if blocker then return false, blocker end
    local config, configStatus = configFor(state)
    if configStatus ~= "known" then return false, "config evidence unknown" end
    if (state.time or 0) > 0 then
        local projected, key, value = {}, nil, nil
        for key, value in pairs(descriptor) do projected[key] = value end
        projected.projectionOpen, descriptor = true, projected
    end
    blocker = policyBlocker(action, state, tooltip, descriptor, config)
    if blocker then return false, blocker end
    local target = descriptor.unit
    blocker = targetBlocker(action, state, descriptor, target)
    if blocker then return false, blocker end blocker = usabilityBlocker(
        action, state, descriptor, target, tooltip)
    if blocker then return false, blocker end blocker =
        ContextPolicy:Blocker(action, state, tooltip)
    if blocker then return false, blocker end
    blocker = XelAssist.Graph.Charge
        and XelAssist.Graph.Charge:Blocker(action, state, descriptor)
    if blocker then return false, blocker end
    blocker = XelAssist.Graph.PlayerTaunt
        and XelAssist.Graph.PlayerTaunt:Blocker(action, state, descriptor)
    if blocker then return false, blocker end
    local actionStart
    actionStart, tooltip, blocker = settleAdmission(action, state, tooltip)
    if blocker then return false, blocker end blocker = Admission:Readiness(action, state, tooltip, actionStart)
    if blocker then return false, blocker end blocker = XelAssist.Graph.SpatialRequirements:Blocker(
        action, state, descriptor, target, tooltip)
    if blocker then return false, blocker end blocker = effectBlocker(
        self, action, state, descriptor, target,
        actionStart, tooltip, config)
    if blocker then return false, blocker end
    local rage = XelAssist.Graph.WarriorRage
    local rageBlocker, rageHandled
    if rage then rageBlocker, rageHandled = rage:Blocker(action, state, descriptor, tooltip) end
    if rageBlocker then return false, rageBlocker end
    blocker = not rageHandled and XelAssist.Graph.ResourceExchange and XelAssist.Graph.ResourceExchange:Blocker(action, state, tooltip)
    if blocker then return false, blocker end blocker = XelAssist.Graph.HealthTransfer and XelAssist.Graph.HealthTransfer:Blocker(action, state, tooltip)
    if blocker then return false, blocker end
    return true, nil, tooltip, target, actionStart, descriptor, state
end
