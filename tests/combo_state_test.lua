XelAssist = { Graph = {} }

dofile("Graph/ComboState.lua")
local C = XelAssist.Graph.ComboState

local state = {}
C:Attach(state, 2)
assert(state.combo == 2 and state.comboAvailability == 1
    and state.comboDistribution[2] == 1,
    "an observed combo count must begin as one exact branch")

local builder = { tooltip = { comboGain = 1 },
    resistance = { landChance = 0.8 } }
assert(C:Apply(state, builder, { kind = "builder" }))
assert(math.abs(state.comboDistribution[2] - 0.2) < 0.0001
    and math.abs(state.comboDistribution[3] - 0.8) < 0.0001
    and math.abs(state.combo - 2.8) < 0.0001
    and state.comboAvailability == 1,
    "an uncertain builder must retain landed and missed point branches")

local finisher = { tooltip = { comboSpendAll = true },
    resistance = { landChance = 0.75 } }
assert(C:Apply(state, finisher, { kind = "damage", combo = true }))
assert(math.abs(state.comboDistribution[0] - 0.75) < 0.0001
    and math.abs(state.comboDistribution[2] - 0.05) < 0.0001
    and math.abs(state.comboDistribution[3] - 0.2) < 0.0001
    and math.abs(state.combo - 0.7) < 0.0001
    and math.abs(state.comboAvailability - 0.25) < 0.0001
    and math.abs(C:ConditionalExpected(state) - 2.8) < 0.0001,
    "a missed finisher must retain the exact prior point branches")

C:Attach(state, 0)
C:Apply(state, { tooltip = { comboGain = 1 },
    resistance = { landChance = 0.6 } }, { kind = "builder" })
assert(math.abs(state.comboDistribution[0] - 0.4) < 0.0001
    and math.abs(state.comboDistribution[1] - 0.6) < 0.0001
    and math.abs(state.comboAvailability - 0.6) < 0.0001
    and C:ConditionalExpected(state) == 1,
    "builder availability must distinguish expected points from points on success")

print("ok: probabilistic combo gain and miss-preserving finisher state")
