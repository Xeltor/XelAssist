XelAssist = { UI = {}, Game = { Capabilities = {
    SpellSlot = function() return 7 end,
} } }
BOOKTYPE_SPELL = "spell"
local calls, cooldown = 0, { start = 12, duration = 4, enabled = 1 }
CooldownFrame_SetTimer = function(_, start, duration, enabled)
    calls = calls + 1
    cooldown.last = { start, duration, enabled }
end
GetSpellCooldown = function()
    return cooldown.start, cooldown.duration, cooldown.enabled
end

dofile("UI/HUDCooldown.lua")
local HUDCooldown = XelAssist.UI.HUDCooldown
local button = { cooldown = {} }
local spell = { name = "Test", executor = "playerSpell" }

assert(HUDCooldown:Update(button, spell) and calls == 1)
assert(not HUDCooldown:Update(button, spell) and calls == 1,
    "an unchanged timer must not be cleared and restarted")
cooldown.duration = 2
assert(HUDCooldown:Update(button, spell) and calls == 2,
    "a material cooldown change must update the overlay")
assert(HUDCooldown:Update(button, nil) and calls == 3
    and cooldown.last[2] == 0)
assert(not HUDCooldown:Update(button, nil) and calls == 3,
    "an already clear overlay must remain untouched")

print("ok: cooldown overlay writes only material timer changes")
