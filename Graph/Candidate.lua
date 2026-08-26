-- Immutable projection of a scored working context into a searchable action
-- edge. Keeping this serialization separate prevents the scoring orchestrator
-- from accumulating ownership, targeting, timeline, and UI transport fields.
XelAssist.Graph.Candidate = {}
local C = XelAssist.Graph.Candidate

local function formID(value)
    if type(value) ~= "number" or value ~= value or value < 0
        or value > 32 or math.floor(value) ~= value then return nil end
    return value
end

local function formMask(value)
    if type(value) ~= "number" or value ~= value or value < 0
        or value > 4294967295 or math.floor(value) ~= value then return nil end
    return value
end

local function consumerKey(context)
    local value = context.setupConsumerKey
    if value == nil and context.tooltip then
        value = context.tooltip.setupConsumerKey
    end
    if value == nil and context.facts then
        value = context.facts.setupConsumerKey
    end
    local priest = XelAssist.Graph.PriestInnerFocus
    if value == nil and priest then
        value = priest:ConsumerKey(context.tooltip)
            or priest:ConsumerKey(context.facts)
    end
    local presence = XelAssist.Graph.MagePresenceOfMind
    if value == nil and presence then
        value = presence:ConsumerKey(context.tooltip)
            or presence:ConsumerKey(context.facts)
    end
    local powerInfusion = XelAssist.Graph.PriestPowerInfusion
    if value == nil and powerInfusion then
        value = powerInfusion:ConsumerKey(context.tooltip)
            or powerInfusion:ConsumerKey(context.facts)
    end
    local manaSpring = XelAssist.Graph.ShamanManaSpring
    if value == nil and manaSpring then
        value = manaSpring:ConsumerKey(context.tooltip)
            or manaSpring:ConsumerKey(context.facts)
    end
    local wisdom = XelAssist.Graph.PaladinWisdom
    if value == nil and wisdom then
        value = wisdom:ConsumerKey(context.tooltip)
            or wisdom:ConsumerKey(context.facts)
    end
    local coldSnap = XelAssist.Graph.MageColdSnap
    if value == nil and coldSnap then
        value = coldSnap:ConsumerKey(
            context.state, context.action, context.tooltip)
    end
    local felDomination = XelAssist.Graph.WarlockFelDomination
    if value == nil and felDomination then
        value = felDomination:ConsumerKey(context.tooltip)
            or felDomination:ConsumerKey(context.facts)
    end
    if type(value) ~= "string" or value == ""
        or string.len(value) > 128 then return nil end
    return value
end

-- A strategic setup identity is mechanical and locale-independent. Include
-- both ends of the edge so distinct graph transitions never share a lane.
local function strategicSetup(tooltip)
    local innerFocus = XelAssist.Graph.PriestInnerFocus
        and XelAssist.Graph.PriestInnerFocus:StrategicSetup(tooltip)
    local presence = XelAssist.Graph.MagePresenceOfMind
        and XelAssist.Graph.MagePresenceOfMind:StrategicSetup(tooltip)
    local powerInfusion = XelAssist.Graph.PriestPowerInfusion
        and XelAssist.Graph.PriestPowerInfusion:StrategicSetup(tooltip)
    local manaSpring = XelAssist.Graph.ShamanManaSpring
        and XelAssist.Graph.ShamanManaSpring:StrategicSetup(tooltip)
    local wisdom = XelAssist.Graph.PaladinWisdom
        and XelAssist.Graph.PaladinWisdom:StrategicSetup(tooltip)
    local coldSnap = XelAssist.Graph.MageColdSnap
        and XelAssist.Graph.MageColdSnap:StrategicSetup(tooltip)
    local felDomination = XelAssist.Graph.WarlockFelDomination
        and XelAssist.Graph.WarlockFelDomination:StrategicSetup(tooltip)
    local warrior = tooltip and tooltip.warriorStanceTransition
    local druid = tooltip and tooltip.druidFormTransition
    local priest = tooltip and tooltip.priestShadowformTransition
    local selected, count = nil, 0
    local function include(value)
        if value then selected, count = value, count + 1 end
    end
    include(innerFocus); include(presence); include(powerInfusion)
    include(manaSpring); include(wisdom); include(coldSnap)
    include(felDomination)
    include(warrior)
    include(druid); include(priest)
    if count ~= 1 then return nil end
    if selected == innerFocus or selected == presence
        or selected == powerInfusion or selected == manaSpring
        or selected == wisdom
        or selected == coldSnap or selected == felDomination then
        return selected
    end
    local transition, prefix = warrior or druid or priest,
        warrior and "warriorStance" or druid and "druidForm"
            or priest and "priestShadowform" or nil
    if not transition then return nil end
    if warrior and transition.kind ~= "warriorStance" then return nil end
    if druid and transition.kind ~= "shift"
        and transition.kind ~= "cancel" then return nil end
    if priest and transition.kind ~= "priestShadowform" then return nil end
    local source, target = formID(transition.sourceForm),
        formID(transition.targetForm)
    if source == nil or target == nil or source == target then return nil end
    return { key = prefix .. ":" .. tostring(source) .. ">" .. tostring(target),
        source = source, target = target,
        consumerKey = "playerForm:" .. tostring(target) }
