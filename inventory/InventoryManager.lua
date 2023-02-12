local constants = require("constants")
local getSearchStrings = require("util.getSearchStrings")

---@class InventoryManager
---@field groupManager GroupManager
---@field rules Rule[]
local InventoryManager = {
    itemDescriptions = {},
    itemDescriptionStrings = {},
    nbtDetails = {},
    nbtDetailStrings = {},
    items = {},
    openStacks = {},
    itemArray = {},
    basicItemSources = {},
    itemSources = {},
    nbtSources = {},
    inventorySizes = {},
    nonFullInventories = {},
    maxCounts = {},
    groupItems = {},
    groupItemSources = {},
    groupManager = nil,
}
local InventoryManager_mt = { __index = InventoryManager }

local function getIdentifier(itemName)
    if itemName:find(":") then
        return itemName:sub(1, itemName:find(":") - 1), itemName:sub(itemName:find(":") + 1)
    else
        return "minecraft", itemName
    end
end

local function ensureDirs()
    if not fs.exists(fs.combine(constants.dir, "items")) then
        fs.makeDir(fs.combine(constants.dir, "items"))
    elseif not fs.isDir(fs.combine(constants.dir, "items")) then
        error(fs.combine(constants.dir, "items") .. "is not a directory!")
    end
    if not fs.exists(fs.combine(constants.dir, "nbt")) then
        fs.makeDir(fs.combine(constants.dir, "nbt"))
    elseif not fs.isDir(fs.combine(constants.dir, "nbt")) then
        error(fs.combine(constants.dir, "nbt") .. "is not a directory!")
    end
end

---@return InventoryManager
function InventoryManager.new(groupManager, rules)
    local self = setmetatable({}, InventoryManager_mt)
    self.groupManager = groupManager
    self.rules = rules
    return self
end

function InventoryManager.getItemID(item)
    if item.nbt then
        return item.name .. "[" .. item.nbt .. "]"
    else
        return item.name
    end
end

function InventoryManager:getItemDescription(item, inventoryName, slot)
    if self.itemDescriptions[item.name] and (item.nbt or not self.itemDescriptions[item.name].hasNbt) then
        return self.itemDescriptions[item.name]
    end
    local namespace, name = getIdentifier(item.name)
    if not fs.exists(fs.combine(constants.dir, "items", namespace)) then
        fs.makeDir(fs.combine(constants.dir, "items", namespace))
    end
    if fs.exists(fs.combine(constants.dir, "items", namespace, name .. ".item")) then
        local file = fs.open(fs.combine(constants.dir, "items", namespace, name .. ".item"), "r")
        local data = file.readAll()
        file.close()
        local itemData = textutils.unserialize(data)
        if itemData and (item.nbt or itemData.hasNbt) then
            self.itemDescriptions[item.name] = itemData
            self.itemDescriptionStrings[item.name] = getSearchStrings(itemData)
            return itemData
        end
    end
    local itemData = peripheral.call(inventoryName, "getItemDetail", slot)
    if itemData then
        if item.nbt then
            itemData.hasNbt = true
        end
        self.groupManager:compareNBTDetailToGroups(itemData)
        itemData.count = nil
        local file = fs.open(fs.combine(constants.dir, "items", namespace, name .. ".item"), "w")
        file.write(textutils.serialize(itemData))
        file.close()
        self.itemDescriptions[item.name] = itemData
        self.itemDescriptionStrings[item.name] = getSearchStrings(itemData)
        return itemData
    end
end

function InventoryManager:getItemDetails(item, inventoryName, slot)
    if self.nbtDetails[item.nbt] then
        return self.nbtDetails[item.nbt]
    end
    local namespace, name = getIdentifier(item.name)
    if fs.exists(fs.combine(constants.dir, "nbt", namespace, name, item.nbt .. ".nbt")) then
        local file = fs.open(fs.combine(constants.dir, "nbt", namespace, name, item.nbt .. ".nbt"), "r")
        local data = file.readAll()
        file.close()
        local itemData = textutils.unserialize(data)
        if itemData then
            self.nbtDetails[item.nbt] = itemData
            self.nbtDetailStrings[item.nbt] = getSearchStrings(itemData)
            return itemData
        end
    end
    local itemData = peripheral.call(inventoryName, "getItemDetail", slot)
    if itemData then
        itemData.count = nil
        local file = fs.open(fs.combine(constants.dir, "nbt", namespace, name, item.nbt .. ".nbt"), "w")
        file.write(textutils.serialize(itemData))
        file.close()
        self.nbtDetails[item.nbt] = itemData
        self.nbtDetailStrings[item.nbt] = getSearchStrings(itemData)
        return itemData
    end
