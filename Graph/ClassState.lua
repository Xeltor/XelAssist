-- Root attachment and branch copying for exact class-owned graph state. This
-- module contains no action ordering, legality, scoring, or transition policy.
XelAssist.Graph.ClassState = {}
local S = XelAssist.Graph.ClassState
local Paladin = XelAssist.Graph.PaladinAuraProjection
local PaladinMight = XelAssist.Graph.PaladinMight
local PaladinWisdom = XelAssist.Graph.PaladinWisdom
local PaladinBlessingThreat = XelAssist.Graph.PaladinBlessingThreat
local PaladinRighteousFury = XelAssist.Graph.PaladinRighteousFury
local PaladinHolyShockRuntime =
    XelAssist.Game.Player.PaladinHolyShockModifiers
local PaladinHolyShock = XelAssist.Graph.PaladinHolyShockModifiers
local Totems = XelAssist.Game.Player.TotemState
local ShamanClearcastingRuntime = XelAssist.Game.Player.ShamanClearcasting
local ShamanClearcasting = XelAssist.Graph.ShamanClearcasting
local ShamanSpiritArmorRuntime = XelAssist.Game.Player.ShamanSpiritArmor
local ShamanManaSpring = XelAssist.Graph.ShamanManaSpring
local ShamanWeaponImbues = XelAssist.Graph.ShamanWeaponImbues
local MageClearcastingRuntime = XelAssist.Game.Player.MageClearcasting
local MageClearcasting = XelAssist.Graph.MageClearcasting
local MagePresenceOfMindRuntime = XelAssist.Game.Player.MagePresenceOfMind
local MagePresenceOfMind = XelAssist.Graph.MagePresenceOfMind
local MageColdSnap = XelAssist.Graph.MageColdSnap
local MageEvocationRuntime = XelAssist.Game.Player.MageEvocationEvidence
local MageEvocation = XelAssist.Graph.MageEvocation
local MageProcWindowsRuntime = XelAssist.Game.Player.MageProcWindows
local MageProcWindows = XelAssist.Graph.MageProcWindows
local DruidClearcastingRuntime = XelAssist.Game.Player.DruidClearcasting
local DruidClearcasting = XelAssist.Graph.DruidClearcasting
local DruidFrenziedRegeneration =
    XelAssist.Graph.DruidFrenziedRegeneration
local DruidEnrage = XelAssist.Graph.DruidEnrage
local DruidBloodFrenzy = XelAssist.Graph.DruidBloodFrenzy
local DruidBarkskin = XelAssist.Graph.DruidBarkskin
local RogueSlice = XelAssist.Graph.RogueSliceAndDice
local RogueRuthlessness = XelAssist.Graph.RogueRuthlessness
local RoguePreparation = XelAssist.Graph.RoguePreparation
local HunterMark = XelAssist.Graph.HunterMark
local HunterHawk = XelAssist.Graph.HunterHawk
local HunterRapidFireRuntime = XelAssist.Game.Player.HunterRapidFire
local HunterRapidFire = XelAssist.Graph.HunterRapidFire
local HunterManaAspects = XelAssist.Graph.HunterManaAspects
local HunterFeignDeathRuntime = XelAssist.Game.Player.HunterFeignDeath
local PriestShadowform = XelAssist.Graph.PriestShadowform
local PriestImprovedShadowform = XelAssist.Game.Player.PriestImprovedShadowform
local PriestAscendance = XelAssist.Graph.PriestAscendance
local PriestInnerFocusRuntime = XelAssist.Game.Player.PriestInnerFocus
local PriestInnerFocus = XelAssist.Graph.PriestInnerFocus
local PriestFade = XelAssist.Graph.PriestFade
local Windfury = XelAssist.Graph.ShamanWindfuryTotem
local WarriorBattleShout = XelAssist.Graph.WarriorBattleShout
local WarriorShieldWall = XelAssist.Graph.WarriorShieldWall
local WarriorShieldBlock = XelAssist.Graph.WarriorShieldBlock
local WarlockFelDominationRuntime =
    XelAssist.Game.Player.WarlockFelDomination
local WarlockFelDomination = XelAssist.Graph.WarlockFelDomination
local WarlockSoulLinkRuntime = XelAssist.Game.Player.WarlockSoulLink
local WarlockSoulLink = XelAssist.Graph.WarlockSoulLink
local WarlockNightfallRuntime = XelAssist.Game.Player.WarlockNightfall
local WarlockNightfall = XelAssist.Graph.WarlockNightfall

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

