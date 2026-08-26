local function expect(value, message)
    if not value then error(message or "expectation failed") end
end

table.getn = table.getn or function(values) return #values end
XelAssist = { Game = { Player = {} }, Graph = {} }

local arrays = {
    effect = { 2, 3, 0 }, effectDieSides = { 22, 0, 0 },
    effectBaseDice = { 1, 0, 0 }, effectDicePerLevel = { 0, 0, 0 },
    effectRealPointsPerLevel = { 0, 0, 0 },
    effectBasePoints = { 138, 0, 0 },
    effectImplicitTargetA = { 25, 25, 0 },
    effectImplicitTargetB = { 0, 0, 0 },
    effectApplyAuraName = { 0, 0, 0 }, effectAmplitude = { 0, 0, 0 },
    effectTriggerSpell = { 0, 0, 0 },
}
local record = { school = 1, category = 1162, baseLevel = 35,
    spellLevel = 35, categoryRecoveryTime = 40000, rangeIndex = 34,
    startRecoveryCategory = 133, startRecoveryTime = 1000,
    spellFamilyName = 6 }
for field, value in pairs(arrays) do record[field] = value end

UnitClass = function() return "Localized", "PRIEST" end
GetSpellName = function() error("Chastise must not use localized names") end
GetSpellRecField = function(spellId, field, copied)
    expect(spellId == 51478, "only exact Chastise identity may be queried")
    local value = record[field]
    expect(value ~= nil, "missing fixture field " .. tostring(field))
    if copied and type(value) == "table" then
        return { value[1], value[2], value[3] }
    end
    return value
end

dofile("Game/Player/PriestChastise.lua")
dofile("Game/ActionInference.lua")
local C = XelAssist.Game.Player.PriestChastise
local facts, reason, handled = C:InferKnowledge(51478)
expect(handled and facts and facts.kind == "damage", reason)
expect(facts.recipientRelation == "hostile"
    and facts.recipientRelationExact == true
    and facts.friendlyBranchWithheld == true,
    "only the exact hostile Chastise lane may enter graph targeting")
local evidence = C:Evidence(facts)
expect(evidence and evidence.damageLow == 139 and evidence.damageHigh == 160
    and evidence.damageAverage == 149.5 and evidence.cooldown == 40,
    "hostile damage and cooldown evidence must remain exact")
expect(evidence.allyMinimumHealthFraction == 0.80
    and evidence.allyMinimumLevel == 35
    and evidence.friendlyHasteSpellId == 51481
    and evidence.friendlyCriticalHasteSpellId == 52658,
    "withheld friendly health, level and critical-duration gates must stay visible")
local dispatched, dispatchedReason, dispatchedHandled =
    XelAssist.Game.ActionInference:ClassKnowledge(51478)
expect(dispatchedHandled and dispatched and dispatched.priestChastise,
    dispatchedReason or "class inference did not dispatch Chastise")

local ordinary, _, ordinaryHandled = C:InferKnowledge(585)
expect(not ordinary and not ordinaryHandled,
    "ordinary Priest spells must fall through")
local original = record.effectImplicitTargetA
record.effectImplicitTargetA = { 6, 25, 0 }
C:Invalidate()
local invalid, invalidReason, invalidHandled = C:InferKnowledge(51478)
expect(not invalid and invalidHandled
    and string.find(invalidReason or "", "topology"),
    "changed polymorphic target topology must fail closed")
record.effectImplicitTargetA = original

print("ok: exact hostile Chastise lane and withheld polymorphic ally branch")
