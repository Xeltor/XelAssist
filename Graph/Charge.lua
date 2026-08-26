-- Charge is a causal engage edge, not a typed Warrior opener. The installed
-- client proves its three rank identities, Battle-Stance usability, range and
-- zero cost; this module projects only the exact rage and same-target melee
-- arrival that follow a successful cast. Damage, facing, aggro and a white
-- swing remain deliberately uncreated.
XelAssist.Graph.Charge = {}
local C = XelAssist.Graph.Charge

local RAGE = 1

local function gain(action)
    local facts = action and action.facts or {}
    local bySpell = facts.rageGainBySpellId
    local amount = bySpell and bySpell[tonumber(action and action.spellId)]
    return tonumber(amount)
end

function C:Is(action)
    return action and action.facts
        and action.facts.chargeMovement == true
end

local function frozenUsability(state, action)
    local root = XelAssist.Graph.RootObservation
    if root and root.Usability then
        local evidence, status = root:Usability(state, action)
        if status == "known" then
            if not (evidence and evidence.known == true) then
                return nil, "Charge usability evidence unknown"
            end
            if evidence.usable ~= true then
                return false, evidence.reason or "Charge unavailable"
            end
            return true
        elseif status ~= "absent" then
            return nil, "Charge usability evidence unknown"
        end
    end
    local usable, reason = XelAssist.Game.Capabilities:Usable(action)
    if usable ~= true then
        return usable, reason or "Charge usability evidence unknown"
    end
    return true
end

function C:Blocker(action, state, descriptor)
    if not self:Is(action) then return nil end
    if not gain(action) then return "unknown Charge rank" end
    if not (state and descriptor and descriptor.unit == "target"
        and descriptor.relation == "hostile" and descriptor.guid ~= nil
        and descriptor.guid == state.targetGUID and state.hostile == true) then
        return "Charge requires the selected hostile"
    end
    if state.inCombat ~= false and action.facts.chargeInCombat ~= true then
        return "combat state"
    end
    if tonumber(state.resourceType) ~= RAGE then return "resource type" end
    local future = (tonumber(state.time) or 0) > 0
    if future and action.facts.chargeInCombat ~= true
        and state.movementSetupTargetGUID ~= descriptor.guid then
        return "Charge is only available before combat"
    end
    local usable, reason = frozenUsability(state, action)
    if usable ~= true then return reason or "Charge unavailable" end
    return nil
end

function C:Score(context)
    if not self:Is(context and context.action) then return false end
    local amount = gain(context.action)
    if not amount then return false end
    context.power, context.expectedPower, context.effectivePower = 0, 0, 0
    context.estimated = false
    context.resourceGain = amount
    context.resourceGainSource = "installed-client Charge rank"
    context.value = 1
    context.reason = "closes to melee range and generates "
        .. tostring(amount) .. " rage"
    return true
end

-- A Charge arrival proves only that the player reached this hostile's ordinary
-- melee band. It cannot prove a rear arc, another target, or a white-swing
-- hitbox clock.
function C:CanReach(action, state, descriptor, maximum)
    local facts = action and action.facts or {}
    maximum = tonumber(maximum)
    return state and state.chargeMeleeTargetGUID ~= nil
        and descriptor and descriptor.guid == state.chargeMeleeTargetGUID
        and descriptor.relation == "hostile"
        and (action.actor or "player") == "player"
        and facts.melee == true and facts.behind ~= true
        and facts.playerAttackContinuation ~= true
        and (maximum == nil or maximum <= 5)
end

function C:Apply(state, candidate)
    local action = candidate and candidate.action
    if not self:Is(action) then return false end
    local amount = gain(action)
    if not amount or candidate.targetGUID == nil then return false end
    local current = math.max(0, tonumber(state.resource) or 0)
    local maximum = math.max(current, tonumber(state.resourceMax) or current)
    state.resource = math.min(maximum, current + amount)
    state.playerResourceExact = true
    state.playerResourceSource = "projected exact Charge rank"
    if state.actors and state.actors.player then
        state.actors.player.resource = state.resource
    end
    state.inCombat = true
    state.chargeMeleeTargetGUID = candidate.targetGUID
    state.movementSetupTargetGUID = nil
    return true
end
