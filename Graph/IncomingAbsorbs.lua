-- Projected absorb consumption for exact-recipient hostile consequences.
-- Ordinary school shields resolve first. Mana Shield is deferred because the
-- build-5875 server spends mana only after ordinary absorbs are exhausted.
XelAssist.Graph.IncomingAbsorbs = {}
local A = XelAssist.Graph.IncomingAbsorbs
local MageShield = XelAssist.Game and XelAssist.Game.Player
    and XelAssist.Game.Player.MageManaShield

local function names(absorbs)
    local out, name, value = {}, nil, nil
    for name, value in pairs(absorbs or {}) do
        if name ~= "available" and (type(value) == "number"
            or type(value) == "table" and tonumber(value.amount)) then
            table.insert(out, name)
        end
    end
    table.sort(out)
    return out
end

local function consumeOrdinary(absorbs, damage, castProbability, seen)
    local ordered, absorbed, partial = names(absorbs), 0, false
    local i, name, entry, amount, probability, used, conditionalUsed
    local hitRemaining, survival, expectedRemaining, remainingProbability
    for i = 1, table.getn(ordered) do
        name, entry = ordered[i], absorbs[ordered[i]]
        if not seen[name] and damage > 0
            and not (MageShield and MageShield:IsEntry(entry)) then
            amount = type(entry) == "table" and tonumber(entry.amount)
                or tonumber(entry) or 0
            probability = type(entry) == "table"
                and tonumber(entry.applicationProbability) or 1
            probability = math.max(0, math.min(1, probability or 1))
            if probability > 0 then seen[name] = true end
            conditionalUsed = math.min(damage, amount)
            used = conditionalUsed * probability
            damage = math.max(0, damage - used)
            absorbed = absorbed + used * castProbability
            hitRemaining = math.max(0, amount - conditionalUsed)
            survival = 1 - castProbability
                + (hitRemaining > 0 and castProbability or 0)
            expectedRemaining = (1 - castProbability) * amount
                + castProbability * hitRemaining
            remainingProbability = probability * survival
            if survival > 0 then expectedRemaining = expectedRemaining / survival end
            if remainingProbability <= 0 or expectedRemaining <= 0 then
                absorbs[name] = nil
            elseif type(entry) == "table" then
                entry.amount = expectedRemaining
                entry.applicationProbability = remainingProbability
            else
                absorbs[name] = remainingProbability < 1
                    and { amount = expectedRemaining,
                        applicationProbability = remainingProbability }
                    or expectedRemaining
            end
            if probability < 1 or castProbability < 1 then partial = true end
        end
    end
    return damage, absorbed, partial
end

local function consumeMana(state, absorbs, damage, castProbability, school, seen)
    local ordered, absorbed, partial = names(absorbs), 0, false
    local i, name, used, entryPartial, handled
    if not MageShield then return damage, absorbed, partial end
    for i = 1, table.getn(ordered) do
        name = ordered[i]
        if not seen[name] and damage > 0 then
            damage, used, _, entryPartial, handled = MageShield:ConsumeEntry(
                state, absorbs, name, damage, castProbability, school)
            if handled then
                seen[name] = true
                absorbed = absorbed + used
                partial = partial or entryPartial
            end
        end
    end
    return damage, absorbed, partial
end

local function consumeBucket(fn, state, absorbs, damage, castProbability,
    school, seen, absorbed, partial)
    if not absorbs then return damage, absorbed, partial end
    local used, bucketPartial
    if fn == consumeMana then
        damage, used, bucketPartial = fn(state, absorbs, damage,
            castProbability, school, seen)
    else
        damage, used, bucketPartial = fn(absorbs, damage,
            castProbability, seen)
    end
    return damage, absorbed + used, partial or bucketPartial
end

function A:Consume(state, recipient, damage, castProbability, school)
    local seen, absorbed, partial = {}, 0, false
    local friendly = recipient.friendly and recipient.friendly.absorbs
    damage, absorbed, partial = consumeBucket(consumeOrdinary, state,
        friendly, damage, castProbability, school, seen, absorbed, partial)
    if recipient.friendly and friendly and friendly.available == false then
        partial = true
    elseif not recipient.friendly
        and (recipient.kind == "player" or recipient.kind == "pet") then
        partial = true
    end
    local player = recipient.kind == "player" and state.absorbs or nil
    damage, absorbed, partial = consumeBucket(consumeOrdinary, state,
        player, damage, castProbability, school, seen, absorbed, partial)
    damage, absorbed, partial = consumeBucket(consumeMana, state,
        friendly, damage, castProbability, school, seen, absorbed, partial)
    damage, absorbed, partial = consumeBucket(consumeMana, state,
        player, damage, castProbability, school, seen, absorbed, partial)
    return damage * castProbability, absorbed, partial
end
