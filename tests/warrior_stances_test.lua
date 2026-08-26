-- Exact, localized-name-independent Warrior stance graph transitions.
XelAssist = { Game = { Player = {} }, Graph = {} }

local classToken, playerPresent = "WARRIOR", true
local talentID, talentRank, talentMaximum = 57, 3, 5

function UnitClass()
    return classToken == "WARRIOR" and "Warrior" or "Mage", classToken
end
function UnitExists(unit) return unit == "player" and playerPresent end
function GetTalentIDByIndex(tab, index)
    assert(tab == 1 and index == 2,
        "Tactical Mastery coordinates must match installed Talent.dbc")
    return talentID
end
function GetTalentInfo(tab, index)
    assert(tab == 1 and index == 2,
        "Tactical Mastery rank query must use its exact tree entry")
    return "localized text is irrelevant", "icon", 0, 1,
        talentRank, talentMaximum
end

local function stance(formID)
    return {
        spellFamilyName = 4, spellFamilyFlags = 8388608,
        powerType = 1, manaCost = 0,
        effect = { 6, 0, 0 }, effectApplyAuraName = { 36, 0, 0 },
        effectMiscValue = { formID, 0, 0 },
        effectImplicitTargetA = { 1, 0, 0 },
        effectImplicitTargetB = { 0, 0, 0 },
    }
end

local records = {
    [2457] = stance(17), [71] = stance(18), [2458] = stance(19),
    [9001] = stance(18), [9002] = stance(18),
    [9003] = stance(5),
}
records[9001].spellFamilyName = 11
records[9002].effect[2] = 6
records[9002].effectApplyAuraName[2] = 16

function GetSpellRecField(spellId, field, copied)
    local row = records[spellId]
    if not row then return nil end
    local value = row[field]
    if copied and type(value) == "table" then
        return { value[1], value[2], value[3] }
    end
    return value
end

dofile("Graph/WarriorStances.lua")
dofile("Graph/FormRequirements.lua")
local Stances = XelAssist.Graph.WarriorStances
local Requirements = XelAssist.Graph.FormRequirements
XelAssist.Game.Player.WarriorStanceEffects = { Project = function(_, state, formID)
    local multiplier = formID == 18 and 1.56 or 0.8
    state.playerThreat = { actor = "player", playerOnly = true,
        formID = formID, exact = true, projected = true,
        multiplier = multiplier, minimum = multiplier, maximum = multiplier }
    return true
end }

local actions = {
    [17] = { name = "Posture inconnue A", spellId = 2457,
        facts = { kind = "form", warriorStance = true } },
    [18] = { name = "Unbekannte Haltung B", spellId = 71,
        facts = { kind = "form", warriorStance = true } },
    [19] = { name = "姿勢 C", spellId = 2458,
        facts = { kind = "form", warriorStance = true } },
}

local formID
for formID = 17, 19 do
    local evidence, reason, recognized = Stances:Classify(
        actions[formID].spellId)
    assert(evidence and evidence.valid == true
        and evidence.targetForm == formID
        and evidence.targetMask == 2 ^ (formID - 1)
        and reason == nil and recognized == true,
        "each installed stance topology must classify without its name")
end

local invalid, invalidReason, invalidRecognized = Stances:Classify(9001)
assert(invalid and invalid.valid == false and invalidRecognized == true
    and invalidReason == "Warrior stance DBC topology is incomplete",
    "a recognized stance destination with the wrong family must fail closed")
invalid, invalidReason, invalidRecognized = Stances:Classify(9002)
assert(invalid and invalid.valid == false and invalidRecognized == true,
    "an extra active effect must invalidate the exact stance topology")
assert(Stances:Classify(9003) == nil,
    "a non-Warrior shapeshift destination must not classify as a stance")

