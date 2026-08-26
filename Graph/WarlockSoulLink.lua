-- Search-pure Soul Link consequences. The profile is captured once at the
-- root. Damage choices gain only their exact all-school multiplier, while an
-- incoming event splits its post-absorb residual with the live demon.
XelAssist.Graph.WarlockSoulLink = {}
local S = XelAssist.Graph.WarlockSoulLink

local function finite(value)
    value = tonumber(value)
    if value == nil or value ~= value
        or value == math.huge or value == -math.huge then return nil end
    return value
end

local function copy(source)
    local out, key, value = {}, nil, nil
    for key, value in pairs(source or {}) do out[key] = value end
    return out
end

local function runtime()
    return XelAssist.Game and XelAssist.Game.Player
        and XelAssist.Game.Player.WarlockSoulLink
end

local function evidence(state)
    local owner = runtime()
    return owner and owner:Evidence(state and state.warlockSoulLink) or nil
end

local function petOf(state)
    return state and state.actors and state.actors.pet or nil
end

local function activeProfile(state)
    local found = evidence(state)
    if not found then return nil, nil, false, "Soul Link evidence unavailable" end
    if found.learned ~= true then
        return nil, nil, true, "Soul Link is not learned"
    end
    local pet = petOf(state)
    if not pet then return nil, nil, true, "no controlled demon" end
    if pet.ownerClass == nil then
        return nil, pet, false, "controlled companion ownership unknown"
    end
    if pet.ownerClass ~= "WARLOCK" then
        return nil, pet, true, "controlled companion is not a Warlock demon"
    end
    local health = finite(pet.health)
    if pet.dead == true or health and health <= 0 then
        return nil, pet, true, "controlled demon is defeated"
    end
    if pet.healthExact == false then
        return nil, pet, false, "controlled demon survival is uncertain"
    end
    if health == nil then
        return nil, pet, false, "controlled demon health unavailable"
    end
    return found, pet, true
end

function S:Attach(state, snapshot)
    if type(state) ~= "table" then return false end
    state.warlockSoulLink = nil
    local owner = runtime()
    local found = owner and owner:Evidence(snapshot) or nil
    if found then
        state.warlockSoulLink = copy(found)
        return true
    end
    if type(snapshot) == "table" then
        state.warlockSoulLink = { available = false, exact = false,
            reason = snapshot.reason or "Soul Link evidence unavailable" }
    end
    return false
end

function S:Active(state)
    local found, pet, known, reason = activeProfile(state)
    return found ~= nil, known, reason, found, pet
end

function S:OutgoingMultiplier(state, actor)
    if actor ~= "player" and actor ~= "pet" then return 1, true, false end
    local found, _, known, reason = activeProfile(state)
    if not found then return 1, known, false, reason end
    return found.damageMultiplier, true, true, found.source
end

function S:AdjustOutgoing(state, actor, amount)
    amount = finite(amount)
    if not amount or amount < 0 then
        return nil, false, false, "outgoing damage unavailable"
    end
    local multiplier, known, active, reason = self:OutgoingMultiplier(state, actor)
    return amount * multiplier, known, active, reason
end

local function playerRecipient(recipient)
    return recipient == "player" or type(recipient) == "table"
        and recipient.kind == "player"
end

local function exactInteger(value, exact)
    return exact == true and value >= 0 and math.floor(value) == value
end

-- `residual` must be the damage left after the player's resistance, ordinary
-- absorbs, and mana shields. Turtle's server applies aura 81 at that point.
function S:PlanResidual(state, recipient, residual, exact)
    if not playerRecipient(recipient) then return nil, "irrelevant" end
    residual = finite(residual)
    if not residual or residual < 0 then
        return nil, "incoming residual unavailable"
    end
    local found, pet, known, reason = activeProfile(state)
    if not found then return nil, known and "inactive" or reason end
    local splitExact = exactInteger(residual, exact)
    local petDamage = residual * found.splitFraction
    if splitExact then petDamage = math.floor(petDamage) end
    petDamage = math.max(0, math.min(residual, petDamage))
    return { exact = splitExact and true or false,
        effectSpellId = found.effectSpellId, schoolMask = found.schoolMask,
        splitFraction = found.splitFraction, incomingDamage = residual,
        playerDamage = residual - petDamage, petDamage = petDamage,
        petGuid = pet.guid, source = found.source }
end

local function friendlyPet(state, pet)
    local friendlies = state and state.friendlies
    if type(friendlies) ~= "table" then return nil end
    local key = friendlies.byUnit and friendlies.byUnit.pet
    local record = key and friendlies.byKey and friendlies.byKey[key]
    if record then return record end
    local i
    for i = 1, table.getn(friendlies.order or {}) do
        record = friendlies.byKey and friendlies.byKey[friendlies.order[i]]
        if record and pet and record.guid == pet.guid then return record end
    end
    return nil
end

local function applyPetDamage(state, plan)
    local pet = petOf(state)
    if not pet or pet.ownerClass ~= "WARLOCK"
        or plan.petGuid ~= nil and pet.guid ~= plan.petGuid then return false end
    local health = finite(pet.health)
    if health == nil then return false end
    local exact = plan.exact == true and pet.healthExact ~= false
    local after = math.max(0, health - plan.petDamage)
    plan.petHealthBefore, plan.petHealthAfter = health, after
    plan.petHealthExact = exact
    pet.health, pet.healthExact = after, exact and true or false
    local friendly = friendlyPet(state, pet)
    if friendly then
        friendly.health = after
        friendly.exact = exact and true or false
    end
    if exact then
        local defeated = after <= 0
        pet.dead, pet.projectedDefeated = defeated, defeated and true or nil
        if friendly then
            friendly.dead = defeated
            friendly.projectedDefeated = defeated and true or nil
        end
        if defeated then
            state.pet = false
            pet.targetExists, pet.targetsCurrent, pet.hasAggro = false, false, false
            plan.petDefeated = true
        end
    else
        pet.dead, pet.projectedDefeated = nil, nil
        if friendly then friendly.dead, friendly.projectedDefeated = nil, nil end
        state.soulLinkSplitPartial = true
    end
    state.lastSoulLinkSplit = plan
    return true
end

-- Returns the residual the player should lose. Pet damage is applied
-- atomically, so a lethal split disables Soul Link for later descendants.
function S:ApplyResidual(state, recipient, residual, exact)
    local plan, status = self:PlanResidual(state, recipient, residual, exact)
    if not plan then return residual, nil, false, status end
    if not applyPetDamage(state, plan) then
        return residual, nil, false, "controlled demon changed before split"
    end
    return plan.playerDamage, plan, true
end
