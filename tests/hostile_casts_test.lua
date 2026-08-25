XelAssist = { Game = {} }
table.getn = table.getn or function(value) return #value end

local function direct(effect, target, points, sides)
    return {
        effect = { effect, 0, 0 },
        effectImplicitTargetA = { target, 0, 0 },
        effectImplicitTargetB = { 0, 0, 0 },
        effectRadiusIndex = { 0, 0, 0 },
        effectChainTarget = { 0, 0, 0 },
        effectBasePoints = { points, 0, 0 },
        effectBaseDice = { 1, 0, 0 },
        effectDieSides = { sides, 0, 0 },
        effectDicePerLevel = { 0, 0, 0 },
        effectRealPointsPerLevel = { 1, 0, 0 },
        effectApplyAuraName = { 0, 0, 0 },
        effectTriggerSpell = { 0, 0, 0 },
        effectAmplitude = { 0, 0, 0 },
        attributesEx = 0, spellLevel = 20, baseLevel = 20, maxLevel = 60,
        school = effect == 2 and 2 or 1,
    }
end

local records = {
    [100] = direct(2, 6, 89, 20),
    [101] = direct(10, 21, 99, 1),
    [102] = direct(10, 1, 49, 1),
    [103] = direct(2, 15, 89, 20),
    [104] = direct(2, 6, 89, 20),
    [105] = direct(3, 6, 89, 20),
    [106] = direct(64, 6, 89, 20),
    [107] = direct(2, 6, 89, 20),
    [108] = direct(2, 6, 89, 20),
    [109] = direct(2, 28, 89, 20),
    [110] = direct(10, 6, 99, 1),
    [111] = direct(2, 21, 89, 20),
    [112] = direct(2, 6, 89, 20),
    [113] = direct(2, 6, 89, 20),
}
records[104].effectChainTarget[1] = 3
records[107].effectTriggerSpell[1] = 999
records[108].effectAmplitude[1] = 3000
records[112].effect = { 2, 6, 0 }
records[112].effectApplyAuraName = { 0, 3, 0 }
records[113].attributesEx = 4

GetSpellRecField = function(spellId, field, copied)
    local record = records[spellId]
    if not record then return nil end
    if copied ~= nil then assert(copied == 1) end
    return record[field]
end

dofile("Game/HostileCasts.lua")
dofile("Game/SpellTopology.lua")
dofile("Game/HostileSpellFacts.lua")

local Casts = XelAssist.Game.HostileCasts
local Facts = XelAssist.Game.HostileSpellFacts

Casts:Reset()
local observed, reason = Casts:Observe("enemy-a", "player-a", "START",
    100, 2000, nil, 10)
assert(observed == nil and reason == "caster ownership unavailable",
    "unknown ownership must never enter the hostile ledger")
observed, reason = Casts:Observe("enemy-a", "player-a", "START",
    100, 2000, true, 10)
assert(observed == nil and reason == "owned cast excluded",
    "the explicit owned lane must exclude player and controlled casts")

local opaqueCaster, opaqueTarget = {}, {}
local opaque = Casts:Observe(opaqueCaster, opaqueTarget, "START",
    100, 2000, false, 10)
assert(opaque and opaque.casterGuid == opaqueCaster
    and opaque.targetGuid == opaqueTarget
    and Casts:Active(opaqueCaster, 10.5).targetGuid == opaqueTarget,
    "session ledgers must preserve non-string opaque identity keys")
local opaqueFacts = assert(Facts:ForCast({ casterGuid = opaqueCaster,
    targetGuid = opaqueTarget, spellId = 100 }, 25))
assert(opaqueFacts.casterGuid == opaqueCaster
    and opaqueFacts.targetGuid == opaqueTarget,
    "hostile spell facts must preserve opaque caster and target identities")
local opaqueEnded = Casts:Observe(opaqueCaster, opaqueTarget, "CAST",
    100, nil, false, 11)
assert(opaqueEnded and opaqueEnded.terminalStatus == "CAST"
    and Casts:Active(opaqueCaster, 11) == nil,
    "opaque identity keys must remain usable through terminal matching")
