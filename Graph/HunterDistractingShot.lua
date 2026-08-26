-- Search-pure graph boundary for Distracting Shot. Runtime code seals the
-- level- and modifier-adjusted effect-63 packet before descendants open; this
-- module only verifies its hostile recipient and exposes delivery semantics.
XelAssist.Graph.HunterDistractingShot = {}
local D = XelAssist.Graph.HunterDistractingShot

local function runtime()
    return XelAssist.Game and XelAssist.Game.Player
        and XelAssist.Game.Player.HunterDistractingShot
end

local function profile(subject)
    local owner = runtime()
    return owner and owner:Profile(subject) or nil
end

function D:Is(subject)
    local facts = type(subject) == "table" and subject.facts or subject
    return type(facts) == "table" and facts.hunterDistractingShot == true
end

function D:Evidence(subject)
    return profile(subject)
end

-- Called after target resolution but before hit/resistance projection. No
-- class action value is assigned here: generic threat policy prices the exact
-- player packet against tank, group, and controlled-companion state.
function D:Prepare(context)
    local action = context and context.action
    if not self:Is(action) then return nil, nil, false end
    local found = profile(context.facts) or profile(action)
    if not found then
        return nil, "exact Distracting Shot threat evidence unavailable", true
    end
    local descriptor = context.descriptor
    if not (action and (action.actor or "player") == "player"
        and tonumber(action.spellId) == found.spellId
        and descriptor and descriptor.relation == "hostile"
        and descriptor.guid ~= nil) then
        return nil, "Distracting Shot requires an exact hostile recipient", true
    end
    local amounts = context.facts and context.facts.baseFlatThreatBySpellId
    if not (type(amounts) == "table"
        and amounts[found.spellId] == found.effectiveThreat
        and context.facts.targetLocalFlatThreat == true
        and context.facts.threatOnly == true) then
        return nil, "Distracting Shot threat packet changed", true
    end
    context.targetEffect, context.damageKind = true, false
    context.threatSchool = found.school
    context.power, context.expectedPower, context.effectivePower = 0, 0, 0
    context.hunterDistractingShot = true
    context.reason = "projects exact selected-hostile threat"
    return true, nil, true
end
