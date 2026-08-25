XelAssist = { Game = {}, Graph = { HostileState = {} } }
XelAssistCharDB = {}
table.getn = table.getn or function(value)
    local count = 0
    while value[count + 1] ~= nil do count = count + 1 end
    return count
end

local liveCount = 1
local tapped, tappedByPlayer = 0, 0
C_Item = { GetItemCount = function(itemId)
    assert(itemId == 6265, "Soul Shard count must use stable item identity")
    return liveCount
end }
GetItemCount = function()
    error("legacy item count must not override exact ClassicAPI identity")
end
UnitIsTapped = function() return tapped end
UnitIsTappedByPlayer = function() return tappedByPlayer end

dofile("Game/SoulShards.lua")
dofile("Graph/SoulShardReserve.lua")

local G = XelAssist.Game.SoulShards
local R = XelAssist.Graph.SoulShardReserve
assert(not R:Relevant({ { facts = { kind = "damage" } } })
    and R:Relevant({ { facts = { reagentName = "Soul Shard" } } }),
    "unrelated classes must not pay Soul Shard inventory-scan cost")
assert(G:Reserve() == 3 and XelAssistCharDB.soulShardReserve == 3,
    "the per-character Soul Shard reserve must default to three")
XelAssistCharDB.soulShardReserve = 99
assert(G:Reserve() == 10 and XelAssistCharDB.soulShardReserve == 10,
    "the character reserve must stay bounded instead of filling every bag")
XelAssistCharDB.soulShardReserve = 3

assert(G:GrayLevel(7) == 2 and G:GrayLevel(39) == 31
    and G:GrayLevel(60) == 51,
    "target validity must scale with current level using Vanilla gray thresholds")
local levelCheckState = { playerLevel = 60 }
local levelCheck = { relation = "hostile", unit = "target",
    record = { unit = "target", encounter = {
        level = 52, creatureTypeId = 7, isPlayer = false } } }
assert(G:TargetEligibility(levelCheckState, levelCheck))
levelCheck.record.encounter.level = 51
assert(not G:TargetEligibility(levelCheckState, levelCheck),
    "eligibility must continue adapting as the Warlock levels")
levelCheck.record.encounter.level, tapped = 52, 1
assert(not G:TargetEligibility(levelCheckState, levelCheck),
    "a target tapped by another player must not promise a shard")
tapped = 0

local guid = {}
local record = { key = guid, guid = guid, unit = "target",
    encounter = { level = 8, creatureTypeId = 7, isPlayer = false } }
local state = { playerLevel = 7, targetHealth = 60,
    targetHealthExact = true, inventory = { reagentCounts = {} },
    targetSurvival = { available = true, incomingDps = 30,
        timeToDie = 2, lowerTimeToDie = 1.5, upperTimeToDie = 2.7,
        confidence = "observed" },
    hostiles = { order = { guid }, byKey = { [guid] = record } } }
local descriptor = { relation = "hostile", key = guid,
    guid = guid, record = record }
local drainSoul = { name = "Localized Drain Soul", spellId = 1120,
    facts = { kind = "damage", channel = true,
        soulShardGenerator = true } }
local function context()
    return { action = drainSoul, state = state, descriptor = descriptor,
        cast = 3, wait = 0, power = 30, expectedPower = 30,
        effectDelivery = 1, estimated = false, value = 500 }
end

local ledger = R:Prepare(state)
assert(ledger.known and ledger.actual == 1 and ledger.expected == 1
    and state.inventory.reagentCounts["Soul Shard"] == 1,
    "root preparation must capture shards even before a shard consumer is learned")
local below = context()
assert(R:Score(below) and below.soulShardStockValue > 0
    and below.value > 500 and below.soulShardOpportunity.sufficient,
    "a likely valid kill below reserve must gain marginal shard value")
local shadowburn = { action = { facts = {
    kind = "damage", reagentName = "Soul Shard" } },
    state = state, value = 3000 }
assert(R:Score(shadowburn) and shadowburn.soulShardStockCost > 0
    and shadowburn.value > 0 and shadowburn.value < 3000,
    "spending protected stock must carry a marginal cost, not a typed ban")
state.soulShards.expected, state.soulShards.actual = 4, 4
local surplusSpend = { action = shadowburn.action, state = state, value = 3000 }
assert(R:Score(surplusSpend) and surplusSpend.soulShardStockCost == nil
    and surplusSpend.value == 3000,
    "shards above reserve must be freely spendable")
state.soulShards.expected, state.soulShards.actual = 1, 1

liveCount = 3
state.inventory.reagentCounts["Soul Shard"] = nil
R:Prepare(state)
local full = context()
assert(R:Score(full) and full.soulShardStockValue == 0
    and full.soulShardOvercapPenalty > 4000 and full.value < 0,
    "a likely shard kill at reserve must be strongly disfavored")

liveCount = 1
state.inventory.reagentCounts["Soul Shard"] = nil
R:Prepare(state)
state.targetSurvival.confidence = "limited samples"
local uncertain = context()
assert(not R:Score(uncertain) and uncertain.soulShardStockValue == nil,
    "limited death timing must not invent shard stock value")
state.targetSurvival.confidence = "observed"

record.encounter.level = 2
R:Prepare(state)
local trivial = context()
assert(not R:Score(trivial)
    and trivial.soulShardOpportunity.targetEligible == false,
    "a gray target must never receive shard-generation value")
record.encounter.level = 8

R:Prepare(state)
local guaranteed = context()
guaranteed.power = 100
assert(R:Score(guaranteed)
    and guaranteed.soulShardOpportunity.guaranteed,
    "exact full-channel lethal damage must be usable death evidence")
local candidate = { action = drainSoul,
    soulShardOpportunity = guaranteed.soulShardOpportunity }
local out = { targetHealth = 0, targetHealthExact = true,
    inventory = { reagentCounts = { ["Soul Shard"] = 1 } },
    soulShards = state.soulShards }
assert(R:Apply(out, candidate)
    and out.inventory.reagentCounts["Soul Shard"] == 2
    and out.soulShards.actual == 2 and out.soulShards.expected == 2,
    "a proven projected channel kill must add exactly one shard")

local summon = { action = { facts = {
    reagentName = "Soul Shard" } } }
out.inventory.reagentCounts["Soul Shard"] = 1
R:Apply(out, summon)
assert(out.soulShards.actual == 1 and out.soulShards.expected == 1,
    "future shard consumption must lower both exact and expected stock")

print("ok: bounded graph-native Soul Shard reserve")
