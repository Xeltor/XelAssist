-- Branch-local Octo Execute damage and variable-rage payment. The base cost is
-- paid atomically by ActionConsumption; this owner handles only the remaining
-- rage whose consumption depends on delivered server damage.
XelAssist.Graph.WarriorExecute = {}
local E = XelAssist.Graph.WarriorExecute

local function evidence(subject)
    local owner = XelAssist.Game.Player.WarriorExecute
    return owner and owner:Evidence(subject) or nil
end

function E:Prepare(context)
    local found = context and evidence(context.facts)
    if not found then
        if context and context.facts
            and context.facts.requiresExactWarriorExecute == true then
            return nil, "Octo Execute evidence unavailable"
        end
        return false, nil
    end
    local state = context.state
    if tonumber(state.resourceType) ~= found.powerType
        or state.playerResourceExact == false
        or tonumber(state.resource) == nil then
        return nil, "exact rage unavailable for Execute"
    end
    local cost = math.max(0, tonumber(context.cost) or found.baseCost)
    local extra = math.max(0, state.resource - cost)
    context.power = found.baseDamage + extra * found.damagePerRage
    context.rawPower = context.power
    context.warriorExecuteExtraRage = extra
    context.warriorExecuteEvidence = found
    context.estimated = true
    return true, nil
end

function E:Consume(out, candidate)
    local found = candidate and evidence(candidate.action)
    if not found then return nil end
    local extra = math.max(0, tonumber(candidate.warriorExecuteExtraRage) or 0)
    if extra <= 0 then return true end
    local delivery = tonumber(candidate.effectDelivery)
    if delivery and delivery >= 1 then
        out.resource = 0
    elseif delivery and delivery <= 0 then
        -- The base cost was already paid; a proven miss retains extra rage.
    else
        -- Octo's private hit-side script is unavailable. Use the safe lower
        -- resource bound and stop later rage-dependent planning on this branch.
        out.resource = 0
        out.playerResourceExact = false
        out.warriorExecuteResourceRange = { minimum = 0, maximum = extra,
            source = "Execute extra rage is consumed only on delivered damage" }
    end
    return true
end
