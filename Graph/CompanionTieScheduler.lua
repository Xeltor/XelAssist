-- Conservative tie arbitration shared by scheduling and event resolution.
-- It chooses a worst-case reservation identity without claiming its effect.
XelAssist.Graph.CompanionTieScheduler = {}
local T = XelAssist.Graph.CompanionTieScheduler

local function sameSpell(left, right)
    if left == right then return left ~= nil end
    local leftNumber, rightNumber = tonumber(left), tonumber(right)
    return leftNumber ~= nil and rightNumber ~= nil
        and leftNumber == rightNumber
end

function T:Same(left, right)
    if not (left and right) then return false end
    if left.autocastSpellId ~= nil or right.autocastSpellId ~= nil then
        return sameSpell(left.autocastSpellId, right.autocastSpellId)
    end
    return left.autocastIndex == right.autocastIndex
        and left.autocastName == right.autocastName
end

function T:Choice(lane)
    return { autocastIndex = lane.index,
        autocastName = lane.ambient.name,
        autocastSpellId = lane.ambient.spellId,
        autocastCooldown = lane.cooldown,
        autocastCost = lane.cost, autocastCostKnown = lane.costKnown,
        autocastBusy = lane.busy, autocastCast = lane.cast,
        targetIndependent = lane.targetIndependent and true or false }
end

function T:Choices(tied)
    local choices, i = {}, nil
    for i = 1, table.getn(tied) do
        table.insert(choices, self:Choice(tied[i]))
    end
    return choices
end

local function worse(left, right)
    if not right then return true end
    if left.costKnown ~= right.costKnown then return not left.costKnown end
    if left.cost ~= right.cost then return (left.cost or 0) > (right.cost or 0) end
    if left.busy ~= right.busy then return left.busy > right.busy end
    if left.cast ~= right.cast then return left.cast > right.cast end
    return left.cooldown > right.cooldown
end

function T:Envelope(tied)
    local reserved, i = nil, nil
    for i = 1, table.getn(tied) do
        local lane = tied[i]
        if worse(lane, reserved) then reserved = lane end
    end
    return reserved, reserved and reserved.busy or 0,
        reserved and reserved.cast or 0
end

function T:Group() return { consumed = {} } end

function T:Consumed(group, identity)
    local i
    for i = 1, table.getn(group and group.consumed or {}) do
        if self:Same(group.consumed[i], identity) then return true end
    end
    return false
end

function T:Mark(group, identity)
    if not group then return end
    table.insert(group.consumed, identity)
end

function T:WorstResolved(resolved, group)
    local best, i
    for i = 1, table.getn(resolved) do
        local value = resolved[i]
        local choice = value.choice
        local lane = { cost = choice.autocastCost,
            costKnown = choice.autocastCostKnown,
            busy = tonumber(choice.autocastBusy) or 0,
            cast = tonumber(choice.autocastCast) or 0,
            cooldown = tonumber(choice.autocastCooldown) or 1.5 }
        if not best or worse(lane, best.lane) then
            best = { ambient = value.ambient, choice = choice, lane = lane }
        end
    end
    return best
end
