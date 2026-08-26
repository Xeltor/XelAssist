XelAssist = { Combat = {}, Game = {} }
table.getn = table.getn or function(value) return #value end

dofile("Combat/Knowledge.lua")
local knowledge = XelAssist.Combat.Knowledge
assert(knowledge.Maul.melee == true and knowledge.Maul.threat == nil
    and knowledge.Swipe.aoe == true and knowledge.Swipe.threat == nil
    and knowledge["Savage Bite"].melee == true
    and knowledge["Savage Bite"].threat == nil,
    "Bear attacks must not carry unproved Octowow threat coefficients")

dofile("Game/SpellClassification.lua")
local out = {}
XelAssist.Game.SpellClassification:Apply({ facts = knowledge.Maul }, out,
    function(field)
        local record = { attributes = 0x414, stances = 0x90,
            stancesNot = 0, spellFamilyName = 7, spellFamilyFlags = 0 }
        return record[field]
    end)
assert(out.onNextSwing == true and out.stances == 0x90,
    "installed Maul attributes must preserve its queued Bear attack identity")

print("ok: patch-5 Bear attack evidence boundaries")
