-- Readable caster fixtures prove that one installed Spell.dbc cadence contract
-- drives the same graph breakpoint. Names never enter the production decision.
table.getn = table.getn or function(values)
    local count = 0
    while values and values[count + 1] ~= nil do count = count + 1 end
    return count
end

local records = {
    [5143] = { effectAmplitude = { 1000, 0, 0 } },
    [15407] = { effectAmplitude = { 1000, 0, 0 } },
    [689] = { effectAmplitude = { 1000, 0, 0 } },
}
function GetSpellRecField(spellId, field, asArray)
    local record = records[spellId]
    if record and asArray then return record[field] end
    return nil
end

XelAssist = { Game = {}, Graph = { State = {} } }
function XelAssist.Graph.State:FriendlyByKey() return nil end
dofile("Game/SpellTiming.lua")
dofile("Graph/ChannelCadence.lua")
dofile("Graph/ChannelBreakpoint.lua")
local Timing = XelAssist.Game.SpellTiming
local Breakpoint = XelAssist.Graph.ChannelBreakpoint

local fixtures = {
    { label = "Mage Arcane Missiles fixture", spellId = 5143,
        name = "arbitrary display text", kind = "damage", duration = 5 },
    { label = "Priest Mind Flay fixture", spellId = 15407,
        name = "different arbitrary text", kind = "damage", duration = 3 },
    { label = "Warlock Drain Life fixture", spellId = 689,
        name = "unread by graph", kind = "damage", duration = 5,
        leech = true },
}

local i
for i = 1, table.getn(fixtures) do
    local fixture = fixtures[i]
    local action = { spellId = fixture.spellId, name = fixture.name,
        facts = { channel = true, kind = fixture.kind } }
    local facts = { duration = fixture.duration }
    Timing:Apply(action, facts)
    assert(facts.channelInterval == 1
        and facts.channelIntervalSource
            == Breakpoint.EXACT_CADENCE_SOURCE,
        fixture.label .. " must expose installed-client cadence evidence")

    local remaining = fixture.duration == 3 and 2.2 or 3.2
    local state = { time = 8, playerChanneling = true,
        playerCastSpellId = fixture.spellId,
        playerCastTargetGUID = "enemy-guid", castRemaining = remaining,
        targetGUID = "enemy-guid", targetHealth = 500,
        targetHealthExact = true, health = 400, healthMax = 500 }
    local cadence = { source = facts.channelIntervalSource,
        interval = facts.channelInterval, total = fixture.duration,
        totalTicks = assert(Timing:TickCount(
            fixture.duration, facts.channelInterval)),
        rootRemaining = remaining, rootNextTickIn = 0.2,
        tickPower = 40 }
    local commitment = { known = true, spellId = fixture.spellId,
        targetGUID = "enemy-guid", targetMatches = true,
        selfChannel = false, kind = fixture.kind, cadence = cadence }
    if fixture.leech then
        commitment.leechEvidence = { damageFactor = 1, ratio = 1,
            applicationDelivery = 1, threatActor = "player",
            threatFactor = 1 }
    end
    local plan = assert(Breakpoint:Plan(state, commitment))
    assert(math.abs(plan.duration - 0.2) < 0.0001 and plan.ticks == 1
        and plan.remainingTicksAfter == plan.remainingTicksBefore - 1,
        fixture.label .. " must expose one marginal reconsideration edge")
end

-- The production planner must never consult DBC or any live API after capture.
GetSpellRecField = function() error("DBC read during graph search") end
GetTime = function() error("time read during graph search") end
GetCastInfo = function() error("cast read during graph search") end
local state = { time = 0, playerChanneling = true,
    playerCastSpellId = 5143, playerCastTargetGUID = "enemy-guid",
    castRemaining = 3.2, targetGUID = "enemy-guid", targetHealth = 500,
    targetHealthExact = true }
local commitment = { known = true, spellId = 5143,
    targetGUID = "enemy-guid", targetMatches = true, selfChannel = false,
    kind = "damage", cadence = { source = Breakpoint.EXACT_CADENCE_SOURCE,
        interval = 1, total = 5, totalTicks = 5, rootRemaining = 3.2,
        rootNextTickIn = 0.2, tickPower = 40 } }
assert(Breakpoint:Plan(state, commitment),
    "frozen graph search must remain independent of live client APIs")

print("ok: Mage Priest and Warlock share name-independent tick breakpoints")
