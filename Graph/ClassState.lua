-- Root attachment and branch copying for exact class-owned graph state. This
-- module contains no action ordering, legality, scoring, or transition policy.
XelAssist.Graph.ClassState = {}
local S = XelAssist.Graph.ClassState
local Paladin = XelAssist.Graph.PaladinAuraProjection
local PaladinMight = XelAssist.Graph.PaladinMight
local PaladinWisdom = XelAssist.Graph.PaladinWisdom
local PaladinBlessingThreat = XelAssist.Graph.PaladinBlessingThreat
local PaladinRighteousFury = XelAssist.Graph.PaladinRighteousFury
local Totems = XelAssist.Game.Player.TotemState
local ShamanClearcastingRuntime = XelAssist.Game.Player.ShamanClearcasting
local ShamanClearcasting = XelAssist.Graph.ShamanClearcasting
local ShamanManaSpring = XelAssist.Graph.ShamanManaSpring
local MageClearcastingRuntime = XelAssist.Game.Player.MageClearcasting
local MageClearcasting = XelAssist.Graph.MageClearcasting
local MagePresenceOfMindRuntime = XelAssist.Game.Player.MagePresenceOfMind
local MagePresenceOfMind = XelAssist.Graph.MagePresenceOfMind
local MageColdSnap = XelAssist.Graph.MageColdSnap
local DruidClearcastingRuntime = XelAssist.Game.Player.DruidClearcasting
local DruidClearcasting = XelAssist.Graph.DruidClearcasting
local RogueSlice = XelAssist.Graph.RogueSliceAndDice
local RogueRuthlessness = XelAssist.Graph.RogueRuthlessness
local HunterMark = XelAssist.Graph.HunterMark
local HunterHawk = XelAssist.Graph.HunterHawk
local PriestShadowform = XelAssist.Graph.PriestShadowform
local PriestInnerFocusRuntime = XelAssist.Game.Player.PriestInnerFocus
local PriestInnerFocus = XelAssist.Graph.PriestInnerFocus
local PriestFade = XelAssist.Graph.PriestFade
local Windfury = XelAssist.Graph.ShamanWindfuryTotem
local WarriorBattleShout = XelAssist.Graph.WarriorBattleShout
local WarriorShieldWall = XelAssist.Graph.WarriorShieldWall
local WarlockFelDominationRuntime =
    XelAssist.Game.Player.WarlockFelDomination
local WarlockFelDomination = XelAssist.Graph.WarlockFelDomination
local WarlockSoulLinkRuntime = XelAssist.Game.Player.WarlockSoulLink
local WarlockSoulLink = XelAssist.Graph.WarlockSoulLink

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

