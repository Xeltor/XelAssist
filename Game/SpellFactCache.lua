-- Rank facts are stable only for one actor identity, spell record and level.
-- Pet spellbook slots are reused when a demon or Hunter companion changes, so
-- a bare bookType:slot key can leak the previous companion's formula.
XelAssist.Game.SpellFactCache = {}
local C = XelAssist.Game.SpellFactCache

local function actorLevel(action)
    local unit = action and action.actor == "pet" and "pet" or "player"
    return UnitLevel and tonumber(UnitLevel(unit)) or 0
end

local function key(action, bookType)
    return tostring(bookType) .. ":" .. tostring(action.slot)
        .. ":" .. tostring(action.spellId or 0)
        .. ":" .. tostring(actorLevel(action))
end

function C:Lookup(owner, action, bookType)
    if not owner.tooltipFacts then
        owner.tooltipFacts = { player = {}, pet = {} }
    end
    local cache
    if action.actor == "pet" then
        local guid = action.actorRef and action.actorRef.guid
        if guid == nil then return nil, key(action, bookType), nil end
        if owner.tooltipFacts.petGuid ~= guid then
            owner.tooltipFacts.petGuid, owner.tooltipFacts.pet = guid, {}
        end
        cache = owner.tooltipFacts.pet
    else cache = owner.tooltipFacts.player end
    local cacheKey = key(action, bookType)
    return cache[cacheKey], cacheKey, cache
end

function C:Store(cache, cacheKey, facts)
    if cache then cache[cacheKey] = facts end
end
