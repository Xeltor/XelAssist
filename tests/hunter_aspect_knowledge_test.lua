-- Installed-client and VMaNGOS evidence identify all Hunter aspects as one
-- exclusive spell-specific family. These are mechanics, not a typed priority.
XelAssist = { Combat = {} }
table.getn = table.getn or function(value)
    local count = 0
    while value[count + 1] ~= nil do count = count + 1 end
    return count
end
dofile("Combat/Knowledge.lua")

local aspects = {
    { "Aspect of the Hawk", "rangedOffense" },
    { "Aspect of the Monkey", "avoidance" },
    { "Aspect of the Cheetah", "movement" },
    { "Aspect of the Pack", "groupMovement" },
    { "Aspect of the Beast", "beastUtility" },
    { "Aspect of the Wild", "natureResistance" },
    { "Aspect of the Wolf", "meleeOffense" },
    { "Aspect of the Viper", "manaRecovery" },
    { "Aspect of the Turtle", "defense" },
    { "Aspect of the Snake", "reactiveUtility" },
}

local index, name, role
for index = 1, table.getn(aspects) do
    name, role = aspects[index][1], aspects[index][2]
    local facts = XelAssist.Combat.Knowledge[name]
    assert(facts and facts.self == true and facts.hunterAspect == true,
        name .. " must be discoverable as a self-recipient graph action")
    assert((facts.kind == "buff" or facts.kind == "resource")
        and facts.exclusiveFamily == "hunterAspect",
        name .. " must participate in the Hunter aspect-exclusive family")
    assert(facts.aspectRole == role,
        name .. " must expose only its installed mechanical role")
end

print("ok: installed Hunter aspects expose one exclusive mechanics family")
