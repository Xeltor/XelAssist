-- Exact defensive companion effects.  Incoming mitigation is target-local;
-- unresolved offensive timing is retained as an explicit graph unknown.
XelAssist.Graph.CompanionDefensives = {}
local D = XelAssist.Graph.CompanionDefensives
local Effects = XelAssist.Game.Pets.Effects
local Facts = XelAssist.Game.Pets.DefensiveActions

function D:Profile(subject)
    return Facts and Facts:Profile(subject) or nil
end

function D:TradeoffUnknown(subject)
    local profile = self:Profile(subject)
    return profile and profile.offensiveTimingExact ~= true
        and "companion defensive attack timing" or nil
end

function D:Apply(state, ambient, entry)
    local profile = self:Profile(ambient)
    local pet = state and state.actors and state.actors.pet
    if not (profile and pet and Effects) then return false end
    local action = { name = ambient.name, spellId = ambient.spellId,
        actor = "pet", facts = { petCombatEffects = { {
            key = "shellShield", duration = profile.duration,
            incomingDamageMultiplier = profile.incomingDamageMultiplier,
            meleeAttackTimeMultiplier = profile.meleeAttackTimeMultiplier,
            offensiveTimingExact = profile.offensiveTimingExact,
            sourceSpellId = profile.spellId } } } }
    local candidate = { action = action, tooltip = ambient.tooltip or {} }
    local applied = Effects:Apply(state, candidate,
        { petEventContext = { applicationElapsed = 0 } })
    if applied and profile.offensiveTimingExact ~= true then
        pet.defensiveOffenseTimingUnknown = true
        state.companionDefensiveTimingUnknown = true
        if pet.attackRound then
            pet.attackRound.phaseExact = false
            pet.attackRound.projectable = false
            pet.attackRound.reason = "companion defensive attack timing"
        end
    end
    return applied and true or false
end

function D:AdjustIncoming(state, entry, amount)
    amount = tonumber(amount)
    local pet = state and state.actors and state.actors.pet
    if not (amount and pet and entry and entry.victimKind == "pet") then
        return amount
    end
    if entry.victimGuid and pet.guid and entry.victimGuid ~= pet.guid then
        return amount
    end
    return amount * Effects:IncomingDamageMultiplier(pet)
end
