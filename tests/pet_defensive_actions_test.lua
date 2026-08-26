XelAssist = { Game = { Pets = {} }, Combat = {} }
table.getn = table.getn or function(value)
    local count = 0
    while value[count + 1] ~= nil do count = count + 1 end
    return count
end

local row = {
    school = 0, attributes = 536870928, castingTimeIndex = 1,
    recoveryTime = 60000, categoryRecoveryTime = 0, durationIndex = 29,
    powerType = 2, manaCost = 10, rangeIndex = 1,
    startRecoveryCategory = 133, startRecoveryTime = 1500,
    spellFamilyName = 9, spellFamilyFlags = 0, spellFamilyFlags2 = 128,
    effect = { 6, 6, 0 }, effectDieSides = { 1, 1, 0 },
    effectBasePoints = { 4294967245, 4294967260, 0 },
    effectImplicitTargetA = { 0, 0, 0 },
    effectImplicitTargetB = { 1, 1, 0 },
    effectApplyAuraName = { 87, 138, 0 },
    effectMiscValue = { 127, 0, 0 }, effectTriggerSpell = { 0, 0, 0 },
}
GetSpellRecField = function(id, field, array)
    if id ~= 26064 then return nil end
    local value = row[field]
    if array and type(value) == "table" then
        return { value[1], value[2], value[3] }
    end
    return value
end
GetSpellDuration = function(id, base)
    return id == 26064 and base == 1 and 12 or nil
end

dofile("Game/Pets/DefensiveActions.lua")
dofile("Combat/PetKnowledge.lua")
local D = XelAssist.Game.Pets.DefensiveActions

local facts = XelAssist.Combat.PetKnowledge:Facts(
    26064, "Localized Shell Shield", "HUNTER")
local profile = D:Profile(facts)
assert(profile and profile.incomingDamageMultiplier == 0.5
    and profile.meleeAttackTimeMultiplier == 1.35
    and profile.duration == 12 and profile.offensiveTimingExact == false
    and facts.petCombatEffects[1].sourceSpellId == 26064,
    "exact numeric Shell Shield must seal both defensive and timing effects")

local fallback = XelAssist.Combat.PetKnowledge:Facts(
    nil, "Shell Shield", "HUNTER")
assert(fallback and not D:Profile(fallback),
    "localized/name fallback must not inherit numeric Shell Shield arithmetic")
row.effectBasePoints = { 4294967246, 4294967260, 0 }
local shifted = D:CaptureFacts(26064,
    { kind = "petDefensive" }, "octowow dbc id")
assert(not D:Profile(shifted)
    and shifted.petDefensiveProfileReason == "Shell Shield DBC topology changed",
    "changed installed topology must fail closed")

print("ok: exact installed Shell Shield defensive profile")
