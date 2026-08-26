XelAssist = { Game = { Player = {} } }
table.getn = table.getn or function(value)
    local count = 0
    while value[count + 1] ~= nil do count = count + 1 end
    return count
end

local playerGUID, allyGUID = "paladin-guid", "ally-guid"
local playerClass, raceAfterQuery = "PALADIN", false
local records = {
    [20154] = { 10, 134217728 }, -- seal bit 27
    [20375] = { 10, 33554432 },  -- seal bit 25
    [21082] = { 10, 512 },       -- seal bit 9
    [19740] = { 10, 268435458 }, -- blessing bit 28 plus subtype bit
    [19742] = { 10, 268500992 }, -- blessing bit 28 plus subtype bit
    [1038] = { 10, 256 },        -- blessing bit 8
    [20271] = { 10, 8388608 },   -- Judgement bit 23
    [20287] = { 10, 68853694464 }, -- full Seal of Righteousness flags
    [25780] = { 10, 1 },         -- Righteous Fury bit 0
    [9999] = { 5, 134217728 },
    [9998] = { 10, 4294967296 },
    [9997] = { 10, 402653184 },  -- seal bit 27 plus blessing bit 28
}

GetSpellRecField = function(spellId, field)
    local row = records[spellId]
    if not row then error("missing") end
    if field == "spellFamilyName" then return row[1] end
    if field == "spellFamilyFlags" then return row[2] end
    error("unknown field")
end
UnitClass = function() return "Paladin", playerClass end
UnitExists = function(unit)
    if unit == "player" then return true, playerGUID end
    if unit == "party1" then
        return true, raceAfterQuery == true and "replacement-guid" or allyGUID
    end
    if unit == "party2" then return true, "other-paladin-guid" end
    if unit == "target" then return true, "enemy-guid" end
    return false, nil
end
UnitCanAssist = function(_, unit) return unit ~= "target" end

local playerAuras = {
    { name = "Seal", spellId = 20154, sourceUnit = "player",
        sourceGUID = playerGUID, duration = 30 },
    { name = "Might", spellId = 19740, sourceUnit = "player",
        sourceGUID = playerGUID, duration = 300 },
    { name = "Righteous Fury", spellId = 25780, sourceUnit = "player",
        sourceGUID = playerGUID },
}
local allyAuras = {
    { name = "Wisdom", spellId = 19742, sourceUnit = "player",
        sourceGUID = playerGUID, duration = 300 },
    { name = "Might", spellId = 19740, sourceUnit = "party2",
        sourceGUID = "other-paladin-guid", duration = 300 },
}
C_UnitAuras = { GetUnitAuras = function(unit)
    local list = unit == "player" and playerAuras or allyAuras
    if unit == "party1" and raceAfterQuery == "armed" then
        raceAfterQuery = true
    end
    return list
end }

dofile("Game/Player/PaladinAuraState.lua")
local Auras = XelAssist.Game.Player.PaladinAuraState

local seal = Auras:Classify(20154)
local command = Auras:Classify(20375)
local crusader = Auras:Classify(21082)
local blessing = Auras:Classify(19740)
local salvation = Auras:Classify(1038)
local judgement = Auras:Classify(20271)
local righteousness = Auras:Classify(20287)
assert(seal.kind == "seal" and command.kind == "seal"
    and crusader.kind == "seal" and blessing.kind == "blessing"
    and salvation.kind == "blessing" and judgement.kind == "judgement",
    "family flags must classify mechanics without localized names")
assert(righteousness.kind == "seal" and righteousness.flags == 134217728
    and righteousness.lowFlags == 134217728
    and righteousness.fullFlags == 68853694464,
    "full Righteousness flags must retain their exact value and low word")
assert(seal.exclusiveFamily == "paladinSeal"
    and seal.recipientRelation == "self"
    and blessing.exclusiveFamily == "paladinBlessingByCaster"
    and blessing.recipientRelation == "friendly"
    and judgement.recipientRelation == "hostile",
    "classification must expose exact exclusive-family and recipient contracts")
local _, conflict = Auras:Classify(9997)
assert(conflict == "Paladin DBC exclusive families conflict",
    "overlapping exclusive family evidence must fail closed")

local player = Auras:Observe("player", playerGUID)
assert(player.available and player.recipientRelation == "self"
    and player.activeSeal.spellId == 20154
    and player.blessingsByCaster[playerGUID].spellId == 19740
    and player.righteousFury.spellId == 25780,
    "own seal, blessing, and threat-mode aura must remain distinct")

local sealProjection, reason = Auras:PrepareSeal(
    { name = "Localized Seal", spellId = 20375 }, player)
assert(sealProjection and reason == nil
    and sealProjection.replacement.spellId == 20154
    and sealProjection.priority == nil and sealProjection.score == nil,
    "seal replacement must expose mechanics without assigning utility")
assert(Auras:ApplySeal(player, sealProjection)
    and player.activeSeal.spellId == 20375,
    "seal application must atomically replace the one self-seal family")
sealProjection, reason = Auras:PrepareSeal(
    { name = "Localized Seal", spellId = 20375 }, player)
assert(sealProjection == nil and reason == "same seal already active",
    "the same active seal must not be double cast")

local stalePlayer = Auras:Observe("player", playerGUID)
sealProjection = Auras:PrepareSeal({ spellId = 20375 }, stalePlayer)
stalePlayer.activeSeal = { spellId = 21082, sourceGUID = playerGUID }
assert(not Auras:ApplySeal(stalePlayer, sealProjection),
    "a seal-family change after preparation must reject the stale projection")

local ally = Auras:Observe("party1", allyGUID)
assert(ally.available and ally.recipientRelation == "party"
    and ally.blessingsByCaster[playerGUID].spellId == 19742
    and ally.blessingsByCaster["other-paladin-guid"].spellId == 19740,
    "different Paladins' blessings must coexist by exact caster GUID")
