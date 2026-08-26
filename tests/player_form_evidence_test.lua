-- Exact form IDs cover Warrior stances and non-Warrior shapeshifts without
-- deriving state from localized aura or action names.
XelAssist = { Game = { Player = {} } }

local live = 17
GetShapeshiftFormID = function() return live end
dofile("Game/Player/FormEvidence.lua")
local Forms = XelAssist.Game.Player.FormEvidence

local value = Forms:Snapshot()
assert(value.available and value.formID == 17
    and value.source == "ClassicAPI stable SpellShapeshiftForm ID",
    "Battle Stance must retain its stable installed-client form ID")

live = 0
value = Forms:Snapshot()
assert(value.available and value.formID == 0,
    "an exact neutral form must remain distinct from unavailable evidence")

live = 33
value = Forms:Snapshot()
assert(not value.available and value.formID == nil
    and value.reason == "player form observation invalid",
    "out-of-domain form IDs must fail closed")

GetShapeshiftFormID = nil
value = Forms:Snapshot()
assert(not value.available and value.reason == "player form API unavailable",
    "a missing ClassicAPI bridge must remain explicit")

print("ok: exact class-neutral player form evidence")
