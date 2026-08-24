XelAssist.Graph.Targets = {}
local T = XelAssist.Graph.Targets
local S = XelAssist.Graph.State

local APPLICATION_BLOCK_THRESHOLD = 0.75

local function friendlyDescriptor(state, record)
    if not record then return nil end
    return S:Descriptor(record.unit, record.relation or "friendly",
        record.source, record.guid, record.key, record)
end

local function unitDescriptor(state, unit, relation, source)
    local record = S:FriendlyByUnit(state, unit)
    if record then return friendlyDescriptor(state, record) end
    if relation == "hostile" then
        local ref = state.targetRef
        return { unit = unit, relation = relation, source = source,
            guid = ref and ref.guid or state.targetGUID,
            key = ref and ref.guid or state.targetGUID or "target",
            targetRef = ref }
    end
    return S:Descriptor(unit, relation, source, nil, nil, nil)
end

function T:VariableFriendlyAction(action)
    if action.actor == "pet" or action.executor == "item" or action.facts.self then
        return false
    end
    local kind = action.facts.kind
    return kind == "heal" or kind == "hot" or kind == "absorb" or kind == "buff"
end

local function fixedActionTarget(action, state)
    local kind = action.facts.kind
    if action.actor == "pet" then
        if kind == "petHeal" then
            return unitDescriptor(state, "pet", "pet", "companion")
        end
        if action.facts.petSacrifice then
            return unitDescriptor(state, "player", "self", "self")
        end
        if kind == "buff" or kind == "absorb" then
            if action.facts.self then
                return unitDescriptor(state, "pet", "pet", "companion")
            end
            return friendlyDescriptor(state, S:PrimaryFriendly(state))
        end
        if kind == "command" then
            if action.command == "attack" then
                return unitDescriptor(state, "target", "hostile", "selected")
            end
            return unitDescriptor(state, "pet", "pet", "companion")
        end
        if kind == "dispel" then
            local unit = XelAssist.Game.Actors:DispelTarget(state)
            if not unit then return nil end
            if unit == "target" and state.hostile then
                return unitDescriptor(state, unit, "hostile", "selected")
            end
            return unitDescriptor(state, unit, "friendly", "dispel")
        end
        return unitDescriptor(state, "target", "hostile", "selected")
    end
    if kind == "summon" or action.facts.self
        or kind == "defensive" or kind == "resource" or kind == "threatDrop"
        or kind == "modifier" then
        return unitDescriptor(state, "player", "self", "self")
    end
    return unitDescriptor(state, "target", "hostile", "selected")
end

function T:Targets(action, state)
    if not self:VariableFriendlyAction(action) then
        local fixed = fixedActionTarget(action, state)
        return fixed and { fixed } or {}
    end
    local out, i, order = {}, nil,
        XelAssist.Game.Friendlies:TargetKeys(state.friendlies, action)
    for i = 1, table.getn(order) do
        local record = S:FriendlyByKey(state, order[i])
        if record and not record.dead then
            table.insert(out, friendlyDescriptor(state, record))
        end
    end
    return out
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
            return state.hostile and pet and not pet.targetsCurrent
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
        or kind == "modifier" or kind == "summon"
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
    if state.hostile then return kind ~= "buff" or action.facts.self end
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
    local actorLineOfSight
    if descriptor.relation == "hostile" then actorLineOfSight = state.targetLineOfSight end
    if descriptor.relation == "hostile" and action.actor == "pet"
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
    if kind == "summon" then
        if state.pet then return "companion already active" end
        if state.inCombat then return "unsafe summon" end
    end
    return nil
end

local function actionTiming(action, state, tooltip)
    local facts, kind = action.facts, action.facts.kind
    local cast = facts.cast
    if cast == nil then cast = tooltip.cast end
    if facts.channel and (not cast or cast <= 0) then cast = tooltip.duration or 3 end
    if state.instantNext and cast and cast > 0 then cast = 0 end
    if state.moving and cast and cast > 0 then return nil, "moving" end
    local actor = action.actor or "player"
    local actionStart = kind == "command" and (state.time or 0) or math.max(
        state.time or 0, (state.actorReadyAt and state.actorReadyAt[actor]) or 0)
    if actor == "pet" and kind ~= "command" and actionStart > (state.time or 0) then
        return nil, "companion casting"
    end
    return actionStart, nil
