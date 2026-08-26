-- Bridges timeline health changes into exact crowd-control break semantics.
-- The bridge is intentionally conservative: expected damage is not promoted
-- to a guaranteed hit, and an unresolved direct/periodic distinction leaves
-- control persistence unknown instead of inventing a server outcome.
XelAssist.Graph.CrowdControlTimeline = {}
local T = XelAssist.Graph.CrowdControlTimeline
local Control = XelAssist.Graph.CrowdControl

function T:Snapshot(state)
    return Control and Control:DamageSnapshot(state) or nil
end

local function eventEvidence(entry, candidate)
    local owner, kind = entry and entry.owner, entry and entry.kind
    if owner == "action" and kind == "chosenAction" then
        return true, tonumber(candidate and candidate.effectDelivery) ~= nil
            and candidate.effectDelivery >= 0.999,
            "chosen action"
    end
    if owner == "autoShot" and kind == "impact" then
        local delivery = entry.shot and tonumber(entry.shot.delivery)
        return true, delivery ~= nil and delivery >= 0.999,
            "auto-shot impact"
    end
    if kind == "playerMainSwing" or kind == "playerOffhandSwing"
        or kind == "petWhiteSwing" then
        return true, false, kind
    end
    if kind == "periodicTick" or kind == "periodicSegment" then
        return false, false, kind
    end
    if kind == "leechChannelTick" or kind == "leechChannelFinish" then
        return nil, false, kind
    end
    if owner == "ongoing" or owner == "autoShot" then
        return nil, false, kind or owner
    end
    return nil, false, kind or owner or "timeline event"
end

function T:ResolveEvent(state, snapshot, entry, candidate)
    if not (Control and snapshot) then return end
    local direct, guaranteed, source = eventEvidence(entry, candidate)
    Control:ResolveDamage(state, snapshot, { direct = direct,
        guaranteed = guaranteed, source = source })
end

function T:ResolveAdvance(state, snapshot)
    if Control and snapshot then
        Control:ResolveDamage(state, snapshot, { direct = false,
            guaranteed = false, source = "periodic aura advance" })
    end
end
