---@class ItemManager
---@field groupManager GroupManager
---@field inventoryManager InventoryManager
local ItemManager = {
    groupManager = nil,
    inventoryManager = nil,
}

local ItemManager_mt = {
    __index = ItemManager
}

local maxFailedAttempts = 3

---@return ItemManager
function ItemManager.new(groupManager, inventoryManager)
    local self = setmetatable({}, ItemManager_mt)
    self.groupManager = groupManager
    self.inventoryManager = inventoryManager
    return self
end

function ItemManager:deposit(inventory, slot, maxCount, item)
    local transferType = "push"
    if type(inventory) == "string" then
        transferType = "pull"
    end
    if not item then
        item = peripheral.call(inventory, "getItemDetail", slot)
    end
    local items = self.inventoryManager:getItems()
    local itemID = self.inventoryManager.getItemID(item)
    local openStacks = self.inventoryManager:getOpenStacks()[itemID]
    local nonFullInventories = self.inventoryManager:getNonFullInventories()
    local inventorySizes = self.inventoryManager:getInventorySizes()
    local itemDescription = self.inventoryManager:getItemDescriptions()[item.name]
    if itemDescription and itemDescription.maxCount then
        item.maxCount = itemDescription.maxCount
    elseif not item.maxCount then
        item.maxCount = 64
    end
    local transferred = 0
    local failedAttempts = 0
    if openStacks then
        for i, openStack in pairs(openStacks) do
            local toTransfer = math.min(maxCount - transferred, item.maxCount - openStack.count)
            if toTransfer > 0 then
                local transferredAmount = 0
                if transferType == "push" then
                    transferredAmount = inventory.pushItems(openStack.inventory, slot, toTransfer, openStack.slot)
                else
                    transferredAmount = peripheral.call(openStack.inventory, "pullItems", inventory, slot, toTransfer, openStack.slot)
                end
                openStack.count = openStack.count + transferredAmount
                transferred = transferred + transferredAmount
                items[itemID].count = items[itemID].count + transferred
                if transferredAmount == 0 then
                    failedAttempts = failedAttempts + 1
                end
                if failedAttempts > maxFailedAttempts then
                    break
                end
            end
            if transferred >= maxCount then
                break
            end
        end
    end
    if transferred < maxCount then
        failedAttempts = 0
        for toInventory, openSlot in pairs(nonFullInventories) do
            local transferredAmount = 0
            if transferType == "push" then
                transferredAmount = inventory.pushItems(toInventory, slot, maxCount - transferred, openSlot)
            else
                transferredAmount = peripheral.call(toInventory, "pullItems", inventory, slot, maxCount - transferred, openSlot)
            end
            transferred = transferred + transferredAmount
            nonFullInventories[toInventory] = openSlot + 1
            if nonFullInventories[toInventory] > inventorySizes[toInventory] then
                nonFullInventories[toInventory] = nil
            end
            if transferredAmount > 0 then
                self.inventoryManager:addItem(toInventory, openSlot, item)
            elseif transferredAmount == 0 then
                failedAttempts = failedAttempts + 1
            end
            if failedAttempts > maxFailedAttempts then
                break
            end
            if transferred >= maxCount then
                break
            end
        end
    end
    return transferred
end

function ItemManager:withdraw(itemID, inventory, slot, maxCount)
    local transferType = "pull"
    if type(inventory) == "string" then
        transferType = "push"
    end
    if not maxCount then
        if self.inventoryManager:getItemDescriptions()[itemID] then
            maxCount = self.inventoryManager:getItemDescriptions()[itemID].maxCount
        else
            maxCount = 64
        end
    end
    local transferred = 0
    local items = self.inventoryManager:getItems()
    local itemSources = self.inventoryManager:getItemSources()[itemID]
    local openStacks = self.inventoryManager:getOpenStacks()[itemID]
    local toRemove = {}
    local failedAttempts = 0
    if openStacks then
        for i = 1, #openStacks do
            local itemSource = openStacks[i]
            local toTransfer = math.min(maxCount - transferred, itemSource.count)
            if toTransfer > 0 then
                local transferredAmount
                if transferType == "pull" then
                    transferredAmount = inventory.pullItems(itemSource.inventory, itemSource.slot, toTransfer, slot)
                else
                    transferredAmount = peripheral.call(itemSource.inventory, "pushItems", inventory, itemSource.slot, toTransfer, slot)
                end
                itemSource.count = itemSource.count - transferredAmount
                transferred = transferred + transferredAmount
                if itemSource.count == 0 then
                    table.insert(toRemove, i)
                end
                if transferredAmount == 0 then
                    failedAttempts = failedAttempts + 1
                end
                if failedAttempts > maxFailedAttempts then
                    break
                end
            end
            if transferred >= maxCount then
                break
            end
        end
        for i = #toRemove, 1, -1 do
            table.remove(openStacks, toRemove[i])
        end
    end
    if itemSources and transferred < maxCount then
        for i = 1, #itemSources do
            local itemSource = itemSources[i]
            local toTransfer = math.min(maxCount - transferred, itemSource.count)
            if toTransfer > 0 then
                local transferredAmount
                if transferType == "pull" then
                    transferredAmount = inventory.pullItems(itemSource.inventory, itemSource.slot, toTransfer, slot)
                else
                    transferredAmount = peripheral.call(itemSource.inventory, "pushItems", inventory, itemSource.slot, toTransfer, slot)
                end
                itemSource.count = itemSource.count - transferredAmount
                transferred = transferred + transferredAmount
                if itemSource.count == 0 then
                    table.insert(toRemove, i)
                end
                if transferredAmount == 0 then
                    failedAttempts = failedAttempts + 1
                end
                if failedAttempts > maxFailedAttempts then
                    break
                end
            end
            if transferred >= maxCount then
                break
            end
        end
        for i = #toRemove, 1, -1 do
            table.remove(itemSources, toRemove[i])
        end
    end
    if items[itemID] then
        items[itemID].count = items[itemID].count - transferred
    end
    return transferred
