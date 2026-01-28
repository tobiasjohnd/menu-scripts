local menuhelper = require("menuhelpers")

local function wifi_enabled()
    local h = io.popen("nmcli radio wifi 2>/dev/null")
    if not h then return false end
    local out = h:read("*a"):match("%S+")
    h:close()
    return out == "enabled"
end

local function toggle_wifi()
    local on = wifi_enabled()
    os.execute("nmcli radio wifi " .. (on and "off" or "on"))
end

local function get_networks()
    local h = io.popen('nmcli -t -f SSID,SIGNAL,SECURITY,IN-USE device wifi list 2>/dev/null')
    if not h then return {} end
    local networks, seen = {}, {}
    for line in h:lines() do
        local ssid, signal, security, in_use = line:match("^(.-):(%d+):(.-):(.-)$")
        if ssid and ssid ~= "" and not seen[ssid] then
            seen[ssid] = true
            networks[#networks + 1] = {
                ssid = ssid,
                signal = tonumber(signal) or 0,
                security = security or "",
                connected = in_use == "*",
            }
        end
    end
    h:close()
    table.sort(networks, function(a, b)
        if a.connected ~= b.connected then return a.connected end
        return a.signal > b.signal
    end)
    return networks
end

local function get_saved_connections()
    local h = io.popen('nmcli -t -f NAME,TYPE connection show 2>/dev/null')
    if not h then return {} end
    local saved = {}
    for line in h:lines() do
        local name, ctype = line:match("^(.-):(.+)$")
        if name and ctype:match("wireless") then
            saved[name] = true
        end
    end
    h:close()
    return saved
end

local function connect(ssid, is_saved)
    if is_saved then
        os.execute("nmcli connection up " .. menuhelper.shell_escape(ssid) .. " &")
    else
        local password = menuhelper.prompt("Password for " .. ssid .. ":")
        if not password then return end
        os.execute("nmcli device wifi connect " .. menuhelper.shell_escape(ssid)
            .. " password " .. menuhelper.shell_escape(password) .. " &")
    end
end

local function disconnect(ssid)
    os.execute("nmcli connection down " .. menuhelper.shell_escape(ssid) .. " &")
end

local function forget(ssid)
    os.execute("nmcli connection delete " .. menuhelper.shell_escape(ssid))
end

return {
    name = "WiFi",
    description = "Manage WiFi connections",
    category = "options",

    execute = function()
        if not menuhelper.command_exists("nmcli") then
            menuhelper.select({ "nmcli not found (install NetworkManager)" })
            return nil
        end

        while true do
            local enabled = wifi_enabled()
            local wifi_label = enabled and "WiFi: ON" or "WiFi: OFF"
            local options = { "[Back]", wifi_label, "Scan", "Refresh", "---" }
            local network_map = {}

            if enabled then
                local networks = get_networks()
                local saved = get_saved_connections()

                if #networks == 0 then
                    options[#options + 1] = "(no networks found)"
                else
                    for _, net in ipairs(networks) do
                        local prefix = net.connected and "* " or (saved[net.ssid] and "+ " or "- ")
                        local lock = net.security ~= "" and " [" .. net.security .. "]" or ""
                        local display = prefix .. net.ssid .. " (" .. net.signal .. "%)" .. lock
                        options[#options + 1] = display
                        network_map[display] = { ssid = net.ssid, connected = net.connected, saved = saved[net.ssid] }
                    end
                end
            else
                options[#options + 1] = "(wifi off)"
            end

            local selection = menuhelper.select(options)
            if not selection or selection == "[Back]" then return nil end

            local actions = {
                [wifi_label] = toggle_wifi,
                ["Scan"] = function() os.execute("nmcli device wifi rescan 2>/dev/null &") end,
                ["Refresh"] = function() end,
            }
            local fn = actions[selection]
            if fn then
                fn()
            elseif network_map[selection] then
                local net = network_map[selection]
                local net_options = { "[Cancel]" }
                if net.connected then
                    net_options[#net_options + 1] = "Disconnect"
                else
                    net_options[#net_options + 1] = "Connect"
                end
                if net.saved then
                    net_options[#net_options + 1] = "Forget"
                end

                local action = menuhelper.select(net_options)
                if action and action ~= "[Cancel]" then
                    local net_actions = {
                        ["Connect"]    = function() connect(net.ssid, net.saved) end,
                        ["Disconnect"] = function() disconnect(net.ssid) end,
                        ["Forget"]     = function() forget(net.ssid) end,
                    }
                    local nfn = net_actions[action]
                    if nfn then nfn() end
                end
            end
        end
    end
}
