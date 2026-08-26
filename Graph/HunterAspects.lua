-- Hunter aspects are persistent self auras in one server-exclusive family.
-- This preparatory adapter owns exact aura replacement. Recommendation remains
-- closed until the graph represents an aspect's downstream combat effects.
XelAssist.Graph.HunterAspects = {}
local H = XelAssist.Graph.HunterAspects
local State = XelAssist.Graph.State

H.FAMILY = "hunterAspect"
H.ROLES = {
    ["Aspect of the Hawk"] = "rangedOffense",
    ["Aspect of the Monkey"] = "avoidance",
    ["Aspect of the Cheetah"] = "movement",
    ["Aspect of the Pack"] = "groupMovement",
    ["Aspect of the Beast"] = "beastUtility",
    ["Aspect of the Wild"] = "natureResistance",
    ["Aspect of the Wolf"] = "meleeOffense",
    ["Aspect of the Viper"] = "manaRecovery",
    ["Aspect of the Turtle"] = "defense",
    ["Aspect of the Snake"] = "reactiveUtility",
}

local function active(aura)
    if aura == nil then return false end
    if type(aura) ~= "table" then return true end
    if (tonumber(aura.applicationProbability) or 1) < 0.75 then return false end
    local remaining = tonumber(aura.remaining)
    return remaining == nil or remaining > 0
end

function H:Is(action)
    local facts = action and action.facts or {}
    return (action and (action.actor or "player") == "player")
        and facts.hunterAspect == true
        and facts.exclusiveFamily == self.FAMILY
        and self.ROLES[action.name] ~= nil
end

-- A complete helpful-aura scan proves both presence and absence. A projected
-- cast also proves the family member because the server replaces the family
-- atomically. Unknown aura enumeration never proves that no aspect is active.
function H:Current(state)
    local player = State and State:FriendlyByUnit(state, "player") or nil
    if not player then return nil, false, "player aura recipient unavailable" end
    if player.hunterAspectExact == true then
        local projected = player.hunterAspectName
        if self.ROLES[projected] then return projected, true, nil, player end
        return nil, false, "projected Hunter aspect is unknown", player
    end
    local auras = player.auras
    if type(auras) ~= "table" then
        return nil, false, "player aura evidence unavailable", player
    end
    local found, name = nil, nil
    for name in pairs(self.ROLES) do
        if active(auras[name]) then
            if found and found ~= name then
                return nil, false, "multiple Hunter aspects observed", player
            end
            found = name
        end
    end
    if found then return found, true, nil, player end
    if auras.available == true then return nil, true, nil, player end
    return nil, false, "player aura evidence incomplete", player
end

function H:Blocker(action)
    if self:Is(action) then
        return "Hunter aspect effects are not represented"
    end
end

function H:Apply(target, candidate, context)
    local action = candidate and candidate.action
    if not self:Is(action) or not target or target.unit ~= "player"
        or candidate.targetRelation ~= "self" then return false end
    target.auras = target.auras or {}
    local name, aura = nil, nil
    for name, aura in pairs(target.auras) do
        if name ~= action.name and (self.ROLES[name]
            or type(aura) == "table"
                and aura.exclusiveFamily == self.FAMILY) then
            target.auras[name] = nil
        end
    end
    local duration = tonumber(candidate.tooltip and candidate.tooltip.duration)
    target.auras[action.name] = {
        name = action.name, spellId = action.spellId,
        duration = duration, remaining = duration,
        mine = true, source = "graph Hunter aspect",
        applicationProbability = 1,
        hunterAspect = true, exclusiveFamily = self.FAMILY,
        aspectRole = action.facts.aspectRole,
    }
    target.hunterAspectName = action.name
    target.hunterAspectExact = true
    return true
end
