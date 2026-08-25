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

print("ok: target-owned probabilistic combo and duration state")
