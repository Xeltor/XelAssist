-- Atomic preview publication. A shorter budget-limited recomputation may
-- refresh the executable root, but cannot collapse an already validated rail
-- for that same action and opaque target identity.
XelAssist.UI.RecommendationStability = {}
local S = XelAssist.UI.RecommendationStability

local function sameAction(left, right)
    if not left or not right then return left == right end
    return left.name == right.name and left.rank == right.rank
        and left.spellId == right.spellId and left.actor == right.actor
        and left.executor == right.executor and left.itemId == right.itemId
        and left.actionSlot == right.actionSlot and left.command == right.command
end

local function sameTarget(left, right)
    if left.targetGUID ~= nil or right.targetGUID ~= nil then
        return left.targetGUID == right.targetGUID
    end
    return left.target == right.target
end

local function sameCandidate(left, right)
    return left and right and sameAction(left.action, right.action)
        and sameTarget(left, right)
        and left.spatialConditionFingerprint
            == right.spatialConditionFingerprint
end

function S:SameRoot(left, right)
    return left and right and sameAction(left.action, right.action)
        and sameTarget(left, right) and left.actor == right.actor
end

local function pathCount(plan)
    return table.getn(plan and plan.path or {})
end

local function copyCurrent(current)
    local out, key, value = {}, nil, nil
    for key, value in pairs(current) do out[key] = value end
    out.path, out.follow = {}, {}
    local i
    for i = 1, pathCount(current) do out.path[i] = current.path[i] end
    for i = 1, table.getn(current.follow or {}) do out.follow[i] = current.follow[i] end
    return out
end

function S:RetainRunway(current, prior)
    if not (current and prior and current.budgetLimited
        and self:SameRoot(current, prior)
        and pathCount(prior) > pathCount(current)) then return current end
    local i
    for i = 1, pathCount(current) do
        if not sameCandidate(current.path[i], prior.path[i]) then return current end
    end
    local out = copyCurrent(current)
    for i = pathCount(current) + 1, pathCount(prior) do
        out.path[i] = prior.path[i]
    end
    out.follow = {}
    for i = 2, table.getn(out.path) do
        out.follow[i - 1] = out.path[i].action
    end
    out.runwayRetained = true
    return out
end

function S:Equivalent(left, right, visibleSteps)
    if not self:SameRoot(left, right) or left.reason ~= right.reason
        or left.confidence ~= right.confidence then return false end
    local count = math.max(1, math.min(5, tonumber(visibleSteps) or 1))
    local i
    for i = 1, count do
        local a, b = left.path and left.path[i], right.path and right.path[i]
        if (a == nil) ~= (b == nil) then return false end
        if a and not sameCandidate(a, b) then return false end
    end
    return true
end

function S:Select(owner, plan, err, force)
    local prior = owner.xelDisplayPlan
    plan = self:RetainRunway(plan, prior)
    local visible = XelAssistCharDB.visibleSteps or XelAssistCharDB.graphDepth or 1
    local changed = force or not (plan and prior
        and self:Equivalent(prior, plan, visible))
    if not force and not plan and not prior
        and owner.xelDisplayError == err then changed = false end
    owner.xelDisplayPlan, owner.xelDisplayError = plan, err
    return plan, err, changed and true or false
end

function S:Reset(owner)
    owner.xelDisplayPlan, owner.xelDisplayError = nil, nil
end
