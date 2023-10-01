--[[
    Based on the installer for artist https://github.com/SquidDev-CC/artist
    Written by DVD-DAVIDE https://github.com/DVD-DAVIDE
--]]

local files = {
    "components/ActiveInput.lua",
    "components/Alert.lua",
    "components/BasicButton.lua",
    "components/BasicText.lua",
    "components/BigText.lua",
    "components/Button.lua",
    "components/ConfigEditor.lua",
    "components/Flex.lua",
    "components/Item.lua",
    "components/Logs.lua",
    "components/Modal.lua",
    "components/Rect.lua",
    "components/RenderCanvas.lua",
    "components/Scrollbar.lua",
    "components/Select.lua",
    "components/SmolButton.lua",
    "components/SmolText.lua",
    "components/Sprite.lua",
    "components/TextInput.lua",
    "components/Toggle.lua",
    "components/WithdrawModal.lua",
    "conditions/Condition.lua",
    "conditions/ItemCondition.lua",
    "conditions/MaxGroupCountCondition.lua",
    "conditions/MaxItemCountCondition.lua",
    "conditions/MaxSlotCondition.lua",
    "conditions/MinGroupCountCondition.lua",
    "conditions/MinItemCountCondition.lua",
    "conditions/MinSlotCondition.lua",
    "inventory/GroupManager.lua",
    "inventory/InventoryManager.lua",
    "inventory/ItemManager.lua",
    "modules/animation/Ease.lua",
    "modules/animation/init.lua",
    "modules/hooks/aabb.lua",
    "modules/hooks/animation.lua",
    "modules/hooks/canvas.lua",
    "modules/hooks/init.lua",
    "modules/hooks/input.lua",
    "modules/hooks/modals.lua",
    "modules/hooks/textCanvas.lua",
    "modules/regex/emitter.lua",
    "modules/regex/init.lua",
    "modules/regex/nfactory.lua",
    "modules/regex/parser.lua",
    "modules/regex/pprint.lua",
    "modules/regex/reducer.lua",
    "modules/regex/util.lua",
    "modules/canvas.lua",
    "modules/display.lua",
    "modules/font.lua",
    "modules/rif.lua",
    "modules/solyd.lua",
    "rules/ExportGroupRule.lua",
    "rules/ExportItemRule.lua",
    "rules/ImportRule.lua",
    "rules/Rule.lua",
    "ui/ArgonUI.lua",
    "util/base64.lua",
    "util/configHelpers.lua",
    "util/ConfigValidator.lua",
    "util/getSearchStrings.lua",
    "util/iter.lua",
    "util/misc.lua",
    "util/score.lua",
    "util/setPalette.lua",
    "argon.lua",
    "config.lua",
    "configDefaults.lua",
    "constants.lua",
    "installer.lua",
    "schemas.lua",
}
local tasks = {}
for i, path in ipairs(files) do
    tasks[i] = function()
        local req, err = http.get("https://github.com/Allymonies/Argon/raw/main/" .. path)
        if not req then error("Failed to download " .. path .. ": " .. err, 0) end

        local file = fs.open("/" .. ((path ~= "installer.lua" and path) or "update.lua"), "w")
        file.write(req.readAll())
        file.close()

        req.close()
    end
end

parallel.waitForAll(table.unpack(tasks))

print("Argon successfully installed! Run /argon.lua to start.")