Casts:Reset()

observed = Casts:Observe("enemy-a", "player-a", "START",
    100, 2000, false, 10)
assert(observed and observed.generation == 1 and observed.startedAt == 10
    and observed.deadline == 12 and observed.remaining == 2
    and not observed.channel and observed.targetKnown,
    "START must retain exact identities, generation and deadline")
assert(observed.name == nil and observed.unit == nil,
    "the session ledger must retain no names or unit tokens")
observed.deadline = 1
assert(Casts:Active("enemy-a", 10.5).deadline == 12,
    "callers must receive copies rather than mutable ledger records")
assert(not Casts:Cancel("enemy-a", 2) and Casts:Active("enemy-a", 10.5),
    "a stale generation must not cancel a replacement cast")

local ended = Casts:Observe("enemy-a", "player-b", "CAST",
    100, nil, false, 11)
assert(ended == nil and Casts:Active("enemy-a", 11),
    "a terminal event for another exact target must not clear the cast")
ended = Casts:Observe("enemy-a", "player-a", "CAST",
    100, nil, false, 11)
assert(ended and ended.terminalStatus == "CAST" and not ended.active
    and Casts:Active("enemy-a", 11) == nil,
    "CAST must finish the matching non-channel generation")
local deadlineCast = Casts:Observe("enemy-deadline", "player-a", "START",
    100, 1000, false, 12)
ended = Casts:Observe("enemy-deadline", "player-a", "CAST",
    100, nil, false, deadlineCast.deadline)
assert(ended and ended.terminalStatus == "CAST" and ended.remaining == 0,
    "a GO arriving at its deadline must remain authoritative completion")

local channel = Casts:Observe("enemy-a", "player-a", "CHANNEL",
    100, 3000, false, 20)
local generation = channel.generation
channel, reason = Casts:Observe("enemy-a", "player-a", "CAST",
    100, nil, false, 20.1)
assert(channel and channel.generation == generation and channel.castObserved
    and reason == "channel remains active",
    "the channel GO CAST event must not erase future channel occupancy")
ended = Casts:Observe("enemy-a", "player-a", "FAIL",
    100, nil, false, 21)
assert(ended and ended.terminalStatus == "FAIL"
    and Casts:Active("enemy-a", 21) == nil,
    "FAIL must clear the matching active channel")

local startOther = Casts:ObserveStartOther("enemy-np", "player-a", 100,
    500, 2500, 1, false, 25)
assert(startOther and startOther.channel and startOther.durationMs == 3000
    and startOther.castTimeMs == 500 and startOther.channelDurationMs == 2500
    and startOther.spellType == 1 and startOther.deadline == 28
    and startOther.source == "Nampower START_OTHER",
    "START_OTHER must retain separate authoritative cast/channel occupancy")
local corroborated, corroboration = Casts:ObserveUnitCast("enemy-np",
    "player-a", "CHANNEL", 100, 9999, false, 25.1)
assert(corroborated and corroborated.generation == startOther.generation
    and corroborated.deadline == 28 and corroborated.source == startOther.source
    and corroborated.unitCastCorroborated
    and corroboration == "cast corroborated",
    "UNIT_CASTEVENT must corroborate without replacing authoritative timing")
local conflicted, conflictReason = Casts:ObserveUnitCast("enemy-np",
    "player-b", "CHANNEL", 100, 9999, false, 25.2)
assert(conflicted and conflicted.generation == startOther.generation
    and conflicted.targetGuid == "player-a"
    and conflictReason == "conflicting fallback cast ignored",
    "a conflicting fallback target must never downgrade START_OTHER evidence")
local wrongSpell, wrongSpellReason = Casts:ObserveUnitCast("enemy-np",
    "player-a", "START", 101, 9999, false, 25.3)
assert(wrongSpell and wrongSpell.generation == startOther.generation
    and wrongSpell.spellId == 100 and wrongSpell.deadline == 28
    and wrongSpellReason == "different-spell fallback cast ignored",
    "a different fallback spell must never replace authoritative Nampower evidence")
