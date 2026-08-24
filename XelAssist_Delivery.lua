-- Ordinary action delivery is a stateless combat-mechanics model. Target
-- identity/profile storage and resistance mitigation remain owned by
-- the resistance subsystem; this module classifies hit tables and builds the exact
-- physical evidence fingerprint shared by estimates and resolved outcomes.
XelAssistDelivery = {}
local D = XelAssistDelivery

local function clamp(value, low, high)
    value = tonumber(value) or low
    if value < low then return low end
    if value > high then return high end
    return value
end

local function hasFlag(value, flag)
    value, flag = tonumber(value) or 0, tonumber(flag) or 1
    return math.floor(value / flag) - math.floor(value / (flag * 2)) * 2 == 1
end

local function guidFor(unit)
    if not UnitExists or not unit then return nil end
    local exists, guid = UnitExists(unit)
    if exists then return guid end
    return nil
end

function D:Model(facts, metadata)
    facts, metadata = facts or {}, metadata or {}
    if facts.deliveryModel == "physical" or facts.deliveryModel == "magic"
        or facts.deliveryModel == "none" then
        return facts.deliveryModel, true, "action semantics"
    end
    if metadata.deliveryModel == "physical" or metadata.deliveryModel == "magic"
        or metadata.deliveryModel == "none" then
        return metadata.deliveryModel, metadata.deliveryModelKnown ~= false,
            metadata.deliveryModelSource or "client DBC"
    end
    if facts.whiteAttack then return "physical", true, "white attack" end
    if facts.weaponRanged or facts.melee then
        return "physical", false, "catalogue delivery fallback"
    end
    return "unknown", false, "delivery class unavailable"
end

function D:Subtype(facts, metadata, model)
    facts, metadata = facts or {}, metadata or {}
    if model ~= "physical" then return nil end
    return facts.deliverySubtype or metadata.deliverySubtype
        or facts.weaponRanged and "ranged" or facts.melee and "melee" or "unknown"
end


function D:AutoAttackEvidence(totalDamage, hitInfo, victimState)
    totalDamage = math.max(0, tonumber(totalDamage) or 0)
    hitInfo, victimState = tonumber(hitInfo), tonumber(victimState)
    if hitInfo == nil or victimState == nil then return nil, "invalid outcome" end
    -- The same opcode is also used by SendMeleeAttackingStateUpdate for melee
    -- spells. Nampower forwards those with NOACTION, so accepting them here
    -- would train yellow outcomes into the white-swing Attack node.
    if hasFlag(hitInfo, 65536) then return nil, "melee spell packet" end
    if hasFlag(hitInfo, 16) then return "ordinary-miss", "miss" end
    if victimState == 2 then return "ordinary-miss", "dodge" end
    if victimState == 3 then return "ordinary-miss", "parry" end
    if victimState == 6 then return "ordinary-miss", "evade" end
    if victimState == 7 then return "ordinary-miss", "immune" end
    if victimState == 8 then return "ordinary-miss", "deflect" end
    -- Upstream uses BLOCKS only for a full block; partial blocks stay NORMAL.
    if victimState == 5 then return "ordinary-miss", "full block" end
    if victimState == 1 then return "hit", "hit" end
    -- UNAFFECTED is documented with HITINFO_MISS. If a custom client emits it
    -- without that flag, or the otherwise undocumented INTERRUPT state, do not
    -- guess and pollute a learned hit table.
    return nil, "unclassified victim state"
end

