local function expect(value, message)
    if not value then error(message or "expectation failed") end
end

table.getn = table.getn or function(values) return #values end

local function near(actual, expected, message)
    if math.abs(actual - expected) > 0.0001 then
        error((message or "values differ") .. ": " .. tostring(actual)
            .. " ~= " .. tostring(expected))
    end
end

XelAssist = { Game = { Player = {} }, Graph = {} }

local PI = 10060
local arrays = {
    effect = { 6, 6, 0 }, effectDieSides = { 1, 1, 0 },
    effectBaseDice = { 1, 1, 0 }, effectDicePerLevel = { 0, 0, 0 },
    effectRealPointsPerLevel = { 0, 0, 0 },
    effectBasePoints = { 19, 19, 0 }, effectImplicitTargetA = { 21, 21, 0 },
    effectImplicitTargetB = { 0, 0, 0 },
    effectApplyAuraName = { 136, 79, 0 }, effectAmplitude = { 0, 0, 0 },
    effectMiscValue = { 126, 126, 0 }, effectTriggerSpell = { 0, 0, 0 },
    effectPointsPerComboPoint = { 0, 0, 0 },
}
local record = {
    school = 1, category = 0, castUI = 0, mechanic = 0,
    attributes = 327680, attributesEx = 0, attributesEx2 = 0,
    attributesEx3 = 0, attributesEx4 = 0, stances = 0, stancesNot = 0,
    castingTimeIndex = 1, recoveryTime = 180000, categoryRecoveryTime = 0,
    durationIndex = 8, powerType = 0, manaCost = 0, manaCostPerlevel = 0,
    manaCostPercentage = 0, rangeIndex = 4, speed = 0,
    startRecoveryCategory = 0, startRecoveryTime = 0,
    spellFamilyName = 6, spellFamilyFlags = 2147483648,
    maxAffectedTargets = 0, dmgClass = 0, preventionType = 1,
}
for field, value in pairs(arrays) do record[field] = value end

local schools = { [589] = 5, [585] = 1, [2054] = 1, [6603] = 0 }
local auraList, modifierFlat, modifierPercent = {}, 0, 0
local dbcCalls, modifierCalls, durationCalls, auraCalls = 0, 0, 0, 0

UnitClass = function() return "Localized", "PRIEST" end
GetSpellName = function()
    error("Power Infusion mechanics must not inspect localized names")
end
GetSpellRecField = function(spellId, field, copied)
    dbcCalls = dbcCalls + 1
    if spellId ~= PI then
        if field == "school" and schools[spellId] ~= nil then
            return schools[spellId]
        end
        error("unexpected DBC query")
    end
    local value = record[field]
    if value == nil then error("missing DBC fixture field " .. tostring(field)) end
    if copied and type(value) == "table" then
        return { value[1], value[2], value[3] }
    end
    return value
end
local function unsigned(value)
    return value < 0 and value + 4294967296 or value
end
GetSpellModifiers = function(spellId, operation)
    modifierCalls = modifierCalls + 1
    expect(spellId == PI and operation == 8,
        "only numeric Power Infusion ALL_EFFECTS may be queried")
    local changed = modifierFlat ~= 0 or modifierPercent ~= 0
    return unsigned(modifierFlat), unsigned(modifierPercent), changed and 1 or 0
end
GetSpellDuration = function(spellId)
    durationCalls = durationCalls + 1
    expect(spellId == PI, "duration query must use numeric identity")
    return 15000
end
UnitExists = function(unit)
    if unit == "player" then return true, "player-guid" end
    return false, nil
end
UnitGUID = function(unit)
    return unit == "player" and "player-guid" or nil
end
GetTime = function() return 100 end
C_UnitAuras = { GetUnitAuras = function(unit, filter)
    auraCalls = auraCalls + 1
    expect(unit == "player" and filter == "HELPFUL",
        "recipient capture must use numeric helpful-aura state")
    return auraList
end }

dofile("Game/Player/PriestPowerInfusion.lua")
dofile("Graph/PriestPowerInfusion.lua")
local Runtime = XelAssist.Game.Player.PriestPowerInfusion
local Graph = XelAssist.Graph.PriestPowerInfusion

local facts, reason, handled = Runtime:InferKnowledge(PI)
expect(handled and facts and facts.priestPowerInfusion,
    reason or "exact Power Infusion was not inferred")
expect(facts.kind == "modifier" and facts.recipientRelation == "friendly",
    "inference must expose consequence shape without an action order")
