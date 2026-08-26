-- Exact installed topology, solo recipient boundary, and graph payoff for the
-- custom build-5875 Windfury Totem chain.  Localized names are unavailable.
XelAssist = { Game = { Player = {} }, Graph = {}, Combat = {} }
table.getn = table.getn or function(value)
    local count = 0
    while value[count + 1] ~= nil do count = count + 1 end
    return count
end

local function triple(first, second, third)
    return { first or 0, second or 0, third or 0 }
end

local function row(scalars, arrays)
    local out, key, value = {}, nil, nil
    for key, value in pairs(scalars) do out[key] = value end
    for key, value in pairs(arrays) do out[key] = value end
    local zeroFields = { "effectDicePerLevel", "effectRealPointsPerLevel",
        "effectMechanic", "effectAmplitude", "effectMultipleValue",
        "effectChainTarget", "effectItemType", "effectPointsPerComboPoint" }
    local index
    for index = 1, table.getn(zeroFields) do
        out[zeroFields[index]] = triple()
    end
    return out
end

local records = {
    [8512] = row({ school = 3, attributes = 65536, attributesEx = 0,
        attributesEx2 = 0, attributesEx3 = 0, attributesEx4 = 0,
        castingTimeIndex = 1, procFlags = 0, procChance = 101,
        procCharges = 0, baseLevel = 32, spellLevel = 32,
        durationIndex = 4, powerType = 0, manaCost = 115, rangeIndex = 1,
        startRecoveryCategory = 108, startRecoveryTime = 1500,
        spellFamilyName = 11, spellFamilyFlags = 4503600164241408,
        dmgClass = 1, preventionType = 1 }, {
        effect = triple(90), effectDieSides = triple(1),
        effectBaseDice = triple(1), effectBasePoints = triple(4),
        effectImplicitTargetA = triple(43), effectImplicitTargetB = triple(),
        effectRadiusIndex = triple(), effectApplyAuraName = triple(),
        effectMiscValue = triple(52144), effectTriggerSpell = triple(),
    }),
    [51367] = row({ school = 3, attributes = 320, attributesEx = 0,
        attributesEx2 = 0, attributesEx3 = 0, attributesEx4 = 0,
        castingTimeIndex = 1, procFlags = 4194320, procChance = 20,
        procCharges = 0, baseLevel = 32, spellLevel = 32,
        durationIndex = 21, powerType = 0, manaCost = 0, rangeIndex = 1,
        startRecoveryCategory = 0, startRecoveryTime = 0,
        spellFamilyName = 11, spellFamilyFlags = 67108864,
        dmgClass = 1, preventionType = 1 }, {
        effect = triple(35), effectDieSides = triple(1),
        effectBaseDice = triple(1), effectBasePoints = triple(-1),
        effectImplicitTargetA = triple(1), effectImplicitTargetB = triple(),
        effectRadiusIndex = triple(10), effectApplyAuraName = triple(42),
        effectMiscValue = triple(), effectTriggerSpell = triple(51368),
    }),
    [51368] = row({ school = 3, attributes = 1,
        attributesEx = 268435456, attributesEx2 = 16777216,
        attributesEx3 = 0, attributesEx4 = 0, castingTimeIndex = 1,
        procFlags = 4, procChance = 100, procCharges = 2,
        baseLevel = 32, spellLevel = 32, durationIndex = 65,
        powerType = 0, manaCost = 0, rangeIndex = 6,
        startRecoveryCategory = 0, startRecoveryTime = 0,
        spellFamilyName = 11, spellFamilyFlags = 8589934592,
        dmgClass = 0, preventionType = 0 }, {
        effect = triple(19, 6), effectDieSides = triple(1, 1),
        effectBaseDice = triple(1, 1), effectBasePoints = triple(),
        effectImplicitTargetA = triple(1, 1),
        effectImplicitTargetB = triple(), effectRadiusIndex = triple(),
        effectApplyAuraName = triple(0, 4), effectMiscValue = triple(),
        effectTriggerSpell = triple(),
    }),
}

local dbcCalls = 0
GetSpellRecField = function(spellId, field, copied)
    dbcCalls = dbcCalls + 1
    local value = records[spellId] and records[spellId][field]
    if copied and type(value) == "table" then
        return { value[1], value[2], value[3] }
    end
    return value
end
GetSpellName = function()
    error("Windfury evidence must not inspect localized spell names")
end
UnitClass = function() return "Localized class", "SHAMAN" end
local raidMembers, partyMembers = 0, 0
GetNumRaidMembers = function() return raidMembers end
GetNumPartyMembers = function() return partyMembers end
local helpful = {}
C_UnitAuras = { GetUnitAuras = function(unit, filter)
    assert(unit == "player" and filter == "HELPFUL")
    return helpful
end }

