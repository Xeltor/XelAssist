-- Short-lived blockers and exact combat outcomes. Long-lived target-school
-- estimates live in XelAssistResistance; absence of evidence remains unknown.
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
    if not action then return end
    if target ~= "target" then
        -- Generic UI errors do not identify their originating action. Once a
        -- friendly/self/off-target action is submitted, the previous hostile
        -- correlation is stale and must not receive its errors.
        self.last = nil
        return
    end
    if XelAssistResistance then
        XelAssistResistance:RememberUnit("target")
        local refresh = XelAssistCapabilities and XelAssistCapabilities.TargetHasDebuff
            and XelAssistCapabilities:TargetHasDebuff(action.name) or false
        XelAssistResistance:Submitted(action, targetGUID(), tooltip, refresh)
    end
    local school = tooltip and tooltip.school or nil
    if XelAssistResistance then school = XelAssistResistance:School(action, tooltip) end
    self.last = { name = action.name, target = targetGUID(), actor = action.actor or "player", at = GetTime(),
        school = school, spellId = action.spellId }
end

function O:AddResistance(guid, school, weight)
    if not guid or not school or school == 0 then return end
    if XelAssistResistance then
        local delivered = weight and weight >= 1 and 0 or 0.75
        XelAssistResistance:Observe(guid, self.last and self.last.spellId, school,
            delivered, delivered <= 0 and "resist" or "damage")
        return
    end
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
    if XelAssistResistance and XelAssistResistance:NumericEventsEnabled() then return nil end
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
        if XelAssistResistance then
            if XelAssistResistance:ShouldTrainChat(last.target, last.spellId) then
                local _, _, resisted = string.find(lower, "%((%d+) resisted%)")
                local _, _, damage = string.find(lower, "for (%d+)")
                local delivered = 0
                if not full then
                    resisted, damage = tonumber(resisted), tonumber(damage)
                    if resisted and damage and resisted + damage > 0 then
                        delivered = damage / (damage + resisted)
                    else delivered = 0.75 end
                end
                XelAssistResistance:Observe(last.target, last.spellId, last.school,
                    delivered, full and "resist" or "damage", nil, 0.25,
                    full and false or nil)
            end
        else
            self:AddResistance(last.target, last.school, full and 1 or 0.5)
        end
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

function O:SpellMiss(spellId, guid, missInfo, casterGuid)
    if not spellId or not guid then return nil end
    missInfo = tonumber(missInfo)
    local name = SpellInfo and SpellInfo(spellId) or nil
    local school
    if GetSpellRecField then
        local ok, value = pcall(GetSpellRecField, spellId, "school")
        if ok then school = value end
    end
    if XelAssistResistance and missInfo and missInfo >= 1 and missInfo <= 11 then
        XelAssistResistance:Miss(spellId, guid, missInfo, casterGuid)
    end
    if missInfo == 1 or missInfo == 2 then
        if not XelAssistResistance and missInfo == 2 then self:AddResistance(guid, school, 1) end
        return "retry", guid, name
    end
    if missInfo == 7 or missInfo == 8 then
        local immuneKey = key(guid, name)
        if immuneKey then self.immunity[immuneKey] = GetTime() + 8 end
        return "immune", guid, name
    end
    if missInfo == 3 or missInfo == 4 or missInfo == 5 or missInfo == 6
        or missInfo == 9 or missInfo == 10 or missInfo == 11 then
        return "retry", guid, name
    end
    return nil, guid, name
end

function O:SpellDamage(targetGuid, casterGuid, spellId, amount, mitigation, hitInfo, school, effectAura)
    if not XelAssistResistance then return nil end
    return XelAssistResistance:DamageEvent(targetGuid, casterGuid, spellId, amount,
        mitigation, hitInfo, school, effectAura)
end

function O:ResistanceMultiplier(action, target, tooltip, state)
    if XelAssistResistance then
        local estimate = XelAssistResistance:Estimate(action, target, tooltip, state)
        return estimate.multiplier, estimate.source, estimate
    end
    if target ~= "target" or not tooltip or not tooltip.school or tooltip.school == 0 then return 1 end
    local live = state and state.targetResistances
    local level = state and state.playerLevel
    local raw = live and live[tooltip.school + 1]
    if type(raw) == "number" and raw >= 0 and type(level) == "number" and level > 0 then
        -- Classic's exact partial-resist roll distribution is discrete. This is
        -- its level-scaled average mitigation, used for relative graph value.
        local ratio = math.min(1, raw / (math.max(20, level) * 5))
        local mitigation = 0.75 * ratio - (3 / 16) * math.max(0, ratio - 2 / 3)
        return 1 - mitigation, "live resistance"
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