local goOther = Casts:ObserveGoOther("enemy-np", "player-a", 100, false, 25.5)
assert(goOther and goOther.castObserved and Casts:Active("enemy-np", 25.5),
    "GO_OTHER must preserve an active channel until its deadline")
local failedOther = Casts:ObserveFailedOther("enemy-np", 100, false, 26)
assert(failedOther and failedOther.terminalStatus == "FAIL"
    and Casts:Active("enemy-np", 26) == nil,
    "FAILED_OTHER must clear caster+spell without inventing a missing target")
local normalOther = Casts:ObserveStartOther("enemy-np", "player-a", 100,
    1000, 500, 0, false, 27)
assert(normalOther and not normalOther.channel and normalOther.durationMs == 1000
    and normalOther.deadline == 28 and normalOther.castTimeMs == 1000
    and normalOther.channelDurationMs == 500,
    "normal START_OTHER occupancy must use cast time without channel duration")
local normalGo = Casts:ObserveGoOther("enemy-np", nil, 100, false, 27.5)
assert(normalGo and normalGo.terminalStatus == "CAST",
    "GO_OTHER without a target must clear its exact caster+spell generation")

local targetless = Casts:ObserveStartOther("enemy-enrich", nil, 100,
    1000, 0, 0, false, 28)
local enriched = Casts:ObserveUnitCast("enemy-enrich", "player-a",
    "START", 100, 4000, false, 28.1)
assert(enriched and enriched.generation == targetless.generation
    and enriched.targetGuid == "player-a" and enriched.targetKnown
    and enriched.targetEnriched and enriched.deadline == 29,
    "later exact fallback evidence must enrich without replacing Nampower timing")
local enrichedGo = Casts:ObserveGoOther("enemy-enrich", "player-a", 100,
    false, 28.5)
assert(enrichedGo and enrichedGo.targetGuid == "player-a"
    and enrichedGo.targetKnown and enrichedGo.targetEnriched,
    "an exact terminal must retain an enriched recipient")

local firstRace = Casts:ObserveStartOther("enemy-race", "player-a", 100,
    1500, 0, 0, false, 29)
local replacementRace = Casts:ObserveStartOther("enemy-race", "player-a", 100,
    1500, 0, 0, false, 29.1)
assert(replacementRace.generation ~= firstRace.generation
    and replacementRace.targetlessTerminalAmbiguous,
    "a live same-spell replacement must mark targetless terminals ambiguous")
local ambiguous, ambiguousReason = Casts:ObserveFailedOther(
    "enemy-race", 100, false, 29.2)
assert(ambiguous and ambiguous.generation == replacementRace.generation
    and ambiguous.active and ambiguousReason == "ambiguous targetless terminal",
    "a delayed targetless failure must not retire a replacement generation")
ambiguous, ambiguousReason = Casts:ObserveGoOther(
    "enemy-race", nil, 100, false, 29.3)
assert(ambiguous and ambiguous.generation == replacementRace.generation
    and ambiguous.active and ambiguousReason == "ambiguous targetless terminal",
    "a delayed targetless completion must not retire a replacement generation")
local exactRace = Casts:ObserveGoOther(
    "enemy-race", "player-a", 100, false, 29.4)
assert(exactRace and exactRace.terminalStatus == "CAST"
    and Casts:Active("enemy-race", 29.4) == nil,
    "an exact replacement terminal must still retire its active generation")

local unknownTarget = Casts:Observe("enemy-unknown", nil, "START",
    100, 1000, false, 30)
assert(unknownTarget and not unknownTarget.targetKnown
    and unknownTarget.targetGuid == nil,
    "missing target identity must remain explicit instead of being invented")
assert(Casts:Active("enemy-unknown", 30.9)
    and Casts:Active("enemy-unknown", 31) == nil,
    "active records must expire exactly at their observed deadline")

Casts:Reset()
local index
for index = 1, 17 do
    Casts:Observe("enemy-" .. index, "player-a", "START",
        100, 100000, false, 40 + index / 100)
