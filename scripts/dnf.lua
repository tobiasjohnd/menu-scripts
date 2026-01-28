local menuhelper = require("menuhelpers")

local function notify(title, body)
    local cmd = "notify-send " .. menuhelper.shell_escape(title)
    if body then
        cmd = cmd .. " " .. menuhelper.shell_escape(body)
    end
    os.execute(cmd)
end

local function run_dnf(args)
    local h = io.popen("pkexec dnf " .. args .. " 2>&1")
    if not h then return "" end
    local out = h:read("*a") or ""
    h:close()
    return out
end

local function search_packages(term)
    local escaped = menuhelper.shell_escape(term)
    local installed, available = {}, {}

    local h = io.popen("dnf list --installed " .. escaped .. " 2>/dev/null")
    if h then
        for line in h:lines() do
            local name = line:match("^(%S+)%s+%S+%s+%S+")
            if name and not name:match("^[A-Z]") then
                installed[#installed + 1] = name
            end
        end
        h:close()
    end

    h = io.popen("dnf list --available " .. escaped .. " 2>/dev/null")
    if h then
        for line in h:lines() do
            local name = line:match("^(%S+)%s+%S+%s+%S+")
            if name and not name:match("^[A-Z]") then
                available[#available + 1] = name
            end
        end
        h:close()
    end

    return installed, available
end

local function package_submenu(pkg, is_installed)
    local options = { "[Cancel]", "View Info" }
    options[#options + 1] = is_installed and "Remove" or "Install"

    local action = menuhelper.select(options)
    if not action or action == "[Cancel]" then return end

    if action == "View Info" then
        local h = io.popen("dnf info " .. menuhelper.shell_escape(pkg) .. " 2>/dev/null")
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
        return
    end

    local cmd = is_installed and "remove" or "install"
    local output = run_dnf(cmd .. " -y " .. menuhelper.shell_escape(pkg))
    local ok = output:match("Complete!") ~= nil
    notify("DNF " .. cmd:sub(1, 1):upper() .. cmd:sub(2),
        ok and (pkg .. " " .. cmd .. (cmd == "remove" and "d" or "ed"))
        or ("Failed to " .. cmd .. " " .. pkg))
end

local function update_system()
    notify("DNF", "Starting system update...")
    local output = run_dnf("upgrade -y")
    if output:match("Nothing to do") then
        notify("DNF Update", "System is up to date")
    elseif output:match("Complete!") then
        notify("DNF Update", "Update complete")
    else
        notify("DNF Update", "Update failed")
    end
end

local function search_menu()
    local term = menuhelper.prompt("Search packages")
    if not term or term == "" then return end

    local installed, available = search_packages(term)

    if #installed == 0 and #available == 0 then
        menuhelper.select({ "(no packages found)" })
        return
    end

    local options = { "[Back]", "---" }
    local pkg_map = {}

    for _, pkg in ipairs(installed) do
        local display = "* " .. pkg
        options[#options + 1] = display
        pkg_map[display] = { name = pkg, installed = true }
    end
    for _, pkg in ipairs(available) do
        local display = "- " .. pkg
        options[#options + 1] = display
        pkg_map[display] = { name = pkg, installed = false }
    end

    local pick = menuhelper.select(options)
    if not pick or pick == "[Back]" then return end

    local entry = pkg_map[pick]
    if entry then
        package_submenu(entry.name, entry.installed)
    end
end

return {
    name = "DNF Packages",
    description = "Search, install, remove packages and run updates",
    category = "system",

    execute = function()
        if not menuhelper.command_exists("dnf") then
            menuhelper.select({ "dnf not found" })
            return nil
        end

        while true do
            local selection = menuhelper.select({ "[Back]", "Update System", "Search Packages" })
            if not selection or selection == "[Back]" then return nil end

            local actions = {
                ["Update System"]   = update_system,
                ["Search Packages"] = search_menu,
            }
            local fn = actions[selection]
            if fn then fn() end
        end
    end
}
