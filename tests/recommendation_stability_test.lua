table.getn = table.getn or function(value)
    local count = 0
    while value[count + 1] ~= nil do count = count + 1 end
    return count
end
XelAssist = { UI = {} }
XelAssistCharDB = { visibleSteps = 4 }

dofile("UI/RecommendationStability.lua")
local Stability = XelAssist.UI.RecommendationStability

local function action(name)
    return { name = name, rank = 1, spellId = string.len(name),
        actor = "player", executor = "playerSpell" }
end

local function candidate(name, target)
    return { action = action(name), target = "target", targetGUID = target }
end

local function plan(names, target, limited)
    local out = { action = action(names[1]), actor = "player",
        target = "target", targetGUID = target, reason = "best path",
        confidence = "client data", budgetLimited = limited,
        path = {}, follow = {} }
    local i
    for i = 1, table.getn(names) do
        out.path[i] = candidate(names[i], target)
        if i > 1 then out.follow[i - 1] = out.path[i].action end
    end
    return out
end

local owner = {}
local first, _, changed = Stability:Select(owner,
    plan({ "Builder", "Builder", "Finisher" }, "enemy-a", false), nil, true)
assert(changed and table.getn(first.path) == 3,
    "the first complete preview must publish atomically")

local retained
retained, _, changed = Stability:Select(owner,
    plan({ "Builder" }, "enemy-a", true), nil, false)
assert(not changed and retained.runwayRetained and table.getn(retained.path) == 3
    and retained.follow[2].name == "Finisher",
    "a same-root budget-short preview must not collapse the validated rail")

local forked
forked, _, changed = Stability:Select(owner,
    plan({ "Builder", "Different Builder" }, "enemy-a", true), nil, false)
assert(changed and not forked.runwayRetained
    and table.getn(forked.path) == 2
    and forked.path[2].action.name == "Different Builder",
    "a changed branch must never splice an incompatible prior suffix")

owner.xelDisplayPlan = retained

local replacement
replacement, _, changed = Stability:Select(owner,
    plan({ "Finisher", "Builder" }, "enemy-a", false), nil, false)
assert(changed and replacement.action.name == "Finisher",
    "a materially different executable root must publish immediately")

local retargeted
retargeted, _, changed = Stability:Select(owner,
    plan({ "Finisher", "Builder" }, "enemy-b", false), nil, false)
assert(changed and retargeted.targetGUID == "enemy-b",
    "opaque target identity changes must invalidate the prior preview")

local empty, reason
empty, reason, changed = Stability:Select(owner, nil, "No worthwhile action", false)
assert(empty == nil and reason == "No worthwhile action" and changed,
    "a hard no-action result must clear the executable preview")

print("ok: atomic recommendation publication and runway retention")
