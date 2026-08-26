-- Supplemental rage and melee haste from an already-admitted Enrage action.
-- This leaf does not admit or score Enrage and cannot hide its armor cost.
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
        and found.hastePercent == spec.hastePercent
        and found.hasteDuration == spec.hasteDuration
        and found.powerType == owner.RAGE
end

local function roundFor(state, hand)
    local attack = state and state.playerAttack
    return attack and (hand == "off" and attack.offhandAttackRound
        or attack.attackRound) or nil
end
local function lane(round, activePercent)
    local speed, interval = finite(round and round.speed),
        finite(round and round.interval)
    if not (speed and speed > 0 and interval and interval > 0
        and round.speedTrusted == true and round.verified == true
        and round.projectable == true) then return nil end
    local multiplier = 1 + (tonumber(activePercent) or 0) / 100
    return { exact = true, baseSpeed = speed * multiplier,
        guard = math.max(0, interval - speed),
        targetGuid = round.targetGuid }
end

function B:Attach(state, classToken)
    local owner = XelAssist.Game.Player.DruidBloodFrenzy
    local root = owner and owner:HasteSnapshot()
    if not (state and classToken == "DRUID" and root
        and root.available == true and root.exact == true) then return false end
    if root.rank == 0 then
        state.druidBloodFrenzy = { available = true, exact = true,
            rank = 0, active = false, lanes = {} }
        return true
    end
    local found = root.profile
    if not valid(found) then return false end
    local activePercent = root.active and found.hastePercent or nil
    state.druidBloodFrenzy = { available = true, exact = true,
        rank = found.rank, active = root.active == true,
        remaining = root.remaining, hastePercent = found.hastePercent,
        hasteDuration = found.hasteDuration,
        hasteSpellId = found.hasteSpellId, lanes = {
            main = lane(roundFor(state, "main"), activePercent),
            off = lane(roundFor(state, "off"), activePercent) } }
    return true
end

function B:Copy(source, target)
    local current = source and source.druidBloodFrenzy
    if not current then target.druidBloodFrenzy = nil; return false end
    local lanes, hand = {}, nil
    for _, hand in ipairs({ "main", "off" }) do
        local found = current.lanes and current.lanes[hand]
        if found then
            lanes[hand] = { exact = found.exact,
                baseSpeed = found.baseSpeed, guard = found.guard,
                targetGuid = found.targetGuid }
        end
    end
    target.druidBloodFrenzy = {
        available = current.available, exact = current.exact,
        rank = current.rank, active = current.active,
        remaining = current.remaining, hastePercent = current.hastePercent,
        hasteDuration = current.hasteDuration,
        hasteSpellId = current.hasteSpellId, lanes = lanes }
    return true
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
    local haste = state.druidBloodFrenzy
    if haste and haste.available == true and haste.exact == true
        and haste.rank == found.rank then
        haste.active, haste.remaining = true, found.hasteDuration
        haste.hastePercent, haste.hasteDuration =
            found.hastePercent, found.hasteDuration
        haste.hasteSpellId = found.hasteSpellId
    end
    return true
end

function B:Advance(state, elapsed)
    local current = state and state.druidBloodFrenzy
    elapsed = tonumber(elapsed)
    if not (current and current.exact == true and current.active == true
        and elapsed and elapsed > 0) then return false end
    current.remaining = math.max(0,
        (tonumber(current.remaining) or 0) - elapsed)
    if current.remaining <= 0 then current.active = false end
    return true
end

function B:IntervalAfter(state, hand, swingOffset, fallback)
    local current = state and state.druidBloodFrenzy
    local found = current and current.lanes and current.lanes[hand]
    if not (current and current.exact == true and found
        and found.exact == true and finite(found.baseSpeed)
        and finite(found.guard)) then return fallback end
    local active = current.active == true
        and (tonumber(current.remaining) or 0)
            > math.max(0, tonumber(swingOffset) or 0) + 0.000001
    local percent = active and tonumber(current.hastePercent) or 0
    return found.baseSpeed / (1 + (percent or 0) / 100) + found.guard
end
