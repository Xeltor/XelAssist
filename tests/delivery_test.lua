table.getn = table.getn or function(value)
    local count = 0
    while value[count + 1] ~= nil do count = count + 1 end
    return count
end

local guids = { player = "player-guid", pet = "pet-guid", target = "target-guid" }
UnitExists = function(unit)
    return guids[unit] ~= nil, guids[unit]
end

local skills = {
    main = { total = 300, known = true, source = "main skill" },
    off = { total = 295, known = true, source = "off skill" },
    ranged = { total = 290, known = true, source = "ranged skill" },
    mainToken = "main-item", offToken = "off-item", rangedToken = "ranged-item",
    dualWield = true, dualWieldKnown = true, formWeaponUseKnown = true,
}
XelAssistCapabilities = { WeaponSkills = function() return skills end }

dofile("XelAssist_Delivery.lua")
local D = XelAssistDelivery

local function close(actual, expected, message)
    assert(math.abs(actual - expected) < 0.0001,
        (message or "values differ") .. ": " .. tostring(actual) .. " vs "
            .. tostring(expected))
end

local normalRanged = D:SpellTraits(1, 32768, 4, 2)
assert(normalRanged.deliveryModel == "physical"
    and normalRanged.deliverySubtype == "ranged"
    and normalRanged.usesWeaponSkill == true,
    "normal-ranged MAGIC must use ranged weapon delivery")
local noneRanged = D:SpellTraits(0, 32768, 2, -1)
assert(noneRanged.deliveryModel == "none" and noneRanged.deliverySubtype == nil
    and noneRanged.combatRange and noneRanged.usesWeaponSkill,
    "normal-ranged must not override DmgClass NONE or Combat Range skill use")
local levelMax = D:SpellTraits(2, 0, 3, -1)
assert(levelMax.deliveryModel == "physical" and levelMax.deliverySubtype == "melee"
    and levelMax.usesWeaponSkill == false and levelMax.combatRange == false,
    "noncombat non-weapon ability must use level-max skill")
local unknownTraits = D:SpellTraits(nil, nil, nil, nil)
assert(unknownTraits.deliveryModel == nil and not unknownTraits.deliveryModelKnown
    and unknownTraits.usesWeaponSkill == nil and not unknownTraits.alwaysHitKnown,
    "missing DBC delivery traits must remain unknown")

local model, known, source = D:Model({ deliveryModel = "magic" },
    { deliveryModel = "physical" })
assert(model == "magic" and known and source == "action semantics",
    "explicit action delivery semantics must outrank DBC metadata")
model, known = D:Model({ melee = true }, {})
assert(model == "physical" and not known,
    "catalogue melee fallback must retain classification uncertainty")
assert(D:Subtype({ weaponRanged = true }, {}, "physical") == "ranged"
    and D:Subtype({ melee = true }, {}, "magic") == nil,
    "delivery subtype must apply only to physical tables")

assert(D:AutoAttackEvidence(40, 0, 1) == "hit"
    and D:AutoAttackEvidence(0, 16, 0) == "ordinary-miss"
    and D:AutoAttackEvidence(0, 0, 2) == "ordinary-miss"
    and D:AutoAttackEvidence(0, 0, 3) == "ordinary-miss"
    and D:AutoAttackEvidence(0, 0, 5) == "ordinary-miss",
    "resolved white attack outcomes were classified incorrectly")
local noAction, noActionReason = D:AutoAttackEvidence(40, 65536, 1)
local interruptState = D:AutoAttackEvidence(40, 0, 4)
assert(noAction == nil and noActionReason == "melee spell packet"
    and interruptState == nil,
    "NOACTION and undocumented victim states must not train white delivery")

local profile = { deliveryContexts = {}, spellDeliveryContexts = {} }
local magicContext = { deliveryModel = "magic", deliveryModelKnown = true,
    key = "player:l60:p0:direct" }
