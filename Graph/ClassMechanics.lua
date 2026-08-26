-- Exact Paladin/Shaman graph boundary. Mutable APIs are confined to Attach;
-- branch preparation consumes only copied action facts and projected state.
-- Lifecycle alone never supplies combat value or a preferred action order.
XelAssist.Graph.ClassMechanics = {}
local M = XelAssist.Graph.ClassMechanics
local Paladin = XelAssist.Graph.PaladinAuraProjection
local PaladinActions = XelAssist.Game.Player.PaladinActions
local PaladinRighteousness = XelAssist.Graph.PaladinRighteousness
local PaladinMight = XelAssist.Graph.PaladinMight
local PaladinWisdom = XelAssist.Graph.PaladinWisdom
local PaladinBlessingThreat = XelAssist.Graph.PaladinBlessingThreat
local PaladinRighteousFury = XelAssist.Graph.PaladinRighteousFury
local Totems = XelAssist.Game.Player.TotemState
local ShamanActions = XelAssist.Game.Player.ShamanActions
local RogueSlice = XelAssist.Graph.RogueSliceAndDice
local PriestFade = XelAssist.Graph.PriestFade
local Windfury = XelAssist.Graph.ShamanWindfuryTotem
local ManaSpring = XelAssist.Graph.ShamanManaSpring
local EarthShock = XelAssist.Graph.ShamanEarthShock
local ActionMechanics = XelAssist.Graph.ClassActionMechanics
local Evidence = XelAssist.Graph.ClassEvidence
local ClassState = XelAssist.Graph.ClassState

local function mergeActionFacts(action, captured)
    local facts, key, value = {}, nil, nil
    for key, value in pairs(action and action.facts or {}) do
        facts[key] = value
    end
    for key, value in pairs(captured or {}) do facts[key] = value end
    return facts
end

function M:Attach(state)
    return ClassState and ClassState:Attach(state) or false
end

function M:Copy(source, target)
    return ClassState and ClassState:Copy(source, target) or false
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

local function paladinProjection(action, state, descriptor, facts)
    facts = mergeActionFacts(action, facts)
    if not (facts.paladinAction == true
        and type(facts.paladinClassification) == "table"
        and facts.paladinClassification.exact == true) then
        return nil, "captured Paladin action classification unavailable", true
    end
    local outcome = facts.paladinDownstreamOutcome
    if PaladinRighteousness then
        local exact, reason, handled = PaladinRighteousness:Outcome(
            action, state, descriptor, facts)
        if handled then
            if not exact then return nil, reason, true end
            outcome = exact
        end
    end
    if PaladinRighteousFury then
        local exact, reason, handled = PaladinRighteousFury:Prepare(
            action, state, descriptor, facts.paladinDownstreamEffect)
        if handled then return exact, reason, true end
    end
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
    if PaladinRighteousness then
        local prepared
        prepared, reason, handled = PaladinRighteousness:Prepare(
            state, projection, facts)
        if handled then
            if not prepared then return nil, reason, true end
            projection = prepared
        end
    end
    if PaladinBlessingThreat then
        local prepared
        prepared, reason, handled = PaladinBlessingThreat:Prepare(
            state, projection)
        if handled then
            if not prepared then return nil, reason, true end
            projection = prepared
        end
    end
    if PaladinMight then
        local prepared
        prepared, reason, handled = PaladinMight:Prepare(
            state, projection, facts)
        if handled then
            if not prepared then return nil, reason, true end
            projection = prepared
        end
    end
    if PaladinWisdom then
        local prepared
        prepared, reason, handled = PaladinWisdom:Prepare(
            state, projection, facts)
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
    if ManaSpring then
        local prepared, handled
        prepared, reason, handled = ManaSpring:Prepare(state, projection)
        if handled then
            if not prepared then return nil, reason, true end
            projection = prepared
        end
    end
    projection.classMechanic = "shaman"
    return projection, nil, true
end

function M:Prepare(action, state, descriptor, tooltip, actionStart)
    local actionFacts = action and action.facts or {}
    local facts = tooltip or actionFacts
    if ActionMechanics then
        local blocker, handled = ActionMechanics:RootBlocker(state)
        if handled and blocker then return nil, blocker, true end
        local projection, reason, handled = ActionMechanics:Prepare(
            action, state, descriptor, facts, actionStart)
        if handled then return projection, reason, true end
    end
    if paladinClaimed(actionFacts) or paladinClaimed(facts) then
        if not (Paladin and PaladinActions) then
            return nil, "Paladin graph mechanic unavailable", true
        end
        return paladinProjection(action, state, descriptor, facts)
    elseif shamanClaimed(actionFacts) or shamanClaimed(facts) then
        if not (Totems and ShamanActions) then
            return nil, "Shaman graph mechanic unavailable", true
        end
        return shamanProjection(action, state)
    end
    return nil, nil, false
end

function M:Blocker(action, state, descriptor, tooltip, actionStart)
    local projection, reason, handled = self:Prepare(
        action, state, descriptor, tooltip, actionStart)
    if not handled then return nil, false end
    if not projection then return reason or "class mechanic unavailable", true end
    return nil, true, projection
end

