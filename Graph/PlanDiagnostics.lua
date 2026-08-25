-- Path-local explanation for a graph branch that cannot continue.  These
-- records describe evidence gaps to the presenter; they are never executable
-- actions and never contribute value to beam selection.
XelAssist.Graph.PlanDiagnostics = {}
local D = XelAssist.Graph.PlanDiagnostics
local State = XelAssist.Graph.State

local resourceNames = {
    [0] = "Mana", [1] = "Rage", [2] = "Focus", [3] = "Energy",
}

local function actionFacts(state, action)
    local root = XelAssist.Graph.RootObservation
    if root and root.Facts then
        local facts, status = root:Facts(state, action)
        if status == "known" then return facts end
        if status ~= "absent" then return nil end
    end
    return XelAssist.Game.Actors:Facts(action)
end

local function recordActionBlocker(blockers, reason, action)
    if not action then return end
    if not blockers.byAction then blockers.byAction = {} end
    local key = tostring(action.name or "Action") .. ":"
        .. tostring(action.rank or 0) .. ":" .. tostring(action.actor or "player")
    local row = blockers.byAction[key]
    if not row then
        row = { name = action.name or "Action", rank = action.rank,
            actor = action.actor or "player", spellId = action.spellId,
            reasons = {} }
        blockers.byAction[key] = row
    end
    row.reasons[reason] = (row.reasons[reason] or 0) + 1
end

function D:Record(blockers, reason, action, descriptor, state)
    blockers[reason] = (blockers[reason] or 0) + 1
    if descriptor then
        blockers.targetAware = true
        if descriptor.source ~= "engaged"
            and (reason == "range" or reason == "minimum range") then
            local key = reason == "range" and "selectedRange"
                or "selectedMinimumRange"
            blockers[key] = (blockers[key] or 0) + 1
        end
    end
    recordActionBlocker(blockers, reason, action)
    if reason ~= "resource" or not action or action.actor == "pet" then return end
    local tooltip = actionFacts(state, action)
    local cost = tonumber(tooltip and tooltip.cost)
    if not cost then blockers.resourceCostUnknown = true; return end
    if not blockers.resourceRequired or cost < blockers.resourceRequired then
        blockers.resourceRequired = cost
    end
end

function D:Reason(state, blockers)
    local minimum, range = blockers["minimum range"], blockers.range
    if blockers.targetAware then
        minimum, range = blockers.selectedMinimumRange, blockers.selectedRange
    end
    if (minimum or 0) > 0 then return "Move farther away" end
    if (range or 0) > 0 then return "Move into range" end
    if (blockers.moving or 0) > 0 then return "Finish moving" end
    if (blockers.resource or 0) > 0 then return "Not enough resources" end
    if (blockers.cooldown or 0) > 0 then return "Waiting for cooldown" end
    if (blockers["stealth opener protection"] or 0) > 0 then
        return "Preserving stealth for an opener"
    end
    local i, injured = nil, false
    for i = 1, table.getn(state.friendlies and state.friendlies.order or {}) do
        if State:Missing(State:FriendlyByKey(
            state, state.friendlies.order[i])) > 0 then
            injured = true
            break
        end
    end
    if not state.hostile and not injured then
        return "Select a target or injured ally"
    end
    return "No worthwhile action"
end

function D:Terminal(state, blockers)
    if not blockers or not next(blockers) then return nil end
    local reason = self:Reason(state, blockers)
    if reason ~= "Not enough resources" then
        return { kind = "blocked", reason = reason }
    end
    local reserved = math.max(0, tonumber(state.playerResourceReserved) or 0)
    local current = math.max(0, (tonumber(state.resource) or 0) - reserved)
    local maximum = math.max(0, (tonumber(state.resourceMax) or current) - reserved)
    local required = tonumber(blockers.resourceRequired)
    local resources = XelAssist.Game.Player and XelAssist.Game.Player.Resources
    local clock = resources and resources:ClockFor(state) or nil
    return { kind = "resource", reason = reason,
        resourceType = tonumber(state.resourceType),
        resourceName = resourceNames[tonumber(state.resourceType)] or "Resource",
        current = current, maximum = maximum, required = required,
        costKnown = required ~= nil and not blockers.resourceCostUnknown,
        timingKnown = clock ~= nil,
        unreachable = required ~= nil and maximum < required or false }
end
