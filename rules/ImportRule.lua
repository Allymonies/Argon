---@class ImportRule : Rule
---@field itemManager ItemManager
---@field inventory string
---@field importConditions ImportCondition[]
---@field conditions Condition[]
local ImportRule = {
}
local ImportRule_mt = {
    __index = ImportRule,
}

---@return ImportRule
function ImportRule.new(inventory, importConditions, conditions, itemManager)
    local self = setmetatable({}, ImportRule_mt)
    self.fails = 0
    self.itemManager = itemManager
    self.inventory = inventory
    self.importConditions = importConditions
    self.conditions = conditions
    return self
end

function ImportRule:evaluate()
    local items = peripheral.call(self.inventory, "list")
    local didImport = false
    for slot, item in pairs(items) do
        local count = item.count
        for _, condition in ipairs(self.importConditions) do
            count = math.min(count, condition:evaluate(slot, item))
            if count == 0 then
                break
            end
        end
        if count > 0 then
            for _, condition in ipairs(self.conditions) do
                count = math.min(count, condition:evaluate(true))
                if count == 0 then
                    break
                end
            end
        end
        if count > 0 then
            local amt = self.itemManager:deposit(self.inventory, slot, count, item)
            if amt > 0 then
                didImport = true
            end
        end
    end
    if not didImport then
        self.fails = self.fails + 1
    else
        self.fails = 0
    end
    return didImport
end

return ImportRule