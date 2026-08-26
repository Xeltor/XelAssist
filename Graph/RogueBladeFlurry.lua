-- Blade Flurry's patch-5 server script chooses the duplicated weapon recipient.
-- The client exposes neither that choice nor a binding radius.  Withholding the
-- toggle is safer than treating it as direct damage or claiming aggregate AoE.
XelAssist.Graph.RogueBladeFlurry = {}
local B = XelAssist.Graph.RogueBladeFlurry

local function runtime()
    return XelAssist.Game and XelAssist.Game.Player
        and XelAssist.Game.Player.RogueBladeFlurry
end

function B:Prepare(action, _, _, facts)
    local owner = runtime()
    local found = owner and (owner:Evidence(facts) or owner:Evidence(action))
    if not found then
        return nil, "exact Blade Flurry evidence unavailable", true
    end
    if found.recipientSelectionObservable ~= false then
        return nil, "Blade Flurry recipient contract changed", true
    end
    return nil, "Blade Flurry nearby recipient is not observable", true
end

function B:Score() return false, "Blade Flurry consequence is withheld" end
function B:Apply() return false end
