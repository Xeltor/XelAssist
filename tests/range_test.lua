XelAssist = { Game = {} }
table.getn = table.getn or function(values)
    local count = 0
    while values[count + 1] ~= nil do count = count + 1 end
    return count
end
dofile("Game/Range.lua")
local Range = XelAssist.Game.Range

local modernCalls, legacyCalls = {}, {}
local modernResults, legacyResult = {}, nil
C_Spell = { IsSpellInRange = function(spell, unit)
    table.insert(modernCalls, { spell = spell, unit = unit })
    local value = modernResults[spell]
    if value == "error" then error("unsupported range query") end
    return value
end }
IsSpellInRange = function(spell, unit)
    table.insert(legacyCalls, { spell = spell, unit = unit })
    return legacyResult
end

modernResults[172] = 0
legacyResult = 1
assert(Range:SpellVerdict(172, "Corruption(Rank 1)", "target") == false
    and table.getn(modernCalls) == 1 and modernCalls[1].spell == 172
    and modernCalls[1].unit == "target" and table.getn(legacyCalls) == 0,
    "the numeric ClassicAPI verdict must be authoritative and normalized")

modernCalls, legacyCalls, modernResults = {}, {}, {}
modernResults[172] = nil
modernResults["Corruption(Rank 1)"] = true
assert(Range:SpellVerdict(172, "Corruption(Rank 1)", "mouseover") == true
    and table.getn(modernCalls) == 2
    and modernCalls[1].spell == 172
    and modernCalls[2].spell == "Corruption(Rank 1)"
    and modernCalls[2].unit == "mouseover"
    and table.getn(legacyCalls) == 0,
    "an unsupported numeric query must fall back to the modern name query")

modernCalls, legacyCalls, modernResults = {}, {}, {}
modernResults[172] = "error"
modernResults["Corruption(Rank 1)"] = nil
legacyResult = 0
assert(Range:SpellVerdict(172, "Corruption(Rank 1)", "party1") == false
    and table.getn(modernCalls) == 2 and table.getn(legacyCalls) == 1
    and legacyCalls[1].spell == "Corruption(Rank 1)"
    and legacyCalls[1].unit == "party1",
    "failed and unknown modern queries must fall back to the legacy API")

modernCalls, legacyCalls, modernResults = {}, {}, {}
modernResults[172] = -1
modernResults["Corruption(Rank 1)"] = "error"
legacyResult = true
assert(Range:SpellVerdict(172, "Corruption(Rank 1)", "target") == true,
    "unsupported modern values and errors must preserve a boolean legacy verdict")

modernCalls, legacyCalls, modernResults = {}, {}, {}
modernResults["Attack"] = 1
assert(Range:SpellVerdict(nil, "Attack", "target") == true
    and table.getn(modernCalls) == 1 and modernCalls[1].spell == "Attack",
    "a missing numeric ID must begin with the modern name query")
assert(Range:SpellVerdict(6603, nil, "target") == nil,
    "a failed numeric query without a cast name must remain unknown")

C_Spell, IsSpellInRange = nil, nil
assert(Range:SpellVerdict(172, "Corruption(Rank 1)", "target") == nil,
    "missing range APIs must remain unknown")

local verdict, reason = Range:BandVerdict(8, 30, 8, "center", false)
assert(verdict == true and reason == nil,
    "the minimum boundary must be inclusive")
verdict, reason = Range:BandVerdict(8, 30, 30, "center", false)
assert(verdict == true and reason == nil,
    "the maximum boundary must be inclusive")
verdict, reason = Range:BandVerdict(8, 30, 7.9, "center", false)
assert(verdict == false and reason == "minimum range",
    "distance below the minimum must be rejected")
verdict, reason = Range:BandVerdict(8, 30, 30.1, "center", false)
assert(verdict == false and reason == "range",
    "distance above the maximum must be rejected")
verdict, reason = Range:BandVerdict(8, 30, nil, "hitbox", false)
assert(verdict == nil and reason == "range unknown",
    "missing distance must remain unknown")
verdict, reason = Range:BandVerdict(nil, nil, 10, "hitbox", false)
assert(verdict == nil and reason == "range unknown",
    "an undiscovered range band must remain unknown")

verdict, reason = Range:BandVerdict(0, 5, 4, "center", true)
assert(verdict == nil and reason == "effect range unknown",
    "center distance must not prove a hitbox-required action in range")
verdict, reason = Range:BandVerdict(0, 5, 40, "center", true)
assert(verdict == nil and reason == "effect range unknown",
    "center distance must not prove a hitbox-required action out of range")
assert(Range:BandVerdict(0, 5, 4, "hitbox", true) == true
    and Range:BandVerdict(0, 5, 4, "combat reach", true) == true,
    "hitbox and combat-reach provenance must satisfy exact effect bands")
verdict, reason = Range:BandVerdict(0, 5, 6, "hitbox", true)
assert(verdict == false and reason == "range",
    "exact hitbox distance outside the effect band must be rejected")

local action = { facts = { effectMinRange = 0, effectMaxRange = 5,
    effectRangeHitbox = true }, tooltip = { minRange = 8, maxRange = 30 } }
local minimum, maximum, requiresHitbox, explicit = Range:EffectBand(action)
assert(minimum == 0 and maximum == 5 and requiresHitbox and explicit,
    "an explicit effect band must be independent of command tooltip range")
verdict, reason, explicit = Range:EffectVerdict(action, 4, "hitbox")
assert(verdict == true and reason == nil and explicit,
    "an exact distance inside the independent effect band must pass")
verdict, reason, explicit = Range:EffectVerdict(action, 12, "hitbox")
assert(verdict == false and reason == "range" and explicit,
    "command acceptance must not override an out-of-range effect payload")

verdict, reason, explicit = Range:EffectVerdict(
    { facts = {}, tooltip = { minRange = 8, maxRange = 30 } }, 20, "center")
assert(verdict == nil and reason == nil and not explicit,
    "tooltip command range must not become an implicit effect band")
verdict, reason = Range:TooltipVerdict({ minRange = 8, maxRange = 30 },
    20, "center")
assert(verdict == true and reason == nil,
    "tooltip range must remain independently evaluable")
verdict, reason = Range:TooltipVerdict({ minRange = 8, maxRange = 30 },
    4, "center")
assert(verdict == false and reason == "minimum range",
    "tooltip minimum range must retain its own verdict")

print("ok: exact spell, tooltip and effect range verdicts")
