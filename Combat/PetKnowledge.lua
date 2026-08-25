-- Declarative controlled-companion action semantics. Actions are still
-- discovered from the live pet spellbook/action bar; this catalogue only says
-- what an observed action means and never orders actions into a rotation.
--
-- Hunter IDs and family links were verified against the installed Octowow
-- client: patch-5.mpq Spell.dbc + SkillLineAbility.dbc and patch-4.mpq
-- CreatureFamily.dbc (2026-08-25). IDs win so localized names remain safe;
-- English names are conservative fallbacks when native ID discovery is absent.
XelAssist.Combat.PetKnowledge = {}
local K = XelAssist.Combat.PetKnowledge

local BY_ID = {}
local BY_NAME = { HUNTER = {}, WARLOCK = {} }
local FAMILY_BY_ID, FAMILY_BY_NAME = {}, {}
local PET_THREAT_BY_ID = {
    [2649] = 50, [14916] = 65, [14917] = 110, [14918] = 170,
    [14919] = 240, [14920] = 320, [14921] = 415,
    [1742] = -30, [1753] = -55, [1754] = -85, [1755] = -125,
    [1756] = -175, [16697] = -225,
}

local function copy(source)
    if not source then return nil end
    local out, key, value = {}, nil, nil
    for key, value in pairs(source) do out[key] = value end
    return out
end

local function define(ownerClass, name, facts, ids)
    local entry = { ownerClass = ownerClass, name = name, facts = facts }
    facts.petKnowledge = true
    if ownerClass == "HUNTER" then facts.hunterPet = true end
    BY_NAME[ownerClass][name] = entry
    local i
    for i = 1, table.getn(ids or {}) do BY_ID[ids[i]] = entry end
end

local function family(id, name, skillLine)
    local entry = { id = id, name = name, skillLine = skillLine }
    FAMILY_BY_ID[id], FAMILY_BY_NAME[name] = entry, entry
end

-- Common trainable Hunter-pet actions.
define("HUNTER", "Growl", { kind = "petThreat", melee = true,
    petThreatGain = true },
    { 2649, 14916, 14917, 14918, 14919, 14920, 14921 })
define("HUNTER", "Cower", { kind = "petThreat", self = true,
    petThreatDrop = true }, { 1742, 1753, 1754, 1755, 1756, 16697 })
define("HUNTER", "Bite", { kind = "damage", melee = true, basicPetAttack = true },
    { 17253, 17255, 17256, 17257, 17258, 17259, 17260, 17261 })
define("HUNTER", "Claw", { kind = "damage", melee = true, basicPetAttack = true },
    { 16827, 16828, 16829, 16830, 16831, 16832, 3010, 3009 })
define("HUNTER", "Dash", { kind = "buff", self = true, movement = true },
    { 23099, 23109, 23110 })
define("HUNTER", "Dive", { kind = "buff", self = true, movement = true },
    { 23145, 23147, 23148 })

-- Family actions linked by the effective CreatureFamily skill line in this
-- exact client build. Hybrid effects retain descriptive flags for later graph
-- refinement while their primary kind is immediately usable by today's graph.
define("HUNTER", "Furious Howl", { kind = "buff", self = true, aoe = true,
    groupSupport = true, familyAction = true }, { 24604, 24605, 24603, 24597 })
define("HUNTER", "Prowl", { kind = "buff", self = true, stealth = true,
    familyAction = true }, { 24450, 24452, 24453 })
define("HUNTER", "Web", { kind = "crowdControl", ranged = true, root = true,
    familyAction = true }, { 36533 })
define("HUNTER", "Roar of Fortitude", { kind = "buff", self = true, aoe = true,
    defensive = true, groupSupport = true, familyAction = true }, { 36535 })
define("HUNTER", "Charge", { kind = "crowdControl", melee = true,
    gapCloser = true, root = true, familyAction = true },
    { 7371, 26177, 26178, 26179, 26201, 27685 })
define("HUNTER", "Death Roll", { kind = "dot", melee = true, slow = true,
    execute = 35, familyAction = true },
    { 36548, 36549, 36550, 36551, 36552, 36553 })
define("HUNTER", "Screech", { kind = "damage", melee = true, aoe = true,
    debuff = true, familyAction = true }, { 24423, 24577, 24578, 24579 })
define("HUNTER", "Bubble Barrier", { kind = "absorb", self = true, aoe = true,
    familyAction = true }, { 36523, 36524, 36525, 36526 })
define("HUNTER", "Thunderstomp", { kind = "damage", melee = true, aoe = true,
    school = 3, threat = 1.6, familyAction = true },
    { 26090, 26187, 26188, 51156 })
define("HUNTER", "Savage Rend", { kind = "dot", melee = true,
    familyAction = true }, { 36536, 36537, 36538, 36539, 36540, 36541 })
define("HUNTER", "Strider Presence", { kind = "buff", self = true, aoe = true,
    groupSupport = true, familyAction = true }, { 36531 })
define("HUNTER", "Scorpid Poison", { kind = "dot", melee = true, school = 3,
    stackable = 5, familyAction = true }, { 24640, 24583, 24586, 24587 })
define("HUNTER", "Shell Shield", { kind = "petDefensive", self = true,
    familyAction = true }, { 26064 })
define("HUNTER", "Packleader", { kind = "buff", self = true,
    summonAlly = true, familyAction = true }, { 36532 })
