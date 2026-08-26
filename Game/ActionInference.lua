-- Root-only dispatcher for exact action identity. Class mechanics run before
-- the localized catalogue; a recognized but incomplete mechanic therefore
-- cannot fall through to a generic damage, buff, or utility shape.
XelAssist.Game.ActionInference = {}
local I = XelAssist.Game.ActionInference

local function infer(module, spellId)
    if not (module and type(module.InferKnowledge) == "function") then
        return nil, nil, false
    end
    local facts, reason, handled = module:InferKnowledge(spellId)
    return facts, reason, handled == true
end

function I:ClassKnowledge(spellId)
    local player = XelAssist.Game.Player or {}
    local facts, reason, handled = infer(player.MageColdSnap, spellId)
    if handled then return facts, reason, true end
    facts, reason, handled = infer(player.MagePresenceOfMind, spellId)
    if handled then return facts, reason, true end
    facts, reason, handled = infer(player.MageManaShield, spellId)
    if handled then return facts, reason, true end
    facts, reason, handled = infer(player.PriestShield, spellId)
    if handled then return facts, reason, true end
    facts, reason, handled = infer(player.PriestShadowform, spellId)
    if handled then return facts, reason, true end
    facts, reason, handled = infer(player.PriestInnerFocus, spellId)
    if handled then return facts, reason, true end
    facts, reason, handled = infer(player.PriestPowerInfusion, spellId)
    if handled then return facts, reason, true end
    facts, reason, handled = infer(player.PriestFade, spellId)
    if handled then return facts, reason, true end
    facts, reason, handled = infer(player.DruidProwl, spellId)
    if handled then return facts, reason, true end
    facts, reason, handled = infer(player.RogueSliceAndDice, spellId)
    if handled then return facts, reason, true end
    facts, reason, handled = infer(player.RogueFeint, spellId)
    if handled then return facts, reason, true end
    facts, reason, handled = infer(player.HunterHawk, spellId)
    if handled then return facts, reason, true end
    facts, reason, handled = infer(player.HunterMark, spellId)
    if handled then return facts, reason, true end
    facts, reason, handled = infer(player.HunterDistractingShot, spellId)
    if handled then return facts, reason, true end
    facts, reason, handled = infer(player.WarriorThunderClap, spellId)
    if handled then return facts, reason, true end
    facts, reason, handled = infer(player.WarriorDemoralizingShout, spellId)
    if handled then return facts, reason, true end
    facts, reason, handled = infer(player.WarriorHeroicStrikeThreat, spellId)
    if handled then return facts, reason, true end
    facts, reason, handled = infer(player.WarriorRevengeThreat, spellId)
    if handled then return facts, reason, true end
    facts, reason, handled = infer(player.WarriorBattleShout, spellId)
    if handled then return facts, reason, true end
    facts, reason, handled = infer(player.WarriorShieldWall, spellId)
    if handled then return facts, reason, true end
    facts, reason, handled = infer(player.WarlockFelDomination, spellId)
    if handled then return facts, reason, true end
    facts, reason, handled = infer(player.WarlockDarkPact, spellId)
    if handled then return facts, reason, true end
    facts, reason, handled = infer(player.PaladinActions, spellId)
    if handled then
        if facts and player.PaladinMight then
            facts = player.PaladinMight:Promote(spellId, facts)
        end
        if facts and player.PaladinWisdom then
            facts = player.PaladinWisdom:Promote(spellId, facts)
        end
        if facts and player.PaladinBlessingThreat then
            facts = player.PaladinBlessingThreat:Promote(spellId, facts)
        end
        if facts and player.PaladinRighteousFury then
            facts = player.PaladinRighteousFury:Promote(spellId, facts)
        end
        return facts, reason, true
    end
    facts, reason, handled = infer(player.ShamanActions, spellId)
    if handled then
        if facts and player.ShamanWindfuryTotem then
            facts = player.ShamanWindfuryTotem:Promote(spellId, facts)
        end
        if facts and player.ShamanManaSpring then
            facts = player.ShamanManaSpring:Promote(spellId, facts)
        end
        return facts, reason, true
    end
    return nil, nil, false
end

