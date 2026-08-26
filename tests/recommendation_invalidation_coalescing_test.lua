XelAssist = { Core = {}, UI = {} }

local clock = 0
GetTime = function() return clock end

XelAssist.mode = "smart"
XelAssist.Core.RecommendationSnapshot = {
    invalidations = 0,
    Invalidate = function(self, reason)
        self.invalidations = self.invalidations + 1
        self.reason = reason
    end,
}

dofile("UI/RecommendationController.lua")
local Controller = XelAssist.UI.RecommendationController
local Snapshot = XelAssist.Core.RecommendationSnapshot

local updates = 0
local owner = {
    SetUpdating = function() updates = updates + 1 end,
}

assert(Controller:Invalidate(owner, "target died") == true
    and Snapshot.invalidations == 1 and updates == 1
    and owner.refreshRequested and owner.forceRequested,
    "the first terminal event must invalidate and request immediate work")

assert(Controller:Invalidate(owner, "target health reached zero") == false
    and Snapshot.invalidations == 1 and updates == 1,
    "a same-frame terminal burst must not retire or repaint twice")

Controller.Begin = function(self, target)
    target.invalidationPending = nil
    target.activeEvaluation = { session = {}, mode = "smart" }
    return true
end
owner.refreshRequested, owner.forceRequested = nil, nil
Controller:Begin(owner, true, "smart")

XelAssist.Graph = {
    CancelEvaluation = function(_, session, reason)
        session.cancelled, session.reason = true, reason
    end,
}
assert(Controller:Invalidate(owner, "new target victim") == true
    and Snapshot.invalidations == 2 and updates == 2
    and owner.activeEvaluation == nil,
    "a later state transition must cancel real work and invalidate anew")

assert(Controller:Invalidate(owner, "duplicate victim event") == false
    and Snapshot.invalidations == 2 and updates == 2,
    "the later transition must also coalesce until its replacement begins")

print("ok: pending recommendation invalidations coalesce per replacement")