dofile("Game/Player/TotemState.lua")
dofile("Game/Player/ShamanWindfuryTotem.lua")
local Totems = XelAssist.Game.Player.TotemState
local Evidence = XelAssist.Game.Player.ShamanWindfuryTotem

local baseFacts = { inferred = true, kind = "totem", kindExact = true,
    shamanAction = true, shamanTotem = true,
    shamanRepresentation = "lifecycleOnly",
    shamanRepresentationExact = true,
    shamanLifecycleRepresented = true,
    shamanEffectRepresented = false,
    shamanRangeRepresented = false,
    shamanRecipientsRepresented = false,
    totemSlot = 4, totemElement = "air", totemElementExact = true,
    totemReplacementSlot = 4, totemReplacementExact = true,
    totemReplacementFamily = "shamanTotemSlot4",
    totemReplacementFamilyExact = true,
    totemLifetime = 120, totemLifetimeExact = true,
    requiresShamanTotemState = true, requiresExactTotemDownstream = true }

local promoted = Evidence:Promote(8512, baseFacts)
local downstream = promoted.shamanTotemDownstream
assert(promoted ~= baseFacts and promoted.shamanEffectRepresented
    and promoted.shamanRangeRepresented
    and promoted.shamanRecipientsRepresented
    and promoted.shamanRepresentation == "windfuryTotemSolo"
    and downstream.exact and downstream.sourceSpellId == 8512
    and downstream.element == "air"
    and downstream.effect.kind == "playerMainHandExtraAttackProc"
    and downstream.effect.auraSpellId == 51367
    and downstream.effect.triggerSpellId == 51368
    and downstream.effect.procFlags == 4194320
    and downstream.effect.procChance == 0.20
    and downstream.effect.extraAttacks == 1
    and downstream.effect.weaponHand == "main"
    and downstream.effect.resetsMainHandTimer
    and downstream.effect.recursive == false
    and downstream.range.center == "totem"
    and downstream.range.minimum == 0 and downstream.range.maximum == 30
    and downstream.recipients.relation == "party"
    and downstream.recipients.shape == "area"
    and downstream.recipients.graphScope == "soloSelf",
    "exact action-aura-trigger topology must promote every downstream gate")
assert(Evidence:Promote(8513, baseFacts) == baseFacts,
    "numeric identity must bound the custom Windfury profile")

local beforeCache = dbcCalls
assert(Evidence:Inspect(8512).valid and dbcCalls == beforeCache,
    "installed topology must be cached after exact promotion")
records[51367].procChance = 19
Evidence:Invalidate()
local malformed = Evidence:Inspect(8512)
assert(malformed.recognized and not malformed.available
    and string.find(malformed.reason or "", "incomplete") ~= nil,
    "a changed proc chance must fail the complete chain closed")
records[51367].procChance = 20
records[51367].effectRadiusIndex[1] = 11
Evidence:Invalidate()
assert(not Evidence:Inspect(8512).available,
    "a changed totem-centered radius must fail closed")
records[51367].effectRadiusIndex[1] = 10
Evidence:Invalidate()
promoted = Evidence:Promote(8512, baseFacts)
downstream = promoted.shamanTotemDownstream

local playerGUID = {}
local function emptyAir()
    return { slot = 4, element = "air", haveTool = true, active = false,
        spellId = nil, startTime = nil, duration = nil, remaining = 0,
        lifetimeExact = true, exact = true }
end
local function stateWith(rowValue)
    return { time = 10, playerGUID = playerGUID,
        totems = { available = true, playerGUID = playerGUID,
            bySlot = { [4] = rowValue or emptyAir() } } }
end

local action = { spellId = 8512, name = "Localized action",
    actor = "player", facts = promoted }
local lifecycle = { exact = true, slot = 4, element = "air",
    duration = 120, replacementSlot = 4,
    replacementFamily = "shamanTotemSlot4", source = "sealed test root" }
local root = stateWith()
local projection, prepareReason = Totems:PrepareCaptured(
    action, root, lifecycle, downstream)
assert(projection and prepareReason == nil and projection.admissible
    and projection.effect.procChance == 0.20,
    "generic lifecycle must bind the exact Windfury downstream descriptor")

dofile("Graph/ShamanWindfuryTotem.lua")
local Graph = XelAssist.Graph.ShamanWindfuryTotem
assert(Graph:Attach(root) and root.shamanWindfuryTotem.exact
    and not root.shamanWindfuryTotem.active,
    "solo root without the numeric aura must seal an inactive component")
local prepared, reason, handled = Graph:Prepare(root, projection)
assert(prepared == projection and reason == nil and handled
    and projection.shamanWindfuryTotem.procChance == 0.20,
    "solo placement must transport only sealed downstream evidence")
