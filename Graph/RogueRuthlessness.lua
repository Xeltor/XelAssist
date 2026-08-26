-- Search-pure Ruthlessness combo transition. It extends the generic combo
-- probability branches instead of choosing a finisher or a spend threshold.
XelAssist.Graph.RogueRuthlessness = {}
local R = XelAssist.Graph.RogueRuthlessness

local MAX_COMBO = 5

local function finite(value, low, high)
    value = tonumber(value)
    if not value or value ~= value or value == math.huge
        or value == -math.huge or value < low or value > high then return nil end
    return value
end

local function integer(value, low, high)
    value = finite(value, low, high)
    return value and math.floor(value) == value and value or nil
end

local function copy(source)
    local out, key, value = {}, nil, nil
    for key, value in pairs(source or {}) do
        out[key] = type(value) == "table" and copy(value) or value
    end
    return out
end

local function profile(state)
    local found = state and state.rogueRuthlessness
    local rank = found and integer(found.rank, 0, 3)
    local chances = { [0] = 0, [1] = 33, [2] = 66, [3] = 100 }
    if not (found and found.available == true and found.exact == true
        and found.talentID == 131 and rank
        and found.active == (rank > 0)
        and found.chancePercent == chances[rank]) then return nil end
    if rank > 0 and not (found.spellId == ({ 14156, 14160, 14161 })[rank]
        and found.procFlags == 87376 and found.finisherMask == 4063232
        and found.triggerSpellId == 14157 and found.comboGain == 1) then
        return nil
    end
    return found
end

local function finisher(candidate)
    local facts = candidate and candidate.action and candidate.action.facts
    local found = facts and facts.rogueRuthlessnessFinisherEvidence
    local flags = type(found) == "table"
        and integer(found.familyFlags, 1, 9007199254740991) or nil
    local scaled = flags and math.floor(flags / 131072) or 0
    local masked = scaled - math.floor(scaled / 32) * 32
    return facts and facts.rogueRuthlessnessFinisher == true
        and (facts.combo == true or facts.comboSpendAll == true)
        and type(found) == "table" and found.exact == true
        and found.spellId == candidate.action.spellId
        and found.family == 8 and found.finisherMask == 4063232
        and masked > 0 and found or nil
end

local function add(branches, targetGUID, points, probability)
    probability = finite(probability, 0, 1)
    points = integer(points, 0, MAX_COMBO)
    if not probability or probability <= 0 or points == nil then return end
    if points == 0 then targetGUID = nil end
    local index
    for index = 1, table.getn(branches) do
        local row = branches[index]
        if row.targetGUID == targetGUID and row.points == points then
            row.probability = row.probability + probability
            return
        end
    end
    table.insert(branches, { targetGUID = targetGUID, points = points,
        probability = probability })
end

local function targetDefeated(state, candidate)
    return candidate.targetRelation == "hostile"
        and state.targetHealthExact == true
        and finite(state.targetHealth, 0, 100000000) == 0
end

local function publish(state, branches, transition)
    state.comboBranches, state.comboProjected = branches, true
    state.comboObservedPoints, state.comboObservedSelectedPoints = nil, nil
    state.comboTargetGUID, state.comboGlobalExact = nil, false
    state.comboTransitionUnknown, state.comboTransitionUnknownReason = false, nil
    state.rogueRuthlessnessTransition = transition
    local combo = XelAssist.Graph.ComboState
    return combo and combo:Refresh(state) ~= nil
end

function R:Attach(state)
    local runtime = XelAssist.Game and XelAssist.Game.Player
        and XelAssist.Game.Player.RogueRuthlessness
    if not (state and runtime and type(runtime.Snapshot) == "function") then
        return false
    end
    state.rogueRuthlessness = runtime:Snapshot()
    return profile(state) ~= nil
end

function R:Copy(source, target)
    if not (source and target and source.rogueRuthlessness) then return false end
    target.rogueRuthlessness = copy(source.rogueRuthlessness)
    target.rogueRuthlessnessTransition = source.rogueRuthlessnessTransition
        and copy(source.rogueRuthlessnessTransition) or nil
    return true
end

-- Returns true only when this leaf has fully replaced ComboState:Apply for an
-- exact active Ruthlessness finisher. False leaves the generic transition in
-- charge, including its existing fail-closed path for unknown hit delivery.
function R:Apply(state, candidate)
    local found, finisherEvidence = profile(state), finisher(candidate)
    if not (found and found.active == true and finisherEvidence) then return false end
    local combo = XelAssist.Graph.ComboState
    if not (combo and type(combo.Ensure) == "function") then return false end
    local land = 1
    if candidate.resistance then
        land = finite(candidate.resistance.landChance, 0, 1)
        if land == nil then return false end
    end
    local current = combo:Ensure(state)
    if type(current) ~= "table" then return false end
    local allOwners = candidate.comboAllOwners == true
    local targetGUID = candidate.comboTargetGUID
    if targetGUID == nil and not allOwners then
        targetGUID = candidate.targetGUID or state.targetGUID
    end
    if targetGUID == nil and not allOwners then return false end
    local chance = found.chancePercent / 100
    local defeated = targetDefeated(state, candidate)
    if defeated then chance = 0 end
    local projected, delivered, index = {}, 0, nil
    for index = 1, table.getn(current) do
        local branch = current[index]
        local points = integer(branch.points, 0, MAX_COMBO)
        local probability = finite(branch.probability, 0, 1)
        if points == nil or probability == nil then return false end
        local spends = points > 0
            and (allOwners or branch.targetGUID == targetGUID)
        if spends then
            add(projected, branch.targetGUID, points,
                probability * (1 - land))
            local landed = probability * land
            local procTarget = allOwners and branch.targetGUID or targetGUID
            add(projected, procTarget, 1, landed * chance)
            add(projected, nil, 0, landed * (1 - chance))
            delivered = delivered + landed
        else add(projected, branch.targetGUID, points, probability) end
    end
    return publish(state, projected, { exact = true, rank = found.rank,
        chancePercent = chance * 100, landedProbability = delivered,
        expectedComboGain = delivered * chance,
        targetDefeated = defeated and true or false,
        source = "projected exact Ruthlessness proc branches" })
end