end

function ItemManager:withdrawGroup(group, inventory, slot, maxCount)
    local transferType = "pull"
    if type(inventory) == "string" then
        transferType = "push"
    end
    if not maxCount then
        maxCount = 64
    end

    local nbtSources = self.inventoryManager:getNbtSources()
    local transferred = 0
    local failedAttempts = 0

    local groupItems = self.groupManager:getGroupItems(group)

    for nbtHash, _ in group.matches do
        for _, itemType in ipairs(groupItems) do
            local itemID = self.inventoryManager.getItemID({ name = itemType, nbt = nbtHash})
            local openStacks = self.inventoryManager:getOpenStacks()[itemID]
            local toRemove = {}
            if openStacks then
                for i = 1, #openStacks do
                    local itemSource = openStacks[i]
                    if self.groupManager:itemTypeInGroup(itemSource.item, group) then
                        local toTransfer = math.min(maxCount - transferred, itemSource.count)
                        if toTransfer > 0 then
                            local transferredAmount
                            if transferType == "pull" then
                                transferredAmount = inventory.pullItems(itemSource.inventory, itemSource.slot, toTransfer, slot)
                            else
                                transferredAmount = peripheral.call(itemSource.inventory, "pushItems", inventory, itemSource.slot, toTransfer, slot)
                            end
                            itemSource.count = itemSource.count - transferredAmount
                            transferred = transferred + transferredAmount
                            if itemSource.count == 0 then
                                table.insert(toRemove, i)
                            end
                            if transferredAmount == 0 then
                                failedAttempts = failedAttempts + 1
                            end
                            if failedAttempts > maxFailedAttempts then
                                break
                            end
                        end
                    end
                    if transferred >= maxCount then
                        break
                    end
                end
                for i = #toRemove, 1, -1 do
                    table.remove(openStacks, toRemove[i])
                end
                if transferred >= maxCount then
                    break
                end
            end
        end
        if transferred >= maxCount then
            break
        end
        local itemSources = nbtSources[nbtHash]
        local toRemove = {}
        for i = 1, #itemSources do
            local itemSource = itemSources[i]
            if self.groupManager:itemTypeInGroup(itemSource.item, group) then
                local toTransfer = math.min(maxCount - transferred, itemSource.count)
                if toTransfer > 0 then
                    local transferredAmount
                    if transferType == "pull" then
                        transferredAmount = inventory.pullItems(itemSource.inventory, itemSource.slot, toTransfer, slot)
                    else
                        transferredAmount = peripheral.call(itemSource.inventory, "pushItems", inventory, itemSource.slot, toTransfer, slot)
                    end
                    itemSource.count = itemSource.count - transferredAmount
                    transferred = transferred + transferredAmount
                    if itemSource.count == 0 then
                        table.insert(toRemove, i)
                    end
                    if transferredAmount == 0 then
                        failedAttempts = failedAttempts + 1
                    end
                    if failedAttempts > maxFailedAttempts then
                        break
                    end
                end
            end
            if transferred >= maxCount then
                break
            end
        end
        for i = #toRemove, 1, -1 do
            table.remove(itemSources, toRemove[i])
        end
        if transferred >= maxCount then
            break
        end
    end
    return transferred
end

return ItemManager