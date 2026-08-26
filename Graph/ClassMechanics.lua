-- Exact Paladin/Shaman graph boundary. Mutable APIs are confined to Attach;
-- branch preparation consumes only copied action facts and projected state.
-- Lifecycle alone never supplies combat value or a preferred action order.
XelAssist.Graph.ClassMechanics = {}
local M = XelAssist.Graph.ClassMechanics
local Paladin = XelAssist.Graph.PaladinAuraProjection
local PaladinActions = XelAssist.Game.Player.PaladinActions
local PaladinBlessingThreat = XelAssist.Graph.PaladinBlessingThreat
local Totems = XelAssist.Game.Player.TotemState
local ShamanActions = XelAssist.Game.Player.ShamanActions
local MageShield = XelAssist.Game.Player.MageManaShield
local PriestShield = XelAssist.Game.Player.PriestShield
local RogueFeint = XelAssist.Game.Player.RogueFeint
local RogueFeintGraph = XelAssist.Graph.RogueFeint
local HunterMark = XelAssist.Game.Player.HunterMark
local HunterMarkGraph = XelAssist.Graph.HunterMark
local PriestShadowformRuntime = XelAssist.Game.Player.PriestShadowform
local PriestShadowform = XelAssist.Graph.PriestShadowform
local Windfury = XelAssist.Graph.ShamanWindfuryTotem

local function classToken()
    if type(UnitClass) ~= "function" then return nil end
    local ok, _, token = pcall(UnitClass, "player")
    return ok and token or nil
end

local function identityField(field)
    if type(field) ~= "string" then return false end
    local lower = string.lower(field)
    return lower == "key" or string.sub(lower, -4) == "guid"
end

local function copy(value, depth, seen, field)
    if type(value) ~= "table" or depth <= 0
        or identityField(field) then return value end
    seen = seen or {}
    if seen[value] then return seen[value] end
    local out, key, entry = {}, nil, nil
    seen[value] = out
    for key, entry in pairs(value) do
        out[key] = copy(entry, depth - 1, seen, key)
    end
    return out
end

function M:Attach(state)
    if not state then return false end
    local token = classToken()
    state.classMechanicClass = token
    if token == "PALADIN" and Paladin then
        local attached = Paladin:Attach(state)
        if PaladinBlessingThreat then PaladinBlessingThreat:Attach(state) end
        return attached
    elseif token == "SHAMAN" and Totems then
        state.totems = Totems:Snapshot()
        local attached = state.totems and state.totems.available == true or false
        if Windfury then Windfury:Attach(state) end
        return attached
    elseif token == "HUNTER" and HunterMarkGraph then
        return HunterMarkGraph:Attach(state) ~= nil
    elseif token == "PRIEST" and PriestShadowform then
        return PriestShadowform:Attach(state, token)
    end
    return false
end

function M:Copy(source, target)
    if not (source and target) then return false end
    target.classMechanicClass = source.classMechanicClass
    if source.paladinAuraState and Paladin then Paladin:Copy(source, target) end
    if source.paladinBlessingThreat and PaladinBlessingThreat then
        PaladinBlessingThreat:Copy(source, target)
    end
    if source.totems then target.totems = copy(source.totems, 7) end
    if source.hunterMarkRoot then target.hunterMarkRoot = source.hunterMarkRoot end
    if PriestShadowform then PriestShadowform:Copy(source, target) end
    if Windfury then Windfury:Copy(source, target) end
    return source.paladinAuraState ~= nil
        or source.paladinBlessingThreat ~= nil or source.totems ~= nil
        or source.hunterMarkRoot ~= nil
        or source.playerShadowformProfileExact == true
        or source.shamanWindfuryTotem ~= nil
end

local function paladinClaimed(facts)
    return facts.paladinAction == true or facts.paladinAura == true
        or facts.paladinSeal == true or facts.paladinBlessing == true
        or facts.paladinJudgement == true or facts.paladinRighteousFury == true
end

local function shamanClaimed(facts)
    return facts.shamanAction == true or facts.shamanTotem == true
        or facts.requiresShamanTotemState == true
end

local function paladinProjection(action, state, descriptor)
    local facts = action.facts or {}
    if not (facts.paladinAction == true
        and type(facts.paladinClassification) == "table"
        and facts.paladinClassification.exact == true) then
        return nil, "captured Paladin action classification unavailable", true
    end
    local outcome = facts.paladinDownstreamOutcome
    local projection, reason, handled = Paladin:Prepare(
        action, state, descriptor, outcome)
    if not handled then
        return nil, reason or "captured Paladin mechanic unavailable", true
    end
    if not projection then return nil, reason, true end
    if not PaladinActions:EffectsRepresented(facts) then
        return nil, "Paladin downstream combat effect unavailable", true
    end
    local effect = projection.outcome and projection.outcome.effect
        or facts.paladinDownstreamEffect
    if not (effect and effect.exact == true
        and type(effect.kind) == "string" and effect.kind ~= "") then
        return nil, "Paladin downstream combat effect unavailable", true
    end
    projection.classMechanic = "paladin"
    projection.effect = effect
    if PaladinBlessingThreat then
        local prepared
        prepared, reason, handled = PaladinBlessingThreat:Prepare(
            state, projection)
        if handled then
            if not prepared then return nil, reason, true end
            projection = prepared
        end
    end
    return projection, nil, true
end

