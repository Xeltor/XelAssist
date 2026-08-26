XelAssist = { Game = { Player = {} }, Graph = {} }
table.getn = table.getn or function(value)
    local count = 0
    while value[count + 1] ~= nil do count = count + 1 end
    return count
end

local playerGUID, allyGUID, otherPaladinGUID, enemyGUID = {}, {}, {}, {}
local allyIdentityRace = false
local records = {
    [20154] = { 10, 134217728 }, -- seal
    [20375] = { 10, 33554432 },  -- different seal
    [21082] = { 10, 512 },       -- third seal
    [19740] = { 10, 268435458 }, -- blessing
    [19742] = { 10, 268500992 }, -- different blessing
    [1038] = { 10, 256 },        -- third blessing
    [20271] = { 10, 8388608 },   -- Judgement
    [25780] = { 10, 1 },         -- Righteous Fury
    [9999] = { 5, 0 },           -- unrelated family
}
GetSpellRecField = function(spellId, field)
    local row = records[spellId]
    if not row then error("missing spell") end
    if field == "spellFamilyName" then return row[1] end
    if field == "spellFamilyFlags" then return row[2] end
    error("unknown field")
end
UnitClass = function() return "Paladin", "PALADIN" end
UnitExists = function(unit)
    if unit == "player" then return true, playerGUID end
    if unit == "party1" then
        return true, allyIdentityRace and {} or allyGUID
    end
    if unit == "party2" then return true, otherPaladinGUID end
    if unit == "target" then return true, enemyGUID end
    return false, nil
end
UnitCanAssist = function(_, unit) return unit ~= "target" end

local playerAuras = {
    { name = "Opaque Seal", spellId = 20154, sourceUnit = "player",
        sourceGUID = playerGUID, duration = 30 },
    { name = "Opaque Blessing", spellId = 19740, sourceUnit = "player",
        sourceGUID = playerGUID, duration = 300 },
    { name = "Opaque Threat Mode", spellId = 25780,
        sourceUnit = "player", sourceGUID = playerGUID },
}
local allyAuras = {
    { name = "Opaque Wisdom", spellId = 19742, sourceUnit = "player",
        sourceGUID = playerGUID, duration = 300 },
    { name = "Opaque Other Blessing", spellId = 19740,
        sourceUnit = "party2", sourceGUID = otherPaladinGUID,
        duration = 300 },
}
C_UnitAuras = { GetUnitAuras = function(unit)
    return unit == "player" and playerAuras or allyAuras
end }

dofile("Game/Player/PaladinAuraState.lua")
dofile("Graph/PaladinAuraProjection.lua")
local Projection = XelAssist.Graph.PaladinAuraProjection

local playerKey, allyKey, enemyKey = {}, {}, {}
local playerRecord = { key = playerKey, unit = "player", relation = "self",
    guid = playerGUID, health = 100, healthMax = 100 }
local allyRecord = { key = allyKey, unit = "party1", relation = "party",
    guid = allyGUID, health = 80, healthMax = 100 }
local enemyRecord = { key = enemyKey, unit = "target", relation = "hostile",
    guid = enemyGUID, health = 100, healthMax = 100, dead = false }

local function rootState()
    return { friendlies = { order = { playerKey, allyKey },
        byKey = { [playerKey] = playerRecord, [allyKey] = allyRecord },
        byUnit = { player = playerKey, party1 = allyKey } },
        hostiles = { order = { enemyKey }, byKey = {
            [enemyKey] = enemyRecord } } }
end
local function selfDescriptor(record)
    return { key = playerKey, unit = "player", relation = "self",
        guid = playerGUID, record = record or playerRecord, exact = true }
end
local function allyDescriptor(record)
    return { key = allyKey, unit = "party1", relation = "friendly",
        guid = allyGUID, record = record or allyRecord, exact = true }
end
local function enemyDescriptor(record)
    return { key = enemyKey, unit = "target", relation = "hostile",
        guid = enemyGUID, record = record or enemyRecord, exact = true }
end

local state = rootState()
assert(Projection:Attach(state)
    and state.paladinAuraState.available
    and state.paladinAuraState.recipientCount == 2
    and state.paladinAuraState.player
        == state.paladinAuraState.byKey[playerKey]
    and state.paladinAuraState.player.activeSeal.spellId == 20154
    and state.paladinAuraState.byKey[allyKey].recipientRelation == "party"
    and state.paladinAuraState.byKey[allyKey]
        .blessingsByCaster[playerGUID].spellId == 19742,
    "Attach must freeze exact self and retained-friendly aura snapshots")

