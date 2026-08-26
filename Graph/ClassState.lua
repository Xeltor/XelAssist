-- Root attachment and branch copying for exact class-owned graph state. This
-- module contains no action ordering, legality, scoring, or transition policy.
XelAssist.Graph.ClassState = {}
local S = XelAssist.Graph.ClassState
local Paladin = XelAssist.Graph.PaladinAuraProjection
local PaladinBlessingThreat = XelAssist.Graph.PaladinBlessingThreat
local PaladinRighteousFury = XelAssist.Graph.PaladinRighteousFury
local Totems = XelAssist.Game.Player.TotemState
local ShamanClearcastingRuntime = XelAssist.Game.Player.ShamanClearcasting
local ShamanClearcasting = XelAssist.Graph.ShamanClearcasting
local MageClearcastingRuntime = XelAssist.Game.Player.MageClearcasting
local MageClearcasting = XelAssist.Graph.MageClearcasting
local RogueSlice = XelAssist.Graph.RogueSliceAndDice
local HunterMark = XelAssist.Graph.HunterMark
local HunterHawk = XelAssist.Graph.HunterHawk
local PriestShadowform = XelAssist.Graph.PriestShadowform
local PriestInnerFocusRuntime = XelAssist.Game.Player.PriestInnerFocus
local PriestInnerFocus = XelAssist.Graph.PriestInnerFocus
local Windfury = XelAssist.Graph.ShamanWindfuryTotem
local WarriorBattleShout = XelAssist.Graph.WarriorBattleShout

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
        if PaladinBlessingThreat then PaladinBlessingThreat:Attach(state) end
        if PaladinRighteousFury then PaladinRighteousFury:Attach(state) end
        return attached
    elseif token == "SHAMAN" then
        local attached = false
        if Totems then
            state.totems = Totems:Snapshot()
            attached = state.totems and state.totems.available == true or false
            if Windfury then Windfury:Attach(state) end
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
    elseif token == "MAGE" and MageClearcastingRuntime then
        return MageClearcastingRuntime:Attach(state, token)
    elseif token == "ROGUE" and RogueSlice then
        return RogueSlice:Attach(state) ~= nil
    elseif token == "WARRIOR" and WarriorBattleShout then
        return WarriorBattleShout:Attach(state)
    end
    return false
end

function S:Copy(source, target)
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
    if ShamanClearcasting then ShamanClearcasting:Copy(source, target) end
    if RogueSlice then RogueSlice:Copy(source, target) end
    if PriestShadowform then PriestShadowform:Copy(source, target) end
    if PriestInnerFocus then PriestInnerFocus:Copy(source, target) end
    if Windfury then Windfury:Copy(source, target) end
    if WarriorBattleShout then WarriorBattleShout:Copy(source, target) end
    return source.paladinAuraState ~= nil
        or source.paladinBlessingThreat ~= nil or source.totems ~= nil
        or source.paladinRighteousFury ~= nil
        or source.hunterMarkRoot ~= nil or source.hunterHawk ~= nil
        or source.mageClearcasting ~= nil or source.shamanClearcasting ~= nil
        or source.rogueSliceAndDice ~= nil
        or source.playerShadowformProfileExact == true
        or source.priestInnerFocus ~= nil
        or source.shamanWindfuryTotem ~= nil
        or source.warriorBattleShout ~= nil
end
