-- Final live usability checks immediately before a published recommendation
-- crosses into a player or companion dispatch API.
XelAssist.Core.DispatchReadiness = {}
local R = XelAssist.Core.DispatchReadiness

function R:Pet(action)
    if action.executor ~= "petAbility" then return nil end
    local remaining = XelAssist.Game.Actors:PetCooldown(action)
    if remaining and remaining > 0 then return "companion action on cooldown" end
    if GetPetActionsUsable then
        local ok, usable = pcall(GetPetActionsUsable)
        if ok and (usable == false or usable == 0) then
            return "companion action unavailable"
        end
    end
    return nil
end

function R:Player(action, usesHostileQueue)
    local facts = action.facts
    if facts.playerAttack or facts.autoRepeat then return nil end
    local usable, reason = XelAssist.Game.Capabilities:Usable(action)
    if usable == false then return reason or "action unavailable" end
    if action.slot and not usesHostileQueue
        and not XelAssist.Game.Capabilities:IsReady(action.name, 0) then
        return "action on cooldown"
    end
    return nil
end