local function attachHunter(state, token)
    local mark = HunterMark and HunterMark:Attach(state)
    local hawk = HunterHawk and HunterHawk:Attach(state) or false
    local rapid = HunterRapidFireRuntime and HunterRapidFire
        and HunterRapidFire:Attach(
            state, HunterRapidFireRuntime:Snapshot(token)) or false
    local mana = HunterManaAspects and HunterManaAspects:Attach(state) or false
    local feign = XelAssist.Graph.HunterFeignDeath
    feign = feign and HunterFeignDeathRuntime
        and feign:Attach(state, HunterFeignDeathRuntime:Snapshot(token)) or false
    local alone = XelAssist.Graph.HunterAloneAgainstWorld
        and XelAssist.Graph.HunterAloneAgainstWorld:Attach(state, token) or false
    return mark ~= nil or hawk or rapid or mana or alone or feign
end
local function attachPaladin(state, token)
    if not Paladin then return false end
    local attached = Paladin:Attach(state)
    local might = PaladinMight and PaladinMight:Attach(state) or false
    local wisdom = PaladinWisdom and PaladinWisdom:Attach(state) or false
    if PaladinBlessingThreat then PaladinBlessingThreat:Attach(state) end
    if PaladinRighteousFury then PaladinRighteousFury:Attach(state) end
    local shock = PaladinHolyShockRuntime and PaladinHolyShock
        and PaladinHolyShock:Attach(state,
            PaladinHolyShockRuntime:Snapshot(token)) or false
    return attached or might or wisdom or shock
end
local function attachShaman(state, token)
    local attached = false
    if Totems then
        state.totems = Totems:Snapshot()
        attached = state.totems and state.totems.available == true or false
        if Windfury then Windfury:Attach(state) end
    end
    if ShamanManaSpring then
        attached = ShamanManaSpring:Attach(state) or attached
    end
    if ShamanWeaponImbues then
        attached = ShamanWeaponImbues:Attach(state, token) or attached
    end
    if ShamanClearcastingRuntime then
        attached = ShamanClearcastingRuntime:Attach(state, token) or attached
    end
    if ShamanSpiritArmorRuntime then
        state.shamanSpiritArmor = ShamanSpiritArmorRuntime:Snapshot(state)
        attached = state.shamanSpiritArmor ~= nil or attached
    end
    local stormstrike = XelAssist.Graph.ShamanStormstrike
    local runtime = XelAssist.Game.Player.ShamanStormstrike
    if stormstrike and runtime then
        attached = stormstrike:Attach(state, runtime:Snapshot(token)) or attached
    end
    return attached
end
local function attachPriest(state, token)
    local attached = PriestShadowform
        and PriestShadowform:Attach(state, token) or false
    if PriestImprovedShadowform then
        attached = PriestImprovedShadowform:Attach(state) or attached
    end
    if PriestInnerFocusRuntime then
        attached = PriestInnerFocusRuntime:Attach(state, token) or attached
    end
    if PriestAscendance then
        attached = PriestAscendance:Attach(state) or attached
    end
    if XelAssist.Graph.PriestResurgentShield then
        attached = XelAssist.Graph.PriestResurgentShield
            :Attach(state, token) or attached
    end
    return attached
end
local function attachMage(state, token)
    local attached = MageClearcastingRuntime
        and MageClearcastingRuntime:Attach(state, token) or false
    if MagePresenceOfMindRuntime then
        attached = MagePresenceOfMindRuntime:Attach(state, token) or attached
    end
    if MageProcWindowsRuntime and MageProcWindows then
        attached = MageProcWindows:Attach(state,
            MageProcWindowsRuntime:Snapshot(token)) or attached
    end
    if MageEvocationRuntime then
        state.mageEvocationEvidence = MageEvocationRuntime:Snapshot()
        attached = state.mageEvocationEvidence ~= nil or attached
    end
    return attached
