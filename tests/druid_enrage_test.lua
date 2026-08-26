XelAssist = { Game = { Player = {} }, Graph = {} }
math.huge = math.huge or 1 / 0
local function t(a, b, c) return { a or 0, b or 0, c or 0 } end
local row = { attributes = 262416, stances = 144,
    recoveryTime = 60000, durationIndex = 1, powerType = 1,
    spellFamilyName = 7, spellFamilyFlags = 524288,
    effect = t(6, 3, 6), effectBasePoints = t(19, -76),
    effectBaseDice = t(1, 1), effectApplyAuraName = t(24, 0, 94),
    effectImplicitTargetA = t(1, 0, 1), effectAmplitude = t(1000),
    effectMiscValue = t(1) }
function GetSpellRecField(id, field, copied)
    assert(id == 5229)
    local value = row[field]
    if value == nil then error("missing fixture " .. field) end
    if copied then return { value[1], value[2], value[3] } end
    return value
end
GetSpellDuration = function(id, base)
    assert(id == 5229 and base == 1); return 10000
end
UnitClass = function() return "Druid", "DRUID" end
GetPlayerBuff = function() return -1 end
GetPlayerBuffID = function() return nil end
GetPlayerBuffTimeLeft = function() return nil end

dofile("Game/Player/DruidEnrage.lua")
local Runtime = XelAssist.Game.Player.DruidEnrage
local facts, reason, handled = Runtime:InferKnowledge(5229)
assert(handled and not reason and facts.druidEnrage
    and facts.druidEnrageEvidence.totalRage == 20
    and facts.druidEnrageEvidence.armorDummyMagnitude == 75
    and facts.druidEnrageEvidence.bearArmorDescriptionPercent == 27
    and facts.druidEnrageEvidence.direBearArmorDescriptionPercent == 16,
    "installed Enrage must seal both rage and armor consequences")
local captured = Runtime:CaptureFacts({ facts = facts }, facts)
assert(captured.resourcePeriodic == 20 and captured.resourceImmediate == 0
    and captured.duration == 10 and captured.cooldown == 60,
    "captured Enrage must expose its finite rage clock")
local root = Runtime:Snapshot()
assert(root.available and root.exact and not root.active,
    "an observed absent Enrage aura must be exact")
row.effectBasePoints = t(19, -50)
Runtime:Invalidate()
local invalid = Runtime:InferKnowledge(5229)
assert(not invalid, "armor topology drift must fail closed")
row.effectBasePoints = t(19, -76)
Runtime:Invalidate()
facts = assert(Runtime:InferKnowledge(5229))

dofile("Graph/DruidEnrage.lua")
local Graph = XelAssist.Graph.DruidEnrage
local state = { resource = 10, resourceMax = 100, resourceType = 1,
    playerResourceExact = true,
    actors = { player = { guid = "player-guid", resource = 10,
        resourceMax = 100 } },
    druidFormState = { available = true, formID = 5 },
    hostileSwings = { lanes = { { victimKind = "player",
        interval = 2, nextSwingIn = 1, expectedDamage = 10 } } } }
assert(Graph:Attach(state, "DRUID"), "root Enrage state must attach")
local descriptor = { relation = "self", unit = "player", guid = "player-guid" }
local action = { spellId = 5229, facts = facts }
local projection = assert(Graph:Prepare(action, state, descriptor, facts))
local context = { state = state, wait = 0, cast = 0 }
assert(Graph:Score(context, projection)
    and context.resourceGain == 20 and context.value == -150,
    "five learned swings must charge the four-times armor upper bound")
local candidate = { action = action, classMechanicProjection = projection }
assert(Graph:Apply(state, candidate) and state.druidEnrage.active
    and state.playerResourceClock.kind == "druidEnrage"
    and state.playerResourceClock.amount == 2,
    "Enrage must open an exact ten-tick rage clock")
dofile("Game/Player/FiniteRageClock.lua")
assert(XelAssist.Game.Player.FiniteRageClock:Advance(state, 2.5) == 4
    and state.resource == 14
    and state.playerResourceClock.ticksRemaining == 8,
    "the shared finite rage clock must deliver exact Enrage ticks")
local amount, adjusted = Graph:AdjustProjectedSwing(state,
    { victimKind = "player" }, 10)
assert(adjusted and amount == 40,
    "active Enrage must conservatively bound learned physical damage")
Graph:Advance(state, 10)
assert(not state.druidEnrage.active,
    "the armor exposure must expire with Enrage")
state.druidFormState.formID = 1
assert(not Graph:Prepare(action, state, descriptor, facts),
    "Cat Form must not admit Enrage")
print("ok: Druid Enrage rage and armor lifecycle")
