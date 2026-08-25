XelAssist = { Game = {} }

dofile("Game/ComboMechanics.lua")
local C = XelAssist.Game.ComboMechanics

C_PlayerInfo = { GetComboPointState = function()
    return 3, "owner-guid"
end }
local observed = C:Observe("selected-guid", true)
assert(observed.points == 3 and observed.ownerGUID == "owner-guid"
    and observed.selectedExact and observed.globalExact
    and observed.source == "ClassicAPI combo owner",
    "ClassicAPI must expose exact hidden combo ownership")

C_PlayerInfo.GetComboPointState = function() return 0, "stale-guid" end
observed = C:Observe("selected-guid", true)
assert(observed.points == 0 and observed.ownerGUID == nil
    and observed.globalExact,
    "zero exact combo points must clear a stale owner")

C_PlayerInfo = nil
GetComboPoints = function() return 2 end
observed = C:Observe("selected-guid", true)
assert(observed.points == 2 and observed.ownerGUID == "selected-guid"
    and observed.globalExact,
    "stock non-zero points must be pinned to the selected hostile")

GetComboPoints = function() return 0 end
observed = C:Observe("selected-guid", true)
assert(observed.points == 0 and observed.ownerGUID == nil
    and observed.selectedExact and not observed.globalExact,
    "stock zero must prove only the selected target, not every prior target")

C_Spell = { GetSpellDurationRange = function(spellId)
    assert(spellId == 1943)
    return 6, 16, true
end }
local facts = {}
assert(C:ApplyDurationFacts({ spellId = 1943 }, facts)
    and facts.durationBase == 6 and facts.durationMax == 16
    and facts.durationComboScaled
    and facts.durationRangeSource == "ClassicAPI SpellDuration",
    "ClassicAPI duration endpoints must remain explicit graph facts")

C_Spell.GetSpellDurationRange = function() return nil end
facts = {}
assert(not C:ApplyDurationFacts({ spellId = 1943 }, facts)
    and facts.durationBase == nil,
    "missing custom-server duration rows must remain conservative")

print("ok: exact combo-owner and duration capability fallbacks")
