XelAssist = { Game = { Player = {} } }
table.getn = table.getn or function(value)
    local count = 0
    while value[count + 1] ~= nil do count = count + 1 end
    return count
end

local at = 0
GetTime = function() return at end
GetNampowerVersion = function() return 4, 7, 1 end
UnitExists = function(unit)
    return unit == "player", unit == "player" and "player-guid" or nil
end
UnitMana = function() return 60 end
UnitManaMax = function() return 100 end
UnitPowerType = function() return 3 end
local registered, callback = {}, nil
CreateFrame = function()
    return {
        RegisterEvent = function(_, name) registered[name] = true end,
        SetScript = function(_, _, value) callback = value end,
    }
end
dofile("Game/Player/EnergyEvidence.lua")
dofile("Game/Player/EnergyEvents.lua")
dofile("Game/Player/Resources.lua")
local Evidence = XelAssist.Game.Player.EnergyEvidence
local Resources = XelAssist.Game.Player.Resources

assert(registered.UNIT_ENERGY_GUID and registered.SPELL_ENERGIZE_ON_SELF
    and not registered.SPELL_ENERGIZE_BY_SELF
    and Evidence.externalEnergizeAvailable and callback,
    "player energy learning must register one exact player energize exclusion path")

event, arg1, arg2, arg3, arg4 = "PLAYER_ENTERING_WORLD", nil, nil, nil, nil
callback()
assert(Evidence.externalEnergizeAvailable,
    "world entry must preserve the process-scoped energize attribution capability")
Evidence:Observe("player-guid", 0, 100, 0, true, 3)
Evidence:Observe("player-guid", 20, 100, 2, true, 3)
Evidence:Observe("player-guid", 40, 100, 4, true, 3)
local learned = Evidence:Observe("player-guid", 60, 100, 6, true, 3)
assert(learned and learned.verified and learned.amount == 20
    and learned.observedInterval == 2 and learned.interval == 2.4
    and learned.phaseKnown and learned.nextIn == 2.4,
    "three exact uncapped ticks must establish a conservative energy envelope")

local state = { time = 0, resource = 20, resourceMax = 100,
    resourceType = 3, playerResourceReserved = 0,
    playerResourceClock = { verified = true, resourceType = 3,
        amount = 20, interval = 2.4, nextIn = 1, phaseKnown = true,
        externalEnergizeExcluded = true } }
assert(Resources:Earliest(state, 40, 0) == 1,
    "admission must wait for the first exact affordable tick")
assert(Resources:Earliest(state, 110, 0) == nil,
    "a cost above maximum available energy must be unreachable, not a timed wait")
assert(Resources:Advance(state, 0.9) == 0 and state.resource == 20)
assert(Resources:Advance(state, 0.2) == 20 and state.resource == 40)
assert(Resources:Spend(state, 30) and state.resource == 10,
    "projected actions must consume the ticked resource causally")

local unknown = { time = 0, resource = 20, resourceMax = 100,
    resourceType = 3, playerResourceReserved = 0 }
assert(Resources:Earliest(unknown, 40, 0) == nil,
    "an unlearned energy cadence must never invent future affordability")

assert(Evidence:ObserveEnergize("player-guid", 3, 6))
assert(Evidence:Snapshot("player-guid", 60, 100, 6) == nil,
    "spell energize evidence must invalidate passive tick attribution")

Evidence:ResetSession()
assert(Evidence.externalEnergizeAvailable,
    "session resets must not erase registered energize attribution")
event, arg1, arg2, arg3, arg4 = "UNIT_ENERGY_GUID", "other-guid", 1, 0, 0
callback()
assert(Evidence.guid == nil,
    "a GUID energy event for another unit must not seed player evidence")
event, arg1, arg2, arg3, arg4 = "UNIT_ENERGY_GUID", "player-guid", 1, 0, 0
callback()
assert(Evidence.guid == "player-guid",
    "the exact player GUID event must snapshot current energy")

print("ok: live-learned player energy evidence and graph clock")