define("HUNTER", "Lightning Breath", { kind = "damage", ranged = true,
    school = 3, familyAction = true }, { 24844, 25008, 25009, 25010, 25011, 25012 })
define("HUNTER", "Poison Spit", { kind = "dot", ranged = true, school = 3,
    familyAction = true }, { 46271, 46272, 46273 })
define("HUNTER", "Grace", { kind = "petDefensive", self = true,
    familyAction = true }, { 46296 })
define("HUNTER", "Pollen Burst", { kind = "buff", self = true, aoe = true,
    groupHeal = true, debuff = true, familyAction = true }, { 42051 })

-- Existing Warlock companion semantics, moved intact from Game/Actors. Exact
-- active-spell IDs are included where this client DBC confirms them; the two
-- Turtle names absent from the effective DBC remain name-fallback only.
define("WARLOCK", "Firebolt", { kind = "damage", ranged = true },
    { 3110, 7799, 7800, 7801, 7802, 11762, 11763 })
define("WARLOCK", "Lash of Pain", { kind = "damage", melee = true },
    { 7814, 7815, 7816, 11778, 11779, 11780 })
define("WARLOCK", "Shadow Bite", { kind = "damage", melee = true })
define("WARLOCK", "Torment", { kind = "taunt", melee = true, threat = 3 },
    { 3716, 7809, 7810, 7811, 11774, 11775 })
define("WARLOCK", "Suffering", { kind = "taunt", aoe = true, threat = 3 },
    { 17735, 17750, 17751, 17752 })
define("WARLOCK", "Sacrifice", { kind = "absorb", petSacrifice = true },
    { 7812, 19438, 19440, 19441, 19442, 19443 })
define("WARLOCK", "Consume Shadows", { kind = "petHeal", channel = true,
    self = true, outOfCombat = true }, { 17767, 17850, 17851, 17852, 17853, 17854 })
define("WARLOCK", "Seduction", { kind = "crowdControl", ranged = true,
    channel = true, requiresCreature = "Humanoid" }, { 6358 })
define("WARLOCK", "Devour Magic", { kind = "dispel", ranged = true },
    { 19505, 19731, 19734, 19736 })
define("WARLOCK", "Spell Lock", { kind = "interrupt", ranged = true },
    { 19244, 19647 })
define("WARLOCK", "Blood Pact", { kind = "buff", self = true },
    { 6307, 7804, 7805, 11766, 11767 })
define("WARLOCK", "Fire Shield", { kind = "buff" },
    { 2947, 8316, 8317, 11770, 11771 })
define("WARLOCK", "Paranoia", { kind = "buff", self = true }, { 19480 })
define("WARLOCK", "Fel Intelligence", { kind = "buff", self = true })
define("WARLOCK", "Tainted Blood", { kind = "debuff", melee = true },
    { 19478, 19655, 19656, 19660 })

-- Effective Hunter-capable CreatureFamily records. Numeric lookup is ready for
-- a native family-ID capability; UnitCreatureFamily currently supplies only a
-- localized name, so Actors uses the name fallback for diagnostics, not gating.
family(1, "Wolf", 208); family(2, "Cat", 209); family(3, "Spider", 203)
family(4, "Bear", 210); family(5, "Boar", 211); family(6, "Crocolisk", 212)
family(7, "Carrion Bird", 213); family(8, "Crab", 214); family(9, "Gorilla", 215)
family(11, "Raptor", 217); family(12, "Tallstrider", 218); family(20, "Scorpid", 236)
family(21, "Turtle", 251); family(24, "Bat", 653); family(25, "Hyena", 654)
family(26, "Owl", 655); family(27, "Wind Serpent", 656)
family(30, "Dragonhawk", 763); family(31, "Ravager", 767)
family(32, "Warp Stalker", 766); family(33, "Sporebat", 765)
family(34, "Nether Ray", 764); family(35, "Serpent", 1009)
family(36, "Fox", 1010); family(37, "Plagued", 208); family(38, "Horse", 208)
family(39, "Moth", 1011)

function K:Facts(spellId, name, ownerClass)
    local entry, source
    spellId = tonumber(spellId)
    if spellId then entry, source = BY_ID[spellId], "octowow dbc id" end
    if entry and ownerClass and entry.ownerClass ~= ownerClass then entry = nil end
    if not entry and ownerClass and BY_NAME[ownerClass] then
        entry, source = BY_NAME[ownerClass][name], "name fallback"
    elseif not entry and not ownerClass then
        entry = BY_NAME.HUNTER[name] or BY_NAME.WARLOCK[name]
        source = entry and "name fallback" or nil
    end
    if not entry then return nil end
    local facts = copy(entry.facts)
    local threat = spellId and PET_THREAT_BY_ID[spellId]
    if threat and threat > 0 then facts.petThreatGain = threat
    elseif threat and threat < 0 then facts.petThreatDrop = math.abs(threat) end
    facts.petKnowledgeSource = source
    facts.petKnowledgeName = entry.name
    return facts
end

function K:Family(familyId, name, ownerClass)
    if ownerClass and ownerClass ~= "HUNTER" then return nil end
    local entry = familyId and FAMILY_BY_ID[tonumber(familyId)] or nil
    local source = entry and "octowow dbc id" or nil
    if not entry then entry, source = FAMILY_BY_NAME[name], "name fallback" end
    if not entry then return nil end
    local out = copy(entry)
    out.source = source
    return out
end
