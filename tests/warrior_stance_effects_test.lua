XelAssist = { Game = { Player = {} } }
table.getn = table.getn or function(value)
    local count = 0
    while value[count + 1] ~= nil do count = count + 1 end
    return count
end

local classToken, talentId, talentRank, talentMaximum = "WARRIOR", 144, 0, 5
local calls = { class = 0, dbc = 0, talentId = 0, talent = 0 }

function UnitClass()
    calls.class = calls.class + 1
    return "Warrior", classToken
end

function GetTalentIDByIndex(tab, index)
    calls.talentId = calls.talentId + 1
    assert(tab == 3 and index == 9)
    return talentId
end

function GetTalentInfo(tab, index)
    calls.talent = calls.talent + 1
    assert(tab == 3 and index == 9)
    return nil, nil, nil, nil, talentRank, talentMaximum
end

local function row(auras, amounts, misc)
    local out = { effect = {}, effectApplyAuraName = {}, effectBasePoints = {},
        effectBaseDice = {}, effectDieSides = {}, effectImplicitTargetA = {},
        effectImplicitTargetB = {}, effectMiscValue = {} }
    local index
    for index = 1, 3 do
        local aura = auras[index] or 0
        local amount = amounts[index]
        out.effect[index] = aura ~= 0 and 6 or 0
        out.effectApplyAuraName[index] = aura
        out.effectBasePoints[index] = amount and amount - 1 or 0
        out.effectBaseDice[index] = amount and 1 or 0
        out.effectDieSides[index] = amount and 1 or 0
        out.effectImplicitTargetA[index] = aura ~= 0 and 1 or 0
        out.effectImplicitTargetB[index] = 0
        out.effectMiscValue[index] = misc[index] or 0
    end
    return out
end

local rows = {
    [21156] = row({ 10 }, { -20 }, { 127 }),
    [7376] = row({ 87, 79, 10 }, { -10, -10, 30 }, { 127, 127, 127 }),
    [7381] = row({ 52, 87, 10 }, { 3, 10, -20 }, { 0, 127, 127 }),
}
local defianceIds = { 12303, 12788, 12789, 12791, 12792 }
local defianceAmounts = { 4, 8, 12, 15, 20 }
local index
for index = 1, 5 do
    rows[defianceIds[index]] = row({ 10 }, { defianceAmounts[index] }, { 127 })
end

function GetSpellRecField(spellId, field)
    calls.dbc = calls.dbc + 1
    local values = rows[spellId] and rows[spellId][field]
    if not values then return nil end
    return { values[1], values[2], values[3] }
end

dofile("Game/Player/WarriorStanceEffects.lua")
local Effects = XelAssist.Game.Player.WarriorStanceEffects

local function close(actual, expected, message)
    assert(type(actual) == "number" and math.abs(actual - expected) < 0.000001,
        message .. ": " .. tostring(actual))
end

local snapshot = Effects:Snapshot()
assert(snapshot and snapshot.available and snapshot.exact
    and snapshot.talent.rank == 0,
    "an exact unallocated talent must still seal all stance evidence")
local battle = Effects:StanceProfile(snapshot, 17)
local defensive = Effects:StanceProfile(snapshot, 18)
local berserker = Effects:StanceProfile(snapshot, 19)
close(battle.threatMultiplier, 0.8, "Battle threat")
close(defensive.threatMultiplier, 1.3, "untalented Defensive threat")
close(defensive.damageDoneMultiplier, 0.9, "Defensive damage done")
close(defensive.damageTakenMultiplier, 0.9, "Defensive damage taken")
close(berserker.threatMultiplier, 0.8, "Berserker threat")
close(berserker.damageTakenMultiplier, 1.1, "Berserker damage taken")
assert(berserker.meleeCriticalPercent == 3,
    "Berserker must expose its exact melee critical modifier")

