-- Combat actors and their live-discovered actions. This module contains
-- semantics and execution evidence, never an ordered pet or class rotation.
XelAssistActors = {}
local A = XelAssistActors

local PET_KNOWLEDGE = {
    ["Firebolt"] = { kind = "damage", ranged = true },
    ["Lash of Pain"] = { kind = "damage", melee = true },
    ["Shadow Bite"] = { kind = "damage", melee = true },
    ["Torment"] = { kind = "taunt", melee = true, threat = 3 },
    ["Suffering"] = { kind = "taunt", aoe = true, threat = 3 },
    ["Sacrifice"] = { kind = "absorb", petSacrifice = true },
    ["Consume Shadows"] = { kind = "petHeal", channel = true, self = true, outOfCombat = true },
    ["Seduction"] = { kind = "crowdControl", ranged = true, channel = true,
        requiresCreature = "Humanoid" },
    ["Devour Magic"] = { kind = "dispel", ranged = true },
    ["Spell Lock"] = { kind = "interrupt", ranged = true },
    ["Blood Pact"] = { kind = "buff", self = true },
    ["Fire Shield"] = { kind = "buff" },
    ["Paranoia"] = { kind = "buff", self = true },
    ["Fel Intelligence"] = { kind = "buff", self = true },
    ["Tainted Blood"] = { kind = "debuff", melee = true }
}

local function copyFacts(source)
    local out, key, value = {}, nil, nil
    for key, value in pairs(source or {}) do out[key] = value end
    return out
end

local function rankNumber(rank)
    local digits = string.gsub(rank or "", "%D", "")
    return tonumber(digits) or 1
end

function A:Invalidate()
    self.petActions = nil
    self.petIdentity = nil
end

function A:PetIdentity()
    if not UnitExists("pet") or UnitIsDead("pet") then return nil end
    local family = UnitCreatureFamily and UnitCreatureFamily("pet") or nil
    local creature = UnitCreatureType and UnitCreatureType("pet") or nil
    local stance, i
    if GetPetActionInfo then
        for i = 1, (NUM_PET_ACTION_SLOTS or 10) do
            local name, _, _, isToken, active = GetPetActionInfo(i)
            if name and isToken and active then
                if string.find(name, "PASSIVE") then stance = "passive"
                elseif string.find(name, "DEFENSIVE") then stance = "defensive"
                elseif string.find(name, "AGGRESSIVE") then stance = "aggressive" end
            end
        end
    end
    return { id = "pet", unit = "pet", actorType = "controlled",
        family = family, creatureType = creature, stance = stance,
        health = UnitHealth("pet") or 0, healthMax = UnitHealthMax("pet") or 0,
        resource = UnitMana("pet") or 0, resourceMax = UnitManaMax("pet") or 0,
        targetExists = UnitExists("pettarget") and true or false,
        targetsCurrent = UnitExists("pettarget") and UnitExists("target")
            and UnitIsUnit("pettarget", "target") and true or false,
        hasAggro = UnitExists("targettarget") and UnitIsUnit("targettarget", "pet") and true or false }
end

function A:BuildPetActions()
    local actions, barByName = {}, {}
    local slots = NUM_PET_ACTION_SLOTS or 10
    local i
    if GetPetActionInfo then
        for i = 1, slots do
            local name, subtext, texture, isToken, active, autocastAllowed, autocastEnabled = GetPetActionInfo(i)
            if name and not isToken then
                barByName[name] = { slot = i, texture = texture, active = active,
                    autocastAllowed = autocastAllowed, autocastEnabled = autocastEnabled }
            end
        end
    end
    i = 1
    while GetSpellName do
        local name, rank = GetSpellName(i, BOOKTYPE_PET)
        if not name then break end
        local passive = false
        if IsPassiveSpell then
            local ok, value = pcall(IsPassiveSpell, i, BOOKTYPE_PET)
            passive = ok and (value == true or value == 1)
        end
        local bar = barByName[name]
        if not passive and bar then
            local facts = copyFacts(PET_KNOWLEDGE[name])
            if not facts.kind then
                local inferred = XelAssistCapabilities:InferKnowledge(i, BOOKTYPE_PET)
                facts = inferred or {}
            end
            if facts.kind then
                facts.petAbility = true
                table.insert(actions, { name = name, rankText = rank or "", rank = rankNumber(rank),
                    slot = i, actionSlot = bar.slot, texture = bar.texture,
                    bookType = BOOKTYPE_PET, actor = "pet", executor = "petAbility",
                    autocastAllowed = bar.autocastAllowed and true or false,
                    autocastEnabled = bar.autocastEnabled and true or false,
                    active = bar.active and true or false, facts = facts })
            end
        end
        i = i + 1
    end
    self.petActions = actions
    return actions
