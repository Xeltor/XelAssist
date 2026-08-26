-- Direct-damage Rogue finishers retain points only when a mechanically legal
-- builder improves their measured energy/time cycle and the observed hostile
-- is likely to survive long enough to liquidate the added point.
XelAssist = { Graph = {} }
table.getn = table.getn or function(values) return #values end
dofile("Graph/RogueComboInvestment.lua")
local Investment = XelAssist.Graph.RogueComboInvestment

local function close(left, right)
    return math.abs(left - right) < 0.000001
end

local function state(points, lower, upper)
    return {
        combo = points, targetGUID = "target-a", targetHealth = 1000,
        targetHealthExact = true, resourceType = 3, resource = 100, time = 0,
        playerResourceClock = { verified = true, resourceType = 3,
            externalEnergizeExcluded = true, amount = 20, interval = 2 },
        targetSurvival = lower and { available = true, incomingDps = 50,
            timeToDie = (lower + upper) / 2,
            lowerTimeToDie = lower, upperTimeToDie = upper } or nil,
    }
end

local function finisher(value, reason, owner)
    return {
        action = { spellId = 2098, facts = { kind = "damage", combo = true } },
        tooltip = { spellFamilyName = 8, comboSpendAll = true,
            comboBonus = 5 },
        targetGUID = owner or "target-a", comboTargetGUID = owner or "target-a",
        targetRelation = "hostile", comboAvailability = 1,
        rawPower = 8.5, power = 8.5, effectivePower = 8.5,
        costKnown = true, cost = 30, valueDowntime = 1.5,
        wait = 0, cast = 0, value = value or 320,
        reason = reason or "best immediate value",
        resistance = { landChance = 1, decisionMultiplier = 1 },
    }
end

local function builder(raw, cost, owner, spellId)
    return {
        action = { spellId = spellId or 1752,
            facts = { kind = "builder" } },
        tooltip = { spellFamilyName = 8, comboGain = 1 },
        targetGUID = owner or "target-a", targetRelation = "hostile",
        rawPower = raw or 11, power = raw or 11,
        costKnown = true, cost = cost or 40, valueDowntime = 1.5,
        wait = 0, cast = 0, value = 330, reason = "best immediate value",
        resistance = { landChance = 1, decisionMultiplier = 1 },
    }
end

local longState = state(1, 10, 20)
local lowFinisher, ordinaryBuilder = finisher(350), builder()
assert(lowFinisher.value > ordinaryBuilder.value,
    "the representative premature finisher must begin above its builder")
assert(Investment:Adjust({ lowFinisher, ordinaryBuilder }, longState) == 1,
    "a surviving target and more efficient next-point cycle must be handled")
local evidence = lowFinisher.rogueComboInvestment
assert(evidence and evidence.points == 1 and evidence.nextPoints == 2
    and close(evidence.currentRate, 19.5 / 7)
    and close(evidence.nextRate, 35.5 / 11)
    and evidence.retentionSurvival == 1
    and evidence.liquidationAt == 3
    and evidence.extraBuilderAttempts == 1,
    "the correction must expose the exact compared cycle and survival window")
assert(lowFinisher.value < ordinaryBuilder.value
    and lowFinisher.comboEfficiencyPenalty > 0
    and ordinaryBuilder.reason
        == "retains combo points for a more efficient damage cycle",
    "a better next-point cycle must make the efficient builder outrank the spend")

local lethal, lethalBuilder = finisher(1020, "finishes the target"), builder()
assert(Investment:Adjust({ lethal, lethalBuilder }, longState) == 0
    and lethal.value == 1020 and lethal.value > lethalBuilder.value
    and lethal.rogueComboInvestment == nil,
    "an exact lethal low-point finisher must never be held")

local imminentState = state(1, 0.5, 2)
local imminent, imminentBuilder = finisher(310), builder()
imminent.comboEfficiencyPenalty = 50
assert(Investment:Adjust({ imminent, imminentBuilder }, imminentState) == 0
    and imminent.value == 360 and imminent.value > imminentBuilder.value
    and imminent.comboEfficiencyPenalty == nil
    and imminent.rogueComboInvestment.decision == "points are at imminent risk",
    "imminent loss must release points and supersede the generic fallback")

local partialState = state(1, 2, 4)
local partial, partialBuilder = finisher(350), builder()
assert(Investment:Adjust({ partial, partialBuilder }, partialState) == 1
    and close(partial.rogueComboInvestment.retentionSurvival, 0.5),
    "an observed survival interval must proportionally bound retention value")
assert(close(partial.comboEfficiencyPenalty,
    lowFinisher.comboEfficiencyPenalty * 0.5),
    "only the survivable half of the cycle improvement may be reserved")

