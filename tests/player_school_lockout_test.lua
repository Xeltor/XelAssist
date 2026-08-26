XelAssist = { Game = { Player = {} }, Graph = {} }
table.getn = table.getn or function(values)
    local count = 0
    for _ in ipairs(values) do count = count + 1 end
    return count
end

local effects = {}
C_LossOfControl = {
    GetActiveLossOfControlDataCount = function() return table.getn(effects) end,
    GetActiveLossOfControlData = function(index) return effects[index] end,
}

dofile("Game/Player/SchoolLockouts.lua")
local L = XelAssist.Game.Player.SchoolLockouts

effects = {
    { locType = "STUN", lockoutSchool = 0, timeRemaining = 2, duration = 3 },
    { locType = "SCHOOL_INTERRUPT", lockoutSchool = 16,
        timeRemaining = 3.5, duration = 4 },
}
local snapshot = L:Snapshot()
assert(snapshot.available and snapshot.exact
    and table.getn(snapshot.order) == 1
    and snapshot.byMask[16].remaining == 3.5,
    "server school-lockout evidence must be captured exactly")

local frost = { name = "Frostbolt", actor = "player", executor = "playerSpell" }
local fire = { name = "Fireball", actor = "player", executor = "playerSpell" }
local state = { playerSchoolLockouts = snapshot }
local blocker, handled = L:Blocker(state, frost, { school = 4 }, 0)
assert(handled and blocker == "spell school locked",
    "matching school must be illegal during the exact lockout")
blocker, handled = L:Blocker(state, fire, { school = 2 }, 0)
assert(handled and blocker == nil,
    "a different known school must remain legal")
blocker, handled = L:Blocker(state, frost, { school = 4 }, 3.5)
assert(not handled and blocker == nil,
    "the same school must become legal at exact lockout expiry")
blocker, handled = L:Blocker(state, frost, {}, 0)
assert(handled and blocker == "spell school unknown during lockout",
    "unknown spell school must fail closed only while a lockout is active")

effects[2].timeRemaining = 5
snapshot = L:Snapshot()
assert(snapshot.available and not snapshot.exact,
    "impossible remaining duration must invalidate the observation")
state.playerSchoolLockouts = snapshot
blocker, handled = L:Blocker(state, fire, { school = 2 }, 0)
assert(handled and blocker == "school lockout evidence unknown",
    "malformed active evidence must not manufacture legality")

C_LossOfControl = nil
snapshot = L:Snapshot()
assert(not snapshot.available and not snapshot.exact,
    "missing compatibility API must remain explicit rather than fabricate data")
print("ok: authoritative player school lockouts gate only matching spell schools")
