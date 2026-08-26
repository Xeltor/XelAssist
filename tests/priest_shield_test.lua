XelAssist = { Game = { Player = {} } }
table.getn = table.getn or function(value)
    local count = 0
    while value and value[count + 1] ~= nil do count = count + 1 end
    return count
end

local function triple(first, second, third)
    return { first or 0, second or 0, third or 0 }
end

local records = {
    [17] = { spellFamilyName = 6, spellFamilyFlags = 1,
        powerType = 0, effect = triple(6),
        effectApplyAuraName = triple(69),
        effectImplicitTargetA = triple(57),
        effectImplicitTargetB = triple(), effectMiscValue = triple(127),
        effectTriggerSpell = triple() },
    [585] = { spellFamilyName = 6, spellFamilyFlags = 128 },
    [6788] = { spellFamilyName = 6, spellFamilyFlags = 536870912,
        effect = triple(6), effectApplyAuraName = triple(77),
        effectImplicitTargetA = triple(25), effectMiscValue = triple(19) },
    [9001] = { spellFamilyName = 6, spellFamilyFlags = 1,
        powerType = 0, effect = triple(6),
        effectApplyAuraName = triple(69),
        effectImplicitTargetA = triple(57),
        effectImplicitTargetB = triple(), effectMiscValue = triple(1),
        effectTriggerSpell = triple() },
}
local dbcCalls, durationCalls, auraCalls = 0, 0, 0
local playerClass, now = "PRIEST", 100
local guids = { player = "player-guid", party1 = "ally-guid" }
local auras = { player = {}, party1 = {
    { spellId = 6788, duration = 15, expirationTime = 110 },
} }
local raceReplacement, auraFailure = false, false

UnitClass = function() return "Localized", playerClass end
UnitExists = function(unit)
    local guid = guids[unit]
    if unit == "party1" and raceReplacement == true then guid = "new-guid" end
    return guid ~= nil, guid
end
UnitGUID = function(unit) return guids[unit] end
GetTime = function() return now end
GetSpellName = function()
    error("Priest shield mechanics must not inspect localized names")
end
GetSpellRecField = function(spellId, field, copied)
    dbcCalls = dbcCalls + 1
    local row = records[spellId]
    if not row or row[field] == nil then error("missing DBC field") end
    if copied and type(row[field]) == "table" then
        return { row[field][1], row[field][2], row[field][3] }
    end
    return row[field]
end
GetSpellDuration = function(spellId)
    durationCalls = durationCalls + 1
    if spellId == 6788 then return 15000 end
    if spellId == 17 or spellId == 9001 then return 30000 end
    error("duration unavailable")
end
C_UnitAuras = { GetUnitAuras = function(unit, filter)
    auraCalls = auraCalls + 1
    assert(filter == "HARMFUL", "lockout observation must use harmful auras")
    if auraFailure then error("aura unavailable") end
    local list = auras[unit] or {}
    if raceReplacement == "armed" then raceReplacement = true end
    return list
end }

dofile("Game/Player/PriestShield.lua")
local Shield = XelAssist.Game.Player.PriestShield

local facts, reason, handled = Shield:InferKnowledge(17)
assert(facts and reason == nil and handled and facts.kind == "absorb"
    and facts.kindExact and facts.recipientRelation == "friendly"
    and facts.recipientRelationExact and facts.priestShield
    and facts.appliesWeakenedSoul and facts.requiresPriestShieldEvidence
    and facts.priestShieldEvidence.lockoutSpellId == 6788
    and facts.priestShieldEvidence.lockoutDuration == 15,
    "shield and linked server lockout must be exact name-independent facts")
assert(facts.priority == nil and facts.score == nil and facts.rotation == nil,
    "shield discovery must not encode a Priest priority")

local beforeDBC, beforeDuration = dbcCalls, durationCalls
local second = Shield:InferKnowledge(17)
assert(second and second ~= facts and dbcCalls == beforeDBC
    and durationCalls == beforeDuration,
    "complete shield and lockout topology must be cached")
second.priestShieldEvidence.lockoutDuration = 99
assert(Shield:InferKnowledge(17).priestShieldEvidence.lockoutDuration == 15,
    "caller mutation must not alter cached lockout evidence")

local unknown
unknown, reason, handled = Shield:InferKnowledge(585)
assert(unknown == nil and not handled
    and reason == "spell is not Power Word Shield",
    "another Priest spell must remain available to generic inference")
unknown, reason, handled = Shield:InferKnowledge(9001)
assert(unknown == nil and handled
    and reason == "Power Word Shield DBC or lockout topology is incomplete",
    "a claimed shield family with changed school mask must fail closed")

local active = Shield:Observe("party1", "ally-guid")
assert(active.known and active.active and active.complete
    and active.spellId == 6788 and active.remaining == 10
    and active.name == nil,
    "exact harmful aura identity must capture active lockout without names")
