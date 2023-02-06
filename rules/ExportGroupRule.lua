---@class ExportGroupRule : Rule
---@field itemManager ItemManager
---@field inventory string
---@field group table
---@field slot number?
---@field conditions Condition[]
local ExportGroupRule = {
}
local ExportGroupRule_mt = {
    __index = ExportGroupRule,
}

---@return ExportGroupRule
function ExportGroupRule.new(inventory, group, slot, conditions, itemManager)
    local self = setmetatable({}, ExportGroupRule_mt)
    self.fails = 0
    self.itemManager = itemManager
    self.inventory = inventory
    self.group = group
    self.slot = slot
    self.conditions = conditions
    return self
end

function ExportGroupRule:evaluate()
    local didExport = false
    local maxCount = 64
    for _, condition in ipairs(self.conditions) do
        maxCount = math.min(maxCount, condition:evaluate(false))
        if maxCount == 0 then
            break
        end
    end
    if maxCount > 0 then
        local amt = self.itemManager:withdrawGroup(self.group, self.inventory, self.slot, maxCount)
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

return ExportGroupRule