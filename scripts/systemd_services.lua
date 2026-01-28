local menuhelper = require("menuhelpers")
local config = require("config")

local function is_active(service)
    local h = io.popen("systemctl is-active " .. menuhelper.shell_escape(service) .. " 2>/dev/null")
    if not h then return false end
    local out = h:read("*l") or ""
    h:close()
    return out == "active"
end

local function is_enabled(service)
    local h = io.popen("systemctl is-enabled " .. menuhelper.shell_escape(service) .. " 2>/dev/null")
    if not h then return "" end
    local out = h:read("*l") or ""
    h:close()
    return out
end

local function get_all_services()
    local h = io.popen("systemctl list-unit-files --type=service --no-pager --plain --no-legend 2>/dev/null")
    if not h then return {} end
    local services = {}
    for line in h:lines() do
        local name, state = line:match("^(%S+%.service)%s+(%S+)")
        if name and state ~= "static" and state ~= "masked" and state ~= "indirect" then
            services[#services + 1] = { name = name, enabled_state = state, active = false }
        end
    end
    h:close()
    for _, svc in ipairs(services) do
        svc.active = is_active(svc.name)
        local dh = io.popen("systemctl show " ..
            menuhelper.shell_escape(svc.name) .. " --property=Description --value 2>/dev/null")
        if dh then
            svc.description = dh:read("*l") or ""
            dh:close()
        else
            svc.description = ""
        end
    end
    table.sort(services, function(a, b)
        if a.active ~= b.active then return a.active end
        local a_en = a.enabled_state == "enabled"
        local b_en = b.enabled_state == "enabled"
        if a_en ~= b_en then return a_en end
        return a.name < b.name
    end)
    return services
end

local function service_submenu(svc)
    local active = is_active(svc.name)
    local enabled_state = is_enabled(svc.name)
    local enabled = enabled_state == "enabled"

    local options = { "[Cancel]" }
    options[#options + 1] = "View Status"
    options[#options + 1] = "View Logs"
    options[#options + 1] = active and "Stop" or "Start"
    options[#options + 1] = "Restart"
    options[#options + 1] = enabled and "Disable" or "Enable"

    local action = menuhelper.select(options)
    if not action or action == "[Cancel]" then return nil end

    local escaped = menuhelper.shell_escape(svc.name)

    if action == "View Status" then
        local h = io.popen("systemctl status " .. escaped .. " 2>&1")
        if h then
            local lines = {}
            for line in h:lines() do
                lines[#lines + 1] = line
            end
            h:close()
            if #lines > 0 then
                menuhelper.select(lines)
            end
        end
        return nil
    end

    if action == "View Logs" then
        local cfg = config:get_config()
        local terminal = cfg.terminal or os.getenv("TERMINAL") or "xterm"
        os.execute(terminal .. " -e journalctl -u " .. escaped .. " -n 100 --follow &")
        return "exit"
    end

    local privileged_actions = {
        ["Start"]   = "start",
        ["Stop"]    = "stop",
        ["Restart"] = "restart",
        ["Enable"]  = "enable",
        ["Disable"] = "disable",
    }
    local cmd = privileged_actions[action]
    if cmd then
        os.execute("pkexec systemctl " .. cmd .. " " .. escaped .. " 2>/dev/null")
    end
    return nil
end

return {
    name = "Systemd Services",
    description = "Manage systemd services",
    category = "system",

    execute = function()
        if not menuhelper.command_exists("systemctl") then
            menuhelper.select({ "systemctl not found" })
            return nil
        end

        while true do
            local options = { "[Back]", "---" }
            local services = get_all_services()
            local service_map = {}

            for _, svc in ipairs(services) do
                local prefix = svc.active and "* " or (svc.enabled_state == "enabled" and "+ " or "- ")
                local desc = svc.description and svc.description ~= "" and (" - " .. svc.description) or ""
                local display = prefix .. svc.name .. desc
                options[#options + 1] = display
                service_map[display] = svc
            end

            local selection = menuhelper.select(options)
            if not selection or selection == "[Back]" then return nil end

            if service_map[selection] then
                local result = service_submenu(service_map[selection])
                if result == "exit" then return "exit" end
            end
        end
    end
}
