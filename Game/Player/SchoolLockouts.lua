-- Exact local-player school lockouts exposed by ClassicAPI's reconstruction of
-- the server SMSG_SPELL_COOLDOWN packet. The interrupting spell is unknowable,
-- but the affected school mask and remaining duration are authoritative.
XelAssist.Game.Player.SchoolLockouts = {}
local L = XelAssist.Game.Player.SchoolLockouts

L.MAX_EFFECTS = 32
L.ALL_SCHOOLS = 127

local function integer(value, minimum, maximum)
    value = tonumber(value)
    if not value or value ~= math.floor(value)
        or value < minimum or value > maximum then return nil end
    return value
end

local function finite(value, minimum, maximum)
    value = tonumber(value)
    if not value or value ~= value or value < minimum or value > maximum then
        return nil
    end
    return value
end

local function api()
    local owner = C_LossOfControl
    if type(owner) ~= "table"
        or type(owner.GetActiveLossOfControlDataCount) ~= "function"
        or type(owner.GetActiveLossOfControlData) ~= "function" then
        return nil
    end
    return owner
end

function L:Snapshot()
    local owner = api()
    if not owner then
        return { available = false, exact = false,
            reason = "ClassicAPI loss-of-control evidence unavailable",
            order = {}, byMask = {} }
    end
    local ok, count = pcall(owner.GetActiveLossOfControlDataCount)
    count = ok and integer(count, 0, self.MAX_EFFECTS) or nil
    if count == nil then
        return { available = true, exact = false,
            reason = "loss-of-control count is malformed",
            order = {}, byMask = {} }
    end
    local out = { available = true, exact = true, order = {}, byMask = {} }
    local index
    for index = 1, count do
        local read, entry = pcall(owner.GetActiveLossOfControlData, index)
        if not read or type(entry) ~= "table" then
            out.exact, out.reason = false,
                "loss-of-control entry is unavailable"
            return out
        end
        if entry.locType == "SCHOOL_INTERRUPT" then
            local mask = integer(entry.lockoutSchool, 1, self.ALL_SCHOOLS)
            local remaining = finite(entry.timeRemaining, 0, 3600)
            local duration = finite(entry.duration, 0, 3600)
            if not mask or not remaining or not duration
                or remaining > duration + 0.1 then
                out.exact, out.reason = false,
                    "school-lockout evidence is malformed"
                return out
            end
            local prior = out.byMask[mask]
            if not prior then
                prior = { schoolMask = mask, remaining = remaining,
                    duration = duration, exact = true,
                    source = "ClassicAPI server cooldown packet" }
                out.byMask[mask] = prior
                table.insert(out.order, mask)
            elseif remaining > prior.remaining then
                prior.remaining, prior.duration = remaining, duration
            end
        end
    end
    return out
end

local function hasFlag(mask, flag)
    return math.floor(mask / flag) - math.floor(mask / (flag * 2)) * 2 == 1
end

function L:Blocker(state, action, tooltip, actionStart)
    if not (action and (action.actor or "player") == "player"
        and action.executor == "playerSpell") then return nil, false end
    local snapshot = state and state.playerSchoolLockouts
    if not (snapshot and snapshot.available == true) then return nil, false end
    if snapshot.exact ~= true then
        return "school lockout evidence unknown", true
    end
    local active = false
    local index
    for index = 1, table.getn(snapshot.order or {}) do
        local entry = snapshot.byMask and snapshot.byMask[snapshot.order[index]]
        if entry and entry.exact == true
            and (tonumber(entry.remaining) or 0) > (tonumber(actionStart) or 0) then
            active = true
            local school = integer(tooltip and tooltip.school, 0, 6)
            if school == nil then
                return "spell school unknown during lockout", true
            end
            if hasFlag(entry.schoolMask, 2 ^ school) then
                return "spell school locked", true
            end
        end
    end
    return nil, active
end
