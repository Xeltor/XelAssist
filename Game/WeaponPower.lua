-- Live weapon-damage bases for VMaNGOS weapon spell effects. Ordinary
-- character-sheet damage is authoritative; normalized specials adjust only
-- the attack-power speed lane that the server replaces.
XelAssist.Game.WeaponPower = {}
local W = XelAssist.Game.WeaponPower

local MAIN_SLOT, RANGED_SLOT = 16, 18
local INVTYPE_RANGED, INVTYPE_2HWEAPON = 15, 17
local INVTYPE_THROWN, INVTYPE_RANGEDRIGHT = 25, 26
local DAGGER_SUBCLASS = 15
local DAGGER_MASTERY_SPELL_ID = 45591

local function call(fn, a, b, c)
    if not fn then return nil end
    local ok, first, second, third, fourth, fifth, sixth, seventh
    if c ~= nil then
        ok, first, second, third, fourth, fifth, sixth, seventh = pcall(fn, a, b, c)
    elseif b ~= nil then
        ok, first, second, third, fourth, fifth, sixth, seventh = pcall(fn, a, b)
    elseif a ~= nil then
        ok, first, second, third, fourth, fifth, sixth, seventh = pcall(fn, a)
    else
        ok, first, second, third, fourth, fifth, sixth, seventh = pcall(fn)
    end
    if ok then return first, second, third, fourth, fifth, sixth, seventh end
    return nil
end

local function equippedItemId(slot)
    local item = call(GetEquippedItem, "player", slot)
    local itemId = type(item) == "table" and tonumber(item.itemId)
    if itemId and itemId > 0 then return itemId end
    local link = call(GetInventoryItemLink, "player", slot)
    local _, _, linked = string.find(link or "", "item:(%d+)")
    return tonumber(linked)
end

local function itemField(itemId, field)
    if not (itemId and GetItemStatsField) then return nil end
    return call(GetItemStatsField, itemId, field)
end

local function ordinaryMelee()
    local low, high, _, _, _, _, percent = call(UnitDamage, "player")
    low, high, percent = tonumber(low), tonumber(high), tonumber(percent)
    if low and high then
        return (low + high) / 2, percent, "live UnitDamage"
    end
    low = tonumber(call(GetUnitField, "player", "minDamage"))
    high = tonumber(call(GetUnitField, "player", "maxDamage"))
    if low and high then return (low + high) / 2, nil, "live damage fields" end
    return nil, nil, "melee damage unavailable"
end

local function ordinaryOffhand()
    local _, _, low, high, _, _, percent = call(UnitDamage, "player")
    low, high, percent = tonumber(low), tonumber(high), tonumber(percent)
    if low and high and high > 0 then
        return (low + high) / 2, percent, "live UnitDamage off-hand"
    end
    low = tonumber(call(GetUnitField, "player", "minOffhandDamage"))
    high = tonumber(call(GetUnitField, "player", "maxOffhandDamage"))
    if low and high and high > 0 then
        return (low + high) / 2, nil, "live off-hand damage fields"
    end
    return nil, nil, "off-hand damage unavailable"
end

local function ordinaryRanged()
    local _, low, high, _, _, percent = call(UnitRangedDamage, "player")
    low, high, percent = tonumber(low), tonumber(high), tonumber(percent)
    if low and high then
        return (low + high) / 2, percent, "live UnitRangedDamage"
    end
    low = tonumber(call(GetUnitField, "player", "minRangedDamage"))
    high = tonumber(call(GetUnitField, "player", "maxRangedDamage"))
    if low and high then return (low + high) / 2, nil, "live ranged fields" end
    return nil, nil, "ranged damage unavailable"
end

local function signed16(value)
    value = math.floor(math.max(0, tonumber(value) or 0)) -
        math.floor(math.max(0, tonumber(value) or 0) / 65536) * 65536
    if value >= 32768 then return value - 65536 end
    return value
end

