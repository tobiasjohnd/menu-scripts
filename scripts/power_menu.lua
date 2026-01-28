local menuhelper = require("menuhelpers")

local function confirm(action, cmd)
    if menuhelper.select({ "Yes", "No" }) == "Yes" then
        os.execute(cmd)
        return "exit"
    end
end

return {
    name = "Logout/Shutdown Menu",
    description = "Logout, reboot, or shutdown",

    execute = function()
        while true do
            local selection = menuhelper.select({ "Logout", "Reboot", "Shutdown", "[Back]" })

            if selection == "Logout" then
                os.execute("loginctl terminate-user " .. os.getenv("USER") .. " &")
                return "exit"
            elseif selection == "Reboot" then
                local result = confirm("reboot", "systemctl reboot &")
                if result then return result end
            elseif selection == "Shutdown" then
                local result = confirm("shutdown", "systemctl poweroff &")
                if result then return result end
            else
                return nil
            end
        end
    end
}
