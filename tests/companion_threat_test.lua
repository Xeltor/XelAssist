XelAssist = { Graph = {} }
XelAssistCharDB = { petThreat = "auto" }

dofile("Graph/CompanionThreat.lua")
local T = XelAssist.Graph.CompanionThreat
dofile("Graph/CompanionEventThreat.lua")
local EventThreat = XelAssist.Graph.CompanionEventThreat

local growl = { name = "Growl", facts = { kind = "petThreat",
    petThreatGain = 415 } }
local cower = { name = "Cower", facts = { kind = "petThreat",
    petThreatDrop = 225 } }

local solo = { groupSize = 0, hasAggro = true, tank = false,
    actors = { pet = { hasAggro = false, health = 900, healthMax = 1000 } } }
local policy, source = T:ResolvePolicy(solo, "auto")
assert(policy == "tank" and source == "solo inference",
    "automatic solo policy should let the companion tank")
assert(T:Block(solo, growl, "tank") == nil,
    "explicit tank policy should retain threat-building actions")
local gainScore, gainReason, gainConfidence = T:Score(solo, growl, "tank")
assert(gainScore > 0 and gainReason == "builds companion tank threat")
assert(gainConfidence == "live bound")

local playerAggroBefore, petAggroBefore = solo.hasAggro,
    solo.actors.pet.hasAggro
local applied, estimate = T:Apply(solo, growl, "tank", 1)
assert(applied and estimate.delta == 415 and estimate.upper == 415
    and estimate.lower == nil)
assert(not estimate.known and estimate.confidence == "projected from live bound")
assert(solo.hasAggro == playerAggroBefore
    and solo.actors.pet.hasAggro == petAggroBefore,
    "Growl projection must not claim that aggro changed owners")
T:Apply(solo, growl, "tank", 0.5)
assert(solo.actors.pet.threatEstimate.delta == 622.5
    and solo.actors.pet.threatEstimate.upper == 622.5,
    "successive threat gains should add to the uncertain relative estimate")

local tauntPath = { groupSize = 0, hasAggro = true,
    actors = { pet = { guid = "pet-guid", hasAggro = false } } }
local tauntRecord = { threat = { playerHasAggro = true,
    petHasAggro = false, playerDelta = 0, petDelta = 0 } }
assert(EventThreat:ApplyRelative(tauntPath, tauntPath, growl,
        tauntRecord, true, 1)
    and tauntRecord.threat.petDelta == 415)
assert(EventThreat:ApplyTaunt(tauntPath, tauntPath,
        { name = "Torment" }, tauntRecord, true, 1)
    and tauntRecord.threat.projectedPetHasAggro)
assert(EventThreat:ApplyRelative(tauntPath, tauntPath, growl,
        tauntRecord, true, 1)
    and tauntRecord.threat.petDelta == 830
    and tauntRecord.companionThreatEstimate.delta == 830
    and tauntRecord.projectedThreat.petThreatAction == 830,
    "a projected taunt must not erase earlier additive companion threat")

local group = { groupSize = 4, hasAggro = false, tank = false,
    actors = { pet = { hasAggro = false } } }
policy, source = T:ResolvePolicy(group, "auto")
assert(policy == "avoid" and source == "group victim inference",
    "an observed group victim should not be displaced by automatic pet threat")
assert(T:Block(group, growl, "avoid") == "companion threat avoidance")
assert(T:Block(group, growl, "assist")
    == "companion assist threat policy")
local avoidScore, avoidReason = T:Score(group, growl, "avoid")
assert(avoidScore < 0 and avoidReason == "avoids displacing the group tank")
assert(T:Block(group, growl, "tank") == nil,
    "an explicit tank policy must override group inference")

local livePetTank = { groupSize = 0, hasAggro = false, tank = false,
    actors = { pet = { hasAggro = true } } }
applied, estimate = T:Apply(livePetTank, growl, "tank", 1)
assert(applied and estimate.lower == 415 and estimate.upper == nil
    and livePetTank.actors.pet.hasAggro,
    "live pet aggro should become a lower bound, not a projected boolean")

local cowerState = { groupSize = 4, hasAggro = true, tank = false,
    actors = { pet = { hasAggro = false } } }
local originalPlayerAggro = cowerState.hasAggro
applied, estimate = T:Apply(cowerState, cower, "avoid", 1)
assert(applied and estimate.delta == -225 and estimate.upper == -225,
    "Cower should subtract from the pet's relative threat estimate")
assert(cowerState.hasAggro == originalPlayerAggro,
    "Cower must never clear player aggro")
assert(cowerState.actors.pet.hasAggro == false,
    "Cower projection must not rewrite live pet aggro")

local petAggro = { groupSize = 4, hasAggro = false, tank = false,
    actors = { pet = { hasAggro = true } } }
local dropScore, dropReason = T:Score(petAggro, cower, "avoid")
assert(dropScore > 0 and dropReason == "reduces unwanted companion aggro")
applied, estimate = T:Apply(petAggro, cower, "avoid", 1)
assert(applied and estimate.lower == -225 and petAggro.actors.pet.hasAggro,
    "a projected drop cannot prove that live companion aggro ended")

local unknown = { groupSize = 1, actors = { pet = {} } }
local unknownGain = { facts = { kind = "petThreat", direction = "gain" } }
applied, estimate = T:Apply(unknown, unknownGain, "tank", 0.5)
assert(applied and estimate.delta == 0.5 and estimate.lower == nil
    and estimate.upper == nil and not estimate.amountKnown)
assert(estimate.confidence == "uncertain projection" and not estimate.known,
    "unknown baseline and rank amount must remain explicitly uncertain")

assert(T:Block({ actors = {} }, growl, "tank") == "companion unavailable")
assert(T:Block(solo, { facts = { kind = "damage" } }, "tank") == nil,
    "ordinary pet damage is outside this focused threat-policy helper")

print("ok: graph-native companion threat policy, scoring and uncertain projection")