end

function InventoryManager:addItem(inventoryName, slot, item, items, itemSources, basicItemSources, nbtSources, groupItems, groupItemSources, openStacks, itemArray)
    if not items then items = self.items end
    if not itemSources then itemSources = self.itemSources end
    if not basicItemSources then basicItemSources = self.basicItemSources end
    if not nbtSources then nbtSources = self.nbtSources end
    if not groupItems then groupItems = self.groupItems end
    if not groupItemSources then groupItemSources = self.groupItemSources end
    if not openStacks then openStacks = self.openStacks end
    if not itemArray then itemArray = self.itemArray end

    local itemDescription = self:getItemDescription(item, inventoryName, slot)
    if not itemDescription then
        return
    end
    local displayName = itemDescription.displayName or item.name
    local itemDetails = nil
    local sourceInfo = {
        item = item.name,
        inventory = inventoryName,
        slot = slot,
        count = item.count
    }
    if item.nbt then
        itemDetails = self:getItemDetails(item, inventoryName, slot)
        if itemDetails then
            if not nbtSources[item.nbt] then
                nbtSources[item.nbt] = {}
            end
            table.insert(nbtSources[item.nbt], sourceInfo)
            if itemDetails.displayName then
                displayName = itemDetails.displayName
            end
            if self.groupManager:getGroupMatches(item.nbt) then
                for _, group in ipairs(self.groupManager:getGroupMatches(item.nbt)) do
                    if self.groupManager:itemTypeInGroup(item.name, group) then
                        if not groupItems[group.id] then
                            groupItems[group.id] = 0
                        end
                        groupItems[group.id] = groupItems[group.id] + item.count
                        if not groupItemSources[group.id] then
                            groupItemSources[group.id] = {}
                        end
                        table.insert(groupItemSources[group.id], sourceInfo)
                    end
                end
            end
        end
    end
    if not basicItemSources[item.name] then
        basicItemSources[item.name] = {}
    end
    if not self.maxCounts[item.name] then
        self.maxCounts[item.name] = itemDescription.maxCount
    end
    table.insert(basicItemSources[item.name], sourceInfo)
    local itemID = self.getItemID(item)
    if not itemSources[itemID] then
        itemSources[itemID] = {}
    end
    table.insert(itemSources[itemID], sourceInfo)
    if item.count < itemDescription.maxCount then
        if not openStacks[itemID] then
            openStacks[itemID] = {}
        end
        table.insert(openStacks[itemID], sourceInfo)
    end
    if not items[itemID] then
        local itemObject = {
            name = item.name,
            id = itemID,
            displayName = displayName,
            nbt = item.nbt,
            count = item.count,
        }
        table.insert(itemArray, itemObject)
        items[itemID] = itemObject
        itemObject.index = #itemArray
    else
        items[itemID].count = items[itemID].count + item.count
    end
end

function InventoryManager:search(str)
    -- Split the search string into words
    local words = {}
    for word in string.gmatch(str, "%S+") do
        table.insert(words, word)
    end
    local results = {}
    local inResults = {}
    local itemArray = self:getItemArray()
    for _, item in ipairs(itemArray) do
        local itemID = self.getItemID(item)
        if not inResults[itemID] then
            local itemDescription = self.itemDescriptions[item.name]
            local displayName = itemDescription.displayName or item.name
            local matchAll = true
            for _, word in ipairs(words) do
                -- term.setBackgroundColor(colors.black)
                -- term.setTextColor(colors.white)
                -- print("Matching " .. word .. " to " .. displayName)
                if not string.find(string.lower(displayName), string.lower(word)) then
                    matchAll = false
                    break
                end
            end
            if matchAll then
                table.insert(results, itemID)
                inResults[itemID] = true
            elseif item.nbt then
                local nbtDescription = self.nbtDetails[item.nbt]
                displayName = nbtDescription.displayName
                local matchAll = true
                for _, word in ipairs(words) do
                    if not string.find(string.lower(displayName), string.lower(word)) then
                        matchAll = false
                        break
                    end
                end
                if matchAll then
                    table.insert(results, itemID)
                    inResults[itemID] = true
                end
            end
        end
    end
    for _, item in ipairs(itemArray) do
        local itemID = self.getItemID(item)
        if not inResults[itemID] then
            local itemDescriptionStrings = self.itemDescriptionStrings[item.name]
            local matchAll = true
            for _, word in ipairs(words) do
                if not string.find(string.lower(itemDescriptionStrings), string.lower(word)) then
                    matchAll = false
                    break
                end
                -- local matchWord = false
                -- for _, descriptionString in ipairs(itemDescriptionStrings) do
                --     if string.find(string.lower(descriptionString), string.lower(word)) then
                --         matchWord = true
                --         break
                --     end
                -- end
                -- if not matchWord then
                --     matchAll = false
                --     break
                -- end
            end
            if matchAll then
                table.insert(results, itemID)
                inResults[itemID] = true
            elseif item.nbt then
                local nbtDescriptionStrings = self.nbtDetailStrings[item.nbt]
                matchAll = true
                for _, word in ipairs(words) do
                    if not string.find(string.lower(nbtDescriptionStrings), string.lower(word)) then
                        matchAll = false
                        break
                    end
                    -- local matchWord = false
                    -- for _, descriptionString in ipairs(nbtDescriptionStrings) do
                    --     if string.find(string.lower(descriptionString), string.lower(word)) then
                    --         matchWord = true
                    --         break
                    --     end
                    -- end
                    -- if not matchWord then
                    --     matchAll = false
                    --     break
                    -- end
                end
                if matchAll then
                    table.insert(results, itemID)
                    inResults[itemID] = true
                end
            end
        end
    end
    return results
