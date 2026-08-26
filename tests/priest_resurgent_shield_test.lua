XelAssist = { Game = { Player = {} }, Graph = {} }
table.getn = table.getn or function(value)
    local count = 0
    while value[count + 1] ~= nil do count = count + 1 end
    return count
end

local learned, active, now = true, true, 100
local rows = {
    [45560] = { spellFamilyName=6, attributes=464, durationIndex=21,
        rangeIndex=1, effect={6,6,0}, effectApplyAuraName={4,4,0},
        effectBasePoints={9,24,0}, effectBaseDice={1,1,0},
        effectImplicitTargetA={1,1,0}, effectTriggerSpell={0,0,0} },
    [51477] = { school=1, spellFamilyName=6, durationIndex=31, rangeIndex=5,
        effect={6,6,30}, effectApplyAuraName={13,135,0},
        effectBasePoints={4,4,24}, effectBaseDice={1,1,1},
        effectImplicitTargetA={1,1,1}, effectMiscValue={2,2,0},
        effectTriggerSpell={0,0,0} }
}
function GetSpellRecField(id, field, array)
    local value = rows[id] and rows[id][field]
    if array and type(value) == "table" then
        return { value[1], value[2], value[3] }
    end
    return value
end
function UnitClass() return "Priest", "PRIEST" end
function IsPlayerSpell(id) return id == 45560 and learned end
function GetTime() return now end
C_UnitAuras = { GetUnitAuras = function()
    return active and { { spellId=51477, isHelpful=true,
        expirationTime=108 } } or {}
end }

dofile("Game/Player/PriestResurgentShield.lua")
dofile("Graph/PriestResurgentShield.lua")
local Runtime = XelAssist.Game.Player.PriestResurgentShield
local Graph = XelAssist.Graph.PriestResurgentShield

local profile = Runtime:Profile()
assert(profile and profile.exact and not profile.dynamicAmountsProjectable
    and profile.tooltipHolyPercent == 10 and profile.tooltipRefundPercent == 25,
    "installed talent/result identities must retain the private dynamic boundary")
local snapshot = Runtime:Snapshot("PRIEST")
assert(snapshot.active and snapshot.remaining == 8,
    "the numeric Resurgence aura may be observed without inventing its amount")
local state = {}
assert(Graph:Attach(state, "PRIEST"))
local yes, note = Graph:ObservedHolyModifier(state)
assert(yes and string.find(note, "engine spell power"),
    "observed Resurgence must be treated as already present in root power")
local power, reason, handled = Graph:ShieldBreakProjection(
    { facts={ priestShield=true } }, state)
assert(handled and power == nil and string.find(reason, "runtime evidence"),
    "future shield breaks must not receive guessed refund or Holy power")

active = false
state = {}; assert(Graph:Attach(state, "PRIEST"))
assert(not Graph:ObservedHolyModifier(state),
    "inactive Resurgence must not claim an observed modifier")
learned = false
state = {}; assert(Graph:Attach(state, "PRIEST")
    and state.priestResurgentShield.learned == false,
    "exact absence of the talent must remain representable")

learned = true
local original = GetSpellRecField
GetSpellRecField = function(id, field, array)
    local value = original(id, field, array)
    if id == 51477 and field == "effectBasePoints" and array then
        value[3] = 25
    end
    return value
end
Runtime:Invalidate()
assert(Runtime:Profile() == nil,
    "shifted result payload must invalidate the sealed topology")

print("ok: observed Resurgence with future dynamic shield break withheld")