local shared, specific, key = D:Record(profile, 133, magicContext, "hit", 1, 100)
D:Record(profile, 133, magicContext, "ordinary-miss", 1, 101)
assert(key == "player:l60:p0:direct" and shared.samples == 2
    and shared.hits == 1 and shared.misses == 1
    and specific == profile.spellDeliveryContexts["133:" .. key]
    and specific.samples == 2 and specific.lastSeen == 101,
    "shared and spell-specific delivery evidence shape changed")
local rejected = D:Record(profile, nil,
    { deliveryModel = "none", deliveryModelKnown = true, key = "none" },
    "hit", 1, 102)
assert(rejected == nil and not profile.deliveryContexts.none,
    "DmgClass NONE must reject ordinary delivery evidence")
local physicalUnknown = { deliveryModel = "physical", deliveryModelKnown = false,
    deliverySubtype = "melee", deliveryKey = "player:l60:p-:mc0" }
D:Record(profile, nil, physicalUnknown, "hit", 1, 103)
assert(profile.deliveryContexts["physical-melee:player:l60:p-:mc0"].hits == 1,
    "facts-derived physical evidence must remain in its uncertain mc0 partition")
local learned, samples = D:Learned({ samples = 1, hits = 1, lastSeen = 100 },
    0.8, function() return 1 end, 4)
close(learned, 0.84, "ordinary delivery posterior changed")
assert(samples == 1, "ordinary delivery sample weight changed")
close(D:BaseSpellHit(60, 63, false), 0.83, "boss-level spell prior changed")

local identity = { guid = "target-guid", level = 60, isPlayer = false }
local context = { actor = "player", level = 60, deliveryModel = "physical",
    deliveryModelKnown = true, deliverySubtype = "melee",
    positionKnown = true, behindTarget = false, positionSource = "test geometry" }
local whiteMain = D:PhysicalContext({ actor = "player", facts = {
    melee = true, whiteAttack = true, weaponHand = "main", alwaysHit = false } },
    {}, context, identity)
close(whiteMain.hitChance, 0.76, "dual-wield main white prior changed")
assert(whiteMain.hand == "main" and whiteMain.weaponSkill == 300
    and whiteMain.dualWieldWhitePenalty == 19
    and string.find(whiteMain.key, ":wt1:", 1, true),
    "white main-hand fingerprint is incomplete")
local whiteOff = D:PhysicalContext({ actor = "player", facts = {
    melee = true, whiteAttack = true, weaponHand = "off", alwaysHit = false } },
    {}, context, identity)
close(whiteOff.hitChance, 0.755, "dual-wield off white prior changed")
assert(whiteOff.hand == "off" and whiteOff.weaponSkill == 295,
    "off-hand white swing must use current off-hand skill")
local yellowOff = D:PhysicalContext({ actor = "player", facts = {
    melee = true, weaponHand = "off", usesWeaponSkill = true, alwaysHit = false } },
    {}, context, identity)
close(yellowOff.hitChance, 0.95, "yellow weapon prior changed")
assert(yellowOff.hand == "main" and yellowOff.dualWieldWhitePenalty == 0
    and string.find(yellowOff.key, ":wt0:", 1, true),
    "yellow off-hand-labelled ability must use the server's main-hand miss roll")
local applied = { actor = "player", level = 60, key = "player:l60:p500" }
D:ApplyPhysicalContext(applied, whiteMain)
assert(string.find(applied.deliveryKey, "player:l60:p-:", 1, true)
    and not string.find(applied.deliveryKey, "p500", 1, true),
    "physical delivery key must exclude Armor/spell penetration")

UnitDefense = function() return 250, 5 end
local pvp = D:PhysicalContext({ actor = "player", facts = {
    melee = true, usesWeaponSkill = true, alwaysHit = false } }, {}, context,
    { guid = "target-guid", level = 60, isPlayer = true })
close(pvp.hitChance, 0.948, "PvP maximum Defense plus bonus prior changed")
assert(pvp.targetDefense == 305 and pvp.targetDefenseKnown,
    "PvP Defense bonus evidence missing")

print("ok: stateless delivery traits, records, white outcomes and weapon-skill contexts")
