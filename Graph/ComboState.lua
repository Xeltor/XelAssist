-- Target-owned probability branches for combo points after uncertain hostile
-- actions. A missed builder retains the old owner; a landed builder transfers
-- ownership to its target; a missed finisher retains that target's points.
XelAssist.Graph.ComboState = {}
local C = XelAssist.Graph.ComboState

local MAX_COMBO = 5
local UNKNOWN_TARGET = {}

local function clampPoints(points)
    return math.max(0, math.min(MAX_COMBO, tonumber(points) or 0))
end

local function clampProbability(probability)
    return math.max(0, math.min(1, tonumber(probability) or 1))
end

local function spendsCombo(facts, tooltip)
    return facts and facts.combo or tooltip and tooltip.comboSpendAll
end

local function addBranch(branches, targetGUID, points, probability)
    probability = math.max(0, tonumber(probability) or 0)
    if probability <= 0 then return end
    points = clampPoints(points)
    if points == 0 then targetGUID = nil end
    local i
    for i = 1, table.getn(branches) do
        local branch = branches[i]
        if branch.points == points and branch.targetGUID == targetGUID then
            branch.probability = branch.probability + probability
            return
        end
    end
    table.insert(branches, { targetGUID = targetGUID, points = points,
        probability = probability })
end

function C:Attach(state, points, ownerGUID, observation)
    points = clampPoints(points)
    if points > 0 and ownerGUID == nil then
        ownerGUID = state.targetGUID or UNKNOWN_TARGET
    end
    state.comboBranches = { { targetGUID = points > 0 and ownerGUID or nil,
        points = points, probability = 1 } }
    state.comboProjected = false
    state.comboObservedPoints = points
    state.comboTargetGUID = points > 0 and ownerGUID or nil
    state.combo = points
    state.comboAvailability = points > 0 and 1 or 0
    state.comboSelectedExact = not observation
        or observation.selectedExact ~= false
    state.comboGlobalExact = observation and observation.globalExact and true or false
    state.comboSource = observation and observation.source or "observed combo state"
    state.comboObservedSelectedPoints = points
    self:Refresh(state)
    -- The compatibility scalar is selected-target local, while the observed
    -- point count above may belong to an unselected hidden owner. Track both
    -- so Ensure does not erase exact off-target ownership as a false mutation.
    state.comboObservedSelectedPoints = clampPoints(state.combo)
end

function C:Ensure(state)
    if type(state.comboBranches) ~= "table"
        or state.comboProjected ~= true
            and clampPoints(state.combo) ~= state.comboObservedSelectedPoints then
        self:Attach(state, state.combo,
            state.comboTargetGUID or state.targetGUID)
    end
    return state.comboBranches
end

function C:Summary(state, targetGUID, allOwners)
    local branches = self:Ensure(state)
    local query = targetGUID
    local global = allOwners == true
    if not global and query == nil then query = state.targetGUID end
    if query == nil then global = true end
    local expected, available, i = 0, 0, nil
    for i = 1, table.getn(branches) do
        local branch = branches[i]
        local probability = clampProbability(branch.probability)
        if branch.points > 0 and (global
            or branch.targetGUID == query) then
            expected = expected + clampPoints(branch.points) * probability
            available = available + probability
        end
    end
    return expected, clampProbability(available)
end

function C:Refresh(state)
    local expected, available = self:Summary(state, state.targetGUID)
    state.combo, state.comboAvailability = expected, available
    return expected, available
end

function C:Expected(state, targetGUID)
    local expected = self:Summary(state, targetGUID)
    return expected
end

function C:Availability(state, targetGUID, allOwners)
    local _, available = self:Summary(state, targetGUID, allOwners)
    return available
end

function C:ConditionalExpected(state, targetGUID, allOwners)
    local expected, available = self:Summary(state, targetGUID, allOwners)
    if available <= 0 then return 0 end
    return expected / available
end

-- A self-recipient finisher still uses points owned by a hostile unit. Keep
-- that resource owner separate from the effect recipient. When a projected
-- branch has multiple possible owners, a self finisher consumes whichever
-- owner actually carries the points because it has no explicit hostile effect
-- target for the server to compare against.
function C:ActionOwner(state, facts, tooltip, descriptor)
    local targetGUID = descriptor and descriptor.guid
    if not spendsCombo(facts, tooltip) then return nil, false end
    if descriptor and descriptor.relation == "hostile" then
        return targetGUID, false
    end
    local branches = self:Ensure(state)
    local owner, found, multiple, i = nil, false, false, nil
    for i = 1, table.getn(branches) do
        local branch = branches[i]
        if clampPoints(branch.points) > 0
            and clampProbability(branch.probability) > 0 then
            if not found then
                owner, found = branch.targetGUID, true
            elseif branch.targetGUID ~= owner then multiple = true end
        end
    end
    if not found then
        return state.comboTargetGUID or state.targetGUID, false
    end
    if multiple or owner == nil or owner == UNKNOWN_TARGET then
        return nil, true
    end
    return owner, false
end

function C:TooltipFor(state, targetGUID, tooltip, allOwners)
    if not (tooltip and tooltip.durationComboScaled
        and tonumber(tooltip.durationBase)
        and tonumber(tooltip.durationMax)) then return tooltip end
    local points = math.max(0, math.min(MAX_COMBO,
        self:ConditionalExpected(state, targetGUID, allOwners)))
    local out, key, value = {}, nil, nil
    for key, value in pairs(tooltip) do out[key] = value end
    out.duration = tooltip.durationBase
        + (tooltip.durationMax - tooltip.durationBase) * points / MAX_COMBO
    out.durationComboPoints = points
    return out
end

function C:Apply(state, candidate, facts)
    local tooltip = candidate.tooltip or {}
    local gain = tonumber(tooltip.comboGain)
    if not gain and (facts.kind == "builder" or facts.comboBuilder) then gain = 1 end
    local spends = facts.combo or tooltip.comboSpendAll
    if not (gain and gain > 0 or spends) then return false end
    local allOwners = candidate.comboAllOwners == true
    local targetGUID = candidate.comboTargetGUID
    if targetGUID == nil and not allOwners then
        targetGUID = candidate.targetGUID or state.targetGUID or UNKNOWN_TARGET
    end
    local land = candidate.resistance
        and candidate.resistance.landChance or 1
    land = clampProbability(land)
    local current, projected = self:Ensure(state), {}
    local i
    for i = 1, table.getn(current) do
        local branch = current[i]
        local prior, probability = clampPoints(branch.points),
            clampProbability(branch.probability)
        if gain and gain > 0 then
            addBranch(projected, branch.targetGUID, prior,
                probability * (1 - land))
            local owned = branch.targetGUID == targetGUID and prior or 0
            addBranch(projected, targetGUID,
                math.min(MAX_COMBO, owned + gain), probability * land)
        elseif (allOwners or branch.targetGUID == targetGUID) and prior > 0 then
            addBranch(projected, branch.targetGUID, prior,
                probability * (1 - land))
            addBranch(projected, nil, 0, probability * land)
        else
            -- This uncertainty branch did not own points on the attempted
            -- target. The conditional finisher cannot consume another unit's
            -- points, so its state remains intact.
            addBranch(projected, branch.targetGUID, prior, probability)
        end
    end
    state.comboBranches = projected
    state.comboProjected = true
    state.comboObservedPoints = nil
    state.comboObservedSelectedPoints = nil
    state.comboTargetGUID = nil
    state.comboGlobalExact = false
    self:Refresh(state)
    return true
end
