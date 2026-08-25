-- Ordinary controlled-actor melee is independent of the pet spell GCD and
-- focus scheduler. Exact phase comes from Game.AttackRounds; this module only
-- emits bounded, target-pinned graph events while live reach is defensible.
XelAssist.Graph.CompanionSwings = {}
local S = XelAssist.Graph.CompanionSwings

local MAX_EVENTS = 8
local READY_DELAY = 0.05

local function addUnknown(candidate, reason)
    candidate.companionUnknowns = candidate.companionUnknowns or {}
    local index
    for index = 1, table.getn(candidate.companionUnknowns) do
        if candidate.companionUnknowns[index] == reason then return end
    end
    table.insert(candidate.companionUnknowns, reason)
end

local function geometry(pet, record)
    local observed = record and record.geometry and record.geometry.pet
    if observed then return observed end
    return { distance = pet.distance, distanceKind = pet.distanceKind,
        lineOfSight = pet.lineOfSight, source = pet.distanceKind }
end

local function legal(pet, record)
    local observed = geometry(pet, record)
    if type(observed.distance) ~= "number" then
        return nil, "companion melee geometry"
    end
    local kind = observed.distanceKind or observed.source
    if kind ~= "hitbox" and kind ~= "combat reach" then
        return nil, "companion melee distance provenance"
    end
    if observed.distance > 5 then return false, "range" end
    return true, nil
end

local function attackAction(melee)
    return { name = "Companion Attack", actor = "pet", kind = "damage",
        power = 0, normalPower = math.max(0, tonumber(melee.power) or 0),
        facts = { kind = "damage", school = 0, damageActor = "pet",
            effectActor = "pet", melee = true, whiteAttack = true,
            weaponHand = "main", deliveryModel = "physical",
            deliverySubtype = "melee", usesWeaponSkill = true,
            powerSource = melee.damageSource, outcomeMagnitudeKnown = false },
        tooltip = { school = 0 }, source = melee.phaseSource }
end

local function event(melee, identity, offset, window)
    return { owner = "ongoing", kind = "petWhiteSwing", priority = 50,
        offset = offset, windowEnd = window,
        targetGuid = identity.guid, targetKey = identity.key,
        targetLocal = identity.localTarget,
        ambient = attackAction(melee), phaseSource = melee.phaseSource }
end

local function holdReady(melee, window)
    melee.nextSwingIn = math.max(0,
        (tonumber(melee.nextSwingIn) or 0) - window)
    if melee.nextSwingIn <= 0 then melee.readyHeld = true end
end

function S:Events(pet, record, candidate, identity)
    local events, melee = {}, pet and pet.attackRound
    if not (melee and identity and melee.projectable
        and melee.attackActive == true) then return events end
    local window = math.max(0, tonumber(candidate.downtime) or 0)
    local allowed, reason = legal(pet, record)
    if allowed ~= true then
        holdReady(melee, window)
        if allowed == nil then
            pet.whiteSwingGeometryUnknown = true
            addUnknown(candidate, reason)
        end
        return events
    end
    local interval = math.max(0.1, tonumber(melee.interval) or 0)
    if interval <= 0.1 and not tonumber(melee.interval) then return events end
    local offset = melee.readyHeld and READY_DELAY
        or math.max(READY_DELAY, tonumber(melee.nextSwingIn) or interval)
    local count = 0
    while offset <= window and count < MAX_EVENTS do
        table.insert(events, event(melee, identity, offset, window))
        offset, count = offset + interval, count + 1
    end
    if count > 0 then
        pet.whiteSwingMagnitudeUnknown = true
        addUnknown(candidate, "companion white-swing outcome magnitude")
    end
    melee.readyHeld = nil
    melee.nextSwingIn = math.max(READY_DELAY, offset - window)
    if count == MAX_EVENTS and offset <= window then
        table.insert(events, { owner = "ongoing", kind = "petSwingTimelineCap",
            priority = 55, offset = offset, windowEnd = window })
        melee.phaseExact = false
        pet.whiteSwingTimelineCapped = true
        addUnknown(candidate, "companion white-swing timeline cap")
    end
    return events
end

local function sameTarget(left, right)
    if left.targetKey ~= nil or right.targetKey ~= nil then
        return left.targetKey ~= nil and left.targetKey == right.targetKey
    end
    return left.targetGuid ~= nil and left.targetGuid == right.targetGuid
end

local function hostileCompletion(entry)
    return (entry.kind == "petAutocast"
            or entry.kind == "petAutocastUnknown")
        and not entry.targetIndependent
end

function S:ResolveTies(events, pet, candidate)
    local swingIndex
    for swingIndex = table.getn(events), 1, -1 do
        local swing = events[swingIndex]
        if swing.kind == "petWhiteSwing" then
            local index, tied = 1, nil
            while index <= table.getn(events) and not tied do
                local entry = events[index]
                if index ~= swingIndex and hostileCompletion(entry)
                    and math.abs(entry.offset - swing.offset) < 0.001
                    and sameTarget(entry, swing) then tied = entry end
                index = index + 1
            end
            if tied then
                tied.kind = "petAutocastUnknown"
                tied.unknownReason = "companion melee order"
                tied.meleeOrderUnknown = true
                tied.tiedWhiteAmbient = swing.ambient
                table.remove(events, swingIndex)
                pet.whiteSwingOrderUnknown = true
                addUnknown(candidate, "companion melee order")
            end
        end
    end
    return events
end

function S:StillCurrent(out, pet, entry)
    local melee = pet and pet.attackRound
    if not (melee and melee.projectable and melee.attackActive == true)
        or pet.attackActive == false then return false end
    local targets = XelAssist.Graph.CompanionTargets
    return targets and targets:StillCurrent(out, pet, entry) or false
end