end
local function attachDruid(state, token)
    local attached = DruidClearcastingRuntime
        and DruidClearcastingRuntime:Attach(state, token) or false
    if DruidFrenziedRegeneration then
        attached = DruidFrenziedRegeneration:Attach(state, token) or attached
    end
    if DruidEnrage then
        attached = DruidEnrage:Attach(state, token) or attached
    end
    if DruidBloodFrenzy then
        attached = DruidBloodFrenzy:Attach(state, token) or attached
    end
    if DruidBarkskin then
        attached = DruidBarkskin:Attach(state, token) or attached
    end
    local brutality = XelAssist.Graph.DruidAncientBrutality
    if brutality then
        attached = brutality:Attach(state, token) or attached
    end
    return attached
end
local function attachRogue(state)
    local attached = RogueSlice and RogueSlice:Attach(state) ~= nil or false
    if RogueRuthlessness then
        attached = RogueRuthlessness:Attach(state) or attached
    end
    return attached
end
local function attachWarlock(state, token)
    local attached = WarlockSoulLinkRuntime and WarlockSoulLink
        and WarlockSoulLink:Attach(
            state, WarlockSoulLinkRuntime:Snapshot(token)) or false
    if WarlockFelDominationRuntime and WarlockFelDomination then
        attached = WarlockFelDominationRuntime:Attach(state, token) or attached
    end
    if WarlockNightfallRuntime and WarlockNightfall then
        attached = WarlockNightfall:Attach(state,
            WarlockNightfallRuntime:Snapshot(token)) or attached
    end
    return attached
end
local function attachWarrior(state, token)
    local attached = WarriorBattleShout
        and WarriorBattleShout:Attach(state) or false
    if WarriorShieldWall then
        attached = WarriorShieldWall:Attach(state, token) or attached
    end
    local graph = XelAssist.Graph.WarriorBerserkerRage
    local runtime = XelAssist.Game.Player.WarriorBerserkerRage
    if runtime and graph then
        attached = graph:Attach(state, runtime:Snapshot()) or attached
    end
    return attached
end

function S:Attach(state)
    if not state then return false end
    local token = classToken()
    state.classMechanicClass = token
    if token == "PALADIN" then
        return attachPaladin(state, token)
    elseif token == "SHAMAN" then
        return attachShaman(state, token)
    elseif token == "HUNTER" then
        return attachHunter(state, token)
    elseif token == "PRIEST" then
        return attachPriest(state, token)
    elseif token == "MAGE" then
        return attachMage(state, token)
    elseif token == "DRUID" then
        return attachDruid(state, token)
    elseif token == "ROGUE" then
        return attachRogue(state)
    elseif token == "WARLOCK" then
        return attachWarlock(state, token)
    elseif token == "WARRIOR" then
        return attachWarrior(state, token)
    end
    return false
end

local function copyWarrior(source, target)
    if WarriorBattleShout then WarriorBattleShout:Copy(source, target) end
    if WarriorShieldWall then WarriorShieldWall:Copy(source, target) end
    if WarriorShieldBlock then WarriorShieldBlock:Copy(source, target) end
    local berserker = XelAssist.Graph.WarriorBerserkerRage
    if berserker then berserker:Copy(source, target) end
end

local function copyDruid(source, target)
    if DruidClearcasting then DruidClearcasting:Copy(source, target) end
    if DruidFrenziedRegeneration then
        DruidFrenziedRegeneration:Copy(source, target)
    end
    if DruidEnrage then DruidEnrage:Copy(source, target) end
    if DruidBloodFrenzy then DruidBloodFrenzy:Copy(source, target) end
    if DruidBarkskin then DruidBarkskin:Copy(source, target) end
    local brutality = XelAssist.Graph.DruidAncientBrutality
    if brutality then brutality:Copy(source, target) end
end

