-- Atomic handoff between the continuously evaluated graph and one-input
-- execution. A physical input may consume one recent, complete publication;
-- it never starts graph work and cannot replay the same publication.
XelAssist.Core = XelAssist.Core or {}
XelAssist.Core.RecommendationSnapshot = {}
local S = XelAssist.Core.RecommendationSnapshot

S.MAX_AGE = 0.45

function S:Publish(plan, mode, errorText)
    self.generation = (self.generation or 0) + 1
    self.plan = plan
    self.mode = mode
    self.errorText = errorText
    -- Freshness starts when the live graph observation began, not when a
    -- potentially expensive search finally handed the plan to the UI.
    self.publishedAt = tonumber(plan and plan.observedAt) or GetTime()
    self.consumedGeneration = nil
    return self.generation
end

function S:Invalidate(reason)
    self.plan = nil
    self.errorText = reason
    self.mode = nil
    self.publishedAt = nil
    self.consumedGeneration = self.generation
end

function S:Acquire(mode)
    local generation = self.generation
    if not self.plan or not generation then
        return nil, self.errorText or "recommendation not ready"
    end
    if self.mode ~= mode then return nil, "recommendation mode changed" end
    if self.consumedGeneration == generation then
        return nil, "waiting for the next graph decision"
    end
    local age = GetTime() - (tonumber(self.publishedAt) or 0)
    if age < 0 or age > self.MAX_AGE then
        self:Invalidate("recommendation expired")
        return nil, "recommendation expired"
    end
    if type(self.plan) ~= "table" or type(self.plan.action) ~= "table" then
        self:Invalidate("recommendation incomplete")
        return nil, "recommendation incomplete"
    end
    self.consumedGeneration = generation
    return self.plan, nil
end