for formID = 17, 19 do
    local facts, reason, recognized = Stances:InferKnowledge(
        actions[formID].spellId)
    assert(facts and facts.kind == "form" and facts.kindExact == true
        and facts.self == true and facts.fixedTarget == "player"
        and facts.warriorStance == true and facts.inferred == true
        and facts.preferred == nil and facts.order == nil
        and reason == nil and recognized == true,
        "stance discovery must describe mechanics without a rotation")
    actions[formID].facts = facts
end
classToken = "MAGE"
assert(Stances:InferKnowledge(71) == nil,
    "non-Warriors must not discover Warrior stance actions")
classToken = "WARRIOR"

local retention = Stances:RetentionSnapshot()
assert(retention.available == true and retention.exact == true
    and retention.talentID == 57 and retention.rank == 3
    and retention.retainedRageCap == 15
    and retention.serverRawRageCap == 150,
    "Tactical Mastery rank three must retain exactly 15 displayed rage")

local function state(currentForm, rage)
    return {
        resourceType = 1, resource = rage, resourceMax = 100,
        playerResourceExact = true, role = "auto",
        tank = currentForm == 18,
        playerForm = { available = true, formID = currentForm },
        actors = { player = { resourceType = 1, resource = rage,
            resourceMax = 100, resourceExact = true } },
        playerThreat = { actor = "player", playerOnly = true,
            formID = currentForm, stance = "battle", exact = true,
            multiplier = 0.8, minimum = 0.8, maximum = 0.8 },
    }
end

local function copyState(source)
    local out, key, value = {}, nil, nil
    for key, value in pairs(source) do out[key] = value end
    out.playerForm = {}
    for key, value in pairs(source.playerForm) do
        if type(value) == "table" then
            out.playerForm[key] = {}
            local innerKey, innerValue
            for innerKey, innerValue in pairs(value) do
                out.playerForm[key][innerKey] = innerValue
            end
        else out.playerForm[key] = value end
    end
    out.actors = { player = {} }
    for key, value in pairs(source.actors.player) do
        out.actors.player[key] = value
    end
    return out
end

local root = state(17, 42)
assert(Stances:Attach(root) == true
    and root.playerForm.warriorRageRetention.retainedRageCap == 15,
    "root state must carry sealed exact retention evidence")
local savedDBC = GetSpellRecField
local ordinaryReads = 0
GetSpellRecField = function(...)
    ordinaryReads = ordinaryReads + 1
    return savedDBC(...)
end
local ordinary = { kind = "damage", ranged = true }
local ordinaryCopy = Stances:CaptureFacts(
    { name = "ordinary spell", spellId = 9001 }, ordinary)
Stances:CaptureFacts({ name = "another ordinary spell", spellId = 9002 },
    { kind = "heal" })
assert(ordinaryReads == 0 and ordinaryCopy ~= ordinary
    and ordinaryCopy.kind == "damage" and ordinaryCopy.ranged == true,
    "ordinary root actions must never be reclassified through Warrior DBC reads")
GetSpellRecField = function() error("sealed stance capture reread DBC") end
local sealedDefensive = {}
for key, value in pairs(actions[18].facts) do sealedDefensive[key] = value end
sealedDefensive.gcd = 1.5
local defensiveFacts = Stances:CaptureFacts(actions[18], sealedDefensive)
GetSpellRecField = savedDBC
assert(defensiveFacts.warriorStanceEvidence.valid == true
    and defensiveFacts.cost == 0 and defensiveFacts.powerType == 1,
    "root tooltip capture must seal stance identity and zero cost")

-- Production-shaped two-edge runway: the first edge changes stance; only then
-- may the ordinary DBC form gate admit the otherwise unchanged tank action.
local tankActionTooltip = { stances = 131072 }
assert(Requirements:Blocker(root, tankActionTooltip)
    == "required player form inactive",
    "the tank action must be illegal in Battle Stance")
local prepared, reason, handled = Stances:Prepare(
    actions[18], root, defensiveFacts)
