-- Search-pure Feign Death continuation. Generic ThreatDrop owns the coupled
-- success/resist branch; this leaf owns player interruption and wake-up state.
XelAssist.Graph.HunterFeignDeath = {}
local F = XelAssist.Graph.HunterFeignDeath
local EPSILON = 0.000001

local function runtime()
    return XelAssist.Game and XelAssist.Game.Player
        and XelAssist.Game.Player.HunterFeignDeath
end
local function copy(value, depth)
    if type(value) ~= "table" or depth <= 0 then return value end
    local out, key, entry = {}, nil, nil
    for key, entry in pairs(value) do out[key] = copy(entry, depth - 1) end
    return out
end
local function exact(state)
    local found, owner = state and state.hunterFeignDeath, runtime()
    local profile = found and found.profile
    if not (owner and found and found.available == true and found.exact == true
        and profile and profile.valid == true and profile.exact == true
        and profile.spellId == owner.SPELL_ID and profile.model == owner.MODEL
        and profile.duration == owner.DURATION
        and profile.outcomeCoupled == true
        and profile.petCombatContinues == true
        and profile.interruptsPlayerAttacks == true) then return nil end
    return found
end

function F:Attach(state, snapshot)
    if type(state) ~= "table" then return false end
    state.hunterFeignDeath = copy(snapshot, 4)
    return exact(state) ~= nil
end
function F:Copy(source, target)
    if not (source and target) then return false end
    target.hunterFeignDeath = copy(source.hunterFeignDeath, 4)
    return target.hunterFeignDeath ~= nil
end
function F:Is(action, tooltip)
    local owner = runtime()
    return owner and (owner:Evidence(tooltip) or owner:Evidence(action)) ~= nil
end
function F:Blocker(action, state, descriptor, tooltip)
    if not self:Is(action, tooltip) then return nil, false end
    local current = exact(state)
    if not current then return "Feign Death root state unavailable", true end
    if descriptor and not (descriptor.unit == "player"
        and descriptor.relation == "self") then
        return "Feign Death requires the player recipient", true
    end
    if current.active == true and (tonumber(current.remaining) or 0) > EPSILON then
        return "Feign Death already active", true
    elseif state.inCombat ~= true then
        return state.inCombat == false and "no combat threat to feign"
            or "combat state unavailable", true
    end
    local certain, uncertain = 0, 0
    if XelAssist.Graph.ThreatDrop then
        certain, uncertain = XelAssist.Graph.ThreatDrop:Risk(state)
    end
    if certain + uncertain == 0 then
        return "no unwanted player aggro", true
    end
    return nil, true
end

local function stopPlayer(state)
    if state.playerAttack then state.playerAttack.active = false end
    if state.autoShot then state.autoShot.active, state.autoShot.pending = false, false end
    if state.wand then state.wand.active, state.wand.pending = false, false end
    state.playerCasting, state.playerChanneling = false, false
    state.playerCastName, state.castRemaining = nil, 0
end

function F:Apply(state, candidate)
    local current, owner = exact(state), runtime()
    if not (current and owner and self:Is(candidate and candidate.action,
        candidate and candidate.tooltip)) then return false end
    current.active, current.remaining, current.projected =
        true, owner.DURATION, true
    current.outcomeKnown, current.wakesOnNextAction = false, true
    current.source = "projected Feign Death application"
    stopPlayer(state)
    return true
end

-- Any later admitted player action is the player's decision to stop feigning.
-- It does not manufacture a successful threat outcome or restart attacks.
function F:Consume(state, candidate)
    local current, owner = exact(state), runtime()
    local action = candidate and candidate.action
    if not (current and current.active == true and action
        and (action.actor == nil or action.actor == "player")
        and tonumber(action.spellId) ~= owner.SPELL_ID) then return false end
    current.active, current.remaining, current.wakesOnNextAction = false, 0, false
    current.source = "projected player action ends Feign Death"
    return true
end

function F:Advance(state, elapsed)
    local current = exact(state)
    if not (current and current.active == true) then return false end
    current.remaining = math.max(0, (tonumber(current.remaining) or 0)
        - math.max(0, tonumber(elapsed) or 0))
    if current.remaining <= EPSILON then
        current.active, current.expirationOutcomeUnknown = false, true
        state.playerSurvivalExact = false
    end
    return true
end