local branch = { friendlies = state.friendlies, hostiles = state.hostiles }
assert(Projection:Copy(state, branch)
    and branch.paladinAuraState.player
        == branch.paladinAuraState.byKey[playerKey]
    and branch.paladinAuraState.player
        ~= state.paladinAuraState.player
    and branch.paladinAuraState.player.guid == playerGUID
    and branch.paladinAuraState.player.activeSeal
        ~= state.paladinAuraState.player.activeSeal
    and branch.paladinAuraState.byKey[allyKey].blessingsByCaster[playerGUID]
        ~= state.paladinAuraState.byKey[allyKey]
            .blessingsByCaster[playerGUID],
    "Copy must preserve opaque identities while isolating mutable aura state")

local seal = { name = "Localized New Seal", spellId = 20375,
    actor = "player" }
local sameSeal = { name = "Localized Current Seal", spellId = 20154,
    actor = "player" }
local blessing = { name = "Localized New Blessing", spellId = 19740,
    actor = "player" }
local sameBlessing = { name = "Localized Current Blessing", spellId = 19742,
    actor = "player" }
local judgement = { name = "Localized Judgement", spellId = 20271,
    actor = "player" }

local blocker, handled, blockerProjection = Projection:Blocker(
    seal, state, selfDescriptor())
assert(blocker == nil and handled and blockerProjection
    and blockerProjection.kind == "seal",
    "a passing blocker must return its reusable exact preparation")
blocker, handled = Projection:Blocker(
    sameSeal, state, selfDescriptor())
assert(blocker == "same seal already active" and handled,
    "the active member of the self-exclusive seal family must be blocked")
blocker, handled = Projection:Blocker(
    blessing, state, allyDescriptor())
assert(blocker == nil and handled,
    "a different own blessing must pass for an exact frozen friendly")
blocker, handled = Projection:Blocker(
    sameBlessing, state, allyDescriptor())
assert(blocker == "same own blessing already active" and handled,
    "the active same-caster blessing must be blocked")

blocker, handled = Projection:Blocker(
    seal, state, allyDescriptor())
assert(blocker == "Paladin seal requires exact self recipient" and handled,
    "a seal must never project onto a friendly recipient")
blocker, handled = Projection:Blocker(blessing, state,
    allyDescriptor({ unit = "party1", guid = allyGUID }))
assert(blocker == "Paladin frozen recipient changed" and handled,
    "descriptor-record races must fail closed")

local projection, reason
projection, reason, handled = Projection:Prepare(
    seal, branch, selfDescriptor())
assert(projection and reason == nil and handled
    and projection.kind == "seal" and projection.replacement.spellId == 20154
    and projection.recipientKey == playerKey
    and projection.priority == nil and projection.score == nil,
    "seal preparation must transport exact replacement without priority")
assert(Projection:Apply(branch, projection)
    and branch.paladinAuraState.player.activeSeal.spellId == 20375
    and state.paladinAuraState.player.activeSeal.spellId == 20154,
    "seal application must remain branch-local and exclusive-family exact")

local stale = { friendlies = state.friendlies, hostiles = state.hostiles }
assert(Projection:Copy(state, stale))
local staleProjection = Projection:Prepare(
    seal, stale, selfDescriptor())
stale.paladinAuraState.player.activeSeal = {
    spellId = 21082, sourceGUID = playerGUID }
assert(not Projection:Apply(stale, staleProjection),
    "a changed seal family member must reject a stale prepared transition")

projection, reason, handled = Projection:Prepare(
    blessing, branch, allyDescriptor())
assert(projection and reason == nil and handled
    and projection.kind == "blessing"
    and projection.replacement.spellId == 19742
    and projection.recipientKey == allyKey,
    "blessing preparation must bind exact recipient and same-caster family")
assert(Projection:Apply(branch, projection)
    and branch.paladinAuraState.byKey[allyKey]
        .blessingsByCaster[playerGUID].spellId == 19740
    and branch.paladinAuraState.byKey[allyKey]
        .blessingsByCaster[otherPaladinGUID].spellId == 19740
    and state.paladinAuraState.byKey[allyKey]
        .blessingsByCaster[playerGUID].spellId == 19742,
    "own blessing replacement must preserve other casters and root state")

local friendlyRace = {
    friendlies = state.friendlies, hostiles = state.hostiles }
assert(Projection:Copy(state, friendlyRace))
local friendlyRaceProjection = Projection:Prepare(
    blessing, friendlyRace, allyDescriptor())
friendlyRace.friendlies = { order = { playerKey, allyKey },
    byKey = { [playerKey] = playerRecord,
        [allyKey] = { key = allyKey, unit = "party1", relation = "party",
            guid = {} } },
    byUnit = { player = playerKey, party1 = allyKey } }