-- Shield discovery is class-specific, but its projected absorb remains a
-- normal graph consequence. Mutable modifier and aura reads are captured only
-- while the root observation is open; descendants consume sealed evidence.
function M:CaptureFacts(action, facts, state)
    return Evidence and Evidence:CaptureFacts(action, facts, state) or facts
end

function M:AuraActive(action, state, descriptor, tooltip, lead)
    if not Evidence then return nil, false end
    return Evidence:AuraActive(action, state, descriptor, tooltip, lead)
end

function M:CaptureRecipient(observed, action, descriptor)
    if not Evidence then return false, nil end
    return Evidence:CaptureRecipient(observed, action, descriptor)
end

function M:EvidenceBlocker(action, state, descriptor, tooltip, actionStart)
    if not Evidence then return nil, false end
    local blocker, handled = Evidence:Blocker(
        action, state, descriptor, tooltip, actionStart)
    if handled then return blocker, true end
    if ActionMechanics then
        blocker, handled = ActionMechanics:EvidenceBlocker(
            action, state, descriptor, tooltip)
        if handled then return blocker, true end
    end
    return nil, false
end

function M:ApplyExactAura(state, candidate)
    return Evidence and Evidence:ApplyExactAura(state, candidate) or false
end

function M:ApplyExactAbsorb(state, target, candidate)
    return Evidence
        and Evidence:ApplyExactAbsorb(state, target, candidate) or false
end

function M:AfterAbsorb(state, candidate)
    return Evidence and Evidence:AfterAbsorb(state, candidate) or false
end

function M:AbsorbCapacity(context)
    return Evidence and Evidence:AbsorbCapacity(context) or nil
end

-- Exact lifecycle evidence still cannot be converted into utility. A later
-- consequence-specific scorer must own magnitude, recipients, and timing.
function M:Score(context, projection)
    if not (context and projection and projection.classMechanic) then
        return false, "class mechanic projection unavailable"
    end
    if PaladinMight and projection.paladinMightTransition then
        return PaladinMight:Score(context, projection)
    end
    if PaladinRighteousness
        and projection.paladinRighteousnessTransition then
        return PaladinRighteousness:Score(context, projection)
    end
    if PaladinWisdom and projection.paladinWisdomTransition then
        local scored, reason = PaladinWisdom:Score(context, projection)
        if scored or reason then return scored, reason end
    end
    if PaladinBlessingThreat then
        local scored, reason = PaladinBlessingThreat:Score(context, projection)
        if scored or reason then return scored, reason end
    end
    if PaladinRighteousFury then
        local scored, reason = PaladinRighteousFury:Score(context, projection)
        if scored or reason then return scored, reason end
    end
    if Windfury then
        local scored, reason = Windfury:Score(context, projection)
        if scored or reason then return scored, reason end
    end
    if ManaSpring then
        local scored, reason = ManaSpring:Score(context, projection)
        if scored or reason then return scored, reason end
    end
    if ActionMechanics then
        local scored, reason, handled = ActionMechanics:Score(
            context, projection)
        if handled then return scored, reason end
    end
    return false, "exact class mechanic consequence scoring unavailable"
end

function M:Apply(state, candidate)
    local projection = candidate and candidate.classMechanicProjection
    if not projection then return false end
    if projection.classMechanic == "paladin" and Paladin then
        if projection.paladinRighteousFury then
            return PaladinRighteousFury
                and PaladinRighteousFury:Apply(state, candidate) or false
        end
        if not Paladin:Apply(state, projection) then return false end
        if projection.paladinRighteousnessTransition then
            return PaladinRighteousness
                and PaladinRighteousness:Apply(state, candidate) or false
        end
        if projection.paladinBlessingThreat then
            if not (PaladinBlessingThreat
                and PaladinBlessingThreat:Apply(state, projection)) then
                return false
            end
        end
        if projection.paladinMightTransition then
            if not (PaladinMight
                and PaladinMight:Apply(state, projection)) then return false end
        end
        if projection.paladinWisdomTransition then
            if not (PaladinWisdom
                and PaladinWisdom:Apply(state, projection)) then return false end
        end
        return true
    elseif projection.classMechanic == "shaman" and Totems then
        if not Totems:Apply(state, projection) then return false end
        if projection.shamanManaSpring then
            if not (ManaSpring and ManaSpring:Apply(state, projection)) then
                return false
            end
        end
        if projection.shamanWindfuryTotem then
            return Windfury and Windfury:Apply(state, projection) or false
        end
        return true
    end
    return ActionMechanics and ActionMechanics:Apply(state, candidate) or false
end

function M:Advance(state, elapsed)
    if EarthShock then EarthShock:Advance(state, elapsed) end
    if ManaSpring then ManaSpring:Advance(state, elapsed) end
    local expired = Totems and Totems:Advance(state, elapsed) or 0
    if RogueSlice then RogueSlice:Advance(state, elapsed) end
    if PaladinMight then PaladinMight:Advance(state, elapsed) end
    if PaladinWisdom then PaladinWisdom:Advance(state, elapsed) end
    if PriestFade then PriestFade:Advance(state, elapsed) end
    if ActionMechanics then ActionMechanics:Advance(state, elapsed) end
    return expired
end
