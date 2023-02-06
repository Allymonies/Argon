---@class MinSlotCondition : ImportCondition
---@field minSlot number
local MinSlotCondition = {
}
local MinSlotCondition_mt = {
    __index = MinSlotCondition,
}

---@return MinSlotCondition
function MinSlotCondition.new(minSlot)
    local self = setmetatable({}, MinSlotCondition_mt)
    self.minSlot = minSlot
    return self
end

function MinSlotCondition:evaluate(slot, item)
    return (slot >= self.minSlot and 64) or 0
end

return MinSlotCondition