-- Exact Paladin/Shaman graph boundary. Mutable APIs are confined to Attach;
-- branch preparation consumes only copied action facts and projected state.
-- Lifecycle alone never supplies combat value or a preferred action order.
XelAssist.Graph.ClassMechanics = {}
local M = XelAssist.Graph.ClassMechanics
local Paladin = XelAssist.Graph.PaladinAuraProjection
local PaladinActions = XelAssist.Game.Player.PaladinActions
local PaladinMight = XelAssist.Graph.PaladinMight
local PaladinWisdom = XelAssist.Graph.PaladinWisdom
local PaladinBlessingThreat = XelAssist.Graph.PaladinBlessingThreat
local PaladinRighteousFury = XelAssist.Graph.PaladinRighteousFury
local Totems = XelAssist.Game.Player.TotemState
local ShamanActions = XelAssist.Game.Player.ShamanActions
local RogueSlice = XelAssist.Graph.RogueSliceAndDice
local HunterHawk = XelAssist.Graph.HunterHawk
local PriestInnerFocus = XelAssist.Graph.PriestInnerFocus
local PriestPowerInfusion = XelAssist.Graph.PriestPowerInfusion
local PriestFade = XelAssist.Graph.PriestFade
local MagePresenceOfMind = XelAssist.Graph.MagePresenceOfMind
local MageColdSnap = XelAssist.Graph.MageColdSnap
local Windfury = XelAssist.Graph.ShamanWindfuryTotem
local ManaSpring = XelAssist.Graph.ShamanManaSpring
local WarriorBattleShout = XelAssist.Graph.WarriorBattleShout
local WarriorShieldWall = XelAssist.Graph.WarriorShieldWall
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

local function warriorClaimed(facts)
    return facts.warriorBattleShout == true
        or facts.requiresExactBattleShoutDownstream == true
end

local function warriorShieldWallClaimed(facts)
    return facts.warriorShieldWall == true
        or facts.requiresExactWarriorShieldWall == true
        or facts.warriorShieldWallTransition ~= nil
end

local function hunterHawkClaimed(facts)
    return facts.hunterHawk == true
        or facts.requiresExactHunterHawkDownstream == true
end

local function priestInnerFocusClaimed(facts)
    return facts.priestInnerFocus == true
        or facts.priestInnerFocusTransition ~= nil
end

local function priestPowerInfusionClaimed(facts)
    return facts.priestPowerInfusion == true
        or facts.priestPowerInfusionTransition ~= nil
end

local function magePresenceOfMindClaimed(facts)
    return facts.magePresenceOfMind == true
        or facts.magePresenceOfMindTransition ~= nil
end

local function mageColdSnapClaimed(facts)
    return facts.mageColdSnap == true
        or facts.mageColdSnapTransition ~= nil
end

local function paladinProjection(action, state, descriptor, facts)
    facts = mergeActionFacts(action, facts)
    if not (facts.paladinAction == true
        and type(facts.paladinClassification) == "table"
        and facts.paladinClassification.exact == true) then
        return nil, "captured Paladin action classification unavailable", true
    end
    local outcome = facts.paladinDownstreamOutcome
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

