-- Player Taunt is a live threat-rescue edge, distinct from companion taunts.
-- The graph admits it only from exact root evidence that a selected hostile is
-- attacking the current controlled pet or a party/raid ally. It projects
-- ownership, never a fabricated numeric threat lead, and leaves the immutable
-- observed victim untouched.
XelAssist.Graph.PlayerTaunt = {}
local T = XelAssist.Graph.PlayerTaunt
local State = XelAssist.Graph.State
local Hostiles = XelAssist.Graph.HostileState

function T:Is(action)
    return action and (action.actor or "player") == "player"
        and action.facts and action.facts.playerTaunt == true
end

local function exactIdentity(action)
    if tonumber(action and action.spellId) == 355 then return true end
    local hand = XelAssist.Game.Player.PaladinHandOfReckoning
    if hand and hand:Evidence(action) ~= nil then return true end
    local growl = XelAssist.Game.Player.DruidGrowl
    return growl and growl:Evidence(action) ~= nil
end

local function usability(state, action)
    local root = XelAssist.Graph.RootObservation
    if root and root.Usability then
        local evidence, status = root:Usability(state, action)
        if status == "known" then
            if not (evidence and evidence.known == true) then
                return nil, "Taunt usability evidence unknown"
            end
            if evidence.usable ~= true then
                return false, evidence.reason or "Taunt unavailable"
            end
            return true
        elseif status ~= "absent" then
            return nil, "Taunt usability evidence unknown"
        end
    end
    local available, reason = XelAssist.Game.Capabilities:Usable(action)
    if available ~= true then
        return available, reason or "Taunt usability evidence unknown"
    end
    return true
end

local function selected(state, descriptor)
    local record = Hostiles and Hostiles:Selected(state) or nil
    if not (state and descriptor and descriptor.unit == "target"
        and descriptor.relation == "hostile" and descriptor.guid ~= nil
        and descriptor.guid == state.targetGUID and record
        and record.guid == descriptor.guid and record.selected == true
        and record.dead == false) then return nil end
    return record
end

local function allyVictim(state, record)
    local victim = record and record.victim
    if not (victim and victim.available == true and victim.guid ~= nil) then
        return nil, "hostile victim unknown"
    end
    local player = state.actors and state.actors.player
    if victim.targetsPlayer == true
        or player and player.guid ~= nil and victim.guid == player.guid then
        return nil, "target already attacks player"
    end
    if victim.targetsPet == true then
        local pet = state.actors and state.actors.pet
        if pet and pet.guid ~= nil and pet.guid == victim.guid then return pet end
        return nil, "target is not attacking an ally"
    end
    if victim.targetsGroup ~= true or victim.groupUnit == nil then
        return nil, "target is not attacking an ally"
    end
    local ally = State:FriendlyByUnit(state, victim.groupUnit)
    if not (ally and ally.guid ~= nil and ally.guid == victim.guid
        and ally.relation ~= "self" and ally.relation ~= "player") then
        return nil, "target is not attacking an ally"
    end
    return ally
end

function T:Blocker(action, state, descriptor)
    if not self:Is(action) then return nil end
    if not exactIdentity(action) then return "unknown player Taunt rank" end
    local record = selected(state, descriptor)
    if not record then return "Taunt requires the selected hostile" end
    if not record.threat then return "hostile threat state unavailable" end
    if not (state.actors and state.actors.player
        and state.actors.player.guid ~= nil) then
        return "player identity unavailable"
    end
    if state.tank ~= true then return "tank role required" end
    if (tonumber(state.time) or 0) > 0 then
        if record.threat.projectedPlayerHasAggro == true then
            return "target already projected on player"
        end
        return "Taunt requires live victim evidence"
    end
    local _, reason = allyVictim(state, record)
    if reason then return reason end
    local available
    available, reason = usability(state, action)
    if available ~= true then return reason or "Taunt unavailable" end
    return nil
end

function T:Score(context)
    if not self:Is(context and context.action) then return false end
    local record = selected(context.state, context.descriptor)
    local ally = record and allyVictim(context.state, record) or nil
    local danger = 0
    if ally and (tonumber(ally.healthMax) or 0) > 0 then
        danger = 1 - math.max(0, tonumber(ally.health) or 0) / ally.healthMax
    end
    context.power, context.expectedPower, context.effectivePower = 0, 0, 0
    context.estimated = false
    context.value = 4200 + danger * 1200
    context.reason = record and record.victim
        and record.victim.targetsPet == true
        and "takes the target from your companion"
        or "takes the target from an ally"
    return true
end

function T:Apply(state, candidate)
    if not self:Is(candidate and candidate.action) then return false end
    local record = Hostiles and Hostiles:Active(state) or nil
    if not (record and record.guid == candidate.targetGUID and record.threat) then
        return false
    end
    local delivery = math.max(0, math.min(1,
        tonumber(candidate.effectDelivery) or 1))
    local threat = record.threat
    threat.tauntDelivery = delivery
    threat.projectedSource = candidate.action.name
    threat.playerDeltaExact = false
    if delivery >= 0.999 then
        local player = state.actors and state.actors.player
        if not (player and player.guid ~= nil) then return false end
        threat.projectedPlayerHasAggro = true
        threat.projectedPlayerReferenceKnown = true
        threat.projectedPlayerReference = true
        threat.projectedPlayerOwnershipUnknown = nil
        threat.projectedPetHasAggro = false
        threat.projectedVictimGuid = player.guid
        threat.projectedOwnershipUnknown = nil
        threat.projectedTauntUncertain = nil
        record.projectedTauntedByPlayer = true
        record.projectedTauntedByPet = nil
        record.tauntFocusExpired = nil
        record.tauntFocusUntil = (tonumber(state.time) or 0)
            + (tonumber(candidate.action.facts.tauntFocusDuration) or 3)
    elseif delivery > 0 then
        threat.projectedTauntUncertain = true
    end
    if State.SyncActiveHostile then State:SyncActiveHostile(state) end
    return true
end

function T:Advance(state)
    local hostiles, current = state and state.hostiles,
        tonumber(state and state.time) or 0
    local changed, i = false, nil
    for i = 1, table.getn(hostiles and hostiles.order or {}) do
        local record = hostiles.byKey and hostiles.byKey[hostiles.order[i]]
        if record and record.tauntFocusUntil
            and current >= record.tauntFocusUntil then
            local threat = record.threat
            record.tauntFocusUntil, record.projectedTauntedByPlayer = nil, nil
            record.tauntFocusExpired = true
            if threat then
                threat.projectedPlayerHasAggro = nil
                threat.projectedPetHasAggro = nil
                threat.projectedVictimGuid = nil
                threat.projectedOwnershipUnknown = true
                threat.playerDeltaExact = false
            end
            changed = true
        end
    end
    if changed and State.SyncActiveHostile then State:SyncActiveHostile(state) end
end
