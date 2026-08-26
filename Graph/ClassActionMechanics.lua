-- Identity-only dispatch for exact class action mechanics. This table never
-- orders recommendations: at most one sealed mechanic may claim an action,
-- and ambiguous evidence fails closed before any consequence is scored.
XelAssist.Graph.ClassActionMechanics = {}
local A = XelAssist.Graph.ClassActionMechanics

local BattleShout = XelAssist.Graph.WarriorBattleShout
local ShieldWall = XelAssist.Graph.WarriorShieldWall
local FelDomination = XelAssist.Graph.WarlockFelDomination
local Hawk = XelAssist.Graph.HunterHawk
local InnerFocus = XelAssist.Graph.PriestInnerFocus
local PowerInfusion = XelAssist.Graph.PriestPowerInfusion
local PresenceOfMind = XelAssist.Graph.MagePresenceOfMind
local ColdSnap = XelAssist.Graph.MageColdSnap
local FrenziedRegeneration = XelAssist.Graph.DruidFrenziedRegeneration
local RoguePreparation = XelAssist.Graph.RoguePreparation

local handlers = {
    {
        name = "Druid Frenzied Regeneration",
        module = FrenziedRegeneration,
        claims = function(facts)
            return facts.druidFrenziedRegeneration == true
                or facts.requiresExactDruidFrenziedRegeneration == true
                or facts.druidFrenziedRegenerationTransition ~= nil
        end,
        matches = function(projection)
            return projection.druidFrenziedRegenerationTransition ~= nil
        end,
        prepare = function(module, action, state, descriptor, facts)
            return module:Prepare(action, state, descriptor, facts)
        end,
    },
    {
        name = "Rogue Preparation", module = RoguePreparation,
        needsActionStart = true,
        claims = function(facts)
            return facts.roguePreparation == true
                or facts.requiresRoguePreparationEvidence == true
                or facts.roguePreparationTransition ~= nil
        end,
        matches = function(projection)
            return projection.roguePreparationTransition ~= nil
        end,
        prepare = function(module, action, state, _, facts, actionStart)
            return module:Prepare(action, state, facts, actionStart)
        end,
    },
    {
        name = "Warlock Fel Domination", module = FelDomination,
        claims = function(facts)
            return facts.warlockFelDomination == true
                or facts.requiresWarlockFelDominationEvidence == true
                or facts.warlockFelDominationTransition ~= nil
        end,
        matches = function(projection)
            return projection.warlockFelDominationTransition ~= nil
        end,
        prepare = function(module, action, state, _, facts)
            return module:PrepareSetup(action, state, facts)
        end,
    },
    {
        name = "Mage Cold Snap", module = ColdSnap,
        claims = function(facts)
            return facts.mageColdSnap == true
                or facts.mageColdSnapTransition ~= nil
        end,
        matches = function(projection)
            return projection.mageColdSnapTransition ~= nil
        end,
        prepare = function(module, action, state, _, facts)
            return module:Prepare(action, state, facts)
        end,
    },
    {
        name = "Mage Presence of Mind", module = PresenceOfMind,
        claims = function(facts)
            return facts.magePresenceOfMind == true
                or facts.magePresenceOfMindTransition ~= nil
        end,
        matches = function(projection)
            return projection.magePresenceOfMindTransition ~= nil
        end,
        prepare = function(module, action, state, _, facts)
            return module:PrepareSetup(action, state, facts)
        end,
    },
    {
        name = "Hunter Hawk", module = Hawk,
        claims = function(facts)
            return facts.hunterHawk == true
                or facts.requiresExactHunterHawkDownstream == true
        end,
        matches = function(projection)
            return projection.hunterHawk == true
        end,
        prepare = function(module, action, state, descriptor, facts)
            return module:Prepare(action, state, descriptor, facts)
        end,
    },
    {
        name = "Priest Inner Focus", module = InnerFocus,
        claims = function(facts)
            return facts.priestInnerFocus == true
                or facts.priestInnerFocusTransition ~= nil
        end,
        matches = function(projection)
            return projection.priestInnerFocusTransition ~= nil
        end,
        prepare = function(module, action, state, _, facts)
            return module:PrepareSetup(action, state, facts)
        end,
    },
    {
        name = "Priest Power Infusion", module = PowerInfusion,
        claims = function(facts)
            return facts.priestPowerInfusion == true
                or facts.priestPowerInfusionTransition ~= nil
        end,
        matches = function(projection)
            return projection.priestPowerInfusionTransition ~= nil
        end,
        prepare = function(module, action, state, descriptor, facts)
            return module:Prepare(action, state, descriptor, facts)
        end,
    },
    {
        name = "Warrior Shield Wall", module = ShieldWall,
        claims = function(facts)
            return facts.warriorShieldWall == true
                or facts.requiresExactWarriorShieldWall == true
                or facts.warriorShieldWallTransition ~= nil
        end,
        matches = function(projection)
            return projection.warriorShieldWallTransition ~= nil
        end,
        prepare = function(module, action, state, descriptor, facts)
            return module:Prepare(action, state, descriptor, facts)
        end,
    },
    {
        name = "Warrior Battle Shout", module = BattleShout,
        claims = function(facts)
            return facts.warriorBattleShout == true
                or facts.requiresExactBattleShoutDownstream == true
        end,
        matches = function(projection)
            return projection.classMechanic == "warriorBattleShout"
        end,
        prepare = function(module, action, state, descriptor, facts)
            return module:Prepare(action, state, descriptor, facts)
        end,
    },
}