local absent = Shield:Observe("player", "player-guid")
assert(absent.known and not absent.active and absent.complete,
    "a complete empty harmful snapshot must prove lockout absence")

auras.party1 = { { spellId = nil },
    { spellId = 6788, expirationTime = 0 } }
local partialActive = Shield:Observe("party1", "ally-guid")
assert(partialActive.known and partialActive.active
    and not partialActive.complete and partialActive.remaining == nil,
    "finding the exact lockout must survive an incomplete neighboring aura")
auras.party1 = { { spellId = nil } }
local incomplete = Shield:Observe("party1", "ally-guid")
assert(not incomplete.known and not incomplete.active
    and incomplete.reason == "Weakened Soul identity evidence incomplete",
    "an incomplete scan without the lockout must not fabricate absence")

auraFailure = true
local failed = Shield:Observe("party1", "ally-guid")
assert(not failed.known
    and failed.reason == "Priest harmful aura observation unavailable",
    "aura API errors must fail closed")
auraFailure = false

auras.party1 = {}
raceReplacement = "armed"
local raced = Shield:Observe("party1", "ally-guid")
assert(not raced.known
    and raced.reason == "Priest shield recipient changed during observation",
    "recipient identity races must invalidate the entire snapshot")
raceReplacement = false

local action = { name = "Localized shield", spellId = 17, facts = facts }
auras.party1 = { { spellId = 6788, expirationTime = 110 } }
local observed = { root = true }
local descriptor = { unit = "party1", guid = "ally-guid",
    key = "ally-key", relation = "party" }
local captured, record = Shield:Capture(observed, action, descriptor)
local capturedCalls = auraCalls
assert(captured and record and record.active
    and observed.priestShieldEvidence["ally-key"] == record,
    "root capture must retain one exact recipient snapshot")
Shield:Capture(observed, action, descriptor)
assert(auraCalls == capturedCalls,
    "multiple ranks or graph lanes must reuse one recipient observation")

local state = { time = 0, rootObservation = observed,
    friendlies = { byKey = { ["ally-key"] = {
        key = "ally-key", unit = "party1", guid = "ally-guid", auras = {} }
    } } }
local blocker, claimed = Shield:Blocker(action, state, descriptor)
assert(claimed and blocker == "Weakened Soul active",
    "an active root lockout must prevent an impossible shield cast")
state.time = 11
blocker, claimed = Shield:Blocker(action, state, descriptor)
assert(claimed and blocker == nil,
    "exact remaining time must reopen the future path after expiry")

local absentObserved = { priestShieldEvidence = {
    ["ally-key"] = { known = true, active = false, complete = true } } }
state.time, state.rootObservation = 0, absentObserved
blocker, claimed = Shield:Blocker(action, state, descriptor)
assert(claimed and blocker == nil,
    "known lockout absence must leave the shield legal")

local candidate = { action = action, targetKey = "ally-key",
    targetGUID = "ally-guid", effectDelivery = 1 }
assert(Shield:Apply(state, candidate),
    "a successful future shield must project its linked lockout")
blocker = Shield:Blocker(action, state, descriptor)
assert(blocker == "Weakened Soul active",
    "projected lockout must prevent repeated future shields")
state.time = 16
blocker = Shield:Blocker(action, state, descriptor)
assert(blocker == nil,
    "projected lockout must expire from graph time, not wall time")

state.rootObservation = { priestShieldEvidence = {
    ["ally-key"] = { known = false, active = false } } }
state.friendlies.byKey["ally-key"].auras = {}
blocker = Shield:Blocker(action, state, descriptor)
assert(blocker == "Weakened Soul evidence unknown",
    "unknown root evidence must never permit an impossible cast")

local savedDBC, savedDuration, savedAuras = GetSpellRecField,
    GetSpellDuration, C_UnitAuras.GetUnitAuras
GetSpellRecField = function() error("DBC read during graph search") end
GetSpellDuration = function() error("duration read during graph search") end
C_UnitAuras.GetUnitAuras = function() error("aura read during graph search") end
state.rootObservation = absentObserved
state.time = 0
assert(Shield:Apply(state, candidate)
    and Shield:Blocker(action, state, descriptor) == "Weakened Soul active",
    "projection and legality must use only sealed graph evidence")
GetSpellRecField, GetSpellDuration, C_UnitAuras.GetUnitAuras =
    savedDBC, savedDuration, savedAuras

playerClass = "MAGE"
beforeDBC = dbcCalls
unknown, reason, handled = Shield:InferKnowledge(17)
assert(unknown == nil and not handled and dbcCalls == beforeDBC,
    "another exact class must be rejected before DBC access")

print("ok: Priest shield blocks exact live and projected Weakened Soul")
