-- Session-local acknowledgement and recovery state for protected pet commands.
-- A command is graph input on the next snapshot; it is never assumed to have
-- changed the client merely because the protected function returned.
XelAssist.Game.Pets = XelAssist.Game.Pets or {}
XelAssist.Game.Pets.CommandState = {}
local C = XelAssist.Game.Pets.CommandState

local ACK_SECONDS = 1.25
local RECOVERY_ENTER = 0.25
local RECOVERY_EXIT = 0.35
local COMMANDS = { "attack", "follow", "passive" }

local function now()
    if type(GetTime) ~= "function" then return 0 end
    local ok, value = pcall(GetTime)
    return ok and tonumber(value) or 0
end

local function healthRatio(pet)
    local current = pet and tonumber(pet.health)
    local maximum = pet and tonumber(pet.healthMax)
    if not current or not maximum or maximum <= 0 then return nil end
    return current / maximum
end

local function liveHealthRatio()
    if type(UnitHealth) ~= "function" or type(UnitHealthMax) ~= "function" then
        return nil
    end
    local okHealth, health = pcall(UnitHealth, "pet")
    local okMaximum, maximum = pcall(UnitHealthMax, "pet")
    health, maximum = tonumber(health), tonumber(maximum)
    if not okHealth or not okMaximum or not health or not maximum
        or maximum <= 0 then return nil end
    return health / maximum
end

local function activity(pet)
    if pet and pet.attackActiveKnown == true then
        return pet.attackActive == true, true
    end
    local round = pet and pet.attackRound
    if round and round.attackActiveKnown == true then
        return round.attackActive == true, true
    end
    return nil, false
end

local function acknowledged(pet, command)
    local active, known = activity(pet)
    if command == "attack" then
        return pet.targetsCurrent == true and known and active == true
    end
    if command == "follow" then
        return pet.targetExists == false
            or pet.followingKnown == true and pet.following == true
    end
    return command == "passive" and pet.stance == "passive"
end

local function retreatField(command, suffix)
    if command ~= "follow" and command ~= "passive" then return nil end
    return command .. suffix
end

local function releaseUnacknowledged(record, command)
    local issued, confirmed = retreatField(command, "Issued"),
        retreatField(command, "Acknowledged")
    if issued and not record[confirmed] then record[issued] = false end
end

local function liveHealingChannel(guid)
    if not (XelAssist.petCastChannel and XelAssist.petCastGuid == guid
        and XelAssist.petCastSpellId and tonumber(XelAssist.petCastUntil)
        and XelAssist.petCastUntil > now()) then return false end
    local knowledge = XelAssist.Combat and XelAssist.Combat.PetKnowledge
    if not (knowledge and knowledge.Facts) then return false end
    local facts = knowledge:Facts(XelAssist.petCastSpellId, nil, nil)
    return facts and facts.kind == "petHeal" and facts.channel == true
end

function C:Reset(reason)
    self.record = nil
    self.lastResetReason = reason or "companion command state reset"
end

function C:IdentityChanged(previousGuid, currentGuid)
    if previousGuid == currentGuid then return false end
    self:Reset("companion identity changed")
    return true
end

function C:Absent()
    if not self.record then return false end
    self:Reset("companion unavailable")
    return true
end

function C:Record(guid)
    if guid == nil then return nil end
    if not self.record or self.record.guid ~= guid then
        self.record = { guid = guid, pending = {}, recovering = false,
            followIssued = false, followAcknowledged = false,
            passiveIssued = false, passiveAcknowledged = false }
    end
    return self.record
end

local function updateRecovery(record, ratio)
    if ratio == nil then return end
    if not record.recovering and ratio < RECOVERY_ENTER then
        record.recovering = true
        record.followIssued, record.passiveIssued = false, false
        record.followAcknowledged, record.passiveAcknowledged = false, false
    elseif record.recovering and ratio >= RECOVERY_EXIT then
        record.recovering = false
        record.followIssued, record.passiveIssued = false, false
        record.followAcknowledged, record.passiveAcknowledged = false, false
    end
end

function C:Attach(pet)
    if not (pet and pet.guid ~= nil) then return pet end
    local record = self:Record(pet.guid)
    updateRecovery(record, healthRatio(pet))
    if record.recovering and pet.followingKnown == true
        and pet.following == true then
        record.followIssued, record.followAcknowledged = true, true
    end
    if record.recovering and pet.stance == "passive" then
        record.passiveIssued, record.passiveAcknowledged = true, true
    end
    local pending, at, index, command = {}, now(), nil, nil
    for index = 1, table.getn(COMMANDS) do
        command = COMMANDS[index]
        local entry = record.pending[command]
        if entry and acknowledged(pet, command) then
            record.pending[command] = nil
            local confirmed = retreatField(command, "Acknowledged")
            if confirmed then record[confirmed] = true end
        elseif entry and at - entry.at >= 0
            and at - entry.at <= ACK_SECONDS then
            pending[command] = true
        else
            record.pending[command] = nil
            if entry then releaseUnacknowledged(record, command) end
        end
    end
    pet.commandPending = pending
    pet.recovering = record.recovering and true or false
    pet.retreatFollowIssued = record.recovering
        and record.followIssued and true or false
    pet.retreatPassiveIssued = record.recovering
        and record.passiveIssued and true or false
    return pet
end

function C:Pending(guid, command)
    local record = self.record
    if not record or record.guid ~= guid then return false end
    local entry = record.pending and record.pending[command]
    if not entry then return false end
    local age = now() - entry.at
    if age < 0 or age > ACK_SECONDS then
        record.pending[command] = nil
        releaseUnacknowledged(record, command)
        return false
    end
    return true
end

function C:Submitted(guid, command)
    local record = self:Record(guid)
    if not record or not command then return false end
    updateRecovery(record, liveHealthRatio())
    record.pending[command] = { at = now() }
    if record.recovering and command == "follow" then
        record.followIssued, record.followAcknowledged = true, false
    elseif record.recovering and command == "passive" then
        record.passiveIssued, record.passiveAcknowledged = true, false
    end
    local revision = XelAssist.Core and XelAssist.Core.CombatRevision
    if revision and revision.Touch then
        revision:Touch("pet", "protected pet command submitted")
    end
    return true
end

function C:LiveBlocker(action, guid)
    if not (action and action.executor == "petCommand" and action.command) then
        return nil
    end
    local record = self:Record(guid)
    updateRecovery(record, liveHealthRatio())
    if liveHealingChannel(guid) then
        return "companion recovery channel active"
    end
    if action.command == "attack" and record.recovering then
        return "companion is recovering"
    end
    if self:Pending(guid, action.command) then
        return "companion command awaiting acknowledgement"
    end
    if record.recovering and action.command == "follow"
        and record.followIssued then return "companion retreat already submitted" end
    if record.recovering and action.command == "passive"
        and record.passiveIssued then return "companion retreat already submitted" end
    return nil
end

C:Reset("session start")
