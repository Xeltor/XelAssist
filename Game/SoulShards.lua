-- Live Soul Shard inventory and target-yield evidence. This module describes
-- one bounded Warlock resource; it does not prescribe a spell sequence.
XelAssist.Game.SoulShards = {}
local S = XelAssist.Game.SoulShards

S.ITEM_ID = 6265
S.REAGENT_NAME = "Soul Shard"
S.DEFAULT_RESERVE = 3
S.MAX_RESERVE = 10

local GENERATOR_IDS = {
    [1120] = true, [8288] = true, [8289] = true,
    [11675] = true, [27217] = true,
}

local function boundedInteger(value, fallback)
    value = tonumber(value)
    if value == nil then value = fallback end
    value = math.floor(value + 0.5)
    return math.max(0, math.min(S.MAX_RESERVE, value))
end

local function safeCall(fn, first, second, third)
    if not fn then return nil, false end
    local ok, value
    if third ~= nil then ok, value = pcall(fn, first, second, third)
    elseif second ~= nil then ok, value = pcall(fn, first, second)
    elseif first ~= nil then ok, value = pcall(fn, first)
    else ok, value = pcall(fn) end
    if not ok then return nil, false end
    return value, true
end

local function truthy(value)
    return value == true or value == 1
end

function S:Reserve()
    local configured = XelAssistCharDB
        and XelAssistCharDB.soulShardReserve or nil
    local reserve = boundedInteger(configured, self.DEFAULT_RESERVE)
    if XelAssistCharDB then XelAssistCharDB.soulShardReserve = reserve end
    return reserve
end

local function bagCount()
    if not (GetContainerNumSlots and GetContainerItemLink
        and GetContainerItemInfo) then return nil, false end
    local total, bag, slot = 0, nil, nil
    for bag = 0, (NUM_BAG_SLOTS or 4) do
        local slots, ok = safeCall(GetContainerNumSlots, bag)
        if not ok or type(slots) ~= "number" then return nil, false end
        for slot = 1, slots do
            local link, linkKnown = safeCall(GetContainerItemLink, bag, slot)
            if not linkKnown then return nil, false end
            local _, _, itemId = string.find(link or "", "item:(%d+)")
            if tonumber(itemId) == S.ITEM_ID then
                local ok, _, stack = pcall(GetContainerItemInfo, bag, slot)
                if not ok then return nil, false end
                total = total + math.max(1, tonumber(stack) or 1)
            end
        end
    end
    return total, true
end

function S:LiveCount()
    local count, known
    if C_Item and C_Item.GetItemCount then
        count, known = safeCall(C_Item.GetItemCount, self.ITEM_ID, false, false)
        if known and tonumber(count) then
            return math.max(0, tonumber(count)), true, "live item count"
        end
    end
    count, known = bagCount()
    if known then return count, true, "live bag scan" end
    if GetItemCount then
        count, known = safeCall(GetItemCount, self.ITEM_ID)
        if known and tonumber(count) then
            return math.max(0, tonumber(count)), true, "legacy item count"
        end
    end
    return nil, false, "Soul Shard inventory unavailable"
end

function S:Snapshot(inventory)
    local count, known, source
    local reagents = inventory and inventory.reagentCounts
    if reagents and tonumber(reagents[self.REAGENT_NAME]) then
        count, known, source = math.max(0,
            tonumber(reagents[self.REAGENT_NAME])), true, "inventory snapshot"
    else
        count, known, source = self:LiveCount()
        if known and inventory then
            inventory.reagentCounts = inventory.reagentCounts or {}
            inventory.reagentCounts[self.REAGENT_NAME] = count
        end
    end
    local reserve = self:Reserve()
    return { actual = count, expected = count, known = known,
        reserve = reserve, deficit = known and math.max(0, reserve - count) or nil,
        source = source }
end

function S:IsGenerator(action)
    if not action then return false end
    local facts = action.facts or {}
    return facts.soulShardGenerator == true
        or GENERATOR_IDS[tonumber(action.spellId)] == true
end

function S:GrayLevel(playerLevel)
    playerLevel = math.max(0, tonumber(playerLevel) or 0)
    if playerLevel <= 5 then return 0 end
    if playerLevel <= 39 then
        return playerLevel - math.floor(playerLevel / 10) - 5
    end
    if playerLevel <= 59 then
        return playerLevel - math.floor(playerLevel / 5) - 1
    end
    return playerLevel - 9
end

local function unitEvidence(state, descriptor)
    local record = descriptor and descriptor.record
    local evidence = record and record.encounter
    if not evidence and record and record.context then
        evidence = record.context.target
    end
    if not evidence and state and state.encounter then
        evidence = state.encounter.target
    end
    return evidence or {}, record and record.unit or descriptor and descriptor.unit
end

local function excludedCreature(evidence)
    local creatureTypeId = tonumber(evidence.creatureTypeId)
    if creatureTypeId == 8 or creatureTypeId == 11
        or creatureTypeId == 12 then return true end
    local creatureType = string.lower(tostring(evidence.creatureType or ""))
    return creatureType == "critter" or creatureType == "totem"
        or creatureType == "non-combat pet" or creatureType == "wild pet"
end

function S:TargetEligibility(state, descriptor)
    if not descriptor or descriptor.relation ~= "hostile" then
        return false, "not a hostile target"
    end
    local evidence, unit = unitEvidence(state, descriptor)
    if evidence.isPlayer then
        return false, "honorable-kill evidence unavailable"
    end
    if evidence.isPet or evidence.isMinion or excludedCreature(evidence) then
        return false, "target cannot yield experience"
    end
    local playerLevel = tonumber(state and state.playerLevel)
    local targetLevel = tonumber(evidence.level)
    if not playerLevel or not targetLevel or targetLevel == 0 then
        return false, "target level unavailable"
    end
    if targetLevel > 0 and targetLevel <= self:GrayLevel(playerLevel) then
        return false, "target is too low level to yield experience"
    end
    if unit and UnitIsTapped then
        local tapped, tappedKnown = safeCall(UnitIsTapped, unit)
        if tappedKnown and truthy(tapped) and UnitIsTappedByPlayer then
            local ours, oursKnown = safeCall(UnitIsTappedByPlayer, unit)
            if oursKnown and not truthy(ours) then
                return false, "target is tapped by another player"
            end
        end
    end
    return true, "nontrivial hostile creature"
end