local blessingProjection
blessingProjection, reason = Auras:PrepareBlessing(
    { name = "Localized Blessing", spellId = 19740 }, ally)
assert(blessingProjection and reason == nil
    and blessingProjection.replacement.spellId == 19742,
    "a new own blessing must displace only the same-caster family")
assert(Auras:ApplyBlessing(ally, blessingProjection)
    and ally.blessingsByCaster[playerGUID].spellId == 19740
    and ally.blessingsByCaster["other-paladin-guid"].spellId == 19740,
    "own blessing replacement must preserve another Paladin's blessing")

local staleAlly = Auras:Observe("party1", allyGUID)
blessingProjection = Auras:PrepareBlessing({ spellId = 1038 }, staleAlly)
staleAlly.blessingsByCaster[playerGUID] = {
    spellId = 19740, sourceGUID = playerGUID }
assert(not Auras:ApplyBlessing(staleAlly, blessingProjection),
    "a blessing-family change after preparation must fail closed")

local target = { guid = "enemy-guid", relation = "hostile", exact = true }
local judgeProjection
judgeProjection, reason = Auras:PrepareJudgement(
    { name = "Localized Judgement", spellId = 20271 }, player, target, nil)
assert(judgeProjection == nil
    and reason == "seal-specific Judgement outcome unavailable",
    "Judgement must not invent a result from its script-effect row")
local outcome = { exact = true, representable = true,
    sourceSealSpellId = 20375, recipientGUID = "enemy-guid",
    recipientRelation = "hostile",
    effect = { exact = true, kind = "damage", spellId = 20966 } }
judgeProjection, reason = Auras:PrepareJudgement(
    { name = "Localized Judgement", spellId = 20271 }, player, target, outcome)
assert(judgeProjection and reason == nil and judgeProjection.consumesSeal
    and judgeProjection.sourceSeal.spellId == 20375,
    "a represented seal-specific outcome must bind exact seal and recipient")
assert(Auras:ApplyJudgement(player, judgeProjection)
    and player.activeSeal == nil
    and player.lastJudgement.targetGUID == "enemy-guid"
    and player.lastJudgement.downstreamPending,
    "Judgement must consume its seal while leaving downstream application to its hook")

judgeProjection, reason = Auras:PrepareJudgement(
    { spellId = 20271 }, player, target, outcome)
assert(judgeProjection == nil
    and reason == "Judgement requires an exact active own seal",
    "Judgement must require an exact active own seal")

player.activeSeal = { spellId = 20154, sourceGUID = playerGUID, exact = true }
outcome.sourceSealSpellId = 20375
judgeProjection, reason = Auras:PrepareJudgement(
    { spellId = 20271 }, player, target, outcome)
assert(judgeProjection == nil
    and reason == "seal-specific Judgement outcome unavailable",
    "seal-specific outcomes must not cross seal identity")
outcome.sourceSealSpellId = 20154
outcome.recipientGUID = "other-enemy"
judgeProjection, reason = Auras:PrepareJudgement(
    { spellId = 20271 }, player, target, outcome)
assert(judgeProjection == nil
    and reason == "seal-specific Judgement outcome unavailable",
    "Judgement outcome recipient races must fail closed")
outcome.recipientGUID = "enemy-guid"
outcome.effect.exact = false
judgeProjection, reason = Auras:PrepareJudgement(
    { spellId = 20271 }, player, target, outcome)
assert(judgeProjection == nil
    and reason == "seal-specific Judgement outcome unavailable",
    "unrepresentable downstream effects must fail closed")

local oldPlayerAuras = playerAuras
playerAuras = {
    { name = "Righteousness", spellId = 20287, sourceUnit = "player",
        sourceGUID = playerGUID, duration = 30 },
    oldPlayerAuras[2], oldPlayerAuras[3],
}
local fullFlagPlayer = Auras:Observe("player", playerGUID)
assert(fullFlagPlayer.available and fullFlagPlayer.activeSeal.spellId == 20287
    and fullFlagPlayer.activeSeal.classification.fullFlags == 68853694464,
    "live aura observation must retain a full Righteousness family value")
playerAuras = oldPlayerAuras
playerAuras = { oldPlayerAuras[1],
    { name = "Other Seal", spellId = 21082, sourceUnit = "player",
        sourceGUID = playerGUID } }
local incoherent = Auras:Observe("player", playerGUID)
assert(not incoherent.available
    and incoherent.reason == "multiple active seals are incoherent",
    "two live members of one exclusive seal family must fail closed")
playerAuras = oldPlayerAuras

raceAfterQuery = "armed"
local raced = Auras:Observe("party1", allyGUID)
assert(not raced.available
    and raced.reason == "Paladin aura recipient changed during observation",
    "recipient GUID races must fail closed across the aura query")
raceAfterQuery = false

local hostile = Auras:Observe("target", "enemy-guid")
assert(not hostile.available
    and hostile.reason == "Paladin aura recipient identity unavailable",
    "helpful aura state must reject a hostile recipient relation")
local highOnly, highReason, highRecognized = Auras:Classify(9998)
assert(highOnly and highOnly.kind == "other" and highOnly.flags == 0
    and highOnly.fullFlags == 4294967296 and highReason == nil
    and not highRecognized,
    "exact high-word flags without a modeled low family must remain unclaimed")

playerClass = "PRIEST"
local wrongClass = Auras:Observe("player", playerGUID)
assert(not wrongClass.available
    and wrongClass.reason == "player is not an exactly identified Paladin",
    "the Paladin model must reject other classes")

print("ok: exact Paladin exclusive-aura and Judgement lifecycle")
