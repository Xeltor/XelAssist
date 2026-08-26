-- Session-learned mana evidence must remain conservative, attributed, and
-- independent of live APIs once root observation requests a snapshot.
XelAssist = { Game = { Player = {} } }
dofile("Game/Player/ManaEvidence.lua")
local Mana = XelAssist.Game.Player.ManaEvidence
local GUID = "exact-player-guid"

local function reset()
    Mana:ResetSession()
    Mana:SetEnergizeEvidenceAvailable(true)
end

local function observe(value, maximum, at, exact, powerType)
    return Mana:Observe(GUID, value, maximum or 200, at,
        exact == nil and true or exact, powerType == nil and 0 or powerType)
end

reset()
observe(100, 200, 0)
observe(110, 200, 2)
observe(120, 200, 4)
local learned = assert(observe(130, 200, 6))
assert(learned.verified and learned.resourceType == 0
    and learned.amount == 10 and learned.interval == 2
    and learned.phaseKnown and learned.nextIn == 2
    and learned.externalEnergizeExcluded,
    "three clean exact gains must publish their observed mana envelope")
local status = Mana:Status(6)
assert(status.verified and status.executable and status.amount == 10
    and status.interval == 2 and status.energizeAttribution,
    "diagnostics must expose the privacy-safe learned mana contract")
local between = assert(Mana:Snapshot(GUID, 130, 200, 7))
assert(between.phaseKnown and between.nextIn == 1,
    "snapshot phase must advance using only the supplied root time")
assert(not Mana:Snapshot(GUID, 130, 200, 8).phaseKnown,
    "a missed observed upper-bound cadence must fail closed")

-- Gain amount and cadence are learned as a conservative envelope rather than
-- replaced by a stock mana tick or suppression constant.
reset()
observe(100, 200, 0)
observe(112, 200, 3)
observe(117, 200, 7)
local mixed = assert(observe(126, 200, 12))
assert(mixed.amount == 5 and mixed.interval == 5
    and mixed.observedIntervalMin == 4,
    "mixed live regimes must use observed minimum gain and maximum cadence")

-- Cap preserves the learned envelope for later evidence, but destroys phase.
local capped = assert(observe(200, 200, 13))
assert(capped.verified and not capped.phaseKnown and capped.nextIn == nil
    and capped.phaseSource == "mana cap erased tick phase",
    "mana cap must erase phase without fabricating a future tick")

-- Post-spend recovery is learned from exact deltas. Two different observed
-- delays prove that no fixed five-second-rule duration was inserted.
-- An expired boundary first proves that a much later hostile drain cannot enter
-- this model; the timeout is event attribution, not a regeneration constant.
assert(Mana:ObserveSpendBoundary(686, "go", 19))
observe(150, 200, 20)
observe(160, 200, 27)
observe(170, 200, 31)
observe(180, 200, 35)
assert(Mana:Snapshot(GUID, 180, 200, 35).postSpendSamples == 0,
    "unattributed mana loss must not teach a casting suppression delay")
assert(Mana:ObserveSpendBoundary(686, "go", 40))
observe(140, 200, 40)
observe(150, 200, 47)
observe(160, 200, 51)
observe(170, 200, 55)
assert(Mana:ObserveSpendBoundary(686, "go", 60))
observe(130, 200, 60)
observe(140, 200, 66)
observe(150, 200, 70)
local postSpend = assert(observe(160, 200, 74))
assert(postSpend.postSpendKnown and postSpend.postSpendDelay == 7
    and postSpend.postSpendSamples == 2 and postSpend.postSpend.verified
    and postSpend.postSpend.delay == 7 and postSpend.postSpend.boundary == "go"
    and postSpend.postSpend.spellId == 686,
    "post-spend projection must use the conservative observed delay envelope")

-- Every returned table, including nested post-spend evidence, is immutable
-- from the caller's perspective and carries no player GUID.
postSpend.amount, postSpend.postSpend.delay = 999, 999
local copied = assert(Mana:Snapshot(GUID, 160, 200, 74))
assert(copied.amount ~= 999 and copied.postSpend.delay == 7
    and copied.guid == nil and copied.sourceGuid == nil,
    "snapshot callers must not mutate session evidence or receive opaque IDs")

