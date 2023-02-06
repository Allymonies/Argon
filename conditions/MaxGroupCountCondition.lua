---@class MaxGroupCountCondition : Condition
---@field inventoryManager InventoryManager
---@field groupID string
---@field count number
local MaxGroupCountCondition = {
}
local MaxGroupCountCondition_mt = {
    __index = MaxGroupCountCondition,
}

---@return MaxGroupCountCondition
function MaxGroupCountCondition.new(inventoryManager, itemID, count)
    local self = setmetatable({}, MaxGroupCountCondition_mt)
    self.inventoryManager = inventoryManager
    self.itemID = itemID
    self.count = count
    return self
end

function MaxGroupCountCondition:evaluate(import)
    local count = 0
    if self.inventoryManager:getGroupItems()[self.groupID] then
        count = self.inventoryManager:getGroupItems()[self.groupID].count
    end
    if import then
        return self.count - count
    end
    return (count <= self.count and 64) or 0
end

return MaxGroupCountCondition