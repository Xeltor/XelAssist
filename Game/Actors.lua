-- Combat actors and their live-discovered actions. This module contains
-- semantics and execution evidence, never an ordered pet or class rotation.
XelAssist.Game.Actors = {}
local A = XelAssist.Game.Actors

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

local function spellIdFor(name, rank)
    local castName = name
    if rank and rank ~= "" then castName = name .. "(" .. rank .. ")" end
    if GetSpellSlotTypeIdForName then
        local ok, _, _, spellId = pcall(GetSpellSlotTypeIdForName, castName)
        if ok and spellId and spellId ~= 0 then return spellId end
    end
    if GetSpellIdForName then
        local ok, spellId = pcall(GetSpellIdForName, castName)
        if ok and spellId and spellId ~= 0 then return spellId end
    end
    return nil
end

function A:Invalidate()
    self.petActions = nil
    self.petActionsGuid = nil
    self.petIdentity = nil
end

function A:PetRef()
    local ref = XelAssist.Game.Capabilities:UnitRef("pet", "controlled", "pet")
    if not ref then return nil end
    if UnitIsDead and UnitIsDead("pet") then return nil end
    return ref
end

function A:ValidateActorRef(ref)
    if type(ref) ~= "table" or ref.unit ~= "pet" or ref.guid == nil then
        return nil, "companion identity unavailable"
    end
    if not XelAssist.Game.Capabilities:SameUnitRef(ref) then
        return nil, "companion changed"
    end
    if UnitIsDead and UnitIsDead(ref.unit) then return nil, "companion defeated" end
    return ref.unit, nil
end

function A:PetIdentity(ref)
    ref = ref or self:PetRef()
    if not ref then return nil end
    local petGuid = ref.guid
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
    local castRemaining = XelAssist and XelAssist.petCastGuid == petGuid
        and XelAssist.petCastUntil and math.max(0, XelAssist.petCastUntil - GetTime()) or 0
    return { id = "pet", unit = "pet", actorType = "controlled", guid = petGuid,
        actorRef = ref,
        family = family, creatureType = creature, stance = stance,
        level = UnitLevel and UnitLevel("pet") or nil,
        health = UnitHealth("pet") or 0, healthMax = UnitHealthMax("pet") or 0,
        resource = UnitMana("pet") or 0, resourceMax = UnitManaMax("pet") or 0,
        casting = castRemaining > 0, castRemaining = castRemaining,
        castSpellId = castRemaining > 0 and XelAssist.petCastSpellId or nil,
        channeling = castRemaining > 0 and XelAssist.petCastChannel or false,
        targetExists = UnitExists("pettarget") and true or false,
        targetsCurrent = UnitExists("pettarget") and UnitExists("target")
            and UnitIsUnit("pettarget", "target") and true or false,
        hasAggro = UnitExists("targettarget") and UnitIsUnit("targettarget", "pet") and true or false }
end

function A:BuildPetActions(ref)
    ref = ref or self:PetRef()
    if not ref then
        self.petActions, self.petActionsGuid = {}, nil
        return self.petActions
    end
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
                local inferred = XelAssist.Game.Capabilities:InferKnowledge(i, BOOKTYPE_PET)
                facts = inferred or {}
            end
            if facts.kind then
                facts.petAbility = true
                table.insert(actions, { name = name, rankText = rank or "", rank = rankNumber(rank),
                    slot = i, actionSlot = bar.slot, texture = bar.texture,
                    spellId = spellIdFor(name, rank),
                    bookType = BOOKTYPE_PET, actor = "pet", executor = "petAbility",
                    actorRef = ref,
                    autocastAllowed = bar.autocastAllowed and true or false,
                    autocastEnabled = bar.autocastEnabled and true or false,
                    active = bar.active and true or false, facts = facts })
            end
        end
        i = i + 1
    end
    self.petActions = actions
    self.petActionsGuid = ref.guid
    return actions
end

