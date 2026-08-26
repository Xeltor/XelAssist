local function expect(value, message)
    if not value then error(message or "expectation failed") end
end
local function close(actual, expected, message)
    expect(math.abs(actual - expected) < 0.0001,
        (message or "values differ") .. ": " .. tostring(actual))
end

XelAssist = { Game = { Player = {} }, Graph = {} }
UnitClass = function() return "Shaman", "SHAMAN" end

local learned = {}
local rows = {
    [45951] = { attributes=2684354752, spellFamilyName=11,
        spellFamilyFlags=0, spellFamilyFlags2=0, effect={6,6,0},
        effectApplyAuraName={4,10,0}, effectBasePoints={14,4,0},
        effectMiscValue={0,127,0}, effectImplicitTargetA={1,1,0} },
    [45952] = { attributes=2684354752, spellFamilyName=11,
        spellFamilyFlags=0, spellFamilyFlags2=0, effect={6,6,0},
        effectApplyAuraName={4,10,0}, effectBasePoints={29,9,0},
        effectMiscValue={0,127,0}, effectImplicitTargetA={1,1,0} },
}
GetSpellRecField = function(id, field, copied)
    local value = rows[id] and rows[id][field]
    expect(value ~= nil, "unexpected DBC field "..tostring(id)..":"..field)
    if copied then
        local out, key = {}, nil
        for key in pairs(value) do out[key] = value[key] end
        return out
    end
    return value
end
IsPlayerSpell = function(id) return learned[id] == true end

dofile("Game/Player/ShamanSpiritArmor.lua")
dofile("Graph/ShamanSpiritArmor.lua")
dofile("Graph/PlayerThreat.lua")
local Runtime = XelAssist.Game.Player.ShamanSpiritArmor
local Threat = XelAssist.Graph.PlayerThreat
local shield = { classificationKnown=true, classID=4, subClassID=6,
    inventoryType=14, broken=false }

local state = { inventory={ offHand=shield }, tank=true }
state.shamanSpiritArmor = Runtime:Snapshot(state)
expect(state.shamanSpiritArmor.exact and state.shamanSpiritArmor.rank == 0
    and state.shamanSpiritArmor.multiplier == 1,
    "an untalented Shaman must retain exact neutral threat")
local amount, exact, multiplier = Threat:Scale(state, "player", 100, 0)
close(amount, 100, "untalented threat"); expect(exact and multiplier == 1)

learned[45952] = true
Runtime:Invalidate()
state.shamanSpiritArmor = Runtime:Snapshot(state)
expect(state.shamanSpiritArmor.exact and state.shamanSpiritArmor.rank == 2
    and state.shamanSpiritArmor.shieldEquipped,
    "rank two plus exact shield must seal Spirit Armor")
amount, exact, multiplier = Threat:Scale(state, "player", 100, 0)
close(amount, 110, "rank-two shield threat")
expect(exact and multiplier == 1.10,
    "exact Spirit Armor must compose as all-player threat")

state.inventory.offHand = { classificationKnown=true, empty=true }
state.shamanSpiritArmor = Runtime:Snapshot(state)
amount, exact, multiplier = Threat:Scale(state, "player", 100, 0)
close(amount, 100, "Spirit Armor without shield")
expect(exact and multiplier == 1,
    "the passive must not manufacture threat without a shield")

state.inventory.offHand = nil
state.shamanSpiritArmor = Runtime:Snapshot(state)
amount, exact, multiplier = Threat:Scale(state, "player", 100, 0)
close(amount, 100, "tank lower threat bound")
expect(not exact and multiplier == 1,
    "unknown shield evidence must under-credit tank threat")
state.tank = false
amount, exact, multiplier = Threat:Scale(state, "player", 100, 0)
close(amount, 110, "non-tank upper threat bound")
expect(not exact and multiplier == 1.10,
    "unknown shield evidence must not understate non-tank threat risk")
amount, exact, multiplier = Threat:Scale(state, "pet", 100, 0)
close(amount, 100, "pet threat bypass")
expect(exact and multiplier == 1, "Spirit Armor is player-only")

rows[45952].effectBasePoints[2] = 8
Runtime:Invalidate()
state.shamanSpiritArmor = Runtime:Snapshot(state)
expect(not state.shamanSpiritArmor.exact
    and string.find(state.shamanSpiritArmor.reason or "", "topology"),
    "changed Spirit Armor arithmetic must remain bounded")

print("ok: exact shield-gated Shaman Spirit Armor threat")