local function attackPower(ranged)
    local baseField = ranged and "rangedAttackPower" or "attackPower"
    local modsField = ranged and "rangedAttackPowerMods" or "attackPowerMods"
    local multiplierField = ranged and "rangedAttackPowerMultiplier"
        or "attackPowerMultiplier"
    local base = tonumber(call(GetUnitField, "player", baseField))
    local packed = tonumber(call(GetUnitField, "player", modsField))
    local multiplier = tonumber(call(GetUnitField, "player", multiplierField))
    if base ~= nil and packed ~= nil and multiplier ~= nil then
        local positive = signed16(packed)
        local negative = signed16(math.floor(packed / 65536))
        return math.max(0, (base + positive + negative)
            * math.max(0, 1 + multiplier)), true
    end
    local fn = ranged and UnitRangedAttackPower or UnitAttackPower
    local apiBase, positive, negative = call(fn, "player")
    apiBase, positive, negative = tonumber(apiBase), tonumber(positive),
        tonumber(negative)
    if apiBase == nil then return nil, false end
    return math.max(0, apiBase + (positive or 0) + (negative or 0)), false
end

local function attackTime(ranged)
    local field = ranged and "rangedAttackTime" or "baseAttackTime"
    local milliseconds = tonumber(call(GetUnitField, "player", field))
    if milliseconds and milliseconds > 0 then return milliseconds / 1000, true end
    local main = tonumber(call(UnitAttackSpeed, "player"))
    if not ranged and main and main > 0 then return main, false end
    if ranged then
        local speed = tonumber(call(UnitRangedDamage, "player"))
        if speed and speed > 0 then return speed, false end
    end
    return nil, false
end

local function normalizedSpeed(ranged, itemId)
    if not itemId then return 2.4, "unarmed normalized speed" end
    local inventoryType = tonumber(itemField(itemId, "inventoryType"))
    local subclass = tonumber(itemField(itemId, "subclass"))
    if inventoryType == INVTYPE_2HWEAPON then
        return 3.3, "two-handed normalized speed"
    end
    if ranged or inventoryType == INVTYPE_RANGED
        or inventoryType == INVTYPE_THROWN
        or inventoryType == INVTYPE_RANGEDRIGHT then
        return 2.8, "ranged normalized speed"
    end
    if subclass == DAGGER_SUBCLASS then
        if type(IsPlayerSpell) == "function" then
            local ok, learned = pcall(IsPlayerSpell, DAGGER_MASTERY_SPELL_ID)
            if ok and learned then
                return 2.3, "Dagger Mastery normalized speed"
            end
        end
        return 1.7, "dagger normalized speed"
    end
    if inventoryType ~= nil and subclass ~= nil then
        return 2.4, "one-handed normalized speed"
    end
    return nil, "weapon type unavailable"
end

function W:Basis(action, tooltip)
    local facts = action and action.facts or {}
    local ranged = facts.ranged and tooltip and tooltip.school == 0 and true or false
    local offhand = not ranged and facts.weaponHand == "off"
    local ordinary, percent, source
    if ranged then ordinary, percent, source = ordinaryRanged()
    elseif offhand then ordinary, percent, source = ordinaryOffhand()
    else ordinary, percent, source = ordinaryMelee() end
    local evidence = { exact = ordinary ~= nil, normalized = false,
        source = source, damagePercent = percent }
    if ordinary == nil then
        evidence.gap = "live weapon damage"
        return nil, evidence
    end
    if not (tooltip and tooltip.weaponNormalized) then return ordinary, evidence end

    evidence.normalized = true
    local slot = ranged and RANGED_SLOT or offhand and 17 or MAIN_SLOT
    local itemId = equippedItemId(slot)
    local speed, speedSource = normalizedSpeed(ranged, itemId)
    local currentSpeed, currentSpeedExact = attackTime(ranged)
    local power, powerExact = attackPower(ranged)
    evidence.normalizedSpeed, evidence.currentSpeed = speed, currentSpeed
    evidence.source = source .. "; " .. speedSource
    if not (speed and currentSpeed and power and percent) then
        evidence.exact = false
        evidence.gap = not speed and "normalized weapon type"
            or not currentSpeed and "weapon attack time"
            or not power and "attack power"
            or "weapon damage multiplier"
        return ordinary, evidence
    end
    evidence.exact = currentSpeedExact and powerExact
    if not evidence.exact then
        evidence.gap = not currentSpeedExact and "exact weapon attack time"
            or "exact attack power"
    end
    local delta = power / 14 * (speed - currentSpeed) * percent
    return math.max(0, ordinary + delta), evidence
end
