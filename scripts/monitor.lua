local menuhelper = require("menuhelpers")

-- Backend functions (xrandr) -- swap these for Wayland support

local function get_monitors()
    local h = io.popen("xrandr --query 2>/dev/null")
    if not h then return {} end
    local monitors = {}
    local current = nil
    for line in h:lines() do
        local name, state = line:match("^(%S+)%s+(connected.-)$")
        if name then
            local primary = state:match("primary") ~= nil
            local res, rate = state:match("(%d+x%d+)%+%d+%+%d+.*%s+(%d+%.%d+)%*")
            if not res then
                res = state:match("(%d+x%d+)%+%d+%+%d+")
            end
            current = {
                name = name,
                active = res ~= nil,
                primary = primary,
                resolution = res,
                rate = rate,
                modes = {},
            }
            monitors[#monitors + 1] = current
        elseif current and line:match("^%s+%d+x%d+") then
            local mode = line:match("^%s+(%d+x%d+)")
            local rates = {}
            for r in line:gmatch("(%d+%.%d+)") do
                rates[#rates + 1] = r
            end
            if mode then
                current.modes[#current.modes + 1] = { resolution = mode, rates = rates }
            end
        elseif line:match("^%S+%s+disconnected") then
            current = nil
        end
    end
    h:close()
    return monitors
end

local function set_resolution(output, mode, rate)
    local cmd = "xrandr --output " .. menuhelper.shell_escape(output) .. " --mode " .. menuhelper.shell_escape(mode)
    if rate then
        cmd = cmd .. " --rate " .. menuhelper.shell_escape(rate)
    end
    os.execute(cmd)
end

local function set_position(output, relation, relative)
    os.execute("xrandr --output " .. menuhelper.shell_escape(output) ..
        " --" .. relation .. " " .. menuhelper.shell_escape(relative))
end

local function set_primary(output)
    os.execute("xrandr --output " .. menuhelper.shell_escape(output) .. " --primary")
end

local function enable_output(output)
    os.execute("xrandr --output " .. menuhelper.shell_escape(output) .. " --auto")
end

local function disable_output(output)
    os.execute("xrandr --output " .. menuhelper.shell_escape(output) .. " --off")
end

-- Menu functions

local function resolution_submenu(monitor)
    local options = { "[Cancel]" }
    local mode_map = {}

    for _, mode in ipairs(monitor.modes) do
        for _, rate in ipairs(mode.rates) do
            local current = monitor.resolution == mode.resolution and monitor.rate == rate
            local prefix = current and "* " or "  "
            local display = prefix .. mode.resolution .. " @ " .. rate .. "Hz"
            options[#options + 1] = display
            mode_map[display] = { resolution = mode.resolution, rate = rate }
        end
    end

    local selection = menuhelper.select(options)
    if not selection or selection == "[Cancel]" then return end

    local picked = mode_map[selection]
    if picked then
        set_resolution(monitor.name, picked.resolution, picked.rate)
    end
end

local function position_submenu(monitor, monitors)
    local others = {}
    for _, m in ipairs(monitors) do
        if m.name ~= monitor.name and m.active then
            others[#others + 1] = m.name
        end
    end

    if #others == 0 then
        menuhelper.select({ "(no other active monitors)" })
        return
    end

    local relation = menuhelper.select({ "[Cancel]", "Left of", "Right of", "Above", "Below", "Mirror" })
    if not relation or relation == "[Cancel]" then return end

    local target = menuhelper.select(others)
    if not target then return end

    local relation_map = {
        ["Left of"]  = "left-of",
        ["Right of"] = "right-of",
        ["Above"]    = "above",
        ["Below"]    = "below",
        ["Mirror"]   = "same-as",
    }

    set_position(monitor.name, relation_map[relation], target)
end

local function monitor_submenu(monitor, monitors)
    local options = { "[Cancel]", "Resolution", "Position", "Primary" }
    options[#options + 1] = monitor.active and "Disable" or "Enable"

    local action = menuhelper.select(options)
    if not action or action == "[Cancel]" then return end

    local actions = {
        ["Resolution"] = function() resolution_submenu(monitor) end,
        ["Position"]   = function() position_submenu(monitor, monitors) end,
        ["Primary"]    = function() set_primary(monitor.name) end,
        ["Enable"]     = function() enable_output(monitor.name) end,
        ["Disable"]    = function() disable_output(monitor.name) end,
    }
    local fn = actions[action]
    if fn then fn() end
end

return {
    name = "Monitor",
    description = "Manage monitors and display settings",
    category = "options",

    execute = function()
        if not menuhelper.command_exists("xrandr") then
            menuhelper.select({ "xrandr not found" })
            return nil
        end

        while true do
            local monitors = get_monitors()
            local options = { "[Back]", "---" }
            local monitor_map = {}

            if #monitors == 0 then
                options[#options + 1] = "(no monitors found)"
            else
                for _, m in ipairs(monitors) do
                    local prefix = m.active and "* " or "- "
                    local info = m.resolution and (m.resolution .. (m.rate and ("@" .. m.rate .. "Hz") or "")) or
                    "inactive"
                    local display = prefix .. m.name .. " - " .. info
                    options[#options + 1] = display
                    monitor_map[display] = m
                end
            end

            local selection = menuhelper.select(options)
            if not selection or selection == "[Back]" then return nil end

            if monitor_map[selection] then
                monitor_submenu(monitor_map[selection], monitors)
            end
        end
    end
}
