local configSchema = {
    settings = {
        dropItems = "boolean",
    },
    theme = {
        colors = {
            titleTextColor = "color",
            titleBgColor = "color",
            bgColor = "color",
            catagoryTextColor = "color",
            catagoryBgColor = "color",
            activeCatagoryBgColor = "color",
            logTextColor = "color",
            configEditor = {
                bgColor = "color",
                textColor = "color",
                buttonColor = "color",
                buttonTextColor = "color",
                inactiveButtonColor = "color",
                inactiveButtonTextColor = "color",
                scrollbarBgColor = "color",
                scrollbarColor = "color",
                inputBgColor = "color",
                inputTextColor = "color",
                errorBgColor = "color",
                errorTextColor = "color",
                toggleColor = "color",
                toggleBgColor = "color",
                toggleOnColor = "color",
                toggleOffColor = "color",
                unsavedChangesColor = "color",
                unsavedChangesTextColor = "color",
                modalBgColor = "color",
                modalTextColor = "color",
                modalBorderColor = "color",
            },
        },
        palette = {
            [colors.black] = "number",
            [colors.blue] = "number",
            [colors.purple] = "number",
            [colors.green] = "number",
            [colors.brown] = "number",
            [colors.gray] = "number",
            [colors.lightGray] = "number",
            [colors.red] = "number",
            [colors.orange] = "number",
            [colors.yellow] = "number",
            [colors.lime] = "number",
            [colors.cyan] = "number",
            [colors.magenta] = "number",
            [colors.pink] = "number",
            [colors.lightBlue] = "number",
            [colors.white] = "number"
        }
    }
}

return {
    configSchema = configSchema,
}