function M:Prepare(action, state, descriptor, tooltip)
    local actionFacts = action and action.facts or {}
    local facts = tooltip or actionFacts
    if mageColdSnapClaimed(facts) or mageColdSnapClaimed(actionFacts) then
        if not MageColdSnap then
            return nil, "Mage Cold Snap graph unavailable", true
        end
        return MageColdSnap:Prepare(action, state, facts)
    elseif magePresenceOfMindClaimed(facts)
        or magePresenceOfMindClaimed(actionFacts) then
        if not MagePresenceOfMind then
            return nil, "Mage Presence of Mind graph unavailable", true
        end
        return MagePresenceOfMind:PrepareSetup(action, state, facts)
    elseif hunterHawkClaimed(facts) or hunterHawkClaimed(actionFacts) then
        if not HunterHawk then
            return nil, "Hunter Hawk graph unavailable", true
        end
        return HunterHawk:Prepare(action, state, descriptor, facts)
    elseif priestInnerFocusClaimed(facts)
        or priestInnerFocusClaimed(actionFacts) then
        if not PriestInnerFocus then
            return nil, "Priest Inner Focus graph unavailable", true
        end
        return PriestInnerFocus:PrepareSetup(action, state, facts)
    elseif priestPowerInfusionClaimed(facts)
        or priestPowerInfusionClaimed(actionFacts) then
        if not PriestPowerInfusion then
            return nil, "Priest Power Infusion graph unavailable", true
        end
        return PriestPowerInfusion:Prepare(
            action, state, descriptor, facts)
    elseif warriorShieldWallClaimed(facts)
        or warriorShieldWallClaimed(actionFacts) then
        if not WarriorShieldWall then
            return nil, "Warrior Shield Wall graph unavailable", true
        end
        return WarriorShieldWall:Prepare(action, state, descriptor, facts)
    elseif warriorClaimed(facts) or warriorClaimed(actionFacts) then
        if not WarriorBattleShout then
            return nil, "Warrior Battle Shout graph unavailable", true
        end
        return WarriorBattleShout:Prepare(
            action, state, descriptor, facts)
    elseif paladinClaimed(actionFacts) or paladinClaimed(facts) then
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

function M:Blocker(action, state, descriptor, tooltip)
    local projection, reason, handled = self:Prepare(
        action, state, descriptor, tooltip)
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
    if WarriorBattleShout then
        blocker, handled = WarriorBattleShout:Blocker(
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
    if MageColdSnap and projection.mageColdSnapTransition then
        return MageColdSnap:Score(context, projection)
    end
    if MagePresenceOfMind and projection.magePresenceOfMindTransition then
        return MagePresenceOfMind:Score(context, projection)
    end
    if PriestPowerInfusion
        and projection.priestPowerInfusionTransition then
        return PriestPowerInfusion:Score(context, projection)
    end
    if PaladinMight and projection.paladinMightTransition then
        return PaladinMight:Score(context, projection)
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
    if PriestInnerFocus and projection.priestInnerFocusTransition then
        return PriestInnerFocus:Score(context, projection)
    end
    if HunterHawk and projection.hunterHawk then
        return HunterHawk:Score(context, projection)
    end
    if WarriorBattleShout then
        local scored, reason = WarriorBattleShout:Score(context, projection)
        if scored or reason then return scored, reason end
    end
    if WarriorShieldWall and projection.warriorShieldWallTransition then
        return WarriorShieldWall:Score(context, projection)
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
    elseif projection.classMechanic == "warriorBattleShout"
        and WarriorBattleShout then
        return WarriorBattleShout:Apply(state, candidate)
    elseif projection.classMechanic == "warriorShieldWall"
        and WarriorShieldWall then
        return WarriorShieldWall:Apply(state, candidate)
    elseif projection.mageColdSnapTransition and MageColdSnap then
        return MageColdSnap:Apply(state, candidate)
    elseif projection.magePresenceOfMindTransition
        and MagePresenceOfMind then
        return MagePresenceOfMind:Apply(state, candidate)
    elseif projection.priestPowerInfusionTransition
        and PriestPowerInfusion then
        return PriestPowerInfusion:Apply(state, candidate)
    elseif projection.priestInnerFocusTransition and PriestInnerFocus then
        return PriestInnerFocus:Apply(state, candidate)
    elseif projection.hunterHawk and HunterHawk then
        return HunterHawk:Apply(state, candidate)
    end
    return false
end

function M:Advance(state, elapsed)
    if ManaSpring then ManaSpring:Advance(state, elapsed) end
    local expired = Totems and Totems:Advance(state, elapsed) or 0
    if RogueSlice then RogueSlice:Advance(state, elapsed) end
    if WarriorBattleShout then WarriorBattleShout:Advance(state, elapsed) end
    if PaladinMight then PaladinMight:Advance(state, elapsed) end
    if PaladinWisdom then PaladinWisdom:Advance(state, elapsed) end
    if PriestFade then PriestFade:Advance(state, elapsed) end
    if WarriorShieldWall then WarriorShieldWall:Advance(state, elapsed) end
    return expired
end
