---@class MaxItemCountCondition : Condition
---@field inventoryManager InventoryManager
---@field itemID string
---@field count number

local MaxItemCountCondition = {
}
local MaxItemCountCondition_mt = {
    __index = MaxItemCountCondition,
}

---@return MaxItemCountCondition
function MaxItemCountCondition.new(inventoryManager, itemID, count)
    local self = setmetatable({}, MaxItemCountCondition_mt)
    self.inventoryManager = inventoryManager
    self.itemID = itemID
    self.count = count
    return self
end

function MaxItemCountCondition:evaluate(import)
    local items = self.inventoryManager:getItems()
    local count = 0
    if items[self.itemID] then
        count = items[self.itemID].count
    end
    if import then
        return self.count - count
    end
    return (count <= self.count and 64) or 0
end

return MaxItemCountCondition