assert(not Projection:Apply(friendlyRace, friendlyRaceProjection),
    "a frozen friendly identity change before apply must reject the transition")

blocker, handled = Projection:Blocker(
    judgement, state, enemyDescriptor(), nil)
assert(blocker == "seal-specific Judgement outcome unavailable" and handled,
    "Judgement must be hard-blocked without an exact downstream outcome")
local outcome = { exact = true, representable = true,
    sourceSealSpellId = 20154, recipientGUID = enemyGUID,
    recipientRelation = "hostile",
    effect = { exact = true, kind = "damage", spellId = 20966 } }
blocker, handled = Projection:Blocker(
    judgement, state, enemyDescriptor(), outcome)
assert(blocker == nil and handled,
    "an exact represented seal-specific outcome may pass the blocker")
outcome.recipientGUID = {}
blocker, handled = Projection:Blocker(
    judgement, state, enemyDescriptor(), outcome)
assert(blocker == "seal-specific Judgement outcome unavailable" and handled,
    "Judgement outcome-target races must fail closed")
outcome.recipientGUID = enemyGUID

projection, reason, handled = Projection:Prepare(
    judgement, state, enemyDescriptor(), outcome)
assert(projection and reason == nil and handled
    and projection.kind == "judgement" and projection.recipientKey == enemyKey,
    "exact Judgement must bind frozen hostile identity and active source seal")
local hostileRace = {
    friendlies = state.friendlies, hostiles = state.hostiles }
assert(Projection:Copy(state, hostileRace))
hostileRace.hostiles = { order = { enemyKey }, byKey = {
    [enemyKey] = { key = enemyKey, unit = "target", relation = "hostile",
        guid = enemyGUID, dead = true } } }
assert(not Projection:Apply(hostileRace, projection),
    "a dead or replaced Judgement target before apply must fail closed")
local judgementBranch = {
    friendlies = state.friendlies, hostiles = state.hostiles }
assert(Projection:Copy(state, judgementBranch)
    and Projection:Apply(judgementBranch, projection)
    and judgementBranch.paladinAuraState.player.activeSeal == nil
    and judgementBranch.paladinAuraState.player.lastJudgement.downstreamPending,
    "Judgement application must consume its seal and leave downstream pending")
local postJudgement = {
    friendlies = state.friendlies, hostiles = state.hostiles }
assert(Projection:Copy(judgementBranch, postJudgement)
    and postJudgement.paladinAuraState.player.lastJudgement
        ~= judgementBranch.paladinAuraState.player.lastJudgement
    and postJudgement.paladinAuraState.player.lastJudgement.outcome == outcome,
    "branch copying must preserve frozen pending Judgement evidence")

local righteousFury = { spellId = 25780, actor = "player" }
blocker, handled = Projection:Blocker(
    righteousFury, state, selfDescriptor())
assert(blocker == "Paladin aura downstream effect unavailable" and handled,
    "unrepresented Paladin aura effects must remain hard-blocked")
local other = { spellId = 9999, actor = "player" }
blocker, handled = Projection:Blocker(other, state, selfDescriptor())
assert(blocker == nil and not handled,
    "non-Paladin-family actions must remain outside this adapter")
local claimedUnknown = { spellId = 7777, actor = "player",
    facts = { paladinAura = true } }
blocker, handled = Projection:Blocker(
    claimedUnknown, state, selfDescriptor())
assert(blocker == "Paladin DBC family evidence unavailable" and handled,
    "an explicitly claimed Paladin action must fail closed when DBC evidence is absent")

local oldMaximum = Projection.MAX_RECIPIENTS
Projection.MAX_RECIPIENTS = 1
local overBudget = rootState()
assert(not Projection:Attach(overBudget)
    and overBudget.paladinAuraState.reason
        == "Paladin friendly snapshot budget unavailable",
    "unbounded friendly snapshots must fail before live aura reads")
Projection.MAX_RECIPIENTS = oldMaximum

allyIdentityRace = true
local partial = rootState()
assert(Projection:Attach(partial)
    and partial.paladinAuraState.available
    and partial.paladinAuraState.byKey[allyKey].available == false,
    "one raced friendly must remain unavailable without corrupting exact self state")
blocker, handled = Projection:Blocker(
    blessing, partial, allyDescriptor())
assert(blocker == "Paladin frozen recipient changed" and handled,
    "an unavailable raced recipient must block its blessing projection")

print("ok: exact Paladin root aura snapshots and exclusive-family projection")
