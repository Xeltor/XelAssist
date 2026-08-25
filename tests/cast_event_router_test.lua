XelAssist = { Core = {}, Game = { Player = {} }, Combat = {} }
table.getn = table.getn or function(value) return #value end

local mockTime = 10
GetTime = function() return mockTime end
local guids = {
    player = "player-guid",
    pet = "pet-guid",
    target = "selected-enemy-guid",
}
UnitExists = function(unit)
    local guid = guids[unit]
    return guid ~= nil, guid
end
SpellInfo = function(spellId) return "Spell " .. tostring(spellId) end

local ownedGuids = { ["player-guid"] = true, ["pet-guid"] = true }
XelAssist.Combat.Resistance = {
    IsOwnedCaster = function(_, guid) return ownedGuids[guid] and true or false end,
}

local hostileCalls = {}
XelAssist.Game.HostileCasts = {
    Reset = function() table.insert(hostileCalls, { "reset" }) end,
    ObserveStartOther = function(_, ...)
        table.insert(hostileCalls, { "start", ... })
    end,
    ObserveGoOther = function(_, ...)
        table.insert(hostileCalls, { "go", ... })
    end,
    ObserveFailedOther = function(_, ...)
        table.insert(hostileCalls, { "failed", ... })
    end,
    ObserveUnitCast = function(_, ...)
        table.insert(hostileCalls, { "unit", ... })
    end,
}
local observedResetCount = 0
local provenHostiles = {
    ["enemy-guid"] = true,
    ["selected-enemy-guid"] = true,
}
XelAssist.Game.Hostiles = {
    ProvesGuid = function(_, guid) return provenHostiles[guid] == true end,
    ResetObserved = function() observedResetCount = observedResetCount + 1 end,
}

local accepted, failed = {}, {}
XelAssist.Core.PlayerNormalQueue = {
    ServerAccepted = function(_, spellId, targetGuid)
        table.insert(accepted, { spellId, targetGuid })
        return { spellId = spellId }
    end,
    ServerFailure = function(_, spellId, targetGuid)
        table.insert(failed, { spellId, targetGuid })
        return { spellId = spellId }
    end,
}
XelAssist.Core.PlayerQueueEvents = {
    Allows = function() return true end,
}

local channelStarts, channelClears = {}, 0
XelAssist.Game.Player.ChannelRuntime = {
    Start = function(_, ...)
        table.insert(channelStarts, { ... })
    end,
    Clear = function() channelClears = channelClears + 1 end,
}

local touches, auraClears, petClears = {}, {}, {}
local decisions, pendingClears, failures = {}, {}, {}
function XelAssist:PlayerGUID() return guids.player end
function XelAssist:TouchPendingSpell(...)
    table.insert(touches, { ... })
end
function XelAssist:ClearAuraPending(...)
    table.insert(auraClears, { ... })
end
function XelAssist:ClearPetCast(...)
    table.insert(petClears, { ... })
    self.petCastGuid, self.petCastSpellId = nil, nil
    self.petCastUntil, self.petCastChannel = nil, nil
end
function XelAssist:UpdateDecisionStatus(...)
    table.insert(decisions, { ... })
end
function XelAssist:ClearPendingBySpell(...)
    table.insert(pendingClears, { ... })
end
function XelAssist:MarkPendingFailure(...)
    table.insert(failures, { ... })
end

dofile("Core/CastEventRouter.lua")
local R = XelAssist.Core.CastEventRouter

XelAssist.targetCastUntil, XelAssist.targetCastGUID = 99, "stale-target"
XelAssist.petCastGuid, XelAssist.petCastSpellId = "stale-pet", 999
XelAssist.petCastUntil, XelAssist.petCastChannel = 99, true
R:Reset()
assert(hostileCalls[1][1] == "reset",
    "router reset must clear the session-only hostile ledger")
assert(observedResetCount == 1 and XelAssist.targetCastUntil == nil
    and XelAssist.targetCastGUID == nil and XelAssist.petCastGuid == nil
    and XelAssist.petCastSpellId == nil and XelAssist.petCastUntil == nil
    and XelAssist.petCastChannel == nil,
    "router reset must clear hostile proof and router-owned cast occupancy")

R:HandleNampower(XelAssist, "SPELL_START_OTHER",
    7, 100, "enemy-guid", "victim-guid", 19, 1200, 3000, 1)
local call = hostileCalls[2]
assert(call[1] == "start" and call[2] == "enemy-guid"
    and call[3] == "victim-guid" and call[4] == 100
    and call[5] == 1200 and call[6] == 3000 and call[7] == 1
    and call[8] == false and call[9] == mockTime,
    "START_OTHER must retain exact caster, target, spell and timing fields")
assert(table.getn(touches) == 0,
    "a proven hostile start must not enter the owned pending-cast lane")

mockTime = 10.2
R:HandleNampower(XelAssist, "SPELL_GO_OTHER",
    7, 100, "enemy-guid", "victim-guid")
call = hostileCalls[3]
assert(call[1] == "go" and call[2] == "enemy-guid"
    and call[3] == "victim-guid" and call[4] == 100
    and call[5] == false and call[6] == mockTime,
    "GO_OTHER must retain its exact caster, target and spell shape")