function S:Attach(state)
    if not state then return false end
    local token = classToken()
    state.classMechanicClass = token
    if token == "PALADIN" and Paladin then
        local attached = Paladin:Attach(state)
        local might = PaladinMight and PaladinMight:Attach(state) or false
        local wisdom = PaladinWisdom and PaladinWisdom:Attach(state) or false
        if PaladinBlessingThreat then PaladinBlessingThreat:Attach(state) end
        if PaladinRighteousFury then PaladinRighteousFury:Attach(state) end
        return attached or might or wisdom
    elseif token == "SHAMAN" then
        local attached = false
        if Totems then
            state.totems = Totems:Snapshot()
            attached = state.totems and state.totems.available == true or false
            if Windfury then Windfury:Attach(state) end
        end
        if ShamanManaSpring then
            attached = ShamanManaSpring:Attach(state) or attached
        end
        if ShamanClearcastingRuntime then
            attached = ShamanClearcastingRuntime:Attach(state, token) or attached
        end
        return attached
    elseif token == "HUNTER" then
        local mark = HunterMark and HunterMark:Attach(state)
        local hawk = HunterHawk and HunterHawk:Attach(state) or false
        return mark ~= nil or hawk
    elseif token == "PRIEST" then
        local attached = PriestShadowform
            and PriestShadowform:Attach(state, token) or false
        if PriestInnerFocusRuntime then
            attached = PriestInnerFocusRuntime:Attach(state, token) or attached
        end
        return attached
    elseif token == "MAGE" then
        local attached = MageClearcastingRuntime
            and MageClearcastingRuntime:Attach(state, token) or false
        if MagePresenceOfMindRuntime then
            attached = MagePresenceOfMindRuntime:Attach(state, token)
                or attached
        end
        return attached
    elseif token == "DRUID" then
        return DruidClearcastingRuntime
            and DruidClearcastingRuntime:Attach(state, token) or false
    elseif token == "ROGUE" then
        local attached = RogueSlice and RogueSlice:Attach(state) ~= nil
            or false
        if RogueRuthlessness then
            attached = RogueRuthlessness:Attach(state) or attached
        end
        return attached
    elseif token == "WARLOCK" then
        local attached = WarlockSoulLinkRuntime and WarlockSoulLink
            and WarlockSoulLink:Attach(
                state, WarlockSoulLinkRuntime:Snapshot(token)) or false
        if WarlockFelDominationRuntime and WarlockFelDomination then
            attached = WarlockFelDominationRuntime:Attach(state, token)
                or attached
        end
        return attached
    elseif token == "WARRIOR" then
        local attached = WarriorBattleShout
            and WarriorBattleShout:Attach(state) or false
        if WarriorShieldWall then
            attached = WarriorShieldWall:Attach(state, token) or attached
        end
        return attached
    end
    return false
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
    if source.totems then target.totems = copy(source.totems, 7) end
    if source.hunterMarkRoot then target.hunterMarkRoot = source.hunterMarkRoot end
    if HunterHawk then HunterHawk:Copy(source, target) end
    if MageClearcasting then MageClearcasting:Copy(source, target) end
    if MagePresenceOfMind then MagePresenceOfMind:Copy(source, target) end
    if MageColdSnap then MageColdSnap:Copy(source, target) end
    if DruidClearcasting then DruidClearcasting:Copy(source, target) end
    if ShamanClearcasting then ShamanClearcasting:Copy(source, target) end
    if ShamanManaSpring then ShamanManaSpring:Copy(source, target) end
    if RogueSlice then RogueSlice:Copy(source, target) end
    if RogueRuthlessness then RogueRuthlessness:Copy(source, target) end
    if PriestShadowform then PriestShadowform:Copy(source, target) end
    if PriestInnerFocus then PriestInnerFocus:Copy(source, target) end
    if PriestFade then PriestFade:Copy(source, target) end
    if Windfury then Windfury:Copy(source, target) end
    if WarriorBattleShout then WarriorBattleShout:Copy(source, target) end
    if WarriorShieldWall then WarriorShieldWall:Copy(source, target) end
    if WarlockFelDomination then WarlockFelDomination:Copy(source, target) end
    if source.warlockSoulLink then
        target.warlockSoulLink = copy(source.warlockSoulLink, 4)
    end
    return source.paladinAuraState ~= nil
        or source.paladinMight ~= nil
        or source.paladinWisdom ~= nil
        or source.paladinBlessingThreat ~= nil or source.totems ~= nil
        or source.paladinRighteousFury ~= nil
        or source.hunterMarkRoot ~= nil or source.hunterHawk ~= nil
        or source.mageClearcasting ~= nil
        or source.magePresenceOfMind ~= nil
        or source.mageColdSnapReset ~= nil
        or source.druidClearcasting ~= nil
        or source.shamanClearcasting ~= nil
        or source.shamanManaSpring ~= nil
        or source.rogueSliceAndDice ~= nil
        or source.rogueRuthlessness ~= nil
        or source.playerShadowformProfileExact == true
        or source.priestInnerFocus ~= nil
        or source.priestFade ~= nil
        or source.shamanWindfuryTotem ~= nil
        or source.warlockSoulLink ~= nil
        or source.warriorBattleShout ~= nil
        or source.warriorShieldWall ~= nil
        or source.warlockFelDomination ~= nil
end