end

function InventoryManager:getItemSources()
    return self.itemSources
end

function InventoryManager:getBasicItemSources()
    return self.basicItemSources
end

function InventoryManager:getNbtSources()
    return self.nbtSources
end

function InventoryManager:getItems()
    return self.items
end

function InventoryManager:getItemArray()
    return self.itemArray
end

function InventoryManager:getOpenStacks()
    return self.openStacks
end

function InventoryManager:getInventorySizes()
    return self.inventorySizes
end

function InventoryManager:getNonFullInventories()
    return self.nonFullInventories
end

function InventoryManager:getItemDescriptions()
    return self.itemDescriptions
end

function InventoryManager:getItemDescriptionStrings()
    return self.itemDescriptionStrings
end

function InventoryManager:getNbtDetails()
    return self.nbtDetails
end

function InventoryManager:getNbtDetailStrings()
    return self.nbtDetailStrings
end

function InventoryManager:getGroupItems()
    return self.groupItems
end

function InventoryManager:getGroupItemSources()
    return self.groupItemSources
end

function InventoryManager:getMaxCounts()
    return self.maxCounts
end

function InventoryManager:scanInventories(modem)
    ensureDirs()
    local names = modem.getNamesRemote()
    local inventories = {}
    for _, name in ipairs(names) do
        if peripheral.hasType(name, "inventory") then
            local validInventory = true
            for _, denyType in pairs(constants.storageDenyList) do
                if peripheral.hasType(name, denyType) then
                    validInventory = false
                    break
                end
            end
            if validInventory then
                table.insert(inventories, peripheral.wrap(name))
            end
        end
    end
    local scanTasks = {}
    local newItemSources = {}
    local newBasicItemSources = {}
    local newNbtSources = {}
    local newItems = {}
    local newitemArray = {}
    local newOpenStacks = {}
    local newGroupItems = {}
    local newGroupItemSources = {}
    local newInventorySizes = {}
    local newNonFullInventories = {}

    local ruleInventories = {}
    for _, rule in ipairs(self.rules) do
        if rule.inventory then
            ruleInventories[rule.inventory] = true
        end
    end

    for _, inventory in ipairs(inventories) do
        table.insert(scanTasks, function()
            local inventoryName = peripheral.getName(inventory)

            if inventoryName:find("turtle") or ruleInventories[inventoryName] then
                return
            end

            if not newInventorySizes[inventoryName] then
                newInventorySizes[inventoryName] = inventory.size()
            end
            local listedItems = inventory.list()
            if #listedItems ~= newInventorySizes[inventoryName] then
                newNonFullInventories[inventoryName] = #listedItems+1
            else
                newNonFullInventories[inventoryName] = nil
            end
            for slot, item in pairs(listedItems) do
                self:addItem(inventoryName, slot, item, newItems, newItemSources, newBasicItemSources, newNbtSources, newGroupItems, newGroupItemSources, newOpenStacks, newitemArray)
            end
        end)
    end
    parallel.waitForAll(unpack(scanTasks))
    self.itemSources = newItemSources
    self.basicItemSources = newBasicItemSources
    self.nbtSources = newNbtSources
    self.items = newItems
    self.itemArray = newitemArray
    self.openStacks = newOpenStacks
    self.groupItems = newGroupItems
    self.groupItemSources = newGroupItemSources
    self.inventorySizes = newInventorySizes
    self.nonFullInventories = newNonFullInventories
end

return InventoryManager