-- Exact Paladin/Shaman graph boundary. Mutable APIs are confined to Attach;
-- branch preparation consumes only copied action facts and projected state.
-- Lifecycle alone never supplies combat value or a preferred action order.
XelAssist.Graph.ClassMechanics = {}
local M = XelAssist.Graph.ClassMechanics
local Paladin = XelAssist.Graph.PaladinAuraProjection
local PaladinActions = XelAssist.Game.Player.PaladinActions
local PaladinBlessingThreat = XelAssist.Graph.PaladinBlessingThreat
local PaladinRighteousFury = XelAssist.Graph.PaladinRighteousFury
local Totems = XelAssist.Game.Player.TotemState
local ShamanActions = XelAssist.Game.Player.ShamanActions
local MageClearcastingRuntime = XelAssist.Game.Player.MageClearcasting
local MageClearcasting = XelAssist.Graph.MageClearcasting
local RogueSlice = XelAssist.Graph.RogueSliceAndDice
local HunterMarkGraph = XelAssist.Graph.HunterMark
local HunterHawk = XelAssist.Graph.HunterHawk
local PriestShadowform = XelAssist.Graph.PriestShadowform
local Windfury = XelAssist.Graph.ShamanWindfuryTotem
local WarriorBattleShout = XelAssist.Graph.WarriorBattleShout
local Evidence = XelAssist.Graph.ClassEvidence

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
        if PaladinRighteousFury then PaladinRighteousFury:Attach(state) end
        return attached
    elseif token == "SHAMAN" and Totems then
        state.totems = Totems:Snapshot()
        local attached = state.totems and state.totems.available == true or false
        if Windfury then Windfury:Attach(state) end
        return attached
    elseif token == "HUNTER" then
        local mark = HunterMarkGraph and HunterMarkGraph:Attach(state)
        local hawk = HunterHawk and HunterHawk:Attach(state) or false
        return mark ~= nil or hawk
    elseif token == "PRIEST" and PriestShadowform then
        return PriestShadowform:Attach(state, token)
    elseif token == "MAGE" and MageClearcastingRuntime then
        return MageClearcastingRuntime:Attach(state, token)
    elseif token == "ROGUE" and RogueSlice then
        return RogueSlice:Attach(state) ~= nil
    elseif token == "WARRIOR" and WarriorBattleShout then
        return WarriorBattleShout:Attach(state)
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
    if PaladinRighteousFury then PaladinRighteousFury:Copy(source, target) end
    if source.totems then target.totems = copy(source.totems, 7) end
    if source.hunterMarkRoot then target.hunterMarkRoot = source.hunterMarkRoot end
    if HunterHawk then HunterHawk:Copy(source, target) end
    if MageClearcasting then MageClearcasting:Copy(source, target) end
    if RogueSlice then RogueSlice:Copy(source, target) end
    if PriestShadowform then PriestShadowform:Copy(source, target) end
    if Windfury then Windfury:Copy(source, target) end
    if WarriorBattleShout then WarriorBattleShout:Copy(source, target) end
    return source.paladinAuraState ~= nil
        or source.paladinBlessingThreat ~= nil or source.totems ~= nil
        or source.paladinRighteousFury ~= nil
        or source.hunterMarkRoot ~= nil
        or source.hunterHawk ~= nil
        or source.mageClearcasting ~= nil
        or source.rogueSliceAndDice ~= nil
        or source.playerShadowformProfileExact == true
        or source.shamanWindfuryTotem ~= nil
        or source.warriorBattleShout ~= nil
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

local function hunterHawkClaimed(facts)
    return facts.hunterHawk == true
        or facts.requiresExactHunterHawkDownstream == true
end

local function paladinProjection(action, state, descriptor)
    local facts = action.facts or {}
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

function M:Prepare(action, state, descriptor, tooltip)
    local actionFacts = action and action.facts or {}
    local facts = tooltip or actionFacts
    if hunterHawkClaimed(facts) or hunterHawkClaimed(actionFacts) then
        if not HunterHawk then
            return nil, "Hunter Hawk graph unavailable", true
        end
        return HunterHawk:Prepare(action, state, descriptor, facts)
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
        return paladinProjection(action, state, descriptor)
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
    if HunterHawk and projection.hunterHawk then
        return HunterHawk:Score(context, projection)
    end
    if WarriorBattleShout then
        local scored, reason = WarriorBattleShout:Score(context, projection)
        if scored or reason then return scored, reason end
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
    elseif projection.classMechanic == "warriorBattleShout"
        and WarriorBattleShout then
        return WarriorBattleShout:Apply(state, candidate)
    elseif projection.hunterHawk and HunterHawk then
        return HunterHawk:Apply(state, candidate)
    end
    return false
end

function M:Advance(state, elapsed)
    local expired = Totems and Totems:Advance(state, elapsed) or 0
    if RogueSlice then RogueSlice:Advance(state, elapsed) end
    if WarriorBattleShout then WarriorBattleShout:Advance(state, elapsed) end
    return expired
end