function I:ExactKnowledge(spellId, skipClass)
    local facts, reason, handled
    if not skipClass then
        facts, reason, handled = self:ClassKnowledge(spellId)
        if handled then return facts, reason, true end
    end
    local player = XelAssist.Game.Player or {}
    facts, reason, handled = infer(player.WarriorRage, spellId)
    if handled then return facts, reason, true end
    local stances = XelAssist.Graph and XelAssist.Graph.WarriorStances
    facts, reason, handled = infer(stances, spellId)
    if handled then return facts, reason, true end
    local control = XelAssist.Game.CrowdControl
    facts, reason, handled = infer(control, spellId)
    if handled then return facts, reason, true end
    local forms = player.DruidFormState
    facts = forms and forms:InferKnowledge(spellId)
    facts = facts or XelAssist.Game.HealthTransfer
        and XelAssist.Game.HealthTransfer:InferDBC(spellId)
        or XelAssist.Game.ResourceExchange
            and XelAssist.Game.ResourceExchange:InferDBC(spellId)
    return facts, nil, facts ~= nil
end

function I:InvalidateClass()
    local player = XelAssist.Game.Player or {}
    if player.MageManaShield then player.MageManaShield:Invalidate() end
    if player.MageClearcasting then player.MageClearcasting:Invalidate() end
    if player.MagePresenceOfMind then
        player.MagePresenceOfMind:Invalidate()
    end
    if player.MageColdSnap then player.MageColdSnap:Invalidate() end
    if player.PriestShield then player.PriestShield:Invalidate() end
    if player.PriestShadowform then player.PriestShadowform:Invalidate() end
    if player.PriestInnerFocus then player.PriestInnerFocus:Invalidate() end
    if player.PriestPowerInfusion then
        player.PriestPowerInfusion:Invalidate()
    end
    if player.PriestFade then player.PriestFade:Invalidate() end
    if player.DruidProwl then player.DruidProwl:Invalidate() end
    if player.DruidClearcasting then player.DruidClearcasting:Invalidate() end
    if player.DruidBearThreat then player.DruidBearThreat:Invalidate() end
    if player.DruidCatThreat then player.DruidCatThreat:Invalidate() end
    if player.RogueSliceAndDice then player.RogueSliceAndDice:Invalidate() end
    if player.RogueRuthlessness then
        player.RogueRuthlessness:Invalidate()
    end
    if player.RogueFeint then player.RogueFeint:Invalidate() end
    if player.HunterMark then player.HunterMark:Invalidate() end
    if player.HunterHawk then player.HunterHawk:Invalidate() end
    if player.HunterDistractingShot then
        player.HunterDistractingShot:Invalidate()
    end
    if player.WarriorBattleShout then
        player.WarriorBattleShout:Invalidate()
    end
    if player.WarriorRevengeThreat then
        player.WarriorRevengeThreat:Invalidate()
    end
    if player.WarriorHeroicStrikeThreat then
        player.WarriorHeroicStrikeThreat:Invalidate()
    end
    if player.WarriorThunderClap then player.WarriorThunderClap:Invalidate() end
    if player.WarriorDemoralizingShout then
        player.WarriorDemoralizingShout:Invalidate()
    end
    if player.WarriorShieldWall then player.WarriorShieldWall:Invalidate() end
    if player.WarlockFelDomination then
        player.WarlockFelDomination:Invalidate()
    end
    if player.WarlockDarkPact then player.WarlockDarkPact:Invalidate() end
    if player.WarlockSoulLink then player.WarlockSoulLink:Invalidate() end
    if player.PaladinActions then player.PaladinActions:Invalidate() end
    if player.PaladinMight then player.PaladinMight:Invalidate() end
    if player.PaladinWisdom then player.PaladinWisdom:Invalidate() end
    if player.PaladinBlessingThreat then
        player.PaladinBlessingThreat:Invalidate()
    end
    if player.PaladinRighteousFury then
        player.PaladinRighteousFury:Invalidate()
    end
    if player.ShamanActions then player.ShamanActions:Invalidate() end
    if player.ShamanWindfuryTotem then
        player.ShamanWindfuryTotem:Invalidate()
    end
    if player.ShamanManaSpring then player.ShamanManaSpring:Invalidate() end
    if player.ShamanClearcasting then player.ShamanClearcasting:Invalidate() end
    local projection = XelAssist.Graph and XelAssist.Graph.PaladinAuraProjection
    if projection then projection:Invalidate() end
end
