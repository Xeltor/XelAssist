XelAssist = { Graph = {} }

local classToken, playerPresent = "DRUID", true
local talentID, talentRank, talentMaximum = 286, 5, 5
local talentSpellIds = {
    [1] = 17056, [2] = 17058, [3] = 17059,
    [4] = 17060, [5] = 17061,
}

function UnitClass(unit)
    assert(unit == "player")
    return "Druide", classToken
end

function UnitExists(unit)
    assert(unit == "player")
    return playerPresent and 1 or nil
end

function GetTalentIDByIndex(tab, index)
    assert(tab == 3 and index == 2)
    return talentID
end

function GetTalentInfo(tab, index)
    assert(tab == 3 and index == 2)
    return nil, nil, 1, 3, talentRank, talentMaximum
end

function GetTalentSpellID(tab, index, rank)
    assert(tab == 3 and index == 2)
    return talentSpellIds[rank]
end

local function triple(first, second, third)
    return { first or 0, second or 0, third or 0 }
end

local records = {}
local rank
for rank = 1, 5 do
    records[talentSpellIds[rank]] = {
        spellFamilyName = 7, spellIconID = 238,
        effect = triple(6), effectApplyAuraName = triple(4),
        effectImplicitTargetA = triple(1),
        effectBasePoints = triple(rank * 20 - 1),
        effectMiscValue = triple(0),
    }
end
records[17057] = {
    spellFamilyName = 0, spellIconID = 238,
    effect = triple(30, 6), effectApplyAuraName = triple(0, 94),
    effectImplicitTargetA = triple(1, 1),
    effectBasePoints = triple(99, 0), effectMiscValue = triple(1, 0),
}
records[17099] = {
    spellFamilyName = 0, spellIconID = 210,
    effect = triple(30), effectApplyAuraName = triple(0),
    effectImplicitTargetA = triple(1),
    effectBasePoints = triple(39), effectMiscValue = triple(3),
}

function GetSpellRecField(spellId, field, copied)
    local record = records[spellId]
    local value = record and record[field]
    if copied == 1 and type(value) == "table" then
        return { value[1], value[2], value[3] }
    end
    return value
end

dofile("Graph/DruidShiftResources.lua")
local Shift = XelAssist.Graph.DruidShiftResources

local evidence = Shift:Snapshot()
assert(evidence.available == true and evidence.exact == true
    and evidence.talentID == 286 and evidence.rank == 5
    and evidence.spellId == 17061 and evidence.chance == 100
    and evidence.guaranteed == true and evidence.catEnergy == 40
    and evidence.energyTriggerSpellId == 17099
    and evidence.bearRage == 10
    and evidence.rageTriggerSpellId == 17057,
    "rank-five installed evidence must seal guaranteed Furor payloads")

local function snapshot(formID, rage, energy)
    return { available = true, formID = formID, primaryType = 0,
        powers = {
            [0] = { current = 500, maximum = 1000,
                currentKnown = true, maximumKnown = true },
            [1] = { current = rage, maximum = 100,
                currentKnown = true, maximumKnown = true },
            [3] = { current = energy, maximum = 100,
                currentKnown = true, maximumKnown = true },
        } }
end

local state = { druidFormState = snapshot(0, 25, 80) }
assert(Shift:Attach(state) == true
    and state.druidFormState.shiftResourceEvidence.guaranteed == true,
    "root state must retain copied exact shift-resource evidence")

local cat, enriched, reason = Shift:Bind(state.druidFormState,
    { kind = "shift", sourceForm = 0, targetForm = 1,
        targetPrimary = 3, destinationPowerKnown = false })
assert(enriched == true and reason == nil
    and cat.destinationPowerKnown == false
    and cat.destinationPowerMinimumKnown == true
    and cat.destinationPowerMinimum == 40
    and cat.druidShiftResourceFloor.powerType == 3
    and cat.druidShiftResourceFloor.observedSourcePower == 80
    and cat.druidShiftResourceFloor.triggerSpellId == 17099,
    "Cat transition must expose a conservative guaranteed 40-energy floor")

