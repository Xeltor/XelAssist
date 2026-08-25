-- Truthful presentation for a requested future row when the selected graph
-- path has no executable candidate to show.
XelAssist.UI.RunwayPlaceholder = {}
local P = XelAssist.UI.RunwayPlaceholder

local function whole(value)
    return tostring(math.floor(math.max(0, tonumber(value) or 0) + 0.5))
end

function P:Describe(plan)
    local terminal = plan and plan.terminal
    if terminal and terminal.kind == "resource" then
        local resource = terminal.resourceName or "Resource"
        local route = string.upper(resource) .. " GATE"
        if terminal.unreachable then
            return route, "Cost exceeds cap",
                "The selected path requires more " .. string.lower(resource)
                    .. " than the character can hold."
        end
        local amount = terminal.required
            and whole(terminal.current) .. " / " .. whole(terminal.required)
                .. " " .. string.lower(resource)
            or "More " .. string.lower(resource) .. " required"
        if terminal.timingKnown then
            return route, amount, "The selected path is waiting for a verified "
                .. string.lower(resource) .. " recovery event."
        end
        return route, amount, "No verified " .. string.lower(resource)
            .. " recovery clock is available; no timestamp or future action was invented."
    end
    if terminal then
        return "STATE GATE", terminal.reason or "Continuation blocked",
            "The selected graph path ended at this state: "
                .. string.lower(terminal.reason or "continuation blocked") .. "."
    end
    if plan and plan.horizonLimited then
        return "GRAPH HORIZON", "Time horizon",
            "The selected path reached the graph's modeled-time horizon."
    end
    if plan and plan.budgetLimited then
        return "LOOK-AHEAD LIMIT", "Search budget",
            "The graph's safe search budget ended before this step."
    end
    return "NO CONTINUATION", "No useful next step",
        "The selected graph path has no positively scored continuation for this step."
end
