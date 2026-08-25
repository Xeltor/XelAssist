-- Exact equipped hit supplied by ClassicAPI. Talent and temporary aura hit
-- remain separate explicit gaps; a proven equipment contribution is still a
-- useful lower-bound input and gets its own delivery-evidence fingerprint.
XelAssist.Game.HitBonuses = {}
local H = XelAssist.Game.HitBonuses

local function clamp(value)
    return math.max(0, tonumber(value) or 0)
end

function H:Invalidate()
    self.cached, self.cachedAt = nil, nil
end

function H:Snapshot()
    local now = GetTime and GetTime() or 0
    if self.cached and self.cachedAt == now then return self.cached end
    local out = { melee = 0, ranged = 0, spell = 0,
        equipmentKnown = false, totalKnown = false,
        source = "equipped hit unavailable",
        gap = "equipment, talent and aura +hit" }
    if C_PlayerInfo
        and type(C_PlayerInfo.GetEquippedHitBonuses) == "function" then
        local ok, melee, ranged, spell, equipped = pcall(
            C_PlayerInfo.GetEquippedHitBonuses)
        if ok and tonumber(melee) and tonumber(ranged) and tonumber(spell) then
            out.melee, out.ranged, out.spell = clamp(melee), clamp(ranged), clamp(spell)
            out.equipped = math.max(0, tonumber(equipped) or 0)
            out.equipmentKnown = true
            out.source = "ClassicAPI equipped item and enchant hit"
            out.gap = "talent and aura +hit"
        end
    end
    self.cached, self.cachedAt = out, now
    return out
end