mockTime = 10.3
R:HandleNampower(XelAssist, "SPELL_FAILED_OTHER", "enemy-guid", 100)
call = hostileCalls[4]
assert(call[1] == "failed" and call[2] == "enemy-guid"
    and call[3] == 100 and call[4] == false and call[5] == mockTime
    and call[6] == nil,
    "FAILED_OTHER must route only caster+spell and never invent a target")

mockTime = 20
R:HandleNampower(XelAssist, "SPELL_START_OTHER",
    0, 200, "pet-guid", "victim-guid", 0, 1500, 3000, 1)
call = hostileCalls[5]
assert(call[1] == "start" and call[8] == true,
    "owned Nampower evidence must reach the ledger exclusion before pet routing")
assert(XelAssist.petCastGuid == "pet-guid" and XelAssist.petCastSpellId == 200
    and XelAssist.petCastChannel and XelAssist.petCastUntil == 24.5,
    "owned pet channel occupancy must preserve cast plus channel duration")
assert(touches[1][1] == 200 and touches[1][2] == "started"
    and touches[1][3] == 6.5 and touches[1][4] == "pet-guid"
    and touches[1][5] == "victim-guid",
    "owned pet start behavior must survive extraction")

XelAssist.currentPendingAuras = {
    ["pet-guid"] = { name = "Pet Spell", target = "victim-guid", spellId = 200 },
}
R:HandleNampower(XelAssist, "SPELL_FAILED_OTHER", "pet-guid", 200)
assert(auraClears[1][1] == "Pet Spell" and auraClears[1][2] == "victim-guid"
    and auraClears[1][3] == "pet-guid" and petClears[1][1] == 200,
    "owned pet failure must still clear only its matching pending spell")

mockTime = 30
R:HandleUnitCast(XelAssist, "enemy-guid", nil, "START", 300, 1800)
call = hostileCalls[7]
assert(call[1] == "unit" and call[2] == "enemy-guid"
    and call[3] == nil and call[4] == "START" and call[5] == 300
    and call[6] == 1800 and call[7] == false and call[8] == mockTime,
    "UNIT_CASTEVENT fallback must preserve an unknown target as nil")

R:HandleUnitCast(XelAssist, "selected-enemy-guid", "player-guid",
    "CHANNEL", 301, 2500)
assert(XelAssist.targetCastGUID == "selected-enemy-guid"
    and XelAssist.targetCastUntil == 32.5,
    "selected-target cast occupancy must survive extraction")
R:HandleUnitCast(XelAssist, "selected-enemy-guid", "player-guid",
    "FAIL", 301, 0)
assert(XelAssist.targetCastGUID == nil and XelAssist.targetCastUntil == nil,
    "selected-target terminal evidence must still clear occupancy")

R:HandleUnitCast(XelAssist, "player-guid", "victim-guid", "START", 400, 900)
assert(accepted[1][1] == 400 and accepted[1][2] == "victim-guid"
    and decisions[1][1] == 400 and decisions[1][2] == "player"
    and decisions[1][3] == "START"
    and channelStarts[1][1] == 400 and channelStarts[1][2] == "victim-guid"
    and channelStarts[1][3] == 900 and channelStarts[1][4] == false,
    "player queue and channel tracking must survive extraction")
R:HandleUnitCast(XelAssist, "player-guid", "victim-guid", "FAIL", 400, 0)
assert(failed[1][1] == 400 and channelClears == 1
    and failures[1][1] == 400 and failures[1][2] == "player-guid"
    and failures[1][3] == "victim-guid",
    "player failure routing must remain attempt-gated and exact-targeted")

R:HandleUnitCast(XelAssist, "pet-guid", "victim-guid", "CHANNEL", 500, 2200)
assert(XelAssist.petCastGuid == "pet-guid" and XelAssist.petCastChannel
    and XelAssist.petCastUntil == 32.2,
    "SuperWoW pet channel fallback must preserve existing occupancy behavior")
R:HandleUnitCast(XelAssist, "pet-guid", "victim-guid", "FAIL", 500, 0)
assert(pendingClears[1][1] == 500 and pendingClears[1][2] == "pet-guid"
    and pendingClears[1][3] == "victim-guid",
    "SuperWoW pet failure must preserve exact pending cleanup")

local hostileCount, touchCount = table.getn(hostileCalls), table.getn(touches)
R:HandleNampower(XelAssist, "SPELL_START_OTHER",
    0, 600, "friendly-guid", "victim-guid", 0, 1000, 0, 0)
call = hostileCalls[hostileCount + 1]
assert(call and call[1] == "start" and call[8] == nil
    and table.getn(touches) == touchCount,
    "a non-owned but unproven caster must remain unknown, never hostile")

hostileCount = table.getn(hostileCalls)
R:HandleUnitCast(XelAssist, "enemy-guid", nil, "MAINHAND", 0, 0)
assert(table.getn(hostileCalls) == hostileCount,
    "non-cast UNIT_CASTEVENT statuses must be discarded before routing")

print("ok: cast event routing and owned lifecycle preservation")
