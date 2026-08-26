-- Octo Frostfire Bolt selects the lower of the target's effective Fire and
-- Frost resistance.  Seal the exceptional installed-row identity at the root;
-- graph search may then choose a school from copied target evidence without
-- reading DBC or live units.
XelAssist.Game.Player.MageFrostfire = {}
local F = XelAssist.Game.Player.MageFrostfire

F.SPELL_ID = 45400
F.FIRE, F.FROST = 2, 4

local PROFILE

local function scalar(field)
    if type(GetSpellRecField) ~= "function" then return nil end
    local ok, value = pcall(GetSpellRecField, F.SPELL_ID, field)
    return ok and tonumber(value) or nil
end

local function triple(field, first, second, third)
    if type(GetSpellRecField) ~= "function" then return false end
    local ok, values = pcall(GetSpellRecField, F.SPELL_ID, field, 1)
    return ok and type(values) == "table" and table.getn(values) == 3
        and tonumber(values[1]) == first and tonumber(values[2]) == second
        and tonumber(values[3]) == third
end

local function profile()
    if PROFILE then return PROFILE.valid and PROFILE or nil, PROFILE.reason end
    PROFILE = { valid = false, exact = false, spellId = F.SPELL_ID,
        fireSchool = F.FIRE, frostSchool = F.FROST,
        policy = "lower-effective-resistance",
        source = "installed patch-5 Frostfire Bolt topology" }
    local duration
    if type(GetSpellDuration) == "function" then
        local ok, value = pcall(GetSpellDuration, F.SPELL_ID)
        if ok then duration = tonumber(value) end
    end
    if scalar("school") ~= F.FROST or scalar("attributes") ~= 65536
        or scalar("spellFamilyName") ~= 3
        or scalar("spellFamilyFlags") ~= 1073741857
        or not triple("effect", 2, 6, 0)
        or not triple("effectApplyAuraName", 0, 3, 0)
        or not triple("effectImplicitTargetA", 6, 6, 0)
        or not triple("effectAmplitude", 0, 2000, 0)
        or duration ~= 8000 then
        PROFILE.reason = "Frostfire Bolt DBC topology is incomplete"
        return nil, PROFILE.reason
    end
    PROFILE.valid, PROFILE.exact = true, true
    return PROFILE
end

local function copy(source)
    local out, key, value = {}, nil, nil
    for key, value in pairs(source or {}) do out[key] = value end
    return out
end

function F:CaptureFacts(action, facts)
    if not (action and tonumber(action.spellId) == self.SPELL_ID) then
        return facts
    end
    local out, found, reason = copy(facts), profile()
    if found then
        out.mageFrostfireResistance = copy(found)
    else
        out.mageFrostfireResistance = { exact = false,
            spellId = self.SPELL_ID, reason = reason }
    end
    return out
end

local function effective(snapshot, school)
    local raw = snapshot and snapshot.live and tonumber(snapshot.live[school])
    if raw == nil then return nil end
    local reduction = snapshot.projectedReduction
        and tonumber(snapshot.projectedReduction[school]) or 0
    if raw >= 0 then return math.max(0, raw - reduction) end
    return raw - reduction
end

-- Returns the resistance-lookup school, handled, source.  This is deliberately
-- separate from the spell's DBC damage school (Frost): target vulnerabilities
-- must not be reassigned merely because Octo checks another resistance lane.
-- A recognized but unprovable rule is handled with a nil lookup school.
function F:ResistanceSchool(action, state)
    local contract = action and action.facts
        and action.facts.mageFrostfireResistance
    if not contract then return nil, false end
    if tonumber(action.spellId) ~= self.SPELL_ID or contract.exact ~= true
        or contract.spellId ~= self.SPELL_ID
        or contract.fireSchool ~= self.FIRE
        or contract.frostSchool ~= self.FROST
        or contract.policy ~= "lower-effective-resistance" then
        return nil, true, "Frostfire resistance contract is incomplete"
    end
    local snapshot = state and state.targetResistance
    if not (snapshot and snapshot.liveTrusted == true) then
        return nil, true, "trusted target resistance unavailable"
    end
    local fire, frost = effective(snapshot, self.FIRE),
        effective(snapshot, self.FROST)
    if fire == nil or frost == nil then
        return nil, true, "Fire/Frost target resistance pair unavailable"
    end
    if fire < frost then
        return self.FIRE, true, "lower effective Fire resistance"
    end
    return self.FROST, true, fire == frost
        and "equal Fire/Frost resistance; DBC Frost fallback"
        or "lower effective Frost resistance"
end

function F:Invalidate() PROFILE = nil end