local rank
for rank = 1, 5 do
    Effects:Invalidate()
    talentRank = rank
    snapshot = Effects:Snapshot()
    defensive = Effects:StanceProfile(snapshot, 18)
    close(defensive.threatMultiplier,
        1.3 * (1 + defianceAmounts[rank] / 100),
        "Defensive plus exact Defiance rank " .. tostring(rank))
    assert(defensive.defianceSpellId == defianceIds[rank]
        and defensive.defianceThreatPercent == defianceAmounts[rank]
        and defensive.threatExact,
        "each allocated rank must bind its exact installed DBC row")
end

local state = { playerForm = { formID = 17 } }
assert(Effects:Attach(state) and state.playerThreat.exact
    and state.playerThreat.formID == 17,
    "root attachment must project the current exact form")
local apiCalls = calls.dbc + calls.talentId + calls.talent
GetSpellRecField = function() error("search must not read DBC") end
GetTalentIDByIndex = function() error("search must not read talents") end
GetTalentInfo = function() error("search must not read talents") end
assert(Effects:Project(state, 18), "future stance projection must be search-pure")
close(state.playerThreat.multiplier, 1.56, "rank-five projected threat")
close(state.playerStanceDamageDoneMultiplier, 0.9,
    "projected Defensive outgoing damage")
close(state.playerStanceDamageTakenMultiplier, 0.9,
    "projected Defensive incoming damage")
assert(state.playerThreat.formID == 18 and state.playerThreat.projected
    and apiCalls == calls.dbc + calls.talentId + calls.talent,
    "projection must use only the immutable root snapshot")
assert(Effects:Project(state, 19) and state.playerThreat.multiplier == 0.8
    and state.playerStanceDamageTakenMultiplier == 1.1,
    "a later branch transition must replace, not compound, stance effects")
local unknownForm = { playerForm = { available = false } }
assert(not Effects:Attach(unknownForm) and unknownForm.playerThreat
    and unknownForm.playerThreat.exact == false
    and unknownForm.playerThreat.minimum == 0.8
    and unknownForm.playerThreat.maximum == 1.56,
    "missing live stance must retain the DBC-sealed all-form threat bounds")

GetSpellRecField = function(spellId, field)
    calls.dbc = calls.dbc + 1
    local values = rows[spellId] and rows[spellId][field]
    return values and { values[1], values[2], values[3] } or nil
end
GetTalentIDByIndex = function() calls.talentId = calls.talentId + 1; return 999 end
GetTalentInfo = function() calls.talent = calls.talent + 1; return nil end
Effects:Invalidate()
local bounded = Effects:Snapshot()
defensive = Effects:StanceProfile(bounded, 18)
assert(bounded.available and not bounded.exact and not defensive.threatExact
    and defensive.threatMultiplier == nil,
    "an unverified talent identity must not fabricate exact Defensive threat")
close(defensive.threatMinimum, 1.3, "unknown Defiance lower bound")
close(defensive.threatMaximum, 1.56, "unknown Defiance upper bound")
close(defensive.damageTakenMultiplier, 0.9,
    "talent uncertainty must not erase exact stance mitigation")

GetTalentIDByIndex = function() return 144 end
GetTalentInfo = function() return nil, nil, nil, nil, 0, 5 end
rows[7376].effectMiscValue[1] = 1
Effects:Invalidate()
local broken = Effects:Snapshot()
assert(broken and not broken.available
    and string.find(broken.reason or "", "topology") ~= nil,
    "a mismatched school mask must fail the installed profile closed")
rows[7376].effectMiscValue[1] = 127

Effects:Invalidate()
classToken = "MAGE"
local priorDBC, priorTalent = calls.dbc, calls.talent
assert(Effects:Snapshot() == nil and calls.dbc == priorDBC
    and calls.talent == priorTalent,
    "another class must not pay for or receive Warrior evidence")

print("ok: exact DBC-sealed Warrior stance, Defiance and mitigation profiles")
