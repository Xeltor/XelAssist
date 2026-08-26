-- Root-captured class evidence and exact support-effect boundaries. This module
-- owns no class action ordering; it only seals mutable facts and delegates
-- blockers or transitions to the mechanic that can prove the consequence.
XelAssist.Graph.ClassEvidence = {}
local E = XelAssist.Graph.ClassEvidence
local PaladinRighteousFury = XelAssist.Game.Player.PaladinRighteousFury
local PaladinConsecration = XelAssist.Game.Player.PaladinConsecration
local PaladinRighteousness = XelAssist.Game.Player.PaladinRighteousness
local PaladinMight = XelAssist.Game.Player.PaladinMight
local PaladinWisdom = XelAssist.Game.Player.PaladinWisdom
local MageShield = XelAssist.Game.Player.MageManaShield
local MageClearcasting = XelAssist.Game.Player.MageClearcasting
local MagePresenceOfMind = XelAssist.Game.Player.MagePresenceOfMind
local MageColdSnap = XelAssist.Game.Player.MageColdSnap
local MageProcWindowsRuntime = XelAssist.Game.Player.MageProcWindows
local DruidClearcasting = XelAssist.Game.Player.DruidClearcasting
local DruidFrenziedRegeneration =
    XelAssist.Game.Player.DruidFrenziedRegeneration
local DruidCasterForms = XelAssist.Game.Player.DruidCasterForms
local ShamanClearcasting = XelAssist.Game.Player.ShamanClearcasting
local ShamanManaSpring = XelAssist.Game.Player.ShamanManaSpring
local ShamanEarthShockRuntime = XelAssist.Game.Player.ShamanEarthShock
local ShamanStormstrikeRuntime = XelAssist.Game.Player.ShamanStormstrike
local ShamanLightningStrike = XelAssist.Game.Player.ShamanLightningStrike
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
local HunterStingingNettle = XelAssist.Game.Player.HunterStingingNettle
local HunterManaAspects = XelAssist.Game.Player.HunterManaAspects
local HunterFeignDeath = XelAssist.Game.Player.HunterFeignDeath
local HunterStings = XelAssist.Game.Player.HunterStings
local PriestShadowform = XelAssist.Game.Player.PriestShadowform
local PriestImprovedShadowform = XelAssist.Game.Player.PriestImprovedShadowform
local PriestAscendanceRuntime = XelAssist.Game.Player.PriestAscendance
local PriestAscendance = XelAssist.Graph.PriestAscendance
local PriestInnerFocusRuntime = XelAssist.Game.Player.PriestInnerFocus
local PriestPowerInfusionRuntime = XelAssist.Game.Player.PriestPowerInfusion
local PriestPowerInfusion = XelAssist.Graph.PriestPowerInfusion
local PriestFadeRuntime = XelAssist.Game.Player.PriestFade
local PriestFade = XelAssist.Graph.PriestFade
local WarriorBattleShout = XelAssist.Game.Player.WarriorBattleShout
local WarriorThunderClap = XelAssist.Game.Player.WarriorThunderClap
local WarriorOverpoweringRage =
    XelAssist.Game.Player.WarriorOverpoweringRage
local WarriorReprisal = XelAssist.Game.Player.WarriorReprisal
local WarriorExecute = XelAssist.Game.Player.WarriorExecute
local WarriorDemoralizingShout =
    XelAssist.Game.Player.WarriorDemoralizingShout
local WarriorShieldWall = XelAssist.Game.Player.WarriorShieldWall
local WarriorShieldMastery = XelAssist.Game.Player.WarriorShieldMastery
local WarriorBerserkerRage = XelAssist.Game.Player.WarriorBerserkerRage
local WarriorBerserkerRageGraph = XelAssist.Graph.WarriorBerserkerRage
local WarriorCostPassives = XelAssist.Game.Player.WarriorCostPassives
local WarriorCostPassivesGraph = XelAssist.Graph.WarriorCostPassives
local WarriorThreatPackets = XelAssist.Graph.WarriorThreatPackets
local WarlockFelDominationRuntime =
    XelAssist.Game.Player.WarlockFelDomination
local WarlockDarkPactRuntime = XelAssist.Game.Player.WarlockDarkPact
local WarlockDarkPact = XelAssist.Graph.WarlockDarkPact
local WarlockNightfallRuntime = XelAssist.Game.Player.WarlockNightfall