-- Interpret only the DBC fields that select an ordinary delivery table. School
-- and effect semantics remain in Resistance because they govern mitigation.
function D:SpellTraits(dmgClass, attributesEx3Raw, rangeIndex, equippedItemClass)
    dmgClass, rangeIndex, equippedItemClass = tonumber(dmgClass),
        tonumber(rangeIndex), tonumber(equippedItemClass)
    local attributesEx3 = tonumber(attributesEx3Raw) or 0
    local normalRanged = hasFlag(attributesEx3, 32768)
    local alwaysHit = hasFlag(attributesEx3, 262144)
    local combatRange
    if rangeIndex ~= nil then combatRange = rangeIndex == 2 end
    local usesWeaponSkill
    if rangeIndex == 2 or equippedItemClass == 2 then
        usesWeaponSkill = true
    elseif rangeIndex ~= nil and equippedItemClass ~= nil then
        usesWeaponSkill = false
    end
    local model
    if dmgClass == 2 or dmgClass == 3
        or dmgClass == 1 and normalRanged then model = "physical"
    elseif dmgClass == 1 then model = "magic"
    elseif dmgClass == 0 then model = "none" end
    local subtype = (dmgClass == 3 or dmgClass == 1 and normalRanged) and "ranged"
        or dmgClass == 2 and "melee" or nil
    return { dmgClass = dmgClass, rangeIndex = rangeIndex,
        equippedItemClass = equippedItemClass, normalRanged = normalRanged,
        alwaysHit = alwaysHit, alwaysHitKnown = attributesEx3Raw ~= nil,
        combatRange = combatRange, usesWeaponSkill = usesWeaponSkill,
        deliveryModel = model, deliveryModelKnown = model ~= nil,
        deliveryModelSource = model and "client DBC DmgClass" or nil,
        deliverySubtype = subtype }
end

local function trimDelivery(record)
    if (record.samples or 0) < 64 then return end
    record.samples = (record.samples or 0) * 0.75
    record.hits = (record.hits or 0) * 0.75
    record.misses = (record.misses or 0) * 0.75
end

local function updateDelivery(record, evidence, weight, observedAt)
    if evidence ~= true and evidence ~= "hit" and evidence ~= "ordinary-miss" then return end
    trimDelivery(record)
    weight = tonumber(weight) or 1
    record.samples = (record.samples or 0) + weight
    if evidence == true or evidence == "hit" then
        record.hits = (record.hits or 0) + weight
    else
        record.misses = (record.misses or 0) + weight
    end
    record.lastSeen = observedAt
end

function D:Key(context)
    local prefix = ""
    if context and context.deliveryModel == "physical" then
        prefix = "physical-" .. tostring(context.deliverySubtype or "unknown") .. ":"
    end
    return prefix .. tostring(context and (context.deliveryKey or context.key) or "unknown")
end

-- Resistance owns the profile; Delivery is the sole writer of ordinary
-- delivery records. Passing observedAt keeps this module stateless/testable.
function D:Record(profile, spellId, context, evidence, weight, observedAt)
    if not profile or (evidence ~= true and evidence ~= "hit"
        and evidence ~= "ordinary-miss") then return nil end
    local model = context and context.deliveryModel
    if model == "none" or model == "unknown"
        or context and context.deliveryModelKnown == false and model ~= "physical" then
        return nil
    end
    if type(profile.deliveryContexts) ~= "table" then profile.deliveryContexts = {} end
    local key = self:Key(context)
    local shared = profile.deliveryContexts[key] or {}
    updateDelivery(shared, evidence, weight, observedAt)
    profile.deliveryContexts[key] = shared
    local specific
    if spellId then
        if type(profile.spellDeliveryContexts) ~= "table" then
            profile.spellDeliveryContexts = {}
        end
        local spellKey = tostring(spellId) .. ":" .. key
        specific = profile.spellDeliveryContexts[spellKey] or {}
        updateDelivery(specific, evidence, weight, observedAt)
        profile.spellDeliveryContexts[spellKey] = specific
    end
    return shared, specific, key
end

function D:BaseSpellHit(attackerLevel, targetLevel, targetIsPlayer)
    if type(attackerLevel) ~= "number" or attackerLevel <= 0
        or type(targetLevel) ~= "number" or targetLevel <= 0 then return 0.96 end
    local difference = targetLevel - attackerLevel
    local percent
    if difference < 3 then percent = 96 - difference
    else percent = 94 - (difference - 2) * (targetIsPlayer and 7 or 11) end
    return clamp(percent / 100, 0.22, 0.99)
end

function D:Learned(record, prior, ageWeight, priorWeight)
    if not record then return nil, 0 end
    local recency = ageWeight(record.lastSeen)
    local samples = (record.samples or 0) * recency
    if samples <= 0 then return nil, 0 end
    local posterior = ((record.hits or 0) + priorWeight * prior)
        / ((record.samples or 0) + priorWeight)
    return prior + (posterior - prior) * recency, samples
