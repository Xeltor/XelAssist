-- Immutable projection of a scored working context into a searchable action
-- edge. Keeping this serialization separate prevents the scoring orchestrator
-- from accumulating ownership, targeting, timeline, and UI transport fields.
XelAssist.Graph.Candidate = {}
local C = XelAssist.Graph.Candidate

function C:Build(context)
    local descriptor, facts = context.descriptor, context.facts
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
        playerThreatExact = context.playerThreatExact,
        playerThreatMultiplier = context.playerThreatMultiplier,
        druidFormTransition = context.tooltip
            and context.tooltip.druidFormTransition,
        tooltip = context.tooltip, power = context.expectedPower,
        powerEvidence = context.powerEvidence,
        survival = context.survival,
        comboAvailability = context.comboAvailability,
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
