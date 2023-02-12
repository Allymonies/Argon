---@diagnostic disable: redundant-return-value
local _ = require("util.score")
local Display = require("modules.display")
local Solyd = require("modules.solyd")
local hooks = require("modules.hooks")
local useCanvas = hooks.useCanvas

local Rect = require("components.Rect")
local BasicText = require("components.BasicText")
local BasicButton = require("components.BasicButton")
local Item = require("components.Item")
local Scrollbar = require("components.Scrollbar")
local ActiveInput = require("components.ActiveInput")
local WithdrawModal = require("components.WithdrawModal")

local function diffCanvasStack(diffDisplay, newStack, lastCanvas)
    -- Find any canvases that were removed
    local removed = {}
    local kept, newCanvasHash = {}, {}
    for i = 1, #lastCanvas.stack do
        removed[lastCanvas.stack[i][1]] = lastCanvas.stack[i]
    end
    for i = 1, #newStack do
        if removed[newStack[i][1]] then
            kept[#kept+1] = newStack[i]
            removed[newStack[i][1]] = nil
            newStack[i][1].allDirty = false
        else -- New
            newStack[i][1].allDirty = true
        end

        newCanvasHash[newStack[i][1]] = newStack[i]
    end

    -- Mark rectangle of removed canvases on bgCanvas (TODO: using bgCanvas is a hack)
    for _, canvas in pairs(removed) do
        if canvas[1].brand == "TextCanvas" then
            diffDisplay.bgCanvas:dirtyRect(canvas[2], canvas[3], canvas[1].width*2, canvas[1].height*3)
        else
            diffDisplay.bgCanvas:dirtyRect(canvas[2], canvas[3], canvas[1].width, canvas[1].height)
        end
    end

    -- For each kept canvas, mark the bounds if the new bounds are different
    for i = 1, #kept do
        local newCanvas = kept[i]
        local oldCanvas = lastCanvas.hash[newCanvas[1]]
        if oldCanvas then
            if oldCanvas[2] ~= newCanvas[2] or oldCanvas[3] ~= newCanvas[3] then
                -- TODO: Optimize this?
                if oldCanvas[1].brand == "TextCanvas" then
                    diffDisplay.bgCanvas:dirtyRect(oldCanvas[2], oldCanvas[3], oldCanvas[1].width*2, oldCanvas[1].height*3)
                    diffDisplay.bgCanvas:dirtyRect(newCanvas[2], newCanvas[3], newCanvas[1].width*2, newCanvas[1].height*3)
                else
                    diffDisplay.bgCanvas:dirtyRect(oldCanvas[2], oldCanvas[3], oldCanvas[1].width, oldCanvas[1].height)
                    diffDisplay.bgCanvas:dirtyRect(newCanvas[2], newCanvas[3], newCanvas[1].width, newCanvas[1].height)
                end
            end
        end
    end

    lastCanvas.stack = newStack
    lastCanvas.hash = newCanvasHash
end

---@class ArgonUI
---@field argon Argon
local ArgonUI = {

}
local ArgonUI_mt = {
    __index = ArgonUI,
}

---@return ArgonUI
function ArgonUI.new(argon)
    local self = setmetatable({}, ArgonUI_mt)
    self.argon = argon
    return self
end

function ArgonUI:run()
    local config = self.argon.config
    local terminal = Display.new({theme=config.theme, monitor=term})
    local lastCanvas = { stack = {}, hash = {} }
    local terminalState = {
        scroll = 0,
        maxScroll = 0,
        itemsPerScreen = 0,
        selectedItem = 1,
        maxSelected = 0,
        category = "inventory",
        lastRefresh = -1,
        searchQuery = nil,
        searchResults = {},
        doWithdraw = false,
        inModal = false,
    }
    local Terminal = Solyd.wrapComponent("Terminal", function(props)
        local withdrawModalOpen, setWithdrawModalOpen = Solyd.useState(false)
        local withdrawModalItem, setWithdrawModalItem = Solyd.useState({})

        local theme = self.argon.config.theme
        local state = props.state

        local headerHeight = 3
        local inventoryManager = self.argon:getInventoryManager()
        local items = inventoryManager:getItemArray()
        local itemTable = inventoryManager:getItems()
        local itemDescriptions = inventoryManager:getItemDescriptions()
        local nbtDetails = inventoryManager:getNbtDetails()

        local numItems = #items
        if state.searchQuery and state.searchQuery ~= "" then
            numItems = #state.searchResults
        end

        if state.category == "inventory" then
            state.maxScroll = math.max(0, numItems - math.floor(terminal.bgCanvas.height / 3) + headerHeight)
            state.maxSelected = numItems
            state.itemsPerScreen = math.floor(terminal.bgCanvas.height / 3) - headerHeight
        else
            state.maxScroll = 0
        end

        local elements = {}

        function changeCategory()
            state.scroll = 0
            state.searchQuery = nil
            state.searchResults = {}
            state.selectedItem = 1
            state.doWithdraw = false
        end

        table.insert(elements, Rect {
            display = terminal,
            x = 1,
            y = 1,
            width = terminal.bgCanvas.width,
            height = 3,
            color = theme.colors.headerColor,
        })

        table.insert(elements, BasicButton {
            display = terminal,
            x = 1,
            y = 1,
            color = (state.category == "inventory" and theme.colors.activeTabColor) or theme.colors.tabColor,
            bg = (state.category == "inventory" and theme.colors.activeTabBgColor) or theme.colors.tabBgColor,
            align = "center",
            width = 10,
            height = 1,
            text = "Inventory",
            onClick = function()
                state.category = "inventory"
                changeCategory()
            end,
        })

        table.insert(elements, BasicButton {
            display = terminal,
            x = 12,
            y = 1,
            color = (state.category == "config" and theme.colors.activeTabColor) or theme.colors.tabColor,
            bg = (state.category == "config" and theme.colors.activeTabBgColor) or theme.colors.tabBgColor,
            align = "center",
            width = 10,
            height = 1,
            text = "Config",
            onClick = function()
                state.category = "config"
                changeCategory()
            end,
        })

        table.insert(elements, BasicButton {
            display = terminal,
            x = 23,
            y = 1,
            color = (state.category == "rules" and theme.colors.activeTabColor) or theme.colors.tabColor,
            bg = (state.category == "rules" and theme.colors.activeTabBgColor) or theme.colors.tabBgColor,
            align = "center",
            width = 10,
            height = 1,
            text = "Rules",
            onClick = function()
                state.category = "rules"
                changeCategory()
            end,
        })

        if state.category == "inventory" then
            table.insert(elements, ActiveInput {
                key = "inventory-search-bar",
                display = terminal,
                align = "left",
                x = 1,
                y = headerHeight - 1,
                color = theme.colors.searchBarColor,
                bg = theme.colors.searchBarBgColor,
                placeholder = "Search...",
                placeholderColor = theme.colors.searchBarPlaceholderColor,
                width = math.floor(terminal.bgCanvas.width/2),
                height = 1,
                inputState = {
                    value = "",
                    active = not withdrawModalOpen
                },
                onChange = function(value)
                    if value ~= state.searchQuery then
                        state.searchQuery = value
                        state.searchResults = {}
                        state.scroll = 0
                        state.selectedItem = 1
                        if value ~= "" then
                            state.searchResults = inventoryManager:search(value)
                        end
                    end
                end,
            })
            table.insert(elements, Item {
                display = terminal,
                itemAlign = "right",
                countAlign = "left",
                displayName = "Item",
                count = "Count",
                x = 1,
                y = headerHeight,
                color = theme.colors.activeItemColor,
                bg = theme.colors.activeItemBgColor,
                width = math.floor(terminal.bgCanvas.width/2) - 1,
                onClick = function() end,
            })
            if state.doWithdraw then
                state.doWithdraw = false
                if not withdrawModalOpen then
                    local item = nil
                    if state.searchQuery and state.searchQuery ~= "" then
                        if state.searchResults[state.selectedItem] then
                            item = itemTable[state.searchResults[state.selectedItem]]
                        end
                    else
                        item = items[state.selectedItem]
                    end
                    if item then
                        setWithdrawModalItem(item)
                        setWithdrawModalOpen(true)
                    end
                end
            end
            for i = headerHeight+1, math.floor(terminal.bgCanvas.height / 3) do
                local itemIndex = i + state.scroll - headerHeight
                local item = nil
                if state.searchQuery and state.searchQuery ~= "" then
                    if state.searchResults[itemIndex] then
                        item = itemTable[state.searchResults[itemIndex]]
                    end
                else
                    item = items[itemIndex]
                end
                if item then
                    local displayName = item.name
                    if item.nbt and nbtDetails[item.nbt] and nbtDetails[item.nbt].displayName then
                        displayName = nbtDetails[item.nbt].displayName
                    elseif itemDescriptions[item.name] and itemDescriptions[item.name].displayName then
                        displayName = itemDescriptions[item.name].displayName
                    end
                    itemColor = theme.colors.itemColor
                    itemBgColor = theme.colors.itemBgColor
                    if state.selectedItem == itemIndex then
                        itemColor = theme.colors.activeItemColor
                        itemBgColor = theme.colors.activeItemBgColor
                    end
                    table.insert(elements, Item {
                        display = terminal,
                        itemAlign = "right",
                        countAlign = "left",
                        displayName = displayName,
                        count = item.count,
                        x = 1,
                        y = i,
                        color = itemColor,
                        bg = itemBgColor,
                        width = math.floor(terminal.bgCanvas.width/2) - 1,
                        onClick = function()
                            setWithdrawModalItem(item)
                            setWithdrawModalOpen(true)
                        end,
                    })
                else
                    break
                end
            end
            table.insert(elements, Scrollbar {
                key = "inventory-scrollbar",
                display = terminal,
                x = terminal.bgCanvas.width - 1,
                y = (headerHeight*3) + 1 - 3,
                width = 2,
                height = terminal.bgCanvas.height - ((headerHeight-1)*3),
                areaHeight = terminal.bgCanvas.height - ((headerHeight-1)*3),
                scroll = state.scroll * 3,
                maxScroll = state.maxScroll * 3,
                color = theme.colors.scrollbarColor,
                bg = theme.colors.scrollbarBgColor,
            })
            state.inModal = false
            if withdrawModalOpen then
                local modalWidth = math.min((terminal.bgCanvas.width/2), 30)
                local modalHeight = 7
                local withdrawItem = withdrawModalItem
                local withdrawItemName = withdrawItem.name
                if withdrawItem.nbt and nbtDetails[withdrawItem.nbt] and nbtDetails[withdrawItem.nbt].displayName then
                    withdrawItemName = nbtDetails[withdrawItem.nbt].displayName
                elseif itemDescriptions[withdrawItem.name] and itemDescriptions[withdrawItem.name].displayName then
                    withdrawItemName = itemDescriptions[withdrawItem.name].displayName
                end
                state.inModal = true
                table.insert(elements, WithdrawModal {
                    key = "withdraw-modal",
                    display = terminal,
                    x = math.floor(1 + (terminal.bgCanvas.width/(2*2)) - (modalWidth/2)),
                    y = math.floor(1 + (terminal.bgCanvas.height/(2*3)) - (modalHeight/2)),
                    align = "center",
                    width = modalWidth,
                    height = modalHeight,
                    text = "Extract: " .. withdrawItemName,
                    color = theme.colors.modalColor,
                    bg = theme.colors.modalBgColor,
                    buttonTextColor = theme.colors.modalButtonTextColor,
                    buttonColor = theme.colors.modalButtonBgColor,
                    borderColor = theme.colors.modalBorderColor,
                    inputColor = theme.colors.modalInputColor,
                    inputBgColor = theme.colors.modalInputBgColor,
                    inputPlaceholderColor = theme.colors.modalInputPlaceholderColor,
                    onConfirm = function(value)
                        local amount = textutils.unserialize(tostring(value))
                        if amount and type(amount) == "number" and amount > 0 then
                            self.argon.pauseDeposits = true
                            local item = withdrawModalItem
                            local itemID = inventoryManager.getItemID(item)
                            local itemDescription = inventoryManager:getItemDescriptions()[item.name]
                            local maxCount = 64
                            if itemDescription and itemDescription.maxCount then
                                maxCount = itemDescription.maxCount
                            end
                            local firstEmptySlot = 1
                            while amount > 0 do
                                local count = math.min(amount, maxCount)
                                local transferred = 0
                                if self.argon.config.settings.dropItems then
                                    if turtle.getItemCount(1) > 0 then
                                        turtle.drop(64)
                                    end
                                    transferred = self.argon:getItemManager():withdraw(itemID, self.argon:getLocalName(), 1, count)
                                    turtle.drop(64)
                                else
                                    local toSlot = nil
                                    for i = firstEmptySlot, 16 do
                                        if turtle.getItemCount(i) == 0 then
                                            toSlot = i
                                            break
                                        end
                                    end
                                    if toSlot then
                                        firstEmptySlot = toSlot + 1
                                        self.argon:freezeSlot(toSlot)
                                        transferred = self.argon:getItemManager():withdraw(itemID, self.argon:getLocalName(), toSlot, count)
                                    else
                                        break
                                    end
                                    --transferred = self.argon:getItemManager():withdraw(itemID, self.argon:getLocalName(), nil, count)
                                end
                                amount = amount - transferred
                                if transferred == 0 then
                                    break
                                end
                            end
                            self.argon.pauseDeposits = false
                        end
                        setWithdrawModalOpen(false)
                        setWithdrawModalItem(nil)
                    end,
                    onCancel = function()
                        setWithdrawModalOpen(false)
                        setWithdrawModalItem(nil)
                    end,
                })
            end
        end

        state.lastRefresh = props.refreshes
        return _.flat(elements), {
            state = props.state,
            modal = props.modal,
        }
    end)
    local tree = nil
    while true do
        tree = Solyd.render(tree, Terminal { state = terminalState, refreshes = self.argon.refreshes, modal = {} })
        local context = Solyd.getTopologicalContext(tree, { "canvas", "aabb", "input"})
        diffCanvasStack(terminal, context.canvas, lastCanvas)
        local cstack = {{terminal.bgCanvas, 1, 1}, unpack(context.canvas)}
        terminal.ccCanvas:composite(unpack(cstack))
        terminal.ccCanvas:outputDirty(terminal.mon)

        local activeNode = hooks.findActiveInput(context.input)
        if activeNode then
            if activeNode.inputState.cursorX and activeNode.inputState.cursorY then
                terminal.mon.setCursorPos(activeNode.inputState.cursorX, activeNode.inputState.cursorY)
            else
                terminal.mon.setCursorPos(activeNode.x, activeNode.y)
            end
            terminal.mon.setTextColor(colors.black)
            terminal.mon.setCursorBlink(true)
        else
            terminal.mon.setCursorBlink(false)
        end
        local e = { os.pullEvent() }
        local name = e[1]
        if name == "term_resize" then
            terminal.ccCanvas:outputFlush(terminal.mon)
        elseif name == "mouse_click" then
            local x, y = e[3], e[4]
            local clearedInput = hooks.clearActiveInput(context.input, x, y)
            if clearedInput and clearedInput.onBlur then
                clearedInput.onBlur()
            end
            local node = hooks.findNodeAt(context.aabb, x, y)
            if node then
                node.onClick()
            end
        elseif name == "mouse_scroll" then
            local dir = e[2]
            local x, y = e[3], e[4]
            local node = hooks.findNodeAt(context.aabb, x, y)
            local cancelScroll = false
            if node and node.onScroll then
                if node.onScroll(dir) then
                    cancelScroll = true
                end
            end
            if not cancelScroll then
                if dir >= 1 and terminalState.scroll < terminalState.maxScroll then
                    terminalState.scroll = math.min(terminalState.scroll + dir, terminalState.maxScroll)
                elseif dir <= -1 and terminalState.scroll > 0 then
                    terminalState.scroll = math.max(terminalState.scroll + dir, 0)
                end
            end
        elseif name == "char" then
            local char = e[2]
            local node = hooks.findActiveInput(context.input)
            if node then
                node.onChar(char)
            end
        elseif name == "key" then
            local key, held = e[2] or 0, e[3] or false
            local node = hooks.findActiveInput(context.input)
            if node then
                node.onKey(key, held)
            end
            if terminalState.category == "inventory" then
                if key == keys.up then
                    terminalState.selectedItem = math.max(terminalState.selectedItem - 1, 1)
                    if terminalState.selectedItem < terminalState.scroll + 1 then
                        terminalState.scroll = math.max(terminalState.selectedItem - 1, 0)
                    end
                elseif key == keys.down then
                    terminalState.selectedItem = math.min(terminalState.selectedItem + 1, terminalState.maxSelected)
                    if terminalState.selectedItem > terminalState.scroll + terminalState.itemsPerScreen then
                        terminalState.scroll = math.min(terminalState.selectedItem - terminalState.itemsPerScreen, terminalState.maxScroll)
                    end
                elseif key == keys.enter and not terminalState.inModal then
                    terminalState.doWithdraw = true
                end
            end
        elseif name == "paste" then
            local contents = e[2]
            local node = hooks.findActiveInput(context.input)
            if node and node.onPaste then
                node.onPaste(contents)
            end
        end
    end
    terminal.mon.setBackgroundColor(colors.black)
    terminal.mon.setTextColor(colors.white)
    terminal.mon.clear()
    terminal.mon.setCursorPos(1,1)
end

return ArgonUI