function S:Copy(source, target)
    if not (source and target) then return false end
    target.classMechanicClass = source.classMechanicClass
    if source.paladinAuraState and Paladin then Paladin:Copy(source, target) end
    if source.paladinMight and PaladinMight then
        PaladinMight:Copy(source, target)
    end
    if source.paladinWisdom and PaladinWisdom then
        PaladinWisdom:Copy(source, target)
    end
    if source.paladinBlessingThreat and PaladinBlessingThreat then
        PaladinBlessingThreat:Copy(source, target)
    end
    if PaladinRighteousFury then PaladinRighteousFury:Copy(source, target) end
    if PaladinHolyShock then PaladinHolyShock:Copy(source, target) end
    if source.totems then target.totems = copy(source.totems, 7) end
    if source.hunterMarkRoot then target.hunterMarkRoot = source.hunterMarkRoot end
    if HunterHawk then HunterHawk:Copy(source, target) end
    if HunterRapidFire then HunterRapidFire:Copy(source, target) end
    if HunterManaAspects then HunterManaAspects:Copy(source, target) end
    if XelAssist.Graph.HunterFeignDeath then
        XelAssist.Graph.HunterFeignDeath:Copy(source, target)
    end
    if XelAssist.Graph.HunterAloneAgainstWorld then
        XelAssist.Graph.HunterAloneAgainstWorld:Copy(source, target)
    end
    if MageClearcasting then MageClearcasting:Copy(source, target) end
    if MagePresenceOfMind then MagePresenceOfMind:Copy(source, target) end
    if MageColdSnap then MageColdSnap:Copy(source, target) end
    if MageEvocation then MageEvocation:Copy(source, target) end
    if MageProcWindows then MageProcWindows:Copy(source, target) end
    copyDruid(source, target)
    if ShamanClearcasting then ShamanClearcasting:Copy(source, target) end
    if source.shamanSpiritArmor then
        target.shamanSpiritArmor = copy(source.shamanSpiritArmor, 2)
    end
    if ShamanManaSpring then ShamanManaSpring:Copy(source, target) end
    if ShamanWeaponImbues then ShamanWeaponImbues:Copy(source, target) end
    if XelAssist.Graph.ShamanStormstrike then XelAssist.Graph.ShamanStormstrike:Copy(source, target) end
    if RogueSlice then RogueSlice:Copy(source, target) end
    if RogueRuthlessness then RogueRuthlessness:Copy(source, target) end
    if RoguePreparation then RoguePreparation:Copy(source, target) end
    if PriestShadowform then PriestShadowform:Copy(source, target) end
    if PriestImprovedShadowform then
        PriestImprovedShadowform:Copy(source, target)
    end
    if PriestAscendance then PriestAscendance:Copy(source, target) end
    if XelAssist.Graph.PriestResurgentShield then
        XelAssist.Graph.PriestResurgentShield:Copy(source, target)
    end
    if PriestInnerFocus then PriestInnerFocus:Copy(source, target) end
    if PriestFade then PriestFade:Copy(source, target) end
    if Windfury then Windfury:Copy(source, target) end
    copyWarrior(source, target)
    if WarlockFelDomination then WarlockFelDomination:Copy(source, target) end
    if WarlockNightfall then WarlockNightfall:Copy(source, target) end
    if source.warlockSoulLink then
        target.warlockSoulLink = copy(source.warlockSoulLink, 4)
    end
    return source.paladinAuraState ~= nil
        or source.paladinMight ~= nil
        or source.paladinWisdom ~= nil
        or source.paladinBlessingThreat ~= nil or source.totems ~= nil
        or source.paladinRighteousFury ~= nil
        or source.paladinHolyShockModifiers ~= nil
        or source.hunterMarkRoot ~= nil or source.hunterHawk ~= nil
        or source.hunterRapidFire ~= nil
        or source.hunterManaAspect ~= nil
        or source.hunterAloneAgainstWorld ~= nil
        or source.mageClearcasting ~= nil
        or source.magePresenceOfMind ~= nil
        or source.mageColdSnapReset ~= nil
        or source.mageProcWindows ~= nil
        or source.druidClearcasting ~= nil
        or source.druidFrenziedRegeneration ~= nil
        or source.druidBarkskin ~= nil
        or source.druidAncientBrutality ~= nil
        or source.shamanClearcasting ~= nil
        or source.shamanManaSpring ~= nil
        or source.shamanStormstrike ~= nil
        or source.rogueSliceAndDice ~= nil
        or source.rogueRuthlessness ~= nil
        or source.roguePreparationReset ~= nil
        or source.playerShadowformProfileExact == true
        or source.priestImprovedShadowform ~= nil
        or source.priestAscendance ~= nil
        or source.priestResurgentShield ~= nil
        or source.priestInnerFocus ~= nil
        or source.priestFade ~= nil
        or source.shamanWindfuryTotem ~= nil
        or source.warlockSoulLink ~= nil
        or source.warriorBattleShout ~= nil
        or source.warriorShieldWall ~= nil
        or source.warriorShieldBlock ~= nil
        or source.warriorBerserkerRage ~= nil
        or source.warlockFelDomination ~= nil
        or source.warlockNightfall ~= nil
end
