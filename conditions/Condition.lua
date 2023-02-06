---@class ImportCondition
---@field evaluate fun(self: ImportCondition, slot: number, item: table): number

---@class Condition
---@field evaluate fun(self: Condition, import: boolean): number