end

local function compactContextToken(value)
    value = tostring(value or "?")
    local hash, index = 0, nil
    for index = 1, string.len(value) do
        local nextHash = hash * 131 + string.byte(value, index)
        hash = nextHash - math.floor(nextHash / 1000003) * 1000003
    end
    return tostring(hash)
end

local function targetDefense(identity, actor, attackerLevel)
    local level = identity and tonumber(identity.level)
    if level == -1 and attackerLevel and attackerLevel > 0 then level = attackerLevel + 3 end
    if identity and identity.isPlayer then
        -- vMaNGOS uses the victim player's maximum Defense when the attacker
        -- is another player, including permanent and temporary Defense
        -- bonuses. A pet/non-player attacker instead checks the victim's
        -- current Defense. UnitDefense exposes the current base plus the same
        -- bonus term when the hostile unit API supplies a non-zero value.
        local liveBase, liveModifier
        if identity.guid == guidFor("target") and UnitDefense then
            local ok, base, modifier = pcall(UnitDefense, "target")
            if ok and type(base) == "number" and base > 0 then
                liveBase, liveModifier = base, tonumber(modifier) or 0
            end
        end
        if actor == "player" and level and level > 0 then
            local maximum = level * 5
            if liveBase then
                return math.max(0, maximum + liveModifier), true,
                    "PvP maximum defense plus live bonuses"
            end
            return maximum, false, "PvP defense bonuses unverified"
        end
        if actor ~= "player" and liveBase then
            local total = liveBase + liveModifier
            if total > 0 then
                return total, true, "live player defense vs non-player attacker"
            end
        end
        return level and level > 0 and level * 5 or nil, false,
            "hostile player current defense unverified"
    end
    if level and level > 0 then
        return level * 5, true, identity and identity.isPlayer
            and "PvP maximum defense" or "NPC level defense"
    end
    return nil, false, "target defense unavailable"
end

local function physicalHitFromSkills(attackerSkill, defense, targetLevel,
    targetIsPlayer, dualWieldWhite)
    if type(attackerSkill) ~= "number" or type(defense) ~= "number" then return nil end
    local difference = attackerSkill - defense
    local miss
    if targetIsPlayer then miss = 5 - difference * 0.04
    elseif difference < -10 then miss = 5 - difference * 0.2
    else miss = 5 - difference * 0.1 end
    if dualWieldWhite then miss = miss + 19 end
    if not targetIsPlayer and type(targetLevel) == "number"
        and targetLevel > 0 and targetLevel < 10 then
        miss = miss * targetLevel / 10
    end
    miss = clamp(miss, 0, 60)
    return 1 - miss / 100, miss
end

