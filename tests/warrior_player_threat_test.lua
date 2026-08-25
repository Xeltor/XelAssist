-- Installed-client Warrior stance and Defiance threat multiplier evidence.
XelAssist = { Game = { Player = {} } }

local classToken = "WARRIOR"
local formID, stockForm, talentRank = 17, 1, 0
local formIDError, stockFormError, talentError = false, false, false
local formIDCalls, stockFormCalls, talentCalls = 0, 0, 0

function UnitClass()
    return classToken == "WARRIOR" and "Warrior" or "Mage", classToken
end
function GetShapeshiftFormID()
    formIDCalls = formIDCalls + 1
    if formIDError then error("form ID unavailable") end
    return formID
end
function GetShapeshiftForm()
    stockFormCalls = stockFormCalls + 1
    if stockFormError then error("stock form unavailable") end
    return stockForm
end
function GetTalentInfo(tab, index)
    talentCalls = talentCalls + 1
    assert(tab == 3 and index == 9, "Defiance talent coordinates drifted")
    if talentError then error("talent unavailable") end
    return "Defiance", "icon", 3, 4, talentRank, 5
end

dofile("Game/Player/Threat.lua")
local Threat = XelAssist.Game.Player.Threat

local function close(actual, expected, message)
    assert(type(actual) == "number" and math.abs(actual - expected) < 0.000001,
        message .. ": " .. tostring(actual))
end

local function reset()
    classToken = "WARRIOR"
    formID, stockForm, talentRank = 17, 1, 0
    formIDError, stockFormError, talentError = false, false, false
    formIDCalls, stockFormCalls, talentCalls = 0, 0, 0
end

local function exact(expected, stanceName)
    local value = Threat:Snapshot()
    assert(value and value.actor == "player" and value.playerOnly == true
        and value.component == "warriorStanceDefiance"
        and value.stance == stanceName and value.exact == true,
        stanceName .. " profile must be exact and player-only")
    close(value.multiplier, expected, stanceName .. " multiplier")
    close(value.minimum, expected, stanceName .. " minimum")
    close(value.maximum, expected, stanceName .. " maximum")
    return value
end

reset()
local battle = exact(0.8, "battle")
assert(battle.formID == 17 and battle.stanceSpellID == 2457
    and battle.stancePassiveSpellID == 21156
    and battle.defianceTalentID == 144
    and talentCalls == 0 and stockFormCalls == 0,
    "exact Battle form ID must not query inactive Defiance or stock fallback")

reset(); formID = 19
local berserker = exact(0.8, "berserker")
assert(berserker.formID == 19 and berserker.stanceSpellID == 2458
    and berserker.stancePassiveSpellID == 7381 and talentCalls == 0,
    "Berserker must use its exact installed-client -20% component")

local rank, expected
for rank = 0, 5 do
    reset(); formID, talentRank = 18, rank
    expected = 1.3 * (1 + 0.03 * rank)
    local defensive = exact(expected, "defensive")
    assert(defensive.formID == 18 and defensive.defianceRank == rank
        and defensive.stanceSpellID == 71
        and defensive.stancePassiveSpellID == 7376
        and defensive.defianceSpellID == ({ [1] = 12303,
            [2] = 12788, [3] = 12789, [4] = 12791, [5] = 12792 })[rank]
        and talentCalls == 1,
        "Defensive Stance must bind the exact Defiance rank")
end

reset(); formID = nil
GetShapeshiftFormID = nil
stockForm = 1
local stockBattle = exact(0.8, "battle")
assert(stockBattle.formID == 17 and stockFormCalls == 1
    and stockBattle.stanceSource == "stock Warrior stance index",
    "stock Battle index must be an exact bounded fallback")
stockForm, talentRank = 2, 2
local stockDefensive = exact(1.3 * 1.06, "defensive")
assert(stockDefensive.formID == 18 and stockDefensive.defianceRank == 2,
    "stock Defensive index must retain exact Defiance evidence")
stockForm = 3
exact(0.8, "berserker")

reset()
GetShapeshiftFormID = function()
    formIDCalls = formIDCalls + 1
    error("form ID unavailable")
end
stockForm, talentRank = 2, 5
local recovered = exact(1.3 * 1.15, "defensive")
assert(recovered.stanceSource == "stock Warrior stance index",
    "a failed optional form-ID API must fall back to stock evidence")

reset()
GetShapeshiftFormID = nil
GetShapeshiftForm = nil
talentRank = 2
local unknownStance = Threat:Snapshot()
assert(unknownStance and not unknownStance.exact
    and unknownStance.multiplier == nil and unknownStance.stance == nil
    and unknownStance.defianceRank == 2,
    "missing stance must remain a range even with exact Defiance evidence")
close(unknownStance.minimum, 0.8, "unknown stance lower bound")
close(unknownStance.maximum, 1.3 * 1.06,
    "known Defiance rank must tighten the unknown-stance upper bound")

reset()
GetShapeshiftFormID = nil
GetShapeshiftForm = function() return 2 end
GetTalentInfo = nil
local unknownDefiance = Threat:Snapshot()
assert(unknownDefiance and unknownDefiance.stance == "defensive"
    and not unknownDefiance.exact and unknownDefiance.multiplier == nil,
    "missing Defiance must not fabricate an exact Defensive multiplier")
close(unknownDefiance.minimum, 1.3, "Defensive lower bound")
close(unknownDefiance.maximum, 1.3 * 1.15, "Defensive upper bound")

reset()
GetShapeshiftFormID = nil
GetShapeshiftForm = nil
GetTalentInfo = nil
local unknownAll = Threat:Snapshot()
assert(unknownAll and not unknownAll.exact and unknownAll.multiplier == nil,
    "missing Warrior evidence must remain explicitly inexact")
close(unknownAll.minimum, 0.8, "fully unknown lower bound")
close(unknownAll.maximum, 1.3 * 1.15, "fully unknown upper bound")

reset()
GetShapeshiftFormID = function() return 18 end
GetShapeshiftForm = function() return 2 end
GetTalentInfo = function() return "Defiance", "icon", 3, 4, "5", 5 end
local coerced = Threat:Snapshot()
assert(coerced and not coerced.exact and coerced.multiplier == nil
    and coerced.defianceRank == nil,
    "coerced talent ranks must not pass as exact runtime evidence")

reset()
GetShapeshiftFormID = function() return "18" end
GetShapeshiftForm = function() return "2" end
GetTalentInfo = nil
local coercedForm = Threat:Snapshot()
assert(coercedForm and coercedForm.stance == nil and not coercedForm.exact,
    "coerced stance values must remain unknown")

reset()
classToken = "MAGE"
local formCallsBefore, talentCallsBefore = formIDCalls, talentCalls
assert(Threat:Snapshot() == nil and formIDCalls == formCallsBefore
    and talentCalls == talentCallsBefore,
    "non-Warriors must not receive or pay for Warrior threat evidence")

reset()
GetShapeshiftFormID = function() return 18 end
GetTalentInfo = function() return "Defiance", "icon", 3, 4, 5, 5 end
local first = Threat:Snapshot()
first.minimum, first.source = 99, "mutated test value"
local second = Threat:Snapshot()
close(second.minimum, 1.3 * 1.15, "snapshots must not share mutable values")
assert(second.source ~= "mutated test value" and second.exact,
    "each threat profile must be an immutable fresh snapshot")

print("ok: exact bounded Warrior stance and Defiance player threat evidence")
