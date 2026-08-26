-- Branch-local Berserker Rage lifetime and incoming-rage consequence.
XelAssist.Graph.WarriorBerserkerRage = {}
local B = XelAssist.Graph.WarriorBerserkerRage

local function copy(source)
    local out, key, value = {}, nil, nil
    for key, value in pairs(source or {}) do out[key] = value end
    return out
end
local function runtime()
    return XelAssist.Game.Player.WarriorBerserkerRage
end
function B:Is(action)
    return action and action.facts
        and action.facts.warriorBerserkerRage == true
end
function B:Attach(state, snapshot)
    if not (state and snapshot and snapshot.active == true
        and snapshot.exact == true and snapshot.spellId == runtime().SPELL_ID
        and snapshot.incomingRageMultiplier == runtime().RAGE_MULTIPLIER
        and tonumber(snapshot.remaining) and snapshot.remaining > 0) then
        return false
    end
    state.warriorBerserkerRage = copy(snapshot)
    return true
end
function B:Copy(source, target)
    if not (source and source.warriorBerserkerRage and target) then return false end
    target.warriorBerserkerRage = copy(source.warriorBerserkerRage)
    return true
end
function B:Blocker(action, state, descriptor, tooltip)
    if not self:Is(action) then return nil, false end
    local found = runtime():Evidence(action)
    if not (found and tooltip and tonumber(tooltip.duration) == found.duration
        and tonumber(tooltip.cost) == 0) then
        return "Berserker Rage evidence unavailable", true
    end
    if not (descriptor and descriptor.unit == "player"
        and descriptor.relation ~= "hostile") then
        return "Berserker Rage requires the player", true
    end
    local active = state and state.warriorBerserkerRage
    if active and tonumber(active.remaining) and active.remaining > 0 then
        return "Berserker Rage already active", true
    end
    return nil, true
end
function B:Score(context)
    if not (context and self:Is(context.action)) then return false end
    context.power, context.expectedPower, context.effectivePower = 0, 0, 0
    context.value, context.estimated = 0, false
    context.reason = "amplifies rage from incoming damage for 10 seconds"
    return true
end
function B:Apply(state, candidate)
    local action = candidate and candidate.action
    local found = self:Is(action) and runtime():Evidence(action)
    if not found then return false end
    state.warriorBerserkerRage = { active = true, exact = true,
        projected = true, spellId = found.spellId,
        remaining = found.duration,
        incomingRageMultiplier = found.incomingRageMultiplier,
        source = found.source }
    return true
end
function B:Advance(state, elapsed)
    local active = state and state.warriorBerserkerRage
    if not (active and active.active == true and active.exact == true) then
        return false
    end
    active.remaining = math.max(0,
        (tonumber(active.remaining) or 0) - math.max(0, tonumber(elapsed) or 0))
    if active.remaining <= 0 then state.warriorBerserkerRage = nil end
    return true
end
function B:IncomingRageMultiplier(state)
    local active = state and state.warriorBerserkerRage
    if active and active.active == true and active.exact == true
        and active.spellId == runtime().SPELL_ID
        and tonumber(active.remaining) and active.remaining > 0
        and active.incomingRageMultiplier == runtime().RAGE_MULTIPLIER then
        return active.incomingRageMultiplier, true
    end
    return 1, true
end
