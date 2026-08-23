XelAssist = { version = "0.2.0", mode = "smart" }
local XA = XelAssist

local EXTRA_ALLOW = { ["Nature's Swiftness"] = true, ["Cold Blood"] = true,
    ["Adrenaline Rush"] = true, ["Inner Focus"] = true }

local function msg(text, r, g, b)
    DEFAULT_CHAT_FRAME:AddMessage("XelAssist: " .. text, r or 0.35, g or 0.85, b or 1)
end

function XA:Init()
    if type(XelAssistDB.ui) ~= "table" then XelAssistDB.ui = {} end
    if type(XelAssistCharDB.toggles) ~= "table" then
        XelAssistCharDB.toggles = { cooldowns = false, consumables = false, reagents = false }
    end
    if XelAssistCharDB.mode then self.mode = XelAssistCharDB.mode end
    XelAssistCharDB.fallback = nil
    XelAssistCharDB.schema = 2
    self:CheckDependencies()
    XelAssistUI:Build()
end

function XA:CheckDependencies()
    local missing = {}
    if not SpellInfo or not SUPERWOW_VERSION then table.insert(missing, "SuperWoW") end
    if not IsAddOnLoaded or not IsAddOnLoaded("SuperAPI") then table.insert(missing, "SuperAPI") end
    if not QueueSpellByName then table.insert(missing, "Nampower") end
    self.missing = missing
    self.executionEnabled = table.getn(missing) == 0
    if not self.executionEnabled then msg("execution disabled; missing " .. table.concat(missing, ", ") .. ".", 1, 0.25, 0.2) end
end

function XA:Fallback(reason)
    self.lastReason = "Conservative hold — " .. reason
    msg(self.lastReason .. ".", 1, 0.65, 0.2)
end

function XA:Execute(mode)
    if not self.executionEnabled then self:CheckDependencies(); if not self.executionEnabled then return end end
    local selected = mode or self.mode
    local ok, plan, err, fallback = pcall(function()
        local p, e, f = XelAssistGraph:Evaluate(selected, false)
        return p, e, f
    end)
    if not ok then self:Fallback("evaluation error"); return end
    if fallback then self:Fallback(err or "incomplete data"); return end
    if not plan then msg(err or "no legal action"); return end
    local a = plan.action
    if a.extra then
        if EXTRA_ALLOW[a[1]] then CastSpellByName(a[1]) end
    elseif a.ground then
        CastSpellByName(a[1], "CLICK")
    elseif plan.target then
        CastSpellByName(a[1], plan.target)
    elseif QueueSpellByName then
        QueueSpellByName(a[1])
    else
        CastSpellByName(a[1])
    end
    self.lastReason = a[1] .. " — " .. plan.reason
    XelAssistUI:Refresh(true)
end

function XA:SetMode(mode)
    self.mode = mode; XelAssistCharDB.mode = mode
    msg("mode set to " .. mode .. ".")
    XelAssistUI:Refresh(true)
end

function XA:Command(text)
    local cmd, arg = string.gsub(text or "", "^%s*(%S*)%s*(.-)%s*$", "%1"), nil
    local p = string.find(text or "", "%s")
    if p then arg = string.gsub(string.sub(text, p + 1), "^%s*(.-)%s*$", "%1") end
    if cmd == "" or cmd == "execute" then self:Execute(); return end
    if cmd == "why" then msg(self.lastReason or XelAssistUI.lastReason or "no decision yet."); return end
    if cmd == "smart" or cmd == "single" or cmd == "aoe" or cmd == "support" then self:SetMode(cmd); return end
    if cmd == "cooldowns" or cmd == "consumables" or cmd == "reagents" then
        local current = XelAssistCharDB.toggles[cmd]
        XelAssistCharDB.toggles[cmd] = not current
        msg(cmd .. " " .. (not current and "enabled" or "disabled") .. ".")
        return
    end
    if cmd == "diagnostics" then
        msg("mode=" .. self.mode .. ", execution=" .. (self.executionEnabled and "ready" or "disabled")
            .. ", fallback=conservative hold, schema=2.")
        return
    end
    if cmd == "show" then XelAssistUI.frame:Show(); return end
    if cmd == "hide" then XelAssistUI.frame:Hide(); return end
    msg("commands: execute, why, smart, single, aoe, support, buffs, cooldowns, consumables, reagents, diagnostics, show, hide")
end

SLASH_XELASSIST1 = "/xassist"
SLASH_XELASSIST2 = "/xa"
SlashCmdList["XELASSIST"] = function(text) XA:Command(text) end

local ev = CreateFrame("Frame")
ev:RegisterEvent("ADDON_LOADED")
ev:RegisterEvent("PLAYER_LOGIN")
if SpellInfo then ev:RegisterEvent("UNIT_CASTEVENT") end
ev:SetScript("OnEvent", function()
    if event == "ADDON_LOADED" and arg1 == "XelAssist" then XA:Init() end
    if event == "PLAYER_LOGIN" then msg("v" .. XA.version .. " loaded. Bind XelAssist: Smart Execute or click the action button.") end
    if event == "UNIT_CASTEVENT" then
        local _, targetGUID = UnitExists("target")
        local _, playerGUID = UnitExists("player")
        if targetGUID and arg1 == targetGUID then
            if arg3 == "START" or arg3 == "CHANNEL" then
                XA.targetCastUntil = GetTime() + ((arg5 or 1500) / 1000)
            elseif arg3 == "CAST" or arg3 == "FAIL" then XA.targetCastUntil = nil end
        end
        if playerGUID and arg1 == playerGUID then
            if arg3 == "START" or arg3 == "CHANNEL" then
                XA.playerCastUntil = GetTime() + ((arg5 or 1500) / 1000)
                XA.playerCastName = SpellInfo and SpellInfo(arg4) or nil
            elseif arg3 == "CAST" or arg3 == "FAIL" then
                XA.playerCastUntil = nil; XA.playerCastName = nil
            end
        end
    end
end)