local resistedState = state(1, 4, 6)
local resisted, resistedBuilder = finisher(), builder()
resistedBuilder.resistance.landChance = 0.5
resistedBuilder.resistance.decisionMultiplier = 0.5
assert(Investment:Adjust({ resisted, resistedBuilder }, resistedState) == 1,
    "a lossy but efficient builder cycle must still be compared")
local resistedEvidence = resisted.rogueComboInvestment
assert(resistedEvidence.extraBuilderAttempts == 2
    and close(resistedEvidence.liquidationAt, 4.5)
    and close(resistedEvidence.retentionSurvival, 0.75),
    "failed builder attempts must extend the point-liquidation window")

local unknownState = state(1)
local unknown, unknownBuilder = finisher(), builder()
unknown.value, unknown.comboEfficiencyPenalty = 270, 50
assert(Investment:Adjust({ unknown, unknownBuilder }, unknownState) == 0
    and unknown.value == 270 and unknown.comboEfficiencyPenalty == 50,
    "missing survival evidence must fail closed without erasing the fallback")

local efficient = finisher()
efficient.rawPower = 101
efficient.tooltip.comboBonus = 1
efficient.cost = 10
efficient.value, efficient.comboEfficiencyPenalty = 270, 50
local weakBuilder = builder(0, 40)
assert(Investment:Adjust({ efficient, weakBuilder }, longState) == 0
    and efficient.value == 320 and efficient.comboEfficiencyPenalty == nil
    and efficient.rogueComboInvestment.decision
        == "spend cycle is at least as efficient",
    "a genuinely more efficient low-point cycle must supersede the fallback")

local fallbackReplacement, replacementBuilder = finisher(), builder()
fallbackReplacement.value, fallbackReplacement.comboEfficiencyPenalty = 300, 50
assert(Investment:Adjust(
    { fallbackReplacement, replacementBuilder }, longState) == 1
    and close(fallbackReplacement.value, lowFinisher.value)
    and close(fallbackReplacement.comboEfficiencyPenalty,
        lowFinisher.comboEfficiencyPenalty),
    "complete cycle evidence must replace rather than stack on the generic penalty")

local otherTarget, localBuilder = finisher(), builder(11, 40, "target-b")
assert(Investment:Adjust({ otherTarget, localBuilder }, longState) == 0,
    "a builder that transfers ownership to another hostile cannot retain these points")

local uncertainState = state(1.5, 10, 20)
local uncertain, uncertainBuilder = finisher(), builder()
assert(Investment:Adjust({ uncertain, uncertainBuilder }, uncertainState) == 0,
    "a non-integral conditional point state must withhold the renewal model")

local branchUncertain = state(2, 10, 20)
branchUncertain.comboBranches = {
    { targetGUID = "target-a", points = 1, probability = 0.5 },
    { targetGUID = "target-a", points = 3, probability = 0.5 },
}
local averaged, averagedBuilder = finisher(), builder()
assert(Investment:Adjust({ averaged, averagedBuilder }, branchUncertain) == 0,
    "an integral average across different point branches is not exact evidence")

local otherObserved = state(1, 10, 20)
otherObserved.targetGUID = "target-b"
local unseenTarget, unseenBuilder = finisher(), builder()
assert(Investment:Adjust({ unseenTarget, unseenBuilder }, otherObserved) == 0,
    "selected-target survival evidence cannot price another hostile's points")

local starvedState = state(1, 5, 10)
starvedState.resource = 0
local starved, starvedBuilder = finisher(), builder()
assert(Investment:Adjust({ starved, starvedBuilder }, starvedState) == 1
    and close(starved.rogueComboInvestment.liquidationAt, 8.5)
    and close(starved.rogueComboInvestment.retentionSurvival, 0.3),
    "liquidation must include the exact energy needed for builder and finisher")

local druidFinisher, druidBuilder = finisher(), builder()
druidFinisher.tooltip.spellFamilyName = 7
druidBuilder.tooltip.spellFamilyName = 7
assert(Investment:Adjust({ druidFinisher, druidBuilder }, longState) == 0,
    "Rogue family evidence must prevent cross-class combo policy")

local noClock = state(1, 10, 20)
noClock.playerResourceClock.externalEnergizeExcluded = false
local unsealed, unsealedBuilder = finisher(), builder()
assert(Investment:Adjust({ unsealed, unsealedBuilder }, noClock) == 0,
    "an unsealed energy source must not invent steady-state efficiency")

local apiCalls = 0
UnitClass = function() apiCalls = apiCalls + 1; error("search API read") end
GetTime = UnitClass
UnitMana = UnitClass
GetSpellRecField = UnitClass
local pureFinisher, pureBuilder = finisher(), builder()
assert(Investment:Adjust({ pureFinisher, pureBuilder }, longState) == 1
    and apiCalls == 0,
    "candidate adjustment must remain API-pure inside graph search")

print("ok: Rogue combo investment follows cycle efficiency and target survival")
