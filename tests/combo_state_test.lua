XelAssist = { Graph = {} }
table.getn = table.getn or function(value)
    local count = 0
    while value[count + 1] ~= nil do count = count + 1 end
    return count
end

dofile("Graph/ComboState.lua")
local C = XelAssist.Graph.ComboState

local function branch(state, targetGUID, points)
    local i
    for i = 1, table.getn(state.comboBranches) do
        local row = state.comboBranches[i]
        if row.targetGUID == targetGUID and row.points == points then
            return row.probability
        end
    end
    return 0
end

local state = { targetGUID = "target-a" }
C:Attach(state, 2, "target-a", { selectedExact = true,
    globalExact = true, source = "test combo owner" })
assert(state.combo == 2 and state.comboAvailability == 1
    and branch(state, "target-a", 2) == 1
    and C:Availability(state, "target-b") == 0,
    "an observed combo count must begin as one exact target-owned branch")

local builder = { targetGUID = "target-a", tooltip = { comboGain = 1 },
    resistance = { landChance = 0.8 } }
assert(C:Apply(state, builder, { kind = "builder" }))
assert(math.abs(branch(state, "target-a", 2) - 0.2) < 0.0001
    and math.abs(branch(state, "target-a", 3) - 0.8) < 0.0001
    and math.abs(C:Expected(state, "target-a") - 2.8) < 0.0001,
    "an uncertain builder must retain landed and missed points on its owner")

C:Attach(state, 2, "target-a", { selectedExact = true,
    globalExact = true, source = "test combo owner" })
local swapBuilder = { targetGUID = "target-b",
    tooltip = { comboGain = 1 }, resistance = { landChance = 0.6 } }
C:Apply(state, swapBuilder, { kind = "builder" })
assert(math.abs(branch(state, "target-a", 2) - 0.4) < 0.0001
    and math.abs(branch(state, "target-b", 1) - 0.6) < 0.0001
    and math.abs(C:Availability(state, "target-a") - 0.4) < 0.0001
    and math.abs(C:Availability(state, "target-b") - 0.6) < 0.0001,
    "a landed builder must transfer ownership while its miss retains the old target")

local finisher = { targetGUID = "target-b",
    tooltip = { comboSpendAll = true }, resistance = { landChance = 0.75 } }
C:Apply(state, finisher, { kind = "damage", combo = true })
assert(math.abs(branch(state, nil, 0) - 0.45) < 0.0001
    and math.abs(branch(state, "target-b", 1) - 0.15) < 0.0001
    and math.abs(branch(state, "target-a", 2) - 0.4) < 0.0001
    and math.abs(C:Availability(state, "target-b") - 0.15) < 0.0001
    and C:ConditionalExpected(state, "target-b") == 1
    and C:ConditionalExpected(state, "target-a") == 2,
    "a finisher must consume only its owner's landed branch and preserve misses and other targets")

local targetBDuration = C:TooltipFor(state, "target-b", {
    duration = 6, durationBase = 6, durationMax = 16,
    durationComboScaled = true })
local targetADuration = C:TooltipFor(state, "target-a", {
    duration = 6, durationBase = 6, durationMax = 16,
    durationComboScaled = true })
assert(targetBDuration.duration == 8 and targetBDuration.durationComboPoints == 1
    and targetADuration.duration == 10
    and targetADuration.durationComboPoints == 2,
    "combo-scaled duration must use conditional points owned by the candidate target")

local selfState = { targetGUID = "target-b" }
C:Attach(selfState, 2, "target-a", { selectedExact = true,
    globalExact = true, source = "test combo owner" })
C:Apply(selfState, swapBuilder, { kind = "builder" })
local selfDescriptor = { unit = "player", guid = "player-guid",
    relation = "self" }
local owner, allOwners = C:ActionOwner(selfState, { combo = true },
    { comboSpendAll = true }, selfDescriptor)
assert(owner == nil and allOwners == true,
    "a self finisher must retain every possible hostile owner branch")
local selfDuration = C:TooltipFor(selfState, owner, {
    duration = 6, durationBase = 6, durationMax = 16,
    durationComboScaled = true }, allOwners)
assert(math.abs(selfDuration.durationComboPoints - 1.4) < 0.0001
    and math.abs(selfDuration.duration - 8.8) < 0.0001,
    "a self finisher must scale from the conditional global combo state")
C:Apply(selfState, { targetGUID = "player-guid", comboTargetGUID = owner,
    comboAllOwners = allOwners, tooltip = { comboSpendAll = true } },
    { kind = "buff", combo = true })
assert(C:Availability(selfState, "target-a") == 0
    and C:Availability(selfState, "target-b") == 0,
    "a landed self finisher must consume whichever hostile branch owns the points")

local unknownState = { targetGUID = "target-a" }
C:Attach(unknownState, 3, "target-a", { selectedExact = true,
    globalExact = true, source = "test combo owner" })
assert(C:Apply(unknownState, { targetGUID = "target-a",
    tooltip = { comboGain = 1 }, resistance = { unknown = true } },
    { kind = "builder" })
    and unknownState.comboTransitionUnknown == true
    and unknownState.comboTransitionUnknownReason
        == "combo delivery probability unknown"
    and C:Availability(unknownState, "target-a") == 0
    and C:Expected(unknownState, "target-a") == 0,
    "missing land probability must erase future combo authority, not assume a hit")

print("ok: target-owned probabilistic combo and duration state")
