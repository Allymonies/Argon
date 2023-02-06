---@class MaxSlotCondition : ImportCondition
---@field maxSlot number
local MaxSlotCondition = {
}
local MaxSlotCondition_mt = {
    __index = MaxSlotCondition,
}

---@return MaxSlotCondition
function MaxSlotCondition.new(maxSlot)
    local self = setmetatable({}, MaxSlotCondition_mt)
    self.maxSlot = maxSlot
    return self
end

function MaxSlotCondition:evaluate(slot, item)
    return (slot <= self.maxSlot and 64) or 0
end

return MaxSlotCondition