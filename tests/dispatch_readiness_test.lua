XelAssist = { Core = {}, Game = { Capabilities = {} } }

local usable, ready, combat = nil, true, false
XelAssist.Game.Capabilities.Usable = function() return usable end
XelAssist.Game.Capabilities.IsReady = function() return ready end
UnitAffectingCombat = function() return combat end

dofile("Core/DispatchReadiness.lua")
local Readiness = XelAssist.Core.DispatchReadiness
local charge = { name = "Charge", slot = 1, executor = "playerSpell",
    facts = { requiresExactUsability = true, outOfCombat = true } }

assert(Readiness:Player(charge, false) == "action availability unknown",
    "an exact-usability action must not dispatch from unknown live evidence")
usable = false
assert(Readiness:Player(charge, false) == "action unavailable",
    "an explicitly unusable Charge must not dispatch")
usable = true
assert(Readiness:Player(charge, false) == nil,
    "an exactly usable, ready, out-of-combat Charge may dispatch")
combat = true
assert(Readiness:Player(charge, false) == "combat state",
    "combat beginning after recommendation must cancel Charge dispatch")

combat, usable = false, nil
local ordinary = { name = "Ordinary", facts = {} }
assert(Readiness:Player(ordinary, false) == nil,
    "ordinary actions must retain conservative unknown-usability behavior")

print("ok: final Charge usability and combat-state dispatch gates")