local setup = { state = root }
assert(Graph:Score(setup, projection) and setup.value == 0
    and setup.power == 0 and setup.kind == "classMechanic"
    and setup.reason == "enables main-hand extra attacks",
    "placement must remain neutral until a descendant consumes the proc")

local branch = stateWith()
branch.shamanWindfuryTotem = {}
assert(Graph:Copy(root, branch)
    and branch.shamanWindfuryTotem ~= root.shamanWindfuryTotem,
    "branch-local Windfury state must be isolated")
local callsBeforeSearch = dbcCalls
GetSpellRecField = function()
    error("graph search must not reread installed spell topology")
end
assert(Totems:Apply(branch, projection) and Graph:Apply(branch, projection)
    and Graph:IsActive(branch)
    and dbcCalls == callsBeforeSearch,
    "accepted placement must activate the solo consequence without DBC reads")

local targetGUID = {}
branch.playerAttack = { attackRound = { normalDamageKnown = true,
    power = 100, targetGuid = targetGUID, projectable = true,
    phaseKnown = true, verified = true } }
XelAssist.Graph.PlayerSwings = { ExpectedWhite = function(_, value, guid)
    assert(value == branch and guid == targetGUID)
    return 80, 0.8
end }
local meleeContext = { state = branch, action = { actor = "player",
    facts = { kind = "damage", melee = true } }, kind = "damage",
    descriptor = { relation = "hostile", guid = targetGUID },
    resistance = { deliveryModel = "physical", deliverySubtype = "melee",
        weaponHand = "main" }, effectDelivery = 0.75,
    power = 125, expectedPower = 100 }
assert(Graph:Adjust(meleeContext)
    and math.abs(meleeContext.windfuryExpectedExtraAttackPower - 12) < 0.000001
    and math.abs(meleeContext.expectedPower - 112) < 0.000001
    and meleeContext.estimated,
    "a landed main-hand action must gain its conditional extra-white value")
local offhand = { state = branch, action = meleeContext.action,
    kind = "damage", descriptor = meleeContext.descriptor,
    resistance = { deliveryModel = "physical", deliverySubtype = "melee",
        weaponHand = "off" }, effectDelivery = 1, expectedPower = 100 }
assert(not Graph:Adjust(offhand) and offhand.expectedPower == 100,
    "off-hand attacks must not receive the main-hand-only proc")

XelAssist.Combat.Resistance = { Estimate = function(_, actionValue)
    assert(actionValue.facts.whiteAttack
        and actionValue.facts.weaponHand == "main")
    return { exact = true }
end }
XelAssist.Graph.Effects = { Decision = function() return 0.8 end }
local adjusted, whiteReason, whiteHandled, whiteDelivery = Graph:WhiteSwingRawPower(
    branch, targetGUID, 100)
assert(whiteHandled and whiteReason == nil
    and math.abs(adjusted - 116) < 0.000001 and whiteDelivery == 0.8,
    "ordinary main-hand swings must include conditional extra-attack delivery")

local candidate = { action = meleeContext.action, effectAction = meleeContext.action,
    resistance = meleeContext.resistance, effectDelivery = 0.75,
    targetRelation = "hostile", targetGUID = targetGUID }
assert(Graph:AfterCandidate(branch, candidate)
    and not branch.playerAttack.attackRound.projectable
    and not branch.playerAttack.attackRound.phaseKnown
    and string.find(branch.playerAttack.attackRound.reason,
        "stochastic", 1, true),
    "a possible proc must retire deterministic future main-hand timing")

local activeRoot = stateWith({ slot = 4, element = "air", haveTool = true,
    active = true, spellId = 8512, startTime = 1, duration = 120,
    remaining = 110, lifetimeExact = true, exact = true })
helpful = { { spellId = 51367 } }
assert(Graph:Attach(activeRoot) and Graph:IsActive(activeRoot),
    "matching numeric aura and live air-slot identity must restore root activity")
local incoherent = stateWith()
assert(not Graph:Attach(incoherent)
    and string.find(incoherent.shamanWindfuryTotem.reason,
        "incoherent", 1, true),
    "an aura without its owned solo air totem must fail closed")

helpful = {}
partyMembers = 1
C_UnitAuras.GetUnitAuras = function()
    error("group roots must stop before unprovable aura attribution")
end
local grouped = stateWith()
assert(not Graph:Attach(grouped)
    and grouped.shamanWindfuryTotem.fanoutUnresolved
    and string.find(grouped.shamanWindfuryTotem.reason,
        "fanout", 1, true),
    "unresolved party recipients must block the graph consequence")

print("ok: exact solo Windfury Totem proc consequence is search-pure")
