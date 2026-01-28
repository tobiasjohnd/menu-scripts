local menuhelper = require("menuhelpers")

local MIN_PERCENT = 10

local function get_brightness()
    local h = io.popen("brightnessctl -c backlight -m 2>/dev/null")
    if not h then return nil end
    local out = h:read("*a")
    h:close()
    local percent = out:match(",(%d+)%%,")
    return percent and tonumber(percent) or nil
end

local function set_brightness(percent)
    if percent < MIN_PERCENT then percent = MIN_PERCENT end
    if percent > 100 then percent = 100 end
    os.execute("brightnessctl -c backlight set " .. percent .. "% >/dev/null 2>&1")
end

return {
    name = "Brightness",
    description = "Adjust screen brightness",
    category = "options",

    execute = function()
        if not menuhelper.command_exists("brightnessctl") then
            menuhelper.select({ "brightnessctl not found" })
            return nil
        end

        -- Check for a real backlight device (not just keyboard LEDs)
        local h = io.popen("brightnessctl -l -c backlight 2>/dev/null")
        local bl_out = h and h:read("*a") or ""
        if h then h:close() end
        if not bl_out:match("Device") then
            menuhelper.select({ "No backlight device found" })
            return nil
        end

        while true do
            local current = get_brightness()
            local current_label = current and ("Current: " .. current .. "%") or "Current: unknown"
            local options = { "[Back]", current_label, "Custom", "---" }

            for i = 100, MIN_PERCENT, -10 do
                local marker = (current and current == i) and "* " or "  "
                options[#options + 1] = marker .. i .. "%"
            end

            local selection = menuhelper.select(options)
            if not selection or selection == "[Back]" then return nil end

            if selection == "Custom" then
                local input = menuhelper.prompt("Brightness % (" .. MIN_PERCENT .. "-100):")
                local val = tonumber(input)
                if val then set_brightness(val) end
            elseif selection:match("%d+%%$") then
                local val = tonumber(selection:match("(%d+)%%$"))
                if val then set_brightness(val) end
            end
        end
    end
}
