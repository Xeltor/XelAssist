XelAssist = { Game = { Player = {} }, Graph = {} }
table.getn = table.getn or function(value)
    local count = 0
    while value[count + 1] ~= nil do count = count + 1 end
    return count
end

local records = {
    sinister = { attributes = 327696, attributesEx = 134218240,
        attributesEx2 = 0, attributesEx4 = 0, stances = 0 },
    cheapShot = { attributes = 2555920, attributesEx = 134479872,
        attributesEx2 = 1048576, attributesEx4 = 0,
        stances = 536870912 },
    sap = { attributes = 1077346320, attributesEx = 134480128,
        attributesEx2 = 0, attributesEx4 = 0,
        stances = 536870912 },
}

dofile("Game/SpellClassification.lua")
local Classification = XelAssist.Game.SpellClassification
local function classify(record)
    local out = {}
    Classification:Apply({}, out, function(field) return record[field] end)
    return out
end

local sinister = classify(records.sinister)
local cheapShot = classify(records.cheapShot)
local sap = classify(records.sap)
assert(sinister.initiatesCombat and not sinister.initiatesCombatPostCast
    and not sinister.requiresStealth,
    "the direct client combat flag must classify Sinister Strike")
assert(cheapShot.initiatesCombat and cheapShot.initiatesCombatPostCast
    and cheapShot.requiresStealth and not cheapShot.stopsPlayerAttack,
    "the post-cast combat flag and stealth stance must classify Cheap Shot")
assert(not sap.initiatesCombat and sap.requiresStealth
    and sap.stopsPlayerAttack and not sap.preservesStealth,
    "Sap must remain a stealth action whose stop flag overrides Attack starts")

local clock, liveAttack = 10, 0
GetTime = function() return clock end
GetCurrentCastingInfo = function()
    return 0, 0, 0, 0, 0, 0, liveAttack
end
AttackTarget = function() error("productive actions must not issue AttackTarget") end
dofile("Game/PlayerAttack.lua")
dofile("Game/Player/Engagement.lua")
local Engagement = XelAssist.Game.Player.Engagement

local playerMelee = { actor = "player", executor = "playerSpell",
    facts = { kind = "builder", melee = true } }
assert(Engagement:Starts(playerMelee, sinister, "hostile"),
    "an exact player melee initiator must establish sustained Attack")
assert(not Engagement:Starts(playerMelee, sap, "hostile")
    and Engagement:Starts(playerMelee,
        { initiatesCombat = true, onNextSwing = true }, "hostile")
    and not Engagement:Starts({ actor = "pet", facts = { melee = true } },
        sinister, "hostile"),
    "stop precedence, exact on-swing starts and actor ownership must remain distinct")

IsStealthed = function() return 1 end
local stealthed, known, source = Engagement:StealthState()
assert(stealthed and known and source == "ClassicAPI player stealth flag",
    "ClassicAPI's exact unit stealth flag must be authoritative")
IsStealthed = nil
GetUnitField = nil
GetPlayerBuff = function(index)
    if index == 0 then return 7 end
    return -1
end
GetPlayerBuffID = function() return 1784 end
GetSpellRecField = function(_, field, copied)
    assert(copied == 1)
    if field == "effect" then return { 6, 6, 6 } end
    if field == "effectApplyAuraName" then return { 36, 16, 33 } end
end
stealthed, known, source = Engagement:StealthState()
assert(stealthed and known and source == "player stealth aura DBC",
    "the exact stealth aura type must protect clients without IsStealthed")

XelAssist.Game.PlayerAttack:Reset()
local submitted, reason = Engagement:Submitted(playerMelee, sinister,
    "hostile", "target-guid", 2)
local pending = XelAssist.Game.PlayerAttack:Snapshot()
assert(submitted and reason == nil and pending.pending
    and pending.pendingTargetGuid == "target-guid"
    and pending.source == "hostile action initiated Attack",
    "a productive melee submission must bridge the cast/event delay")
clock = 12
assert(XelAssist.Game.PlayerAttack:Snapshot().pending,
    "the engagement latch must cover the supplied cast delay")
clock = 12.8
assert(not XelAssist.Game.PlayerAttack:Snapshot().pending,
    "the engagement latch must retire after its bounded delay")

GetUnitField = function(unit, field)
    assert(unit == "player" and field == "bytes1")
    return 33554432
end
stealthed, known, source = Engagement:StealthState()
assert(stealthed and known and source == "Nampower player stealth flag",
    "the exact raw player flag must precede the sorted aura fallback")

XelAssist.Game.PlayerAttack:Submitted("target-guid", 1, "prior start")
assert(Engagement:Submitted(playerMelee, sap,
    "hostile", "target-guid", 0))
assert(not XelAssist.Game.PlayerAttack:Snapshot().pending,
    "an exact stop-Attack action must retire an earlier start latch")

dofile("Graph/PlayerEngagement.lua")
local sapState = { targetGUID = "target-guid", playerStealthed = true,
    playerStealthKnown = true,
    playerAttack = XelAssist.Game.PlayerAttack:Projected("target-guid") }
XelAssist.Graph.PlayerEngagement:Apply(sapState, {
    action = playerMelee, tooltip = sap, targetRelation = "hostile",
    targetGUID = "target-guid" })
assert(sapState.playerAttack.active == false
    and sapState.playerAttack.activeKnown
    and sapState.playerStealthed == false,
    "Sap must stop projected Attack and consume stealth without inventing damage")

print("ok: exact combat-initiation flags, stealth evidence and productive melee latch")
