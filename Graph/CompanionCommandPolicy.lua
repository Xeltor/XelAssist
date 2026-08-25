-- Graph semantics for controlled-companion commands. Recovery is a state, not
-- an ordered rotation: any discovered command is evaluated against the same
-- health, activity, acknowledgement, and target evidence.
XelAssist.Graph.CompanionCommandPolicy = {}
local P = XelAssist.Graph.CompanionCommandPolicy

local RECOVERY_ENTER = 0.25
local RECOVERY_EXIT = 0.35

function P:Activity(pet)
    if pet and pet.attackActiveKnown == true then
        return pet.attackActive == true, true
    end
    local round = pet and pet.attackRound
    if round and round.attackActiveKnown == true then
        return round.attackActive == true, true
    end
    return nil, false
end

function P:Recovering(pet)
    if not pet then return false end
    local current, maximum = tonumber(pet.health), tonumber(pet.healthMax)
    local ratio = current ~= nil and maximum ~= nil and maximum > 0
        and current / maximum or nil
    if ratio and ratio >= RECOVERY_EXIT then return false end
    return pet.recovering == true
        or ratio ~= nil and ratio < RECOVERY_ENTER
end

function P:UpdateRecovery(pet)
    if not pet then return false end
    local recovering = self:Recovering(pet)
    pet.recovering = recovering and true or false
    if not recovering then
        pet.retreatFollowIssued, pet.retreatPassiveIssued = false, false
    end
    return recovering
end

function P:HealingChannel(pet)
    if not (pet and pet.channeling and pet.castSpellId) then return false end
    local knowledge = XelAssist.Combat and XelAssist.Combat.PetKnowledge
    if not (knowledge and knowledge.Facts) then return false end
    local facts = knowledge:Facts(pet.castSpellId, nil, pet.ownerClass)
    return facts and facts.kind == "petHeal" and facts.channel == true
end

local function pending(pet, command)
    return pet and pet.commandPending
        and pet.commandPending[command] == true
end

function P:Relevant(action, state)
    local pet, command = state.actors and state.actors.pet, action.command
    if not pet or pending(pet, command) then return false end
    local recovering = self:Recovering(pet)
    local active, activeKnown = self:Activity(pet)
    if self:HealingChannel(pet) then return false end
    if command == "attack" then
        if recovering then return false end
        return state.hostile and (not pet.targetsCurrent
            or activeKnown and active ~= true)
    end
    if command == "passive" then
        return recovering and not pet.retreatPassiveIssued
            and pet.stance ~= "passive"
    end
    if command ~= "follow" or not pet.targetExists then return false end
    if recovering then return not pet.retreatFollowIssued end
    if state.hostile then return false end
    return not pet.targetsCurrent and (not activeKnown or active == true)
end

local function setActivity(pet, active)
    pet.attackActive, pet.attackActiveKnown = active, true
    if pet.attackRound then
        pet.attackRound.attackActive = active
        pet.attackRound.attackActiveKnown = true
        pet.attackRound.projectable = false
        pet.attackRound.phaseKnown = false
    end
end

function P:Apply(pet, action, targetGuid)
    local command = action.command
    if command == "passive" then
        pet.stance = "passive"
        pet.retreatPassiveIssued = self:Recovering(pet) and true or false
        setActivity(pet, false)
    elseif command == "follow" then
        pet.targetExists, pet.targetsCurrent = false, false
        pet.following, pet.followingKnown = true, true
        pet.retreatFollowIssued = self:Recovering(pet) and true or false
        setActivity(pet, false)
    elseif command == "attack" then
        pet.targetExists, pet.targetsCurrent = true, true
        pet.targetGuid = targetGuid
        pet.following, pet.followingKnown = false, true
        setActivity(pet, true)
        if pet.attackRound then
            pet.attackRound.reason =
                "attack command submitted; awaiting resolved swing"
        end
    end
end
