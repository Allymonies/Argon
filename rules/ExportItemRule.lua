---@class ExportItemRule : Rule
---@field itemManager ItemManager
---@field inventory string
---@field itemID string
---@field slot number?
---@field conditions Condition[]
local ExportItemRule = {
}
local ExportItemRule_mt = {
    __index = ExportItemRule,
}

---@return ExportItemRule
function ExportItemRule.new(inventory, itemID, slot, conditions, itemManager)
    local self = setmetatable({}, ExportItemRule_mt)
    self.fails = 0
    self.itemManager = itemManager
    self.inventory = inventory
    self.itemID = itemID
    self.slot = slot
    self.conditions = conditions
    return self
end

function ExportItemRule:evaluate()
    local didExport = false
    local maxCount = 64
    for _, condition in ipairs(self.conditions) do
        maxCount = math.min(maxCount, condition:evaluate(false))
        if maxCount == 0 then
            break
        end
    end
    if maxCount > 0 then
        local amt = self.itemManager:withdraw(self.itemID, self.inventory, self.slot, maxCount)
        if amt > 0 then
            didExport = true
        end
        if not didExport then
            self.fails = self.fails + 1
        else
            self.fails = 0
        end
    end
    return didExport
end

return ExportItemRule