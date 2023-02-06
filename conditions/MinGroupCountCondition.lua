---@class MinGroupCountCondition : Condition
---@field inventoryManager InventoryManager
---@field groupID string
---@field count number
local MinGroupCountCondition = {
}
local MinGroupCountCondition_mt = {
    __index = MinGroupCountCondition,
}

---@return MinGroupCountCondition
function MinGroupCountCondition.new(inventoryManager, itemID, count)
    local self = setmetatable({}, MinGroupCountCondition_mt)
    self.inventoryManager = inventoryManager
    self.itemID = itemID
    self.count = count
    return self
end

function MinGroupCountCondition:evaluate(import)
    local count = 0
    if self.inventoryManager:getGroupItems()[self.groupID] then
        count = self.inventoryManager:getGroupItems()[self.groupID].count
    end
    if not import then
        return count - self.count
    end
    return (count >= self.count and 64) or 0
end

return MinGroupCountCondition