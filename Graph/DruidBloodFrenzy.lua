-- Supplemental immediate rage from an already-admitted Enrage action. This
-- leaf does not admit or score Enrage and therefore cannot hide its armor cost.
XelAssist.Graph.DruidBloodFrenzy = {}
local B = XelAssist.Graph.DruidBloodFrenzy

local function finite(value)
    value = tonumber(value)
    return value and value == value and value ~= math.huge
        and value ~= -math.huge and value or nil
end
local function evidence(candidate)
    local facts = candidate and candidate.action and candidate.action.facts or {}
    local tooltip = candidate and candidate.tooltip or {}
    return tooltip.druidBloodFrenzyEvidence
        or facts.druidBloodFrenzyEvidence
end
local function valid(found)
    local owner = XelAssist.Game.Player.DruidBloodFrenzy
    local spec = found and owner and owner.RANKS[found.rank]
    return found and found.available == true and found.exact == true
        and found.valid == true and spec and found.talentID == owner.TALENT_ID
        and found.talentSpellId == spec.talentSpellId
        and found.triggerSpellId == spec.triggerSpellId
        and found.hasteSpellId == spec.hasteSpellId
        and found.enrageSpellId == owner.ENRAGE_ID
        and found.bonusRage == spec.bonusRage
        and found.powerType == owner.RAGE
end

function B:ApplyImmediate(state, candidate)
    local found, owner = evidence(candidate),
        XelAssist.Game.Player.DruidBloodFrenzy
    local form = state and state.druidFormState
    local current, maximum = finite(state and state.resource),
        finite(state and state.resourceMax)
    if not (valid(found) and candidate.action.spellId == owner.ENRAGE_ID
        and form and form.available == true
        and (form.formID == 5 or form.formID == 8)
        and state.resourceType == owner.RAGE
        and state.playerResourceExact == true and current and maximum
        and current >= 0 and maximum >= current) then return false end
    local gained = math.max(0, math.min(maximum - current, found.bonusRage))
    state.resource = current + gained
    local actor = state.actors and state.actors.player
    if actor and finite(actor.resource) and finite(actor.resourceMax)
        and actor.resourceMax == maximum then actor.resource = state.resource end
    state.druidBloodFrenzyLast = { exact = true, rage = gained,
        triggerSpellId = found.triggerSpellId, source = found.source }
    return true
end
