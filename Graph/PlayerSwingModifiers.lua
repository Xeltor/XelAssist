-- Ordered composition of independent, exact player melee-clock modifiers.
-- Each owner receives the prior interval and may alter only a future reset.
XelAssist.Graph.PlayerSwingModifiers = {}
local M = XelAssist.Graph.PlayerSwingModifiers

function M:IntervalAfter(state, hand, offset, fallback)
    local interval = fallback
    local rapid = XelAssist.Graph.HunterRapidFire
    if state.classMechanicClass == "HUNTER" and rapid then
        interval = rapid:MeleeIntervalAfter(state, hand, offset, interval)
    end
    local slice = XelAssist.Graph.RogueSliceAndDice
    if slice then interval = slice:IntervalAfter(state, hand, offset, interval) end
    local blood = XelAssist.Graph.DruidBloodFrenzy
    if blood then interval = blood:IntervalAfter(state, hand, offset, interval) end
    local overpower = XelAssist.Graph.WarriorOverpoweringRage
    if overpower then
        interval = overpower:IntervalAfter(state, hand, offset, interval)
    end
    local barkskin = XelAssist.Graph.DruidBarkskin
    if barkskin then interval = barkskin:MeleeInterval(state, interval) end
    return interval
end