-- Search and application must use only the sealed copy; no talent, Unit, or
-- DBC API may be consulted after the mutable root boundary.
local savedUnitClass, savedUnitExists = UnitClass, UnitExists
local savedTalentID, savedTalentInfo = GetTalentIDByIndex, GetTalentInfo
local savedTalentSpell, savedDBC = GetTalentSpellID, GetSpellRecField
UnitClass = function() error("live class read during graph search") end
UnitExists = function() error("live unit read during graph search") end
GetTalentIDByIndex = function() error("live talent identity read") end
GetTalentInfo = function() error("live talent rank read") end
GetTalentSpellID = function() error("live talent spell read") end
GetSpellRecField = function() error("live DBC read during graph search") end

state.druidFormState.formID, state.druidFormState.primaryType = 1, 3
local catSlot = state.druidFormState.powers[3]
catSlot.priorObservedCurrent, catSlot.priorObservedMaximum =
    catSlot.current, catSlot.maximum
catSlot.current, catSlot.maximum = nil, nil
catSlot.currentKnown, catSlot.maximumKnown = false, false
assert(Shift:Apply(state.druidFormState, cat) == true,
    "sealed Cat resource floor must apply after the form edge")
local floor, known = Shift:ResourceFloor(state.druidFormState)
assert(floor == 40 and known == true and catSlot.currentKnown == false,
    "the graph must retain a usable lower bound without claiming exact energy")

UnitClass, UnitExists = savedUnitClass, savedUnitExists
GetTalentIDByIndex, GetTalentInfo = savedTalentID, savedTalentInfo
GetTalentSpellID, GetSpellRecField = savedTalentSpell, savedDBC

local bearState = snapshot(0, 25, 80)
bearState.shiftResourceEvidence = evidence
local bear, bearEnriched = Shift:Bind(bearState,
    { kind = "shift", sourceForm = 0, targetForm = 5,
        targetPrimary = 1, destinationPowerKnown = false }, true)
assert(bearEnriched == true and bear.destinationPowerMinimum == 10
    and bear.druidShiftResourceFloor.powerType == 1
    and bear.druidShiftResourceFloor.combatStable == true
    and bear.druidShiftResourceFloor.triggerSpellId == 17057,
    "in-combat Bear transition must expose the exact ten-rage Furor floor")
bearState.formID, bearState.primaryType = 5, 1
local bearSlot = bearState.powers[1]
bearSlot.priorObservedCurrent, bearSlot.priorObservedMaximum =
    bearSlot.current, bearSlot.maximum
bearSlot.current, bearSlot.maximum = nil, nil
bearSlot.currentKnown, bearSlot.maximumKnown = false, false
assert(Shift:Apply(bearState, bear) == true,
    "sealed in-combat Bear rage floor must apply after the form edge")
local bearFloor, bearKnown = Shift:ResourceFloor(bearState)
assert(bearFloor == 10 and bearKnown == true,
    "in-combat Bear Furor must expose spendable displayed rage")

local idleBear = snapshot(0, 25, 80)
idleBear.shiftResourceEvidence = evidence
local idleTransition, idleEnriched = Shift:Bind(idleBear,
    { kind = "shift", sourceForm = 0, targetForm = 5,
        targetPrimary = 1, destinationPowerKnown = false }, false)
assert(idleEnriched == false and idleTransition.destinationPowerMinimum == nil,
    "out-of-combat Bear rage must remain unknown without decay timing")

local capped = snapshot(0, 95, 0)
capped.shiftResourceEvidence = evidence
local cappedBear, cappedEnriched = Shift:Bind(capped,
    { kind = "shift", sourceForm = 0, targetForm = 8, targetPrimary = 1,
        destinationPowerKnown = false }, true)