function A:Actions()
    local out, players, i = {}, XelAssist.Game.Capabilities:Actions(), nil
    for i = 1, table.getn(players) do table.insert(out, players[i]) end
    local ref = self:PetRef()
    if ref then
        local pets = self.petActions and self.petActionsGuid == ref.guid
            and self.petActions or self:BuildPetActions(ref)
        for i = 1, table.getn(pets) do table.insert(out, pets[i]) end
        if PetAttack then
            table.insert(out, { name = "Pet Attack", rank = 1, actor = "pet",
                executor = "petCommand", command = "attack",
                actorRef = ref,
                facts = { kind = "command", petCommand = true } })
        end
        if PetFollow then
            table.insert(out, { name = "Pet Follow", rank = 1, actor = "pet",
                executor = "petCommand", command = "follow",
                actorRef = ref,
                facts = { kind = "command", petCommand = true } })
        end
        if PetPassiveMode then
            table.insert(out, { name = "Pet Passive", rank = 1, actor = "pet",
                executor = "petCommand", command = "passive",
                actorRef = ref,
                facts = { kind = "command", petCommand = true } })
        end
    end
    return out
end

function A:Facts(action)
    if action.executor == "item" and XelAssist.Game.Inventory then return XelAssist.Game.Inventory:Facts(action) end
    if action.actor == "pet" and action.executor == "petCommand" then
        return { cost = 0, cast = 0, gcd = 0, source = "pet command" }
    end
    return XelAssist.Game.Capabilities:Facts(action)
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
    local _, playerGuid = UnitExists("player")
    local player = { id = "player", unit = "player", actorType = "player",
        guid = playerGuid,
        level = UnitLevel and UnitLevel("player") or nil,
        health = UnitHealth("player") or 0, healthMax = UnitHealthMax("player") or 0,
        resource = UnitMana("player") or 0, resourceMax = UnitManaMax("player") or 0 }
    local actors = { player = player, allies = {}, controlled = {} }
    if XelAssist.Game.Encounter then actors.target = XelAssist.Game.Encounter:Unit("target", "target") end
    local raid = GetNumRaidMembers and GetNumRaidMembers() or 0
    local party = GetNumPartyMembers and GetNumPartyMembers() or 0
    local i
    if XelAssist.Game.Encounter then
        if raid > 0 then
            for i = 1, raid do
                local ally = XelAssist.Game.Encounter:Unit("raid" .. i, "ally")
                if ally then table.insert(actors.allies, ally) end
            end
        else
            for i = 1, party do
                local ally = XelAssist.Game.Encounter:Unit("party" .. i, "ally")
                if ally then table.insert(actors.allies, ally) end
            end
        end
    end
    local pet = self:PetIdentity()
    if pet then
        pet.distance, pet.distanceKind = self:Distance("pet", "target")
        local geometry = XelAssist.Game.Capabilities:Geometry("pet", "target")
        pet.lineOfSight, pet.behind = geometry.lineOfSight, geometry.behind
        pet.autocasts = {}
        local actions = self.petActions and self.petActionsGuid == pet.guid
            and self.petActions or self:BuildPetActions(pet.actorRef)
        for i = 1, table.getn(actions) do
            if actions[i].autocastEnabled then
                local tooltip = self:Facts(actions[i])
                table.insert(pet.autocasts, { name = actions[i].name,
                    kind = actions[i].facts.kind, threat = actions[i].facts.threat,
                    actor = "pet", spellId = actions[i].spellId, facts = actions[i].facts,
                    cost = tooltip.cost or 0,
                    power = tooltip.average or tooltip.dbcAverage or 0,
                    tooltip = tooltip,
                    cooldown = tooltip.cooldown or 1.5,
                    readyIn = math.max(self:PetCooldown(actions[i]) or 0,
                        pet.castRemaining or 0) })
            end
        end
        actors.pet = pet
        table.insert(actors.controlled, pet)
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

function A:Execute(action, expectedRef)
    if not action or action.actor ~= "pet" then return false, "not a companion action" end
    local _, reason = self:ValidateActorRef(expectedRef or action.actorRef)
    if reason then return false, reason end
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