-- Build only the initial physical miss roll here. Dodge/parry/block/mechanic
-- outcomes remain exact learned evidence because their availability depends on
-- position and target flags. The +19% dual-wield term is valid only for white
-- melee swings; yellow abilities and ranged attacks never inherit it.
function D:PhysicalContext(action, metadata, context, identity)
    local facts = action and action.facts or {}
    metadata = metadata or {}
    local subtype = context and context.deliverySubtype or facts.deliverySubtype
        or metadata.deliverySubtype or facts.weaponRanged and "ranged"
        or facts.melee and "melee" or "unknown"
    local hand = facts.weaponHand or (subtype == "ranged" and "ranged" or "main")
    if hand ~= "main" and hand ~= "off" and hand ~= "ranged" then hand = "main" end
    -- Current vMaNGOS uses BASE_ATTACK for the miss roll of melee specials,
    -- even when later damage/proc processing identifies an off-hand weapon.
    -- OFF_ATTACK skill is therefore valid only for an actual off-hand white
    -- swing until the live fork proves otherwise.
    if hand == "off" and facts.whiteAttack ~= true then hand = "main" end
    local actualSkill
    if facts.whiteAttack or facts.weaponRanged or facts.usesWeaponSkill == true
        or metadata.usesWeaponSkill == true then actualSkill = true
    elseif facts.usesWeaponSkill == false or metadata.usesWeaponSkill == false then
        actualSkill = false
    end
    local actor = context and context.actor or action and action.actor or "player"
    local level = context and tonumber(context.level)
    local skills = actor == "player" and XelAssistCapabilities
        and XelAssistCapabilities.WeaponSkills and XelAssistCapabilities:WeaponSkills() or nil
    local record, attackerSkill, skillKnown, skillSource, weaponToken
    if actor ~= "player" then
        attackerSkill, skillKnown = level and level > 0 and level * 5 or nil,
            level and level > 0 and true or false
        skillSource = skillKnown and "unit level skill" or "unit skill unavailable"
        actualSkill = true
    elseif actualSkill == true then
        record = type(skills) == "table" and skills[hand] or nil
        attackerSkill = record and tonumber(record.total)
        skillKnown = record and record.known == true and attackerSkill ~= nil or false
        skillSource = record and record.source or "current weapon skill unavailable"
        weaponToken = type(skills) == "table" and skills[hand .. "Token"] or nil
    elseif actualSkill == false then
        attackerSkill, skillKnown = level and level > 0 and level * 5 or nil,
            level and level > 0 and true or false
        skillSource = skillKnown and "spell uses level-max skill" or "level-max skill unavailable"
    else
        skillKnown, skillSource = false, "spell weapon-skill mode unavailable"
    end
    local defense, defenseKnown, defenseSource = targetDefense(identity, actor, level)
    local dualRelevant = facts.whiteAttack == true and subtype ~= "ranged"
    local dualStateKnown = not dualRelevant
    if dualRelevant and type(skills) == "table" then
        if skills.dualWieldKnown ~= nil then
            dualStateKnown = skills.dualWieldKnown == true
        else
            -- Compatibility with a capability provider that predates the
            -- explicit durability-aware certainty bit.
            dualStateKnown = skills.dualWield ~= nil
        end
    end
    local dual = dualRelevant and type(skills) == "table"
        and skills.dualWield == true or false
    local targetLevel = identity and tonumber(identity.level)
    if targetLevel == -1 and level and level > 0 then targetLevel = level + 3 end
    local hit, miss = physicalHitFromSkills(attackerSkill, defense, targetLevel,
        identity and identity.isPlayer, dual)
    local positionRelevant = subtype ~= "ranged"
    local positionKnown = positionRelevant and context
        and context.positionKnown == true and type(context.behindTarget) == "boolean" or false
    local attackPosition = not positionRelevant and "not-applicable"
        or positionKnown and (context.behindTarget and "behind" or "front") or "unknown"
    local modeToken = actualSkill == true and "1" or actualSkill == false and "0" or "?"
    local modelKnown = context and context.deliveryModelKnown == true
    local alwaysHit, alwaysHitKnown
    if facts.alwaysHit ~= nil then
        alwaysHit, alwaysHitKnown = facts.alwaysHit and true or false, true
    elseif metadata.alwaysHitKnown then
        alwaysHit, alwaysHitKnown = metadata.alwaysHit and true or false, true
    elseif facts.whiteAttack then
        alwaysHit, alwaysHitKnown = false, true
    else
        alwaysHit, alwaysHitKnown = false, false
    end
    local token = "w" .. hand .. ":s" .. tostring(attackerSkill or "?")
        .. ":sk" .. (skillKnown and "1" or "0")
        .. ":d" .. tostring(defense or "?")
        .. ":dk" .. (defenseKnown and "1" or "0") .. ":u" .. modeToken
        .. ":wt" .. (facts.whiteAttack == true and "1" or "0")
        .. ":mc" .. (modelKnown and "1" or "0")
        .. ":ah" .. (not alwaysHitKnown and "?" or alwaysHit and "1" or "0")
        .. ":x" .. compactContextToken(weaponToken or (actualSkill == false and "level" or "?"))
        .. ":dw" .. (not dualStateKnown and "?" or dual and "1" or "0")
        .. ":p" .. attackPosition
    local priorGaps = {}
    if not skillKnown then table.insert(priorGaps, "weapon skill") end
    if not defenseKnown then table.insert(priorGaps, "target Defense") end
    if not modelKnown then table.insert(priorGaps, "delivery class") end
    if not alwaysHitKnown then table.insert(priorGaps, "always-hit flag") end
    if type(skills) == "table" and skills.formWeaponUseKnown == false then
        table.insert(priorGaps, "shapeshift weapon rule")
    end
    if hit == nil then table.insert(priorGaps, "base miss roll") end
    if not dualStateKnown then table.insert(priorGaps, "off-hand durability") end
    if positionRelevant and not positionKnown then table.insert(priorGaps, "attack position") end
    -- The stock/Nampower APIs do not expose a complete additive +hit total or
    -- a target's live dodge/parry/block table. Exact hit/miss outcomes learn
    -- those omitted sub-rolls in this fully partitioned context.
    if not alwaysHit then table.insert(priorGaps, "+hit") end
    if facts.whiteAttack then
        table.insert(priorGaps, "active defenses")
    elseif subtype == "ranged" then
        table.insert(priorGaps, "mechanic resistance")
    else
        table.insert(priorGaps, "active defenses/mechanic resistance")
    end
    return { key = token, subtype = subtype, hand = hand,
        weaponSkill = attackerSkill, weaponSkillKnown = skillKnown,
        weaponSkillSource = skillSource, usesWeaponSkill = actualSkill,
        targetDefense = defense, targetDefenseKnown = defenseKnown,
        targetDefenseSource = defenseSource, dualWieldWhitePenalty = dual and 19 or 0,
        whiteAttack = facts.whiteAttack == true,
        dualWieldStateKnown = dualStateKnown,
        deliveryModelKnown = modelKnown,
        alwaysHit = alwaysHit, alwaysHitKnown = alwaysHitKnown,
        formWeaponUseKnown = type(skills) == "table" and skills.formWeaponUseKnown,
        attackPosition = attackPosition, positionKnown = positionKnown,
        positionRelevant = positionRelevant,
        positionSource = positionKnown and context.positionSource
            or positionRelevant and "position unavailable" or "ranged attack table",
        hitChance = hit, missChance = miss,
        priorGaps = table.concat(priorGaps, ", "), unknown = table.getn(priorGaps) > 0,
        hitBonusKnown = false, hitBonusSource = "+hit excluded from skill prior" }