local function shamanProjection(action, state)
    local facts = action.facts or {}
    local lifecycle, reason = ShamanActions:Lifecycle(facts)
    if not lifecycle then return nil, reason, true end
    if not ShamanActions:DownstreamRepresented(facts) then
        return nil, "Shaman totem downstream consequence unavailable", true
    end
    local projection
    projection, reason = Totems:PrepareCaptured(
        action, state, lifecycle, facts.shamanTotemDownstream)
    if not projection then return nil, reason, true end
    if Windfury then
        local prepared, handled
        prepared, reason, handled = Windfury:Prepare(state, projection)
        if handled then
            if not prepared then return nil, reason, true end
            projection = prepared
        end
    end
    projection.classMechanic = "shaman"
    return projection, nil, true
end

function M:Prepare(action, state, descriptor)
    local facts = action and action.facts or {}
    if paladinClaimed(facts) then
        if not (Paladin and PaladinActions) then
            return nil, "Paladin graph mechanic unavailable", true
        end
        return paladinProjection(action, state, descriptor)
    elseif shamanClaimed(facts) then
        if not (Totems and ShamanActions) then
            return nil, "Shaman graph mechanic unavailable", true
        end
        return shamanProjection(action, state)
    end
    return nil, nil, false
end

function M:Blocker(action, state, descriptor)
    local projection, reason, handled = self:Prepare(action, state, descriptor)
    if not handled then return nil, false end
    if not projection then return reason or "class mechanic unavailable", true end
    return nil, true, projection
end

-- Shield discovery is class-specific, but its projected absorb remains a
-- normal graph consequence. Mutable modifier and aura reads are captured only
-- while the root observation is open; descendants consume sealed evidence.
function M:CaptureFacts(action, facts)
    local out = facts
    if MageShield then out = MageShield:CaptureFacts(action, out) end
    if RogueFeint then out = RogueFeint:CaptureFacts(action, out) end
    if HunterMark then out = HunterMark:CaptureFacts(action, out) end
    if PriestShadowformRuntime then
        out = PriestShadowformRuntime:CaptureFacts(action, out)
    end
    return out
end

function M:AuraActive(action, state, descriptor, tooltip, lead)
    if not HunterMarkGraph then return nil, false end
    return HunterMarkGraph:AuraActive(action, state, descriptor, tooltip, lead)
end

function M:CaptureRecipient(observed, action, descriptor)
    if PriestShield then return PriestShield:Capture(observed, action, descriptor) end
    return false, nil
end

function M:EvidenceBlocker(action, state, descriptor, tooltip, actionStart)
    local blocker, handled
    if MageShield then
        blocker, handled = MageShield:Blocker(action, state, tooltip)
        if handled then return blocker, true end
    end
    if PriestShield then
        blocker, handled = PriestShield:Blocker(action, state, descriptor)
        if handled then return blocker, true end
    end
    if RogueFeintGraph then
        blocker, handled = RogueFeintGraph:Blocker(
            action, state, descriptor, tooltip)
        if handled then return blocker, true end
    end
    if HunterMarkGraph then
        blocker, handled = HunterMarkGraph:Blocker(
            action, state, descriptor, tooltip, actionStart)
        if handled then return blocker, true end
    end
    return nil, false
end

function M:ApplyExactAura(state, candidate)
    return HunterMarkGraph and HunterMarkGraph:Apply(state, candidate) or false
end

function M:ApplyExactAbsorb(state, target, candidate)
    if not (MageShield and MageShield:Is(candidate and candidate.action)) then
        return false
    end
    local entry = MageShield:Entry(candidate)
    if not entry then return true end
    local recipient = target or state
    recipient.absorbs = recipient.absorbs or {}
    recipient.absorbs[candidate.action.name] = entry
    return true
end

function M:AfterAbsorb(state, candidate)
    if PriestShield and PriestShield:Is(candidate and candidate.action) then
        return PriestShield:Apply(state, candidate)
    end
    return false
end

function M:AbsorbCapacity(context)
    if MageShield and MageShield:Is(context and context.action) then
        return MageShield:EffectiveCapacity(context, context.state)
    end
    return nil
end

-- Exact lifecycle evidence still cannot be converted into utility. A later
-- consequence-specific scorer must own magnitude, recipients, and timing.
function M:Score(context, projection)
    if not (context and projection and projection.classMechanic) then
        return false, "class mechanic projection unavailable"
    end
    if PaladinBlessingThreat then
        local scored, reason = PaladinBlessingThreat:Score(context, projection)
        if scored or reason then return scored, reason end
    end
    if Windfury then
        local scored, reason = Windfury:Score(context, projection)
        if scored or reason then return scored, reason end
    end
    return false, "exact class mechanic consequence scoring unavailable"
end

function M:Apply(state, candidate)
    local projection = candidate and candidate.classMechanicProjection
    if not projection then return false end
    if projection.classMechanic == "paladin" and Paladin then
        if not Paladin:Apply(state, projection) then return false end
        if projection.paladinBlessingThreat then
            return PaladinBlessingThreat
                and PaladinBlessingThreat:Apply(state, projection) or false
        end
        return true
    elseif projection.classMechanic == "shaman" and Totems then
        if not Totems:Apply(state, projection) then return false end
        if projection.shamanWindfuryTotem then
            return Windfury and Windfury:Apply(state, projection) or false
        end
        return true
    end
    return false
end

function M:Advance(state, elapsed)
    if Totems then return Totems:Advance(state, elapsed) end
    return 0
end
