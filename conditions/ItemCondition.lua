---@class ItemCondition : ImportCondition
---@field itemName string

local ItemCondition = {
}
local ItemCondition_mt = {
    __index = ItemCondition,
}

---@return ItemCondition
function ItemCondition.new(itemName)
    local self = setmetatable({}, ItemCondition_mt)
    self.itemName = itemName
    return self
end

function ItemCondition:evaluate(slot, item)
    return (item.name == self.itemName and 64) or 0
end

return ItemCondition