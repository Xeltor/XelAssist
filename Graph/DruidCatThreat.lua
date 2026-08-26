-- Branch-local Cat Form all-school threat multiplier. Its value emerges only
-- through later player threat; entering Cat receives no flat action score.
XelAssist.Graph.DruidCatThreat = {}
local C = XelAssist.Graph.DruidCatThreat

local function finite(value)
    value = tonumber(value)
    if value == nil or value ~= value
        or value == math.huge or value == -math.huge then return nil end
    return value
end

local function copy(source)
    local out, key, value = {}, nil, nil
    for key, value in pairs(source or {}) do
        out[key] = type(value) == "table" and copy(value) or value
    end
    return out
end

local function runtime()
    return XelAssist.Game and XelAssist.Game.Player
        and XelAssist.Game.Player.DruidCatThreat
end

local function exactProfile(value)
    local owner = runtime()
    local multiplier = value and finite(value.multiplier)
    return owner and type(value) == "table" and value.valid == true
        and value.exact == true and value.passiveSpellId == owner.PASSIVE_ID
        and value.family == owner.DRUID_FAMILY
        and value.catForm == owner.CAT_FORM
        and value.schoolMask == owner.ALL_SCHOOLS
        and value.percent == owner.THREAT_PERCENT
        and multiplier == owner.THREAT_MULTIPLIER and value or nil
end

local function formID(state)
    local snapshot = state and state.druidFormState
    local value = snapshot and finite(snapshot.formID)
    if not (snapshot and snapshot.available == true and value
        and value >= 0 and value <= 32 and math.floor(value) == value) then
        return nil
    end
    local forms = XelAssist.Game and XelAssist.Game.Player
        and XelAssist.Game.Player.DruidFormState
    if not (forms and forms.FORMS and forms.FORMS[value]) then return nil end
    return value
end

local function sync(state, component)
    local owner = runtime()
    local profile = component and exactProfile(component.profile)
    local current = formID(state)
    if not (owner and profile and current ~= nil) then
        if component then
            component.available, component.exact = false, false
            component.reason = "Druid Cat threat form evidence unavailable"
        end
        return false
    end
    local active = owner:IsCatForm(current)
    component.available, component.exact = true, true
    component.formID, component.active = current, active
    component.multiplier = active and profile.multiplier or 1
    component.reason = nil
    return true
end

function C:Attach(state)
    if type(state) ~= "table" then return false end
    local owner = runtime()
    local profile = owner and owner:Snapshot() or nil
    local out = { available = false, exact = false,
        profile = profile and copy(profile) or nil,
        source = "exact Druid form and Cat threat passive profile" }
    state.druidCatThreat = out
    if not exactProfile(profile) then
        out.reason = profile and profile.reason
            or "Druid Cat threat profile unavailable"
        return false
    end
    return sync(state, out)
end

function C:Copy(source, target)
    if not (source and target and source.druidCatThreat) then return false end
    target.druidCatThreat = copy(source.druidCatThreat)
    return sync(target, target.druidCatThreat)
end

-- DruidForms applies and synchronizes the exact form transition first.
function C:AfterForm(state)
    local component = state and state.druidCatThreat
    if not component then return false end
    local changed = component.formID ~= formID(state)
    local ok = sync(state, component)
    if ok and changed then component.projected = true end
    return ok
end

-- Compose with earlier player-owned threat factors. Pets deliberately bypass
-- this player-form modifier.
function C:Resolve(state, actor, baseMultiplier, baseExact)
    baseMultiplier = finite(baseMultiplier)
    if actor ~= "player" or not baseMultiplier or baseMultiplier < 0 then
        return baseMultiplier, baseExact ~= false
    end
    local component = state and state.druidCatThreat
    if component == nil then return baseMultiplier, baseExact ~= false end
    local owner, current = runtime(), formID(state)
    local multiplier = component and finite(component.multiplier)
    local expected = owner and current ~= nil
        and (owner:IsCatForm(current) and owner.THREAT_MULTIPLIER or 1)
    if not (component.available == true and component.exact == true
        and exactProfile(component.profile) and current ~= nil
        and component.formID == current and multiplier and multiplier > 0
        and multiplier == expected) then
        return baseMultiplier, false, component
    end
    return baseMultiplier * multiplier, baseExact ~= false, component
end
