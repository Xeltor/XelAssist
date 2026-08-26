-- DBC masks are frozen facts. Their legality must remain identical at root and
-- after waits unless an explicit graph transition changes the player form.
XelAssist = { Graph = {} }
dofile("Graph/FormRequirements.lua")
local Forms = XelAssist.Graph.FormRequirements

local battle = { available = true, formID = 17 }
local defensive = { available = true, formID = 18 }
local neutral = { available = true, formID = 0 }
local battleMask, defensiveMask = 65536, 131072

local function blocked(form, facts)
    return Forms:Blocker({ playerForm = form, time = 12 }, facts)
end

assert(blocked(battle, { stances = battleMask }) == nil,
    "a matching exact Warrior stance must satisfy the DBC mask")
assert(blocked(defensive, { stances = battleMask })
    == "required player form inactive",
    "a future wait must not legalize an unchanged mismatched stance")
assert(blocked(neutral, { stances = battleMask })
    == "required player form inactive",
    "neutral form cannot satisfy a positive form mask")
assert(blocked(neutral, { stances = battleMask,
        attributesEx2 = 524288 }) == nil,
    "the exact allow-while-neutral bit must preserve caster-form legality")
assert(blocked(defensive, { stances = battleMask,
        attributesEx2 = 524288 }) == "required player form inactive",
    "allow-while-neutral must not legalize a different positive form")
assert(blocked(defensive, { stances = battleMask + defensiveMask }) == nil,
    "a multi-form allow mask must accept any exact included form")
assert(blocked(defensive, { stancesNot = defensiveMask })
    == "current player form excluded",
    "an exact negative DBC form mask must reject its included form")
assert(blocked(neutral, { stancesNot = defensiveMask }) == nil,
    "a neutral player is not in an excluded positive form")
assert(Forms:Blocker({ playerForm = { available = false } },
        { stances = battleMask }) == "player form state unavailable",
    "missing exact form evidence must fail closed for constrained spells")
assert(Forms:Blocker({}, { stances = 0, stancesNot = 0 }) == nil,
    "unconstrained spells must not require the optional bridge")

print("ok: exact DBC form requirements survive future graph depth")
