-- Root-captured class evidence and exact support-effect boundaries. This module
-- owns no class action ordering; it only seals mutable facts and delegates
-- blockers or transitions to the mechanic that can prove the consequence.
XelAssist.Graph.ClassEvidence = {}
local E = XelAssist.Graph.ClassEvidence
local PaladinRighteousFury = XelAssist.Game.Player.PaladinRighteousFury
local PaladinRighteousness = XelAssist.Game.Player.PaladinRighteousness
local PaladinMight = XelAssist.Game.Player.PaladinMight
local PaladinWisdom = XelAssist.Game.Player.PaladinWisdom
local MageShield = XelAssist.Game.Player.MageManaShield
local MageClearcasting = XelAssist.Game.Player.MageClearcasting
local MagePresenceOfMind = XelAssist.Game.Player.MagePresenceOfMind
local MageColdSnap = XelAssist.Game.Player.MageColdSnap
local DruidClearcasting = XelAssist.Game.Player.DruidClearcasting
local DruidFrenziedRegeneration =
    XelAssist.Game.Player.DruidFrenziedRegeneration
local ShamanClearcasting = XelAssist.Game.Player.ShamanClearcasting
local ShamanManaSpring = XelAssist.Game.Player.ShamanManaSpring
local ShamanEarthShockRuntime = XelAssist.Game.Player.ShamanEarthShock
local ShamanEarthShock = XelAssist.Graph.ShamanEarthShock
local PriestShield = XelAssist.Game.Player.PriestShield
local RogueFeint = XelAssist.Game.Player.RogueFeint
local RogueFeintGraph = XelAssist.Graph.RogueFeint
local RogueSliceRuntime = XelAssist.Game.Player.RogueSliceAndDice
local RogueSlice = XelAssist.Graph.RogueSliceAndDice
local RogueRuthlessness = XelAssist.Game.Player.RogueRuthlessness
local RoguePreparation = XelAssist.Game.Player.RoguePreparation
local HunterMark = XelAssist.Game.Player.HunterMark
local HunterMarkGraph = XelAssist.Graph.HunterMark
local HunterHawk = XelAssist.Game.Player.HunterHawk
local HunterDistractingShot = XelAssist.Game.Player.HunterDistractingShot
local HunterRapidFire = XelAssist.Game.Player.HunterRapidFire
local PriestShadowform = XelAssist.Game.Player.PriestShadowform
local PriestInnerFocusRuntime = XelAssist.Game.Player.PriestInnerFocus
local PriestPowerInfusionRuntime = XelAssist.Game.Player.PriestPowerInfusion
local PriestPowerInfusion = XelAssist.Graph.PriestPowerInfusion
local PriestFadeRuntime = XelAssist.Game.Player.PriestFade
local PriestFade = XelAssist.Graph.PriestFade
local WarriorBattleShout = XelAssist.Game.Player.WarriorBattleShout
local WarriorThunderClap = XelAssist.Game.Player.WarriorThunderClap
local WarriorDemoralizingShout =
    XelAssist.Game.Player.WarriorDemoralizingShout
local WarriorShieldWall = XelAssist.Game.Player.WarriorShieldWall
local WarriorThreatPackets = XelAssist.Graph.WarriorThreatPackets
local WarlockFelDominationRuntime =
    XelAssist.Game.Player.WarlockFelDomination
local WarlockDarkPactRuntime = XelAssist.Game.Player.WarlockDarkPact
local WarlockDarkPact = XelAssist.Graph.WarlockDarkPact