end

local function readinessBlocker(action, state, tooltip, actionStart)
    local facts = action.facts
    local actor = action.actor or "player"
    local resource = state.resource
    if action.actor == "pet" and state.actors and state.actors.pet then
        resource = state.actors.pet.resource
    end
    if resource < (tooltip.cost or 0) then
        return action.actor == "pet" and "pet resource" or "resource"
    end
    if action.executor == "item" then
        local remaining = XelAssist.Game.Inventory:Cooldown(action)
        if remaining and remaining > actionStart then return "item cooldown" end
    elseif action.actor == "pet" then
        local remaining = XelAssist.Game.Actors:PetCooldown(action)
        if remaining and remaining > actionStart then return "pet cooldown" end
    elseif not XelAssist.Game.Capabilities:IsReady(action.name, actionStart) then
        return "cooldown"
    end
    if state.readyAt[actor .. ":" .. action.name]
        and state.readyAt[actor .. ":" .. action.name] > actionStart then
        return "future cooldown"
    end
    local cooldownGroup = facts.cooldownGroup or tooltip.cooldownGroup
    if cooldownGroup and state.readyAt["group:" .. cooldownGroup]
        and state.readyAt["group:" .. cooldownGroup] > actionStart then
        return "shared cooldown"
    end
    return nil
end

local function rangeBlocker(action, state, descriptor, target, tooltip)
    local liveRange
    if action.actor ~= "pet" and action.executor ~= "item" then
        liveRange = XelAssist.Game.Capabilities:InRange(
            XelAssist.Game.Capabilities:CastName(action), target)
    end
    if liveRange == false then return "range" end
    -- Unknown direct range remains unknown; only then use discovered geometry.
    local rangeDistance = descriptor.record and descriptor.record.distance or state.distance
    if action.actor == "pet" and descriptor.relation == "hostile"
        and state.actors and state.actors.pet then
        rangeDistance = state.actors.pet.distance
    elseif descriptor.relation == "hostile" and state.targetDistance ~= nil then
        rangeDistance = state.targetDistance
    elseif target == "player" or target == "pet" and descriptor.relation ~= "hostile" then
        rangeDistance = 0
    end
    if liveRange == nil and rangeDistance then
        if tooltip.minRange and rangeDistance < tooltip.minRange then
            return "minimum range"
        end
        if tooltip.maxRange and tooltip.maxRange > 0
            and rangeDistance > tooltip.maxRange then
            return "range"
        end
    end
    return nil
end

local function effectBlocker(owner, action, state, descriptor, target, actionStart)
    local facts, kind = action.facts, action.facts.kind
    if (kind == "dot" or kind == "debuff")
        and owner:AuraActive(action, state, descriptor) then
        return "already active"
    end
    if (kind == "dot" or kind == "debuff" or kind == "crowdControl"
        or kind == "buff" or kind == "hot" or kind == "absorb" or kind == "resource")
        and XelAssist and XelAssist.IsAuraPending
        and XelAssist:IsAuraPending(action.name, action.actor,
            descriptor.guid or target) then
        return "application pending"
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
    if facts.aoe and not friendlySupport and state.mode ~= "aoe"
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
    actionStart, blocker = actionTiming(action, state, tooltip)
    if blocker then return false, blocker end
    blocker = readinessBlocker(action, state, tooltip, actionStart)
    if blocker then return false, blocker end
    blocker = rangeBlocker(action, state, descriptor, target, tooltip)
    if blocker then return false, blocker end
    blocker = effectBlocker(self, action, state, descriptor, target, actionStart)
    if blocker then return false, blocker end
    return true, nil, tooltip, target, actionStart, descriptor
end