end
local snapshot = Casts:Snapshot(41)
assert(table.getn(snapshot) == 16 and Casts:Active("enemy-1", 41) == nil
    and Casts:Active("enemy-17", 41),
    "the exact-GUID ledger must evict its oldest generation at cap 16")
local newest = Casts:Active("enemy-17", 41)
assert(Casts:Cancel("enemy-17", newest.generation)
    and Casts:Active("enemy-17", 41) == nil,
    "generation cancellation must remove only the matching active cast")
Casts:Reset()
assert(table.getn(Casts:Snapshot(41)) == 0,
    "reset must clear all session-only hostile cast evidence")

local damage = assert(Facts:ForCast({ casterGuid = "enemy-a",
    targetGuid = "player-a", spellId = 100 }, 25))
assert(damage.kind == "damage" and damage.direct and damage.singleTarget
    and damage.amount == 104.5 and damage.estimated
    and damage.casterLevel == 25 and damage.targetGuid == "player-a",
    "direct damage must use DBC base dice, die sides and level scaling")
local heal = assert(Facts:ForCast({ casterGuid = "enemy-a",
    targetGuid = "enemy-b", spellId = 101 }, 20))
assert(heal.kind == "heal" and heal.amount == 100 and heal.estimated,
    "an exact friendly single-target direct heal must be classified")
assert(Facts:ForCast({ casterGuid = "enemy-a", targetGuid = "enemy-a",
    spellId = 102 }, 20), "an exact hostile self-heal must be classified")

local rejected = {
    { { casterGuid = "enemy-a", spellId = 100 }, 25,
        "missing targets must be rejected" },
    { { casterGuid = "enemy-a", targetGuid = "player-a", spellId = 100,
        channel = true }, 25, "observed channels must be rejected" },
    { { casterGuid = "enemy-a", targetGuid = "player-a", spellId = 103 }, 25,
        "areas must be rejected" },
    { { casterGuid = "enemy-a", targetGuid = "player-a", spellId = 104 }, 25,
        "chains must be rejected" },
    { { casterGuid = "enemy-a", targetGuid = "player-a", spellId = 105 }, 25,
        "dummy effects must be rejected" },
    { { casterGuid = "enemy-a", targetGuid = "player-a", spellId = 106 }, 25,
        "trigger effects must be rejected" },
    { { casterGuid = "enemy-a", targetGuid = "player-a", spellId = 107 }, 25,
        "triggered side effects must be rejected" },
    { { casterGuid = "enemy-a", targetGuid = "player-a", spellId = 108 }, 25,
        "periodic timing must be rejected" },
    { { casterGuid = "enemy-a", targetGuid = "player-a", spellId = 109 }, 25,
        "ground effects must be rejected" },
    { { casterGuid = "enemy-a", targetGuid = "player-a", spellId = 110 }, 25,
        "hostile-target healing topology must be rejected" },
    { { casterGuid = "enemy-a", targetGuid = "enemy-b", spellId = 111 }, 25,
        "friendly-target damage topology must be rejected" },
    { { casterGuid = "enemy-a", targetGuid = "player-a", spellId = 112 }, 25,
        "mixed direct and aura effects must be rejected" },
    { { casterGuid = "enemy-a", targetGuid = "player-a", spellId = 113 }, 25,
        "DBC-flagged channels must be rejected" },
    { { casterGuid = "enemy-a", targetGuid = "player-a", spellId = 999 }, 25,
        "missing DBC records must be rejected" },
}
for index = 1, table.getn(rejected) do
    local facts = Facts:ForCast(rejected[index][1], rejected[index][2])
    assert(facts == nil, rejected[index][3])
end
local selfMismatch = Facts:ForCast({ casterGuid = "enemy-a",
    targetGuid = "enemy-b", spellId = 102 }, 20)
assert(selfMismatch == nil, "self-only heals must require exact caster identity")

print("ok: bounded hostile casts and conservative direct DBC consequences")