assert(cappedEnriched == true and cappedBear.destinationPowerMinimum == 10,
    "in-combat Dire Bear must share the exact ten-rage Furor floor")

local travel, travelEnriched = Shift:Bind(capped,
    { sourceForm = 0, targetForm = 3, targetPrimary = 0 })
assert(travel and travelEnriched == false
    and travel.druidShiftResourceFloor == nil,
    "noncombat forms must remain outside Furor resource projection")

talentRank = 4
Shift:Invalidate()
local probabilistic = Shift:Snapshot()
assert(probabilistic.available == true and probabilistic.exact == true
    and probabilistic.rank == 4 and probabilistic.chance == 80
    and probabilistic.guaranteed == false,
    "sub-max Furor must be observed but never promoted to a guaranteed floor")
local probabilisticState = snapshot(0, 20, 0)
probabilisticState.shiftResourceEvidence = probabilistic
local unchanged, changed, unavailableReason = Shift:Bind(probabilisticState,
    { kind = "shift", sourceForm = 0, targetForm = 1, targetPrimary = 3,
        destinationPowerKnown = false })
assert(unchanged and changed == false
    and unavailableReason == "guaranteed Furor evidence unavailable"
    and unchanged.druidShiftResourceFloor == nil,
    "probabilistic Furor must leave the conservative form edge unchanged")

talentRank = "5"
Shift:Invalidate()
assert(Shift:Snapshot().available == false,
    "coerced talent ranks must not become exact evidence")
talentRank = 5

talentID = 999
Shift:Invalidate()
assert(Shift:Snapshot().available == false,
    "a shifted talent tree identity must fail closed")
talentID = 286

records[17061].effectBasePoints[1] = 98
Shift:Invalidate()
assert(Shift:Snapshot().available == false,
    "a changed talent payload must fail closed")
records[17061].effectBasePoints[1] = 99

records[17099].effectMiscValue[1] = 0
Shift:Invalidate()
assert(Shift:Snapshot().available == false,
    "a changed energize power type must fail closed")
records[17099].effectMiscValue[1] = 3

records[17057].effectMiscValue[1] = 0
Shift:Invalidate()
local brokenBear = Shift:Snapshot()
assert(brokenBear.available == true and brokenBear.catEnergy == 40
    and brokenBear.bearRage == nil
    and brokenBear.bearReason == "Furor Bear energize payload unavailable",
    "a changed Bear payload must preserve Cat evidence and fail Bear closed")
local brokenBearState = snapshot(0, 0, 0)
brokenBearState.shiftResourceEvidence = brokenBear
local blockedBear, blockedBearEnriched = Shift:Bind(brokenBearState,
    { kind = "shift", sourceForm = 0, targetForm = 5,
        targetPrimary = 1, destinationPowerKnown = false }, true)
assert(blockedBearEnriched == false
    and blockedBear.druidShiftResourceFloor == nil,
    "invalid Bear payload must never create a rage floor")
bearState.shiftResourceEvidence = brokenBear
assert(Shift:Apply(bearState, bear) == false,
    "a stale sealed Bear transition must reject changed root payload evidence")
records[17057].effectMiscValue[1] = 1

classToken = "PALADIN"
Shift:Invalidate()
assert(Shift:Snapshot().available == false,
    "non-Druids must never receive Druid shift evidence")
classToken = "DRUID"
playerPresent = false
assert(Shift:Snapshot().available == false,
    "missing player identity must fail closed")
playerPresent = true

Shift:Invalidate()
local validAgain = Shift:Snapshot()
local replacement = snapshot(0, 0, 0)
replacement.shiftResourceEvidence = validAgain
local frozen = Shift:Bind(replacement,
    { kind = "shift", sourceForm = 0, targetForm = 1, targetPrimary = 3,
        destinationPowerKnown = false })
replacement.formID, replacement.primaryType = 5, 1
assert(Shift:Apply(replacement, frozen) == false,
    "a different projected form must reject stale floor evidence")

print("druid shift resources: ok")