assert(prepared and reason == nil and handled == true
    and prepared.warriorStanceTransition.sourceForm == 17
    and prepared.warriorStanceTransition.targetForm == 18
    and prepared.warriorStanceTransition.retentionCap == 15,
    "the first edge must project exact Battle-to-Defensive semantics")
local future = copyState(root)
assert(Stances:Apply(future, { action = actions[18], tooltip = prepared }),
    "the prepared stance edge must apply")
assert(future.playerForm.formID == 18 and future.resource == 15
    and future.actors.player.resource == 15
    and future.actors.player.resourceExact == true and future.tank == true,
    "the stance edge must synchronize form, retained rage, actor, and auto role")
assert(Requirements:Blocker(future, tankActionTooltip) == nil,
    "the second edge must become legal from projected Defensive Stance")
assert(root.playerForm.formID == 17 and root.resource == 42
    and root.actors.player.resource == 42 and root.tank == false,
    "applying a future edge must not mutate its root state")
assert(root.playerThreat.exact == true and root.playerThreat.formID == 17
    and future.playerThreat.exact == true
    and future.playerThreat.formID == 18
    and future.playerThreat.multiplier == 1.56,
    "a transition must replace stale threat with the sealed target-form profile")

local same, sameReason = Stances:Prepare(actions[17], root,
    Stances:CaptureFacts(actions[17], actions[17].facts))
assert(same == nil and sameReason == "Warrior stance already active",
    "the active stance must not be a graph edge")

local score = { action = actions[18], tooltip = defensiveFacts,
    power = 99, expectedPower = 99, effectivePower = 99,
    value = 99, estimated = true }
assert(Stances:Score(score) and score.value == 0
    and score.power == 0 and score.expectedPower == 0
    and score.effectivePower == 0 and score.estimated == false,
    "stance value must be neutral until a later edge benefits")

talentID = 999
local unknown = state(17, 30)
assert(Stances:Attach(unknown)
    and unknown.playerForm.warriorRageRetention.exact == false,
    "a mismatched talent identity must remain sealed as unavailable")
local blocked, blockedReason = Stances:Prepare(
    actions[18], unknown, defensiveFacts)
assert(blocked == nil
    and blockedReason == "Warrior stance rage retention unavailable",
    "positive rage must fail closed without exact retention evidence")
unknown.resource, unknown.actors.player.resource = 0, 0
local zero, zeroReason = Stances:Prepare(actions[18], unknown, defensiveFacts)
assert(zero == nil
    and zeroReason == "Warrior stance rage retention unavailable",
    "even zero current rage must fail closed because rage may change before application")

talentID, talentRank = 57, "3"
local coerced = Stances:RetentionSnapshot()
assert(coerced.available == false and coerced.exact == false,
    "coerced rank values must never become exact graph evidence")
talentRank = 3

local rageUnknown = state(17, 20)
Stances:Attach(rageUnknown)
rageUnknown.playerResourceExact = false
local unavailable, unavailableReason = Stances:Prepare(
    actions[18], rageUnknown, defensiveFacts)
assert(unavailable == nil
    and unavailableReason == "Warrior rage state unavailable",
    "inexact future rage must block the stance transition")

local berserker = state(18, 12)
Stances:Attach(berserker)
local berserkerFacts = Stances:CaptureFacts(actions[19], actions[19].facts)
local toBerserker = Stances:Prepare(actions[19], berserker, berserkerFacts)
assert(toBerserker
    and toBerserker.warriorStanceTransition.targetMask == 262144,
    "Berserker transition must preserve its exact DBC form mask")
assert(Stances:Apply(berserker, { action = actions[19],
        tooltip = toBerserker })
    and berserker.playerForm.formID == 19 and berserker.resource == 12
    and berserker.tank == false,
    "rage below the exact cap must survive while auto-role leaves tank stance")

print("ok: exact Warrior stance edges unlock gated future actions neutrally")
