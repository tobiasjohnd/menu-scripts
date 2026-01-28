local menuhelper = require("menuhelpers")

local function bt_powered()
    local h = io.popen("bluetoothctl show 2>/dev/null")
    if not h then return false end
    local out = h:read("*a")
    h:close()
    return out:match("Powered:%s*yes") ~= nil
end

local function toggle_power()
    local on = bt_powered()
    os.execute("bluetoothctl power " .. (on and "off" or "on"))
end

local function get_devices()
    local h = io.popen("bluetoothctl devices 2>/dev/null")
    if not h then return {} end
    local devices = {}
    for line in h:lines() do
        local mac, name = line:match("^Device%s+(%S+)%s+(.+)$")
        if mac and name then
            devices[#devices + 1] = { mac = mac, name = name }
        end
    end
    h:close()
    return devices
end

local function get_device_info(mac)
    local h = io.popen("bluetoothctl info " .. menuhelper.shell_escape(mac) .. " 2>/dev/null")
    if not h then return {} end
    local out = h:read("*a")
    h:close()
    return {
        connected = out:match("Connected:%s*yes") ~= nil,
        paired = out:match("Paired:%s*yes") ~= nil,
        trusted = out:match("Trusted:%s*yes") ~= nil,
    }
end

local function device_action(mac, info)
    local options = { "[Cancel]" }
    options[#options + 1] = info.connected and "Disconnect" or "Connect"
    options[#options + 1] = info.trusted and "Untrust" or "Trust"
    options[#options + 1] = info.paired and "Unpair" or "Pair"
    options[#options + 1] = "Remove"

    local action = menuhelper.select(options)
    if not action or action == "[Cancel]" then return end

    local escaped = menuhelper.shell_escape(mac)
    local actions = {
        ["Connect"]    = function() os.execute("bluetoothctl connect " .. escaped) end,
        ["Disconnect"] = function() os.execute("bluetoothctl disconnect " .. escaped) end,
        ["Trust"]      = function() os.execute("bluetoothctl trust " .. escaped) end,
        ["Untrust"]    = function() os.execute("bluetoothctl untrust " .. escaped) end,
        ["Pair"]       = function() os.execute("bluetoothctl pair " .. escaped) end,
        ["Unpair"]     = function() os.execute("bluetoothctl cancel-pairing " .. escaped) end,
        ["Remove"]     = function() os.execute("bluetoothctl remove " .. escaped) end,
    }
    local fn = actions[action]
    if fn then fn() end
end

return {
    name = "Bluetooth",
    description = "Manage bluetooth devices",
    category = "options",

    execute = function()
        if not menuhelper.command_exists("bluetoothctl") then
            menuhelper.select({ "bluetoothctl not found" })
            return nil
        end

        while true do
            local powered = bt_powered()
            local power_label = powered and "Power: ON" or "Power: OFF"
            local options = { "[Back]", power_label, "Scan", "Refresh", "---" }
            local device_map = {}

            if powered then
                local devices = get_devices()
                if #devices == 0 then
                    options[#options + 1] = "(no devices)"
                else
                    local connected, paired, unpaired = {}, {}, {}
                    for _, dev in ipairs(devices) do
                        local info = get_device_info(dev.mac)
                        local entry = { dev = dev, info = info }
                        if info.connected then
                            connected[#connected + 1] = entry
                        elseif info.paired then
                            paired[#paired + 1] = entry
                        else
                            unpaired[#unpaired + 1] = entry
                        end
                    end
                    for _, group in ipairs({ connected, paired, unpaired }) do
                        for _, e in ipairs(group) do
                            local prefix = e.info.connected and "* " or (e.info.paired and "+ " or "- ")
                            local display = prefix .. e.dev.name
                            options[#options + 1] = display
                            device_map[display] = { mac = e.dev.mac, info = e.info }
                        end
                    end
                end
            else
                options[#options + 1] = "(bluetooth off)"
            end

            local selection = menuhelper.select(options)
            if not selection or selection == "[Back]" then return nil end

            local actions = {
                [power_label] = toggle_power,
                ["Scan"] = function() os.execute("bluetoothctl --timeout 10 scan on >/dev/null 2>&1 &") end,
                ["Refresh"] = function() end,
            }
            local fn = actions[selection]
            if fn then
                fn()
            elseif device_map[selection] then
                local dev = device_map[selection]
                device_action(dev.mac, dev.info)
            end
        end
    end
}