end

function C:Build(context)
    local descriptor, facts = context.descriptor, context.facts
    local setup = strategicSetup(context.tooltip)
    return {
        action = context.action, value = context.value, reason = context.reason,
        effectAction = context.effectAction, effectTooltip = context.effectTooltip,
        target = context.target, targetKey = descriptor and descriptor.key,
        targetGUID = descriptor and descriptor.guid,
        targetRelation = descriptor and descriptor.relation,
        targetSource = descriptor and descriptor.source,
        targetRef = descriptor and descriptor.targetRef,
        castTarget = descriptor and descriptor.castUnit,
        castTargetGUID = descriptor and descriptor.castGuid,
        castTargetRelation = descriptor and descriptor.castRelation,
        castTargetSource = descriptor and descriptor.castSource,
        castTargetRef = descriptor and descriptor.castTargetRef,
        targetPriority = descriptor and descriptor.record
            and descriptor.record.priority,
        cost = context.cost, costKnown = context.costKnown,
        cast = context.cast, downtime = context.advanceDowntime,
        valueDowntime = context.downtime,
        threat = context.threat, estimated = context.estimated,
        rogueFeintExpectedThreatReduction =
            context.rogueFeintExpectedThreatReduction,
        playerThreatExact = context.playerThreatExact,
        playerThreatMultiplier = context.playerThreatMultiplier,
        druidFormTransition = context.tooltip
            and context.tooltip.druidFormTransition,
        warriorStanceTransition = context.tooltip
            and context.tooltip.warriorStanceTransition,
        warriorDemoralizingShoutPackets = context.warriorDemoralizingShoutPackets,
        priestShadowformTransition = context.tooltip
            and context.tooltip.priestShadowformTransition,
        classMechanicProjection = context.classMechanicProjection,
        strategicSetup = setup and true or nil,
        strategicSetupKey = setup and setup.key,
        strategicSetupSourceForm = setup and setup.source,
        strategicSetupTargetForm = setup and setup.target,
        strategicSetupConsumerKey = setup and setup.consumerKey,
        setupConsumerKey = consumerKey(context),
        setupAllowedForms = formMask(context.tooltip
            and context.tooltip.stances),
        setupExcludedForms = formMask(context.tooltip
            and context.tooltip.stancesNot),
        tooltip = context.tooltip, power = context.expectedPower,
        powerEvidence = context.powerEvidence,
        survival = context.survival,
        comboAvailability = context.comboAvailability,
        comboEfficiencyPenalty = context.comboEfficiencyPenalty,
        comboTargetGUID = context.comboTargetGUID,
        comboAllOwners = context.comboAllOwners,
        effectivePower = context.effectivePower, rawPower = context.power,
        supportAoeUnknown = facts.aoe and context.friendlySupport and true or false,
        resistance = context.resistance, effectDelivery = context.effectDelivery,
        dotRawDirectPower = context.dotRawDirectPower,
        dotRawPeriodicPower = context.dotRawPeriodicPower,
        dotPeriodicExpectedPower = context.dotPeriodicExpectedPower,
        wait = context.wait, occupancy = context.occupancy,
        gcd = context.gcd, normalGcd = context.normalGcd,
        actionStart = context.actionStart,
        clipsChannel = XelAssist.Graph.ChannelCommitment
            and context.clipsChannel and true or false,
        preservesChannel = context.preservesChannel and true or false,
        channelCommitment = (context.clipsChannel or context.preservesChannel)
            and context.state.channelCommitment or nil,
        channelOpportunityValue = context.channelOpportunityValue,
        healthTransfer = context.healthTransfer,
        healingTriage = context.healingTriage,
        recipientEffects = context.recipientEffects,
        areaRecipientGroups = context.areaRecipientGroups,
        areaUnknowns = context.areaUnknowns,
        areaRecipientsUnknown = context.areaRecipientsUnknown,
        areaDirectResolved = context.areaDirectResolved,
        areaSelectedIncluded = context.areaSelectedIncluded,
        totalExpectedPower = context.totalExpectedPower,
        totalEffectivePower = context.totalEffectivePower,
        collateralExpectedPower = context.collateralExpectedPower,
        companionUnknowns = context.companionUnknowns,
        onNextSwing = context.onNextSwing,
        impactDelay = context.impactDelay,
        displacedWhitePower = context.displacedWhitePower,
        marginalPower = context.marginalPower,
        marginalEffectivePower = context.marginalEffectivePower,
        playerSwingUnknowns = context.playerSwingUnknowns,
        startsPlayerAttack = context.startsPlayerAttack,
        resourceGain = context.resourceGain,
        resourceGainSource = context.resourceGainSource,
        soulShardOpportunity = context.soulShardOpportunity,
        soulShardStockValue = context.soulShardStockValue,
        soulShardStockCost = context.soulShardStockCost,
        soulShardOvercapPenalty = context.soulShardOvercapPenalty,
        confidence = descriptor and descriptor.projectionOpen
            and "partial data" or nil,
        spatialConditions = descriptor and descriptor.spatialConditions,
        spatialConditionFingerprint = descriptor
            and descriptor.spatialConditionFingerprint,
        spatialConditionalOnly = descriptor
            and descriptor.spatialConditionalOnly,
    }
end
