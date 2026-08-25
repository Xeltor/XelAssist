-- Incremental renderer for the read-only future recommendation rail. Graph
-- evaluations may replace one distant branch without repainting every visible
-- row (or the executable current card).
XelAssist.UI.RunwayRenderer = {}
local R = XelAssist.UI.RunwayRenderer
local Theme = XelAssist.UI.Theme
local Placeholder = XelAssist.UI.RunwayPlaceholder

local function renderKey(route, name, time, certainty, icon, actor, placeholder)
    return table.concat({
        placeholder and "placeholder" or "action",
        tostring(route or ""), tostring(name or ""), tostring(time or ""),
        tostring(certainty or ""), tostring(icon or ""), tostring(actor or "")
    }, "\031")
end

local function hideRow(row)
    row.action, row.candidate, row.placeholder = nil, nil, nil
    row.placeholderReason = nil
    if row.xelRenderKey == "hidden" then return end
    row.xelRenderKey = "hidden"
    row.xelRenderRevision = row.xelRenderRevision + 1
    row.route:SetText(""); row.name:SetText(""); row.time:SetText("")
    row.certainty:SetText(""); row:Hide()
end

local function paintRow(row, spec)
    if row.xelRenderKey == spec.key then return end
    row.xelRenderKey = spec.key
    row.xelRenderRevision = row.xelRenderRevision + 1
    row.icon:SetTexture(spec.icon)
    if row.icon.SetDesaturated then row.icon:SetDesaturated(spec.placeholder and true or false) end
    Theme:SetIconActor(row.iconFrame, spec.actor)
    spec.setFittedText(row.route, spec.route, 112)
    row.route:SetTextColor(spec.routeR, spec.routeG, spec.routeB)
    spec.setFittedText(row.name, spec.name, 112)
    row.time:SetText(spec.time)
    row.certainty:SetText(spec.certainty)
    row.certainty:SetTextColor(spec.certaintyR, spec.certaintyG, spec.certaintyB)
    row:Show()
end

function R:Clear(frame)
    local i
    for i = 1, table.getn(frame.follow or {}) do hideRow(frame.follow[i]) end
    return 0
end

function R:Render(frame, plan, requested, helpers)
    local visible, placeholderShown, pathTime = 0, false,
        math.max(0, tonumber(plan.downtime) or 0)
    local i
    for i = 1, table.getn(frame.follow or {}) do
        local row = frame.follow[i]
        local follow = plan.follow and plan.follow[i]
        if follow and i <= requested and not placeholderShown then
            local candidate = plan.path and plan.path[i + 1] or nil
            local route = helpers.routeCopy(follow, candidate and candidate.target,
                candidate and candidate.targetRef)
            local name = helpers.actionName(follow)
            local start = candidate and tonumber(candidate.actionStart) or pathTime
            local time = helpers.timeCopy(start)
            local certainty, cr, cg, cb = helpers.certaintyCopy(nil, candidate)
            local icon = helpers.iconFor(follow)
            local actor = follow.actor or "player"
            local routeR = actor == "pet" and 0.72 or 0.64
            local routeG = actor == "pet" and 0.48 or 0.69
            local routeB = actor == "pet" and 0.92 or 0.76
            row.action, row.candidate, row.placeholder = follow, candidate, nil
            row.placeholderReason, row.stepIndex = nil, i + 1
            paintRow(row, { key = renderKey(route, name, time, certainty,
                    icon, actor, false), icon = icon, actor = actor,
                route = route, routeR = routeR, routeG = routeG, routeB = routeB,
                name = name, time = time, certainty = certainty,
                certaintyR = cr, certaintyG = cg, certaintyB = cb,
                setFittedText = helpers.setFittedText })
            visible = visible + 1
            if candidate then
                pathTime = math.max(pathTime, start or pathTime)
                    + math.max(0, tonumber(candidate.downtime) or 0)
            end
        elseif i <= requested and not placeholderShown then
            local route, name, detail = Placeholder:Describe(plan)
            placeholderShown, visible = true, visible + 1
            row.action, row.candidate, row.placeholder = nil, nil, true
            row.placeholderReason, row.stepIndex = detail, i + 1
            paintRow(row, { key = renderKey(route, name, "--", "OPEN",
                    helpers.fallbackIcon, "placeholder", true),
                icon = helpers.fallbackIcon, actor = "placeholder",
                route = route, routeR = 0.48, routeG = 0.52, routeB = 0.58,
                name = name, time = "--", certainty = "OPEN",
                certaintyR = 0.95, certaintyG = 0.73, certaintyB = 0.34,
                placeholder = true, setFittedText = helpers.setFittedText })
        else
            hideRow(row)
        end
    end
    return visible
end
