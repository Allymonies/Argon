---@class MinItemCountCondition : Condition
---@field inventoryManager InventoryManager
---@field itemID string
---@field count number

local MinItemCountCondition = {
}
local MinItemCountCondition_mt = {
    __index = MinItemCountCondition,
}

---@return MinItemCountCondition
function MinItemCountCondition.new(inventoryManager, itemID, count)
    local self = setmetatable({}, MinItemCountCondition_mt)
    self.inventoryManager = inventoryManager
    self.itemID = itemID
    self.count = count
    return self
end

function MinItemCountCondition:evaluate(import)
    local items = self.inventoryManager:getItems()
    local count = 0
    if items[self.itemID] then
        count = items[self.itemID].count
    end
    if not import then
        return count - self.count
    end
    return (count >= self.count and 64) or 0
end

return MinItemCountCondition