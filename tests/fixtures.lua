return {
    WARRIOR = { resource = "rage", movement = true, forms = { 1, 2, 3 } },
    PALADIN = { resource = "mana", healing = true, reagent = true },
    HUNTER = { resource = "mana", pet = true, autoshot = true, range = true },
    ROGUE = { resource = "energy", combo = 5, movement = true },
    PRIEST = { resource = "mana", healing = true, wand = true, dispel = true },
    SHAMAN = { resource = "mana", healing = true, ranks = true, pet = false },
    MAGE = { resource = "mana", talents = { frost = 40 }, wand = true, ground = "Blizzard" },
    WARLOCK = { resource = "mana", pet = true, reagent = true, wand = true },
    DRUID = { resource = "mana", healing = true, forms = { 0, 1, 3 } },
    missing_apis = { SpellInfo = false, QueueSpellByName = false, SuperAPI = false },
}