end

function D:ApplyPhysicalContext(context, physical)
    if not context or not physical then return context end
    -- A submission can know that an action is melee/ranged from graph facts
    -- even when its DBC row is incomplete. Restore that captured subtype on
    -- delayed combat events so learned outcomes use the exact key Estimate
    -- will read for the action.
    context.deliverySubtype = physical.subtype or context.deliverySubtype
    -- Armor/spell penetration changes landed-hit mitigation, never the
    -- physical hit table. Keep it in context.key for mitigation while the
    -- delivery key uses a deliberate not-applicable marker. This also lets a
    -- first dynamic-school wand miss train the later discovered school.
    context.deliveryKey = tostring(context.actor or "player") .. ":l"
        .. tostring(context.level or 0) .. ":p-:" .. tostring(physical.key)
    context.weaponSkill = physical.weaponSkill
    context.targetDefense = physical.targetDefense
    context.attackPosition = physical.attackPosition
    context.positionKnown = physical.positionKnown
    context.physicalDelivery = physical
    return context
end

-- Physical spell attacks use the weapon table, not the magic spell table.
-- This level prior is retained only when a live skill or target-defense input
-- is unavailable; the result is marked as delivery-unknown by Estimate.
function D:BasePhysicalHit(attackerLevel, targetLevel, targetIsPlayer)
    if type(attackerLevel) ~= "number" or attackerLevel <= 0
        or type(targetLevel) ~= "number" or targetLevel <= 0 then return 0.95 end
    local difference = targetLevel - attackerLevel
    local miss
    if targetIsPlayer then miss = 5 + math.max(0, difference) * 0.2
    elseif difference > 2 then miss = 5 + difference
    else miss = 5 + difference * 0.5 end
    return clamp(1 - miss / 100, 0.40, 0.99)
end