end

function A:Actions()
    local out, players, i = {}, XelAssistCapabilities:Actions(), nil
    for i = 1, table.getn(players) do table.insert(out, players[i]) end
    if UnitExists("pet") and not UnitIsDead("pet") then
        local pets = self.petActions or self:BuildPetActions()
        for i = 1, table.getn(pets) do table.insert(out, pets[i]) end
        if PetAttack then
            table.insert(out, { name = "Pet Attack", rank = 1, actor = "pet",
                executor = "petCommand", command = "attack",
                facts = { kind = "command", petCommand = true } })
        end
        if PetFollow then
            table.insert(out, { name = "Pet Follow", rank = 1, actor = "pet",
                executor = "petCommand", command = "follow",
                facts = { kind = "command", petCommand = true } })
        end
        if PetPassiveMode then
            table.insert(out, { name = "Pet Passive", rank = 1, actor = "pet",
                executor = "petCommand", command = "passive",
                facts = { kind = "command", petCommand = true } })
        end
    end
    return out
end

function A:Facts(action)
    if action.executor == "item" and XelAssistInventory then return XelAssistInventory:Facts(action) end
    if action.actor == "pet" and action.executor == "petCommand" then
        return { cost = 0, cast = 0, gcd = 0, source = "pet command" }
    end
    return XelAssistCapabilities:Facts(action)
end

function A:PetCooldown(action)
    if not (action.actionSlot and GetPetActionCooldown) then return nil end
    local ok, start, duration, enabled = pcall(GetPetActionCooldown, action.actionSlot)
    if not ok then return nil end
    local remaining = (start or 0) + (duration or 0) - GetTime()
    if enabled == 0 then return nil end
    return math.max(0, remaining)
end

function A:Distance(from, to)
    if not (from and to and UnitExists(from) and UnitExists(to)) then return nil, nil end
    if UnitXP then
        local ok, distance = pcall(UnitXP, "distanceBetween", from, to)
        if ok and type(distance) == "number" and distance >= 0 then return distance, "hitbox" end
    end
    return nil, nil
end

function A:Snapshot()
    local player = { id = "player", unit = "player", actorType = "player",
        health = UnitHealth("player") or 0, healthMax = UnitHealthMax("player") or 0,
        resource = UnitMana("player") or 0, resourceMax = UnitManaMax("player") or 0 }
    local actors = { player = player }
    local pet = self:PetIdentity()
    if pet then
        pet.distance, pet.distanceKind = self:Distance("pet", "target")
        local geometry = XelAssistCapabilities:Geometry("pet", "target")
        pet.lineOfSight, pet.behind = geometry.lineOfSight, geometry.behind
        actors.pet = pet
    end
    return actors
end

function A:HasReagent(name)
    if not name or not GetItemCount then return nil end
    local ok, count = pcall(GetItemCount, name)
    if not ok then return nil end
    return (tonumber(count) or 0) > 0
end

local function hasMagicAura(unit, helpful)
    if not unit or not UnitExists(unit) then return false end
    local i
    for i = 1, 40 do
        local texture, stacks, auraType, d4, d5
        if helpful then texture, stacks, auraType, d4, d5 = UnitBuff(unit, i)
        else texture, stacks, auraType, d4, d5 = UnitDebuff(unit, i) end
        if not texture then break end
        if auraType == "Magic" or d4 == "Magic" or d5 == "Magic" then return true end
    end
    return false
end

function A:DispelTarget(state)
    if state.dispelled then return nil end
    if state.hostile and hasMagicAura("target", true) then return "target" end
    if state.healUnit and hasMagicAura(state.healUnit, false) then return state.healUnit end
    return nil
end

function A:Execute(action)
    if action.executor == "petAbility" and action.actionSlot and CastPetAction then
        CastPetAction(action.actionSlot); return true
    end
    if action.executor == "petCommand" and action.command == "attack" and PetAttack then
        PetAttack(); return true
    end
    if action.executor == "petCommand" and action.command == "follow" and PetFollow then
        PetFollow(); return true
    end
    if action.executor == "petCommand" and action.command == "passive" and PetPassiveMode then
        PetPassiveMode(); return true
    end
    return false
end

function A:Knowledge(name)
    return PET_KNOWLEDGE[name]
end
