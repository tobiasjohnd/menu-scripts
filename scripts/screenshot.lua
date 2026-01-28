local menuhelper = require("menuhelpers")

return {
    name = "Screenshot",
    description = "Take a screenshot with flameshot",
    category = "utilities",

    execute = function()
        if not menuhelper.command_exists("flameshot") then
            menuhelper.select({ "Flameshot not found" })
            return nil
        end

        local selection = menuhelper.select({ "GUI Mode", "Full Screen", "[Back]" })

        if selection == "GUI Mode" then
            os.execute("flameshot gui &")
            return "exit"
        elseif selection == "Full Screen" then
            os.execute("flameshot full &")
            return "exit"
        end
        return nil
    end
}