local function selectClaim(facts, actionFacts)
    local selected, count, index = nil, 0, nil
    for index = 1, table.getn(handlers) do
        local handler = handlers[index]
        if handler.claims(facts) or handler.claims(actionFacts) then
            selected, count = handler, count + 1
        end
    end
    if count > 1 then
        return nil, "ambiguous exact class mechanic evidence", true
    end
    return selected, nil, count == 1
end

local function selectProjection(projection)
    local selected, count, index = nil, 0, nil
    for index = 1, table.getn(handlers) do
        local handler = handlers[index]
        if handler.matches(projection) then
            selected, count = handler, count + 1
        end
    end
    if count ~= 1 then return nil end
    return selected
end

function A:Prepare(action, state, descriptor, facts, actionStart)
    local actionFacts = action and action.facts or {}
    facts = facts or actionFacts
    local handler, reason, handled = selectClaim(facts, actionFacts)
    if not handled then return nil, reason, false end
    if not handler then return nil, reason, true end
    if handler.needsActionStart and actionStart == nil then
        return nil, nil, false
    end
    if not handler.module then
        return nil, handler.name .. " graph unavailable", true
    end
    return handler.prepare(
        handler.module, action, state, descriptor, facts, actionStart)
end

function A:Score(context, projection)
    local handler = projection and selectProjection(projection)
    if not (handler and handler.module) then
        return false, nil, false
    end
    local scored, reason = handler.module:Score(context, projection)
    return scored, reason, true
end

function A:Apply(state, candidate)
    local projection = candidate and candidate.classMechanicProjection
    local handler = projection and selectProjection(projection)
    if not (handler and handler.module) then return false end
    return handler.module:Apply(state, candidate)
end

function A:Advance(state, elapsed)
    if FrenziedRegeneration then
        FrenziedRegeneration:Advance(state, elapsed)
    end
    if BattleShout then BattleShout:Advance(state, elapsed) end
    if ShieldWall then ShieldWall:Advance(state, elapsed) end
    if FelDomination then FelDomination:Advance(state, elapsed) end
end

function A:RootBlocker(state)
    if not FrenziedRegeneration then return nil, false end
    return FrenziedRegeneration:RootBlocker(state)
end

function A:EvidenceBlocker(action, state, descriptor, tooltip)
    if not BattleShout then return nil, false end
    return BattleShout:Blocker(action, state, descriptor, tooltip)
end
