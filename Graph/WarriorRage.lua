-- Bloodrage graph semantics. The action is an exact resource investment: it
-- pays health now, opens a finite rage clock, and enters combat. No preferred
-- Warrior sequence is encoded; later legal spenders determine whether the
-- investment was useful enough for the search to publish.
XelAssist.Graph.WarriorRage = {}
local W = XelAssist.Graph.WarriorRage
local State = XelAssist.Graph.State

local function runtime()
    return XelAssist.Game.Player and XelAssist.Game.Player.WarriorRage
end

local function facts(action)
    return action and action.facts or {}
end

function W:Is(action)
    return facts(action).warriorRage == true
end

local function descriptor(action, tooltip)
    local owner = runtime()
    local found = owner and owner.Evidence and owner:Evidence(action)
    if not (found and tooltip
        and tonumber(tooltip.healthCostPercent) == found.healthCostPercent
        and tonumber(tooltip.resourceGain) == found.totalGain
        and tonumber(tooltip.resourceImmediate) == found.immediateGain
        and tonumber(tooltip.resourcePeriodic)
            == found.periodicGain * found.ticks
        and tonumber(tooltip.cost) == 0 and tonumber(tooltip.gcd) == found.gcd
        and tonumber(tooltip.cooldown) == found.cooldown
        and tonumber(tooltip.duration) == found.duration
        and tonumber(tooltip.powerType) == owner.RAGE
        and tooltip.resourceType == "rage") then return nil end
    return found
end

local function healthCost(state, found)
    local base = tonumber(state and state.playerBaseHealth)
    if not (state and state.playerBaseHealthExact == true and base
        and base > 0 and found and found.baseHealthPercent == 10
        and found.healthCriticalMultiplier == 2) then return nil end
    return math.floor(base * found.baseHealthPercent / 100)
        * found.healthCriticalMultiplier
end

local function frozenUsability(state, action)
    local root = XelAssist.Graph.RootObservation
    if root and root.Usability then
        local observed, status = root:Usability(state, action)
        if status == "known" then
            if not (observed and observed.known == true) then
                return nil, "Bloodrage usability evidence unknown"
            end
            if observed.usable ~= true then
                return false, observed.reason or "Bloodrage unavailable"
            end
            return true
        elseif status ~= "absent" then
            return nil, "Bloodrage usability evidence unknown"
        end
    end
    if (tonumber(state and state.time) or 0) > 0 then
        return nil, "Bloodrage usability evidence unknown"
    end
    local capabilities = XelAssist.Game.Capabilities
    if not (capabilities and capabilities.Usable) then
        return nil, "Bloodrage usability evidence unknown"
    end
    local usable, reason = capabilities:Usable(action)
    if usable ~= true then
        return usable, reason or "Bloodrage usability evidence unknown"
    end
    return true
end

-- The second return identifies this portfolio so Targets can skip the generic
-- instantaneous health-conversion blocker after this exact delayed model ran.
function W:Blocker(action, state, target, tooltip)
    if not self:Is(action) then return nil, false end
    local found = descriptor(action, tooltip)
    if not found then return "Bloodrage evidence unavailable", true end
    if not (target and target.unit == "player"
        and target.relation ~= "hostile") then
        return "Bloodrage requires the player", true
    end
    local owner = runtime()
    if not (owner and tonumber(state and state.resourceType) == owner.RAGE
        and state.playerResourceExact == true) then
        return "Warrior rage state unavailable", true
    end
    local resource, maximum = tonumber(state.resource),
        tonumber(state.resourceMax)
    if not resource or not maximum or resource < 0 or maximum < resource then
        return "Warrior rage state unavailable", true
    end
    local health, healthMax = tonumber(state.health), tonumber(state.healthMax)
    if not health or not healthMax or healthMax <= 0 or health > healthMax then
        return "health state unknown", true
    end
    if owner:Active(state) then return "Bloodrage already active", true end
    local cost = healthCost(state, found)
    if not cost or cost <= 0 then
        return "base health evidence unavailable", true
    end
    if health <= cost then
        return "Bloodrage would be lethal", true
    end
    local usable, reason = frozenUsability(state, action)
    if usable ~= true then return reason or "Bloodrage unavailable", true end
    return nil, true
end

function W:Score(context)
    if not (context and self:Is(context.action)) then return false end
    local found = descriptor(context.action, context.tooltip)
    if not found then return false end
    local cost = healthCost(context.state, found)
    if not cost then return false end
    local current, maximum = tonumber(context.state.resource) or 0,
        tonumber(context.state.resourceMax) or 0
    local missing = math.max(0, maximum - current)
    local effective = math.min(found.totalGain, missing)
    context.power, context.expectedPower, context.effectivePower =
        found.totalGain, found.totalGain, effective
    context.resourceGain = found.totalGain
    context.resourceGainSource = found.source
    context.estimated = false
    -- Exact health paid is the only standalone score. ResourceInvestment keeps
    -- the lane open until later player costs prove the generated rage mattered.
    context.value = -cost
    context.healthCost = cost
    context.reason = "pays " .. tostring(cost)
        .. " health for " .. tostring(found.immediateGain)
        .. " rage now and " .. tostring(found.periodicGain)
        .. " each second"
    return true
end

local function syncHealth(state)
    local player = State and State.FriendlyByUnit
        and State:FriendlyByUnit(state, "player") or nil
    if player then player.health = state.health end
    local actor = state.actors and state.actors.player
    if actor then actor.health, actor.resource = state.health, state.resource end
end

function W:Apply(state, candidate)
    local action = candidate and candidate.action
    if not self:Is(action) then return false end
    local found = descriptor(action, candidate.tooltip)
    local owner = runtime()
    local cost = healthCost(state, found)
    if not (found and owner and tonumber(state.health)
        and cost and state.health > cost) then return false end
    local health = state.health
    if not owner:Start(state, action) then return false end
    state.health = health - cost
    state.inCombat = true
    state.warriorRageCombatUntil = (tonumber(state.time) or 0)
        + found.duration
    syncHealth(state)
    return true
end
