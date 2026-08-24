-- Short-lived, target-scoped evidence learned from authoritative client events.
-- Absence of an event is unknown; only explicit outcomes create graph blockers.
XelAssistObservations = { immunity = {}, lineOfSight = {}, resistance = {} }
local O = XelAssistObservations

local function targetGUID()
    local exists, guid = UnitExists("target")
    if exists then return guid end
    return nil
end

local function key(guid, spell)
    if not guid or not spell then return nil end
    return guid .. ":" .. spell
end

function O:Submitted(action, target, tooltip)
    if not action or target ~= "target" then return end
    self.last = { name = action.name, target = targetGUID(), actor = action.actor or "player", at = GetTime(),
        school = tooltip and tooltip.school or nil }
end

function O:AddResistance(guid, school, weight)
    if not guid or not school or school == 0 then return end
    if not self.resistance[guid] then self.resistance[guid] = {} end
    local rec = self.resistance[guid][school] or { weight = 0 }
    local age = rec.at and math.max(0, GetTime() - rec.at) or 0
    rec.weight = math.max(0, rec.weight - age / 30) + (weight or 1)
    rec.at = GetTime()
    self.resistance[guid][school] = rec
end

function O:LiveResistances(unit)
    if not GetUnitField or not unit or not UnitExists(unit) then return nil end
    local ok, values = pcall(GetUnitField, unit, "resistances", 1)
    if ok and type(values) == "table" then return values end
    return nil
end

function O:CombatMessage(message)
    local last = self.last
    if not message or not last or not last.target or GetTime() - last.at > 5 then return nil end
    if not string.find(message, last.name, 1, true) then return nil end
    local lower = string.lower(message)
    if string.find(lower, "miss") then
        self.immunity[key(last.target, last.name)] = nil
        return "retry", last.target, last.name
    end
    if string.find(lower, "resist") then
        self.immunity[key(last.target, last.name)] = nil
        local full = string.find(lower, "was resisted") or string.find(lower, "resisted by")
        self:AddResistance(last.target, last.school, full and 1 or 0.5)
        return full and "retry" or "partial resist", last.target, last.name
    end
    if string.find(lower, "immune") then
        -- This proves only the observed attempt. A short expiry prevents a tap
        -- loop without inventing a permanent creature or school immunity.
        self.immunity[key(last.target, last.name)] = GetTime() + 8
        return "immune", last.target, last.name
    end
    return nil
end

function O:SpellMiss(spellId, guid, missInfo)
    if not spellId or not guid then return nil end
    local name = SpellInfo and SpellInfo(spellId) or nil
    local school
    if GetSpellRecField then
        local ok, value = pcall(GetSpellRecField, spellId, "school")
        if ok then school = value end
    end
    if missInfo == 2 then
        self:AddResistance(guid, school, 1)
        return "retry", guid, name
    end
    if missInfo == 7 or missInfo == 8 then
        local immuneKey = key(guid, name)
        if immuneKey then self.immunity[immuneKey] = GetTime() + 8 end
        return "immune", guid, name
    end
    if missInfo == 3 or missInfo == 4 or missInfo == 5 or missInfo == 6 then
        return "retry", guid, name
    end
    return nil, guid, name
end


function O:ResistanceMultiplier(action, target, tooltip, state)
    if target ~= "target" or not tooltip or not tooltip.school or tooltip.school == 0 then return 1 end
    local live = state and state.targetResistances
    local level = state and state.playerLevel
    local raw = live and live[tooltip.school + 1]
    if type(raw) == "number" and raw >= 0 and type(level) == "number" and level > 0 then
        -- Classic's exact partial-resist roll distribution is discrete. This is
        -- its level-scaled average mitigation, used for relative graph value.
        return math.max(0.25, 1 - math.min(0.75, raw / (level * 5))), "live resistance"
    end
    local guid = targetGUID()
    local rec = guid and self.resistance[guid] and self.resistance[guid][tooltip.school]
    if not rec then return 1 end
    local weight = math.max(0, rec.weight - math.max(0, GetTime() - rec.at) / 30)
    if weight <= 0 then return 1 end
    return math.max(0.35, 1 - weight * 0.15), "observed resistance"
end

function O:ErrorMessage(message)
    local last = self.last
    if not message or not last or not last.target or GetTime() - last.at > 3 then return nil end
    local lower = string.lower(message)
    local lineError = (SPELL_FAILED_LINE_OF_SIGHT and message == SPELL_FAILED_LINE_OF_SIGHT)
        or (ERR_LINE_OF_SIGHT and message == ERR_LINE_OF_SIGHT)
        or string.find(lower, "line of sight")
    if lineError then
        self.lineOfSight[last.target .. ":" .. (last.actor or "player")] = GetTime() + 1.5
        return "line of sight"
    end
    return nil
end

function O:Blocker(action, target)
    if target ~= "target" then return nil end
    local guid, now = targetGUID(), GetTime()
    if not guid then return nil end
    local immuneKey = key(guid, action and action.name)
    local immuneUntil = immuneKey and self.immunity[immuneKey]
    if immuneUntil then
        if immuneUntil > now then return "observed immunity" end
        self.immunity[immuneKey] = nil
    end
    local losKey = guid .. ":" .. ((action and action.actor) or "player")
    local losUntil = self.lineOfSight[losKey]
    if losUntil then
        if losUntil > now then return "line of sight" end
        self.lineOfSight[losKey] = nil
    end
    return nil
end

function O:ClearCurrent()
    self.last = nil
end
