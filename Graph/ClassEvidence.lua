-- Root-captured class evidence and exact support-effect boundaries. This module
-- owns no class action ordering; it only seals mutable facts and delegates
-- blockers or transitions to the mechanic that can prove the consequence.
XelAssist.Graph.ClassEvidence = {}
local E = XelAssist.Graph.ClassEvidence
local PaladinRighteousFury = XelAssist.Game.Player.PaladinRighteousFury
local MageShield = XelAssist.Game.Player.MageManaShield
local MageClearcasting = XelAssist.Game.Player.MageClearcasting
local ShamanClearcasting = XelAssist.Game.Player.ShamanClearcasting
local PriestShield = XelAssist.Game.Player.PriestShield
local RogueFeint = XelAssist.Game.Player.RogueFeint
local RogueFeintGraph = XelAssist.Graph.RogueFeint
local RogueSliceRuntime = XelAssist.Game.Player.RogueSliceAndDice
local RogueSlice = XelAssist.Graph.RogueSliceAndDice
local HunterMark = XelAssist.Game.Player.HunterMark
local HunterMarkGraph = XelAssist.Graph.HunterMark
local HunterHawk = XelAssist.Game.Player.HunterHawk
local PriestShadowform = XelAssist.Game.Player.PriestShadowform
local PriestInnerFocusRuntime = XelAssist.Game.Player.PriestInnerFocus
local WarriorBattleShout = XelAssist.Game.Player.WarriorBattleShout
local WarriorRevengeThreat = XelAssist.Graph.WarriorRevengeThreat
local WarlockDarkPactRuntime = XelAssist.Game.Player.WarlockDarkPact
local WarlockDarkPact = XelAssist.Graph.WarlockDarkPact

function E:CaptureFacts(action, facts, state)
    local out = facts
    if PaladinRighteousFury then
        out = PaladinRighteousFury:CaptureFacts(action, out)
    end
    if MageShield then out = MageShield:CaptureFacts(action, out) end
    if MageClearcasting then
        out = MageClearcasting:CaptureFacts(action, out, state)
    end
    if ShamanClearcasting then
        out = ShamanClearcasting:CaptureFacts(action, out, state)
    end
    if RogueFeint then out = RogueFeint:CaptureFacts(action, out) end
    if RogueSliceRuntime then out = RogueSliceRuntime:CaptureFacts(action, out) end
    if WarriorBattleShout then
        out = WarriorBattleShout:CaptureFacts(action, out)
    end
    if WarlockDarkPactRuntime then
        out = WarlockDarkPactRuntime:CaptureFacts(action, out)
    end
    if HunterMark then out = HunterMark:CaptureFacts(action, out) end
    if HunterHawk then out = HunterHawk:CaptureFacts(action, out) end
    if PriestShadowform then
        out = PriestShadowform:CaptureFacts(action, out)
    end
    if PriestInnerFocusRuntime then
        out = PriestInnerFocusRuntime:CaptureFacts(action, out, state)
    end
    return out
end

function E:AuraActive(action, state, descriptor, tooltip, lead)
    if not HunterMarkGraph then return nil, false end
    return HunterMarkGraph:AuraActive(
        action, state, descriptor, tooltip, lead)
end

function E:CaptureRecipient(observed, action, descriptor)
    if PriestShield then return PriestShield:Capture(observed, action, descriptor) end
    return false, nil
end

function E:Blocker(action, state, descriptor, tooltip, actionStart)
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
    if RogueSlice then
        blocker, handled = RogueSlice:Blocker(
            action, state, descriptor, tooltip)
        if handled then return blocker, true end
    end
    if WarriorRevengeThreat then
        blocker, handled = WarriorRevengeThreat:Blocker(
            action, state, descriptor)
        if handled then return blocker, true end
    end
    if WarlockDarkPact then
        blocker, handled = WarlockDarkPact:Blocker(
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

function E:ApplyExactAura(state, candidate)
    if RogueSlice and RogueSlice:Apply(state, candidate) then return true end
    return HunterMarkGraph and HunterMarkGraph:Apply(state, candidate) or false
end

function E:ApplyExactAbsorb(state, target, candidate)
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

function E:AfterAbsorb(state, candidate)
    if PriestShield and PriestShield:Is(candidate and candidate.action) then
        return PriestShield:Apply(state, candidate)
    end
    return false
end

function E:AbsorbCapacity(context)
    if MageShield and MageShield:Is(context and context.action) then
        return MageShield:EffectiveCapacity(context, context.state)
    end
    return nil
end
