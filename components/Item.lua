local Solyd = require("modules.solyd")
local hooks = require("modules.hooks")
local useBoundingBox = hooks.useBoundingBox

local BasicText = require("components.BasicText")

local countWidth = 8

return Solyd.wrapComponent("Item", function(props)
    -- local canvas = Solyd.useContext("canvas")
    -- local canvas = useCanvas()
    local elements = {}

    table.insert(elements, BasicText {
        display = props.display,
        align = props.itemAlign,
        text = props.displayName,
        x = props.x,
        y = props.y,
        bg = props.bg,
        color = props.color,
        width = props.width - 3 - countWidth,
    })

    table.insert(elements, BasicText {
        display = props.display,
        align = "left",
        text = " \149 ",
        x = props.x + props.width - 3 - countWidth,
        y = props.y,
        bg = props.bg,
        color = props.color,
        width = 3,
    })

    table.insert(elements, BasicText {
        display = props.display,
        align = props.countAlign,
        text = tostring(props.count),
        x = props.x + props.width - countWidth,
        y = props.y,
        bg = props.bg,
        color = props.color,
        width = countWidth,
    })

    return elements, {
        -- canvas = canvas,
        aabb = useBoundingBox((props.x*2)-1, (props.y*3)-2, (props.width)*2, 3, props.onClick, props.onScroll),
    }
end)
