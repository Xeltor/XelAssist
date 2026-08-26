-- Root snapshots and graph descendants may consume only exact learned mana
-- clocks. Spell starts close unknown regimes and exact GO contracts rearm them.
XelAssist = { Game = { Player = {} }, Graph = {} }
table.getn = table.getn or function(value)
    local count = 0
    while value[count + 1] ~= nil do count = count + 1 end
    return count
end

local calls = { manaSnapshot = 0, manaObserve = 0, energyObserve = 0 }
XelAssist.Game.Player.ManaEvidence = {
    Snapshot = function(_, guid, value, maximum, at)
        calls.manaSnapshot = calls.manaSnapshot + 1
        assert(guid == "player-guid" and value == 30 and maximum == 100
            and at == 17, "root mana snapshot must receive frozen state")
        return { verified = true, resourceType = 0, amount = 10,
            interval = 2, nextIn = 1, phaseKnown = true,
            externalEnergizeExcluded = true }
    end,
    Observe = function() calls.manaObserve = calls.manaObserve + 1 end,
}
XelAssist.Game.Player.EnergyEvidence = {
    Observe = function(_, guid, value, maximum, at, exact, kind)
        calls.energyObserve = calls.energyObserve + 1
        assert(guid == "player-guid" and value == 30 and maximum == 100
            and at == 18 and exact == false and kind == 3)
        return { verified = true, resourceType = 3 }
    end,
}

dofile("Game/Player/Resources.lua")
dofile("Graph/PlayerResourceTimeline.lua")
local Resources = XelAssist.Game.Player.Resources
local Timeline = XelAssist.Graph.PlayerResourceTimeline
local root = { resourceType = 0, resource = 30, resourceMax = 100 }
local evidence = Resources:RootEvidence(root, { guid = "player-guid" }, 17)
assert(evidence and evidence.resourceType == 0 and calls.manaSnapshot == 1
    and calls.manaObserve == 0 and calls.energyObserve == 0,
    "graph root must snapshot mana evidence without training it")
root.resourceType = 3
assert(Resources:RootEvidence(root, { guid = "player-guid" }, 18)
    and calls.energyObserve == 1 and calls.manaObserve == 0,
    "energy must preserve its established root observation path")

local function action(spellId, costKnown)
    return { action = { spellId = spellId, actor = "player", facts = {} },
        cost = 20, costKnown = costKnown, wait = 2, cast = 1.5,
        downtime = 3.5 }
end
local function manaState(spellId, boundary)
    return { time = 0, resourceType = 0, resource = 30,
        resourceMax = 100, playerResourceReserved = 0,
        playerResourceClock = { verified = true, resourceType = 0,
            amount = 10, interval = 2, nextIn = 1, phaseKnown = true,
            externalEnergizeExcluded = true,
            postSpend = { verified = true, boundary = boundary or "go",
                spellId = spellId or 686, delay = 5 } } }
end

local waiting = manaState()
assert(Resources:Earliest(waiting, 50, 0) == 3,
    "verified root mana ticks must expose exact future affordability")
local events = {}
assert(Timeline:Append(events, waiting, action(686, true), 4, 3.5) == 5
    and table.getn(events) == 1 and events[1].offset == 2
    and events[1].kind == "chosenActionStart" and events[1].order == 4,
    "mana casting must add one causal start after its resource wait")

local matched = manaState()
Resources:Advance(matched, 2)
assert(matched.resource == 40 and matched.playerResourceClock.nextIn == 1,
    "root phase may advance during the pre-cast wait")
assert(Timeline:Begin(matched, action(686, true))
    and matched.playerResourceClock.pendingSpendSpellId == 686
    and matched.playerResourceClock.phaseKnown,
    "an exact GO contract may preserve the clock through cast time")
Resources:Advance(matched, 1.5)
assert(matched.resource == 50,
    "a repeatedly observed GO-paid spell may receive a pre-GO passive tick")
assert(Resources:Spend(matched, 20, action(686, true))
    and matched.resource == 30 and matched.playerResourceClock.phaseKnown
    and matched.playerResourceClock.nextIn == 5
    and matched.playerResourceClock.pendingSpendSpellId == nil,
    "matching payment must rearm the observed spend-to-gain delay")
assert(Resources:Advance(matched, 4.9) == 0
    and Resources:Advance(matched, 0.2) == 10,
    "post-spend mana must wait for the conservative learned delay")

local mismatched = manaState()
Timeline:Begin(mismatched, action(999, true))
assert(not mismatched.playerResourceClock.phaseKnown
    and mismatched.playerResourceClock.nextIn == nil,
    "a different spell must close the clock before its cast")
assert(Resources:Spend(mismatched, 20, action(999, true))
    and not mismatched.playerResourceClock.phaseKnown,
    "mismatched payment must not fabricate future mana")

local startPaid = manaState(686, "start")
Timeline:Begin(startPaid, action(686, true))
assert(not startPaid.playerResourceClock.phaseKnown,
    "a start-paid contract must fail closed until payment timing is modeled")
local estimated = manaState()
Timeline:Begin(estimated, action(686, false))
assert(not estimated.playerResourceClock.phaseKnown,
    "an estimated cost must not inherit an exact post-spend clock")
local free = action(686, true)
free.cost = 0
local freeEvents = {}
assert(Timeline:Append(freeEvents, manaState(), free, 1, 2) == 1
    and table.getn(freeEvents) == 0,
    "free actions must not disturb or schedule a mana-spend boundary")

print("ok: exact mana clocks cross only matching GO-paid graph actions")