-- Combat-log energize attribution may follow its UNIT_MANA delta. It must scrub
-- any post-spend sample that the positive delta tentatively created.
assert(Mana:ObserveSpendBoundary(686, "go", 75))
observe(120, 200, 75)
local tentativelyPoisoned = assert(observe(150, 200, 81))
assert(tentativelyPoisoned.postSpendSamples == 3,
    "the ordering regression requires UNIT_MANA to arrive before energize")
assert(Mana:ObserveEnergize(GUID, 0, 81))
local scrubbed = assert(Mana:Snapshot(GUID, 150, 200, 81))
assert(not scrubbed.postSpendKnown and scrubbed.postSpendSamples == 0,
    "event-after-delta energize must retire every poisoned post-spend sample")

-- Energizes can be delivered on either side of UNIT_MANA. Quarantine retires
-- the phase and requires a further ambiguous positive delta to be discarded.
assert(Mana:ObserveEnergize(GUID, 0, 82),
    "matching mana energize must be attributed to the player")
local quarantined = assert(Mana:Snapshot(GUID, 150, 200, 82))
assert(not quarantined.phaseKnown and not quarantined.externalEnergizeExcluded,
    "energize attribution must retire the current clock immediately")
observe(190, 200, 83)
local afterAmbiguous = assert(Mana:Snapshot(GUID, 190, 200, 83))
assert(not afterAmbiguous.phaseKnown and afterAmbiguous.externalEnergizeExcluded,
    "the first positive delta after an energize must be discarded")
observe(195, 200, 87)
observe(198, 200, 91)
local rebuilt = assert(observe(199, 200, 95))
assert(rebuilt.phaseKnown and rebuilt.amount == 1,
    "clean evidence after quarantine must rebuild a conservative live phase")
assert(not Mana:ObserveEnergize("other-guid", 0, 96)
    and not Mana:ObserveEnergize(GUID, 3, 96),
    "other recipients and non-mana energizes must not disturb player evidence")

-- Without an exact energize stream, positive deltas never become passive
-- evidence. Inexact unit events and modifier changes also retire all evidence.
Mana:SetEnergizeEvidenceAvailable(false)
observe(150, 200, 70)
observe(160, 200, 72)
observe(170, 200, 74)
observe(180, 200, 76)
assert(Mana:Snapshot(GUID, 180, 200, 76) == nil,
    "unattributed gains must never produce a mana clock")
reset()
observe(100, 200, 0)
observe(110, 200, 2)
observe(120, 200, 4)
assert(observe(130, 200, 6))
assert(Mana:Observe(GUID, 140, 200, 8, false, 0) == nil,
    "an inexact mana event must invalidate the learned model")
observe(140, 200, 9)
observe(150, 200, 11)
observe(160, 200, 13)
assert(observe(170, 200, 15))
Mana:ModifierChanged("equipment changed")
assert(Mana:Snapshot(GUID, 170, 200, 15) == nil,
    "modifier invalidation must make every prior root snapshot unusable")

-- Maximum changes and power-type changes cannot inherit an old envelope.
reset()
observe(100, 200, 0)
observe(110, 200, 2)
observe(120, 200, 4)
assert(observe(130, 200, 6))
assert(observe(130, 220, 7) == nil,
    "a maximum-mana change must establish a new empty evidence epoch")
assert(Mana:Observe(GUID, 0, 100, 8, true, 3) == nil,
    "a non-mana power type must never receive mana evidence")

-- Root snapshotting is graph-search pure: all live APIs may be unavailable.
reset()
observe(100, 200, 0)
observe(110, 200, 2)
observe(120, 200, 4)
assert(observe(130, 200, 6))
GetTime = function() error("live time read during frozen snapshot") end
UnitMana = function() error("live mana read during frozen snapshot") end
UnitManaMax = function() error("live maximum read during frozen snapshot") end
UnitPowerType = function() error("live power type read during frozen snapshot") end
assert(Mana:Snapshot(GUID, 130, 200, 7).phaseKnown,
    "frozen mana snapshot must not consult live APIs")

print("ok: exact player mana deltas learn a conservative immutable clock")