function E:CaptureFacts(action, facts, state)
    local out = facts
    if PaladinRighteousness then
        out = PaladinRighteousness:CaptureFacts(action, out, state)
    end
    if PaladinRighteousFury then
        out = PaladinRighteousFury:CaptureFacts(action, out)
    end
    if PaladinMight then out = PaladinMight:CaptureFacts(action, out) end
    if PaladinWisdom then out = PaladinWisdom:CaptureFacts(action, out) end
    if MageShield then out = MageShield:CaptureFacts(action, out) end
    if MageClearcasting then
        out = MageClearcasting:CaptureFacts(action, out, state)
    end
    if MagePresenceOfMind then
        out = MagePresenceOfMind:CaptureFacts(action, out, state)
    end
    if MageColdSnap then out = MageColdSnap:CaptureFacts(action, out) end
    if DruidClearcasting then
        out = DruidClearcasting:CaptureFacts(action, out, state)
    end
    if DruidFrenziedRegeneration then
        out = DruidFrenziedRegeneration:CaptureFacts(action, out)
    end
    if ShamanClearcasting then
        out = ShamanClearcasting:CaptureFacts(action, out, state)
    end
    if ShamanManaSpring then
        out = ShamanManaSpring:CaptureFacts(action, out)
    end
    if ShamanEarthShockRuntime then
        out = ShamanEarthShockRuntime:CaptureFacts(action, out, state)
    end
    if RogueFeint then out = RogueFeint:CaptureFacts(action, out) end
    if RogueSliceRuntime then out = RogueSliceRuntime:CaptureFacts(action, out) end
    if RogueRuthlessness then
        out = RogueRuthlessness:CaptureFacts(action, out)
    end
    if RoguePreparation then out = RoguePreparation:CaptureFacts(action, out) end
    if WarriorBattleShout then
        out = WarriorBattleShout:CaptureFacts(action, out)
    end
    if WarriorThunderClap then
        out = WarriorThunderClap:CaptureFacts(action, out)
    end
    if WarriorDemoralizingShout then
        out = WarriorDemoralizingShout:CaptureFacts(action, out)
    end
    if WarriorShieldWall then
        out = WarriorShieldWall:CaptureFacts(action, out)
    end
    if WarlockFelDominationRuntime then
        out = WarlockFelDominationRuntime:CaptureFacts(action, out, state)
    end
    if WarlockDarkPactRuntime then
        out = WarlockDarkPactRuntime:CaptureFacts(action, out)
    end
    if HunterMark then out = HunterMark:CaptureFacts(action, out) end
    if HunterHawk then out = HunterHawk:CaptureFacts(action, out) end
    if HunterDistractingShot then
        out = HunterDistractingShot:CaptureFacts(action, out, state)
    end
    if HunterRapidFire then
        out = HunterRapidFire:CaptureFacts(action, out, state)
    end
    if PriestShadowform then
        out = PriestShadowform:CaptureFacts(action, out)
    end
    if PriestInnerFocusRuntime then
        out = PriestInnerFocusRuntime:CaptureFacts(action, out, state)
    end
    if PriestPowerInfusionRuntime then
        out = PriestPowerInfusionRuntime:CaptureFacts(action, out)
    end
    if PriestFadeRuntime then out = PriestFadeRuntime:CaptureFacts(action, out) end
    return out
end

function E:AuraActive(action, state, descriptor, tooltip, lead)
    local active, handled, reason
    if PriestPowerInfusion then
        active, handled, reason = PriestPowerInfusion:AuraActive(
            action, state, descriptor, tooltip, lead)
        if handled then return active, true, reason end
    end
    if HunterMarkGraph then return HunterMarkGraph:AuraActive(
        action, state, descriptor, tooltip, lead) end
    return nil, false
end

function E:CaptureRecipient(observed, action, descriptor)
    local handled, record
    if PriestShield then
        handled, record = PriestShield:Capture(observed, action, descriptor)
        if handled then return true, record end
    end
    if PriestPowerInfusionRuntime then
        return PriestPowerInfusionRuntime:CaptureRecipient(
            observed, action, descriptor)
    end
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
    if PriestFade then
        blocker, handled = PriestFade:Blocker(action, state, descriptor, tooltip)
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
    if WarriorThreatPackets then
        blocker, handled = WarriorThreatPackets:Blocker(
            action, state, descriptor, tooltip)
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
    if ShamanEarthShock then
        blocker, handled = ShamanEarthShock:Blocker(
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