local CAPTURE_MODULES = {}
local function captureModule(module)
    if module and type(module.CaptureFacts) == "function" then
        table.insert(CAPTURE_MODULES, module)
    end
end
captureModule(PaladinRighteousness)
captureModule(PaladinRighteousFury)
captureModule(PaladinConsecration)
captureModule(PaladinMight)
captureModule(PaladinWisdom)
captureModule(XelAssist.Game.Player.PaladinHolyShockModifiers)
captureModule(XelAssist.Game.Player.PaladinMartyr)
captureModule(MageShield)
captureModule(MageClearcasting)
captureModule(MagePresenceOfMind)
captureModule(MageColdSnap)
captureModule(MageProcWindowsRuntime)
captureModule(XelAssist.Game.Player.MageAcceleratedArcana)
captureModule(XelAssist.Game.Player.MageFrostfire)
captureModule(DruidClearcasting)
captureModule(DruidFrenziedRegeneration)
captureModule(XelAssist.Game.Player.DruidAncientBrutality)
captureModule(XelAssist.Game.Player.DruidEnrage)
captureModule(XelAssist.Game.Player.DruidBloodFrenzy)
captureModule(DruidCasterForms)
captureModule(ShamanClearcasting)
captureModule(XelAssist.Game.Player.ShamanWeaponImbues)
captureModule(ShamanManaSpring)
captureModule(ShamanEarthShockRuntime)
captureModule(ShamanLightningStrike)
captureModule(ShamanStormstrikeRuntime)
captureModule(XelAssist.Game.Player.ShamanChainHealTiming)
captureModule(XelAssist.Game.Player.ShamanFlameShockTiming)
captureModule(RogueFeint)
captureModule(RogueSliceRuntime)
captureModule(RogueRuthlessness)
captureModule(RoguePreparation)
captureModule(WarriorBattleShout)
captureModule(WarriorThunderClap)
captureModule(WarriorOverpoweringRage)
captureModule(WarriorReprisal)
captureModule(WarriorExecute)
captureModule(WarriorDemoralizingShout)
captureModule(WarriorShieldWall)
captureModule(WarriorShieldMastery)
captureModule(WarriorBerserkerRage)
captureModule(WarriorCostPassives)
captureModule(WarlockFelDominationRuntime)
captureModule(WarlockDarkPactRuntime)
captureModule(WarlockNightfallRuntime)
captureModule(HunterMark)
captureModule(HunterHawk)
captureModule(HunterDistractingShot)
captureModule(HunterRapidFire)
captureModule(HunterStingingNettle)
captureModule(HunterManaAspects)
captureModule(HunterFeignDeath)
captureModule(HunterStings)
captureModule(PriestShadowform)
captureModule(PriestImprovedShadowform)
captureModule(PriestAscendanceRuntime)
captureModule(PriestInnerFocusRuntime)
captureModule(PriestPowerInfusionRuntime)
captureModule(PriestFadeRuntime)

function E:CaptureFacts(action, facts, state)
    local out, index = facts, nil
    for index = 1, table.getn(CAPTURE_MODULES) do
        out = CAPTURE_MODULES[index]:CaptureFacts(action, out, state)
    end
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
    if WarriorCostPassivesGraph then
        blocker, handled = WarriorCostPassivesGraph:Blocker(
            action, state, descriptor, tooltip)
        if handled then return blocker, true end
    end
    if WarriorBerserkerRageGraph then
        blocker, handled = WarriorBerserkerRageGraph:Blocker(
            action, state, descriptor, tooltip)
        if handled then return blocker, true end
    end
    if PriestAscendance then
        local prepared
        prepared, blocker, handled = PriestAscendance:Prepare(
            action, state, tooltip)
        if handled then return blocker, true end
    end
    if DruidCasterForms then
        blocker, handled = DruidCasterForms:FormBlocker(action, state)
        if handled then return blocker, true end
    end
    if PaladinConsecration then
        blocker, handled = PaladinConsecration:Blocker(
            action, state, descriptor, tooltip)
        if handled then return blocker, true end
    end
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
    if WarriorBerserkerRageGraph
        and WarriorBerserkerRageGraph:Apply(state, candidate) then return true end
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
