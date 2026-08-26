XelAssist = { Game = { Player = {} } }
local flames = { [8050] = true, [8052] = true, [8053] = true,
    [10447] = true, [10448] = true, [29228] = true }
local talents = { [16085] = 3000, [51864] = 6000 }
local active, live = 51864, 18000

function IsPlayerSpell(id) return id == active end
function GetSpellDuration(_, base) return base and 12000 or live end
function GetSpellRecField(id, field, array)
    if flames[id] then
        if field == "spellFamilyName" then return 11 end
        if field == "spellFamilyFlags" then return 268435456 end
        if array and field == "effect" then return { 2, 6, 0 } end
        if array and field == "effectApplyAuraName" then return { 0, 3, 0 } end
        if array and field == "effectAmplitude" then return { 0, 3000, 0 } end
    elseif talents[id] then
        if field == "spellFamilyName" then return 11 end
        if field == "spellFamilyFlags" then return 0 end
        if array and field == "effect" then return { 6, 0, 0 } end
        if array and field == "effectApplyAuraName" then return { 107, 0, 0 } end
        if array and field == "effectMiscValue" then return { 1, 0, 0 } end
        if array and field == "effectBasePoints" then
            return { talents[id] - 1, 0, 0 }
        end
    end
end

dofile("Game/Player/ShamanFlameShockTiming.lua")
local T = XelAssist.Game.Player.ShamanFlameShockTiming
for id in pairs(flames) do
    local facts = T:Promote(id, { shamanFlameShock = true })
    local captured = T:CaptureFacts({ spellId = id }, facts)
    assert(captured.duration == 18 and captured.shamanFlameShockDurationExact
        and captured.shamanFlameShockBaseDuration == 12
        and captured.shamanFlameShockTalentSpellId == 51864
        and captured.shamanFlameShockTalentDuration == 6,
        "every Flame Shock rank must use the exact engine-effective duration")
end

active, live = 16085, 15000
local lower = T:CaptureFacts({ spellId = 8050 },
    T:Promote(8050, { shamanFlameShock = true }))
assert(lower.duration == 15 and lower.shamanFlameShockTalentSpellId == 16085,
    "the installed three-second modifier must remain distinct")

active, live = nil, 12000
local base = T:CaptureFacts({ spellId = 8052 },
    T:Promote(8052, { shamanFlameShock = true }))
assert(base.duration == 12 and base.shamanFlameShockDurationExact
    and base.shamanFlameShockTalentSpellId == nil,
    "untalented Flame Shock must retain its twelve-second duration")

active, live = 51864, 15000
local mismatch = T:CaptureFacts({ spellId = 8053 },
    T:Promote(8053, { shamanFlameShock = true }))
assert(mismatch.duration == 15 and mismatch.shamanFlameShockDurationExact
    and mismatch.shamanFlameShockTalentSpellId == nil
    and mismatch.shamanFlameShockTalentOwnershipReason ==
        "engine duration and Improved Flame Shock ownership disagree",
    "engine duration must win over contradictory passive ownership")

live = 17000
local invalid = T:CaptureFacts({ spellId = 10447 },
    T:Promote(10447, { shamanFlameShock = true }))
assert(not invalid.shamanFlameShockDurationExact
    and invalid.shamanFlameShockTimingReason ==
        "effective Flame Shock duration is not exact",
    "non-tick-aligned duration evidence must fail closed")

local unrelated = { kind = "damage" }
assert(T:Promote(403, unrelated) == unrelated
    and not unrelated.shamanFlameShockTiming,
    "unrelated actions must not be claimed")

print("ok: Octo Improved Flame Shock duration is engine-sealed")
