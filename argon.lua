local constants = require("constants")
local InventoryManager = require("inventory.InventoryManager")
local GroupManager = require("inventory.GroupManager")
local ItemManager = require("inventory.ItemManager")
local ImportRule = require("rules.ImportRule")
local ExportItemRule = require("rules.ExportItemRule")
local MinSlotCondition = require("conditions.MinSlotCondition")
local MaxSlotCondition = require("conditions.MaxSlotCondition")
local ItemCondition = require("conditions.ItemCondition")
local MaxItemCountCondition = require("conditions.MaxItemCountCondition")
local MinItemCountCondition = require("conditions.MinItemCountCondition")
local configHelpers = require("util.configHelpers")
local ConfigValidator = require("util.ConfigValidator")
local ArgonUI = require("ui.ArgonUI")
local configDefaults = require("configDefaults")

local modem = peripheral.find("modem", function(name, modem)
    return not modem.isWireless() -- Check this modem is wired
end)

if not modem then
    error("No wired modem found")
end

if not turtle then
    error("This program must be run on a turtle")
end

local config = nil
if fs.exists(fs.combine(fs.getDir(shell.getRunningProgram()), "config.lua")) then
    config = require("config")
end

local version = "0.8.1"
local refreshFrequency = 120 -- 2 minutes
local maxBackoff = 5 * 20 -- 5 seconds
local backoffFactor = 1 -- Each rule failure increases duration before it is ran again by 1 tick

---@class Argon
---@field itemManager ItemManager
---@field inventoryManager InventoryManager
---@field groupManager GroupManager
---@field rules Rule[]
local Argon = {
    refreshFrequency = refreshFrequency,
    refreshes = 0,
    version = version,
    frozenSlots = {},
    config = config,
    pauseDeposits = false
}
local Argon_mt = { __index = Argon }

function Argon.new(setConfig)
    local self = setmetatable({}, Argon_mt)
    self.rules = {}
    self.groupManager = GroupManager.new()
    self.inventoryManager = InventoryManager.new(self.groupManager, self.rules)
    self.itemManager = ItemManager.new(self.groupManager, self.inventoryManager)
    self.config = setConfig or config or {}
    configHelpers.loadDefaults(self.config, configDefaults)
    local configErrors = ConfigValidator.validateConfig(self.config)
    if (configErrors and #configErrors > 0) then
        error("Config errors: " .. table.concat(configErrors, ", "))
    end
    return self
end

function Argon:refresh()
    local lastRefresh = 0
    while true do
        local curTime = os.epoch("utc")
        if (curTime - lastRefresh) >= (self.refreshFrequency*1000) then
            lastRefresh = curTime
            --print("Refreshing...")
            local start = os.epoch("utc")
            self.inventoryManager:scanInventories(modem)
            --print("Refreshed in " .. (os.epoch("utc") - start) .. "ms")
            local items = self.inventoryManager:getItemArray()
            local totalCount = 0
            table.sort(items, function (a, b)
                return a.count > b.count
            end)
            self.refreshes = self.refreshes + 1
            --[[for i = 1, math.min(5, #items) do
                local item = items[i]
                print(item.id .. " " .. item.count)
            end
            for _, item in ipairs(items) do
                totalCount = totalCount + item.count
            end--]]
            --print("Total: " .. totalCount)
            --self.itemManager:withdraw("minecraft:coal", modem.getNameLocal(), 1, 48)
        end
        sleep(self.refreshFrequency / 10)
    end
end

function Argon:tasks()
    local runCounter = 0
    while true do
        local rulesToRun = {}
        for _, rule in ipairs(self.rules) do
            if runCounter % math.min(maxBackoff, backoffFactor * rule.fails) then
                table.insert(rulesToRun, function() rule:evaluate() end )
            end
        end
        if #rulesToRun > 0 then
            parallel.waitForAll(unpack(rulesToRun))
        end
        runCounter = runCounter + 1
        if runCounter > 2^30 then
            runCounter = 0
        end
        sleep(0.05)
    end
end

function Argon:turtleDeposit()
    while true do
        local event = os.pullEvent("turtle_inventory")
        for i = 1, 16 do
            if not self.frozenSlots[i] and turtle.getItemCount(i) > 0 then
                local item = turtle.getItemDetail(i)
                local maxCount = InventoryManager:getMaxCounts()[item.name]
                if not maxCount then
                    maxCount = turtle.getItemCount(i) + turtle.getItemSpace(i)
                end
                item.maxCount = maxCount
                if not self.pauseDeposits then
                    -- Race condition
                    self.itemManager:deposit(modem.getNameLocal(), i, item.count, item)
                end
            elseif self.frozenSlots[i] and turtle.getItemCount(i) == 0 and not self.pauseDeposits then
                self.frozenSlots[i] = nil
            end
            if self.pauseDeposits then
                break
            end
        end
        if self.pauseDeposits then
            sleep(0.1)
        end
    end
end

function Argon:run()
    print("Argon " .. version .. " starting...")--[[
    table.insert(self.rules, ImportRule.new(
        "ender_storage_126",
        {
            --ItemCondition.new("minecraft:raw_copper"),
        },
        {
            --MaxItemCountCondition.new(self.inventoryManager, "minecraft:raw_copper", 63000),
        },
        self.itemManager
    ))
    local trash = "turtle_889"
    local trashCounts = {
        ["minecraft:dirt"] = 50000,
        ["minecraft:tuff"] = 50000,
        ["minecraft:cobblestone"] = 50000,
        ["minecraft:cobbled_deepslate"] = 50000,
        ["minecraft:gravel"] = 50000,
        ["minecraft:andesite"] = 50000,
        ["minecraft:diorite"] = 50000,
        ["minecraft:granite"] = 50000
    }
    for item, count in pairs(trashCounts) do
        table.insert(self.rules, ExportItemRule.new(
            trash,
            item,
            1,
            {
                MinItemCountCondition.new(self.inventoryManager, item, count),
            },
            self.itemManager
        ))
    end
    local composter = "ender_storage_6091"
    local compostCounts = {
        ["minecraft:carrot"] = 30000,
        ["minecraft:wheat_seeds"] = 20000,
        ["minecraft:wheat"] = 30000,
    }
    for item, count in pairs(compostCounts) do
        table.insert(self.rules, ExportItemRule.new(
            composter,
            item,
            nil,
            {
                MinItemCountCondition.new(self.inventoryManager, item, count),
            },
            self.itemManager
        ))
    end--]]
    parallel.waitForAny(
        function() self:refresh() end,
        function() self:tasks() end,
        function() self:turtleDeposit() end
    )
end

function Argon:getInventoryManager()
    return self.inventoryManager
end

function Argon:getItemManager()
    return self.itemManager
end

function Argon:getGroupManager()
    return self.groupManager
end

function Argon:getLocalName()
    return modem.getNameLocal()
end

function Argon:freezeSlot(slot)
    self.frozenSlots[slot] = true
end

if not fs.exists(constants.dir) then
    fs.makeDir(constants.dir)
elseif not fs.isDir(constants.dir) then
    error("argon directory is not a directory")
end

local _, usage = pcall(debug.getlocal, 4, 1)
if usage and (usage == "_sPath" or usage == "(*temporary)") then
    return Argon
else
    local argon = Argon.new()
    local argonUI = ArgonUI.new(argon)
    parallel.waitForAny(
        function() argon:run() end,
        function() argonUI:run() end
    )
end