local ordinary, _, ordinaryHandled = Runtime:InferKnowledge(14752)
expect(not ordinary and not ordinaryHandled,
    "ordinary same-family Priest spells must fall through")

local originalAura = record.effectApplyAuraName
record.effectApplyAuraName = { 136, 0, 0 }
Runtime:Invalidate()
local invalid, invalidReason, invalidHandled = Runtime:InferKnowledge(PI)
expect(not invalid and invalidHandled
    and string.find(invalidReason or "", "topology"),
    "recognized malformed Power Infusion must fail closed")
record.effectApplyAuraName = originalAura
Runtime:Invalidate()
facts = select(1, Runtime:InferKnowledge(PI))
expect(facts ~= nil, "restored exact topology was not accepted")

local action = { actor = "player", executor = "playerSpell",
    spellId = PI, facts = facts }
modifierFlat, modifierPercent = 5, 10
local modifiedFacts = Runtime:CaptureFacts(action, facts)
expect(modifiedFacts.priestPowerInfusionContract.exact,
    "modified exact contract was not sealed")
expect(modifiedFacts.priestPowerInfusionContract.percent == 27,
    "server ALL_EFFECTS ordering/truncation was not preserved")
near(modifiedFacts.priestPowerInfusionContract.multiplier, 1.27,
    "modified multiplier")

modifierFlat, modifierPercent = 0, 0
local sealed = Runtime:CaptureFacts(action, facts)
action.facts = sealed
expect(sealed.priestPowerInfusionContract.percent == 20
    and sealed.priestPowerInfusionContract.duration == 15,
    "base magnitude/duration contract is wrong")

local damageAction = { actor = "player", executor = "playerSpell",
    spellId = 589, facts = { kind = "dot" } }
local damageFacts = Runtime:CaptureFacts(damageAction, damageAction.facts)
local healAction = { actor = "player", executor = "playerSpell",
    spellId = 2054, facts = { kind = "heal" } }
local healFacts = Runtime:CaptureFacts(healAction, healAction.facts)
local physicalAction = { actor = "player", executor = "playerSpell",
    spellId = 6603, facts = { kind = "damage" } }
local physicalFacts = Runtime:CaptureFacts(physicalAction, physicalAction.facts)
expect(Graph:ConsumerKey(damageFacts) and Graph:ConsumerKey(healFacts),
    "affected damage/healing consumers were not mechanically identified")
expect(Graph:ConsumerKey(physicalFacts) == nil,
    "physical damage must not consume the magic-spell setup")

local descriptor = { unit = "player", key = "player-key",
    guid = "player-guid", relation = "self" }
local function capture(list)
    auraList = list
    local observed = { currentRecord = { facts = sealed } }
    local claimed, captured = Runtime:CaptureRecipient(
        observed, action, descriptor)
    expect(claimed and captured, "recipient evidence was not captured")
    return observed.priestPowerInfusionEvidence
end

local inactive = capture({})
expect(inactive["player-key"].known and inactive["player-key"].exact
    and not inactive["player-key"].active,
    "complete aura absence must be exact")
local ownActive = capture({ { spellId = PI, isHelpful = true,
    expirationTime = 112, sourceGUID = "player-guid" } })
expect(ownActive["player-key"].active and not ownActive["player-key"].exact
    and ownActive["player-key"].remaining == 12,
    "pre-existing aura lifecycle must not invent a magnitude snapshot")
local foreignActive = capture({ { spellId = PI, isHelpful = true,
    expirationTime = 112, sourceGUID = "other-priest-guid" } })
expect(foreignActive["player-key"].active
    and not foreignActive["player-key"].exact,
    "foreign active magnitude must remain unknown")

local function state(records)
    local friendly = { key = "player-key", unit = "player",
        guid = "player-guid", auras = {}, health = 500, healthMax = 1000,
        healthExact = true }
    return { time = 0, actors = { player = { guid = "player-guid" } },
        friendlies = { byUnit = { player = "player-key" },
            byKey = { ["player-key"] = friendly }, order = { "player-key" } },
        rootObservation = { sealed = true,
            priestPowerInfusionEvidence = records } }, friendly
end

-- Descendants are pure: every mutable client/DBC API becomes fatal here.
local saved = { UnitClass, GetSpellRecField, GetSpellModifiers,
    GetSpellDuration, UnitExists, UnitGUID, GetTime,
    C_UnitAuras.GetUnitAuras }
UnitClass = function() error("class read during graph search") end
GetSpellRecField = function() error("DBC read during graph search") end
GetSpellModifiers = function() error("modifier read during graph search") end
GetSpellDuration = function() error("duration read during graph search") end
UnitExists = function() error("identity read during graph search") end
UnitGUID = function() error("GUID read during graph search") end
GetTime = function() error("clock read during graph search") end
C_UnitAuras.GetUnitAuras = function() error("aura read during graph search") end

local graphState, player = state(inactive)
local blocker, blockerHandled = Graph:Blocker(
    action, graphState, descriptor, sealed)
expect(blockerHandled and not blocker, blocker or "exact self cast was blocked")
local projection, prepareReason, prepareHandled = Graph:Prepare(
    action, graphState, descriptor, sealed)
expect(prepareHandled and projection, prepareReason or "transition unavailable")
local setup = Graph:StrategicSetup(sealed)
expect(setup and setup.consumerKey == Graph.CONSUMER_KEY,
    "mechanical downstream setup identity missing")
local scoreContext = { action = action, power = 100,
    expectedPower = 100, value = 1, estimated = true }
expect(Graph:Score(scoreContext, projection), "transition did not score")
expect(scoreContext.value == 0 and scoreContext.power == 0
    and scoreContext.estimated == false,
    "setup action must have no invented flat utility")

local candidate = { action = action, targetKey = "player-key",
    targetGUID = "player-guid", effectDelivery = 1,
    classMechanicProjection = projection }
expect(Graph:Apply(graphState, candidate), "exact transition was not applied")
local active, activeHandled = Graph:AuraActive(
    action, graphState, descriptor)
expect(activeHandled and active, "projected aura is not active")

local damageContext = { action = damageAction, state = graphState,
    facts = damageAction.facts, tooltip = damageFacts,
    power = 100, expectedPower = 80 }
local adjusted, adjustReason, adjustHandled = Graph:Adjust(damageContext)
expect(adjustHandled and adjusted, adjustReason or "damage was not adjusted")
near(damageContext.power, 120, "magic damage multiplier")
near(damageContext.expectedPower, 96, "expected magic damage multiplier")

local healContext = { action = healAction, state = graphState,
    facts = healAction.facts, tooltip = healFacts,
    power = 50, expectedPower = 50 }
expect(Graph:Adjust(healContext), "healing was not adjusted")
near(healContext.power, 60, "healing multiplier")

local physicalContext = { action = physicalAction, state = graphState,
    facts = physicalAction.facts, tooltip = physicalFacts,
    power = 100, expectedPower = 100 }
local physicalAdjusted, _, physicalHandled = Graph:Adjust(physicalContext)
expect(not physicalAdjusted and not physicalHandled
    and physicalContext.power == 100,
    "physical damage was incorrectly modified")

player.auras[Runtime.PROJECTION_KEY].remaining = 0
local expiredAdjusted = Graph:Adjust({ action = damageAction,
    state = graphState, facts = damageAction.facts, tooltip = damageFacts,
    power = 100, expectedPower = 100 })
expect(not expiredAdjusted, "expired projection still modified a spell")

local activeState = state(ownActive)
local rootContext = { action = healAction, state = activeState,
    facts = healAction.facts, tooltip = healFacts,
    power = 100, expectedPower = 100 }
local rootAdjusted, rootReason, rootHandled = Graph:Adjust(rootContext)
expect(not rootAdjusted and rootHandled
    and string.find(rootReason or "", "snapshot"),
    "pre-existing magnitude must fail closed")
activeState.time = 12
expect(not Graph:Adjust({ action = healAction, state = activeState,
    facts = healAction.facts, tooltip = healFacts,
    power = 100, expectedPower = 100 }),
    "root aura did not expire causally")

local foreignState = state(foreignActive)
local foreignAdjusted, foreignReason, foreignHandled = Graph:Adjust({
    action = damageAction, state = foreignState, facts = damageAction.facts,
    tooltip = damageFacts, power = 100, expectedPower = 100 })
expect(not foreignAdjusted and foreignHandled
    and string.find(foreignReason or "", "magnitude"),
    "foreign caster magnitude must fail closed")

UnitClass, GetSpellRecField, GetSpellModifiers, GetSpellDuration,
    UnitExists, UnitGUID, GetTime, C_UnitAuras.GetUnitAuras =
    saved[1], saved[2], saved[3], saved[4], saved[5], saved[6], saved[7],
    saved[8]

expect(dbcCalls > 0 and modifierCalls == 2 and durationCalls == 2
    and auraCalls == 3, "root evidence API counts are unexpected")
print("priest_power_infusion_test: ok")
