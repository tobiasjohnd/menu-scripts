local menuhelper = require("menuhelpers")

local function get_processes()
    local h = io.popen("ps -eo pid,comm --no-headers --sort=comm 2>/dev/null")
    if not h then return {} end
    local procs = {}
    for line in h:lines() do
        local pid, name = line:match("^%s*(%d+)%s+(.+)$")
        if pid and name then
            procs[#procs + 1] = { pid = pid, name = name }
        end
    end
    h:close()
    return procs
end

local function kill_submenu(proc)
    local action = menuhelper.select({ "[Cancel]", "Kill", "Force Kill" })
    if not action or action == "[Cancel]" then return end

    local actions = {
        ["Kill"]       = function() os.execute("kill " .. proc.pid) end,
        ["Force Kill"] = function() os.execute("kill -9 " .. proc.pid) end,
    }
    local fn = actions[action]
    if fn then fn() end
end

return {
    name = "Process Killer",
    description = "Kill running processes",
    category = "system",

    execute = function()
        while true do
            local options = { "[Back]", "---" }
            local proc_map = {}
            local procs = get_processes()

            for _, proc in ipairs(procs) do
                local display = proc.name .. " (" .. proc.pid .. ")"
                options[#options + 1] = display
                proc_map[display] = proc
            end

            local selection = menuhelper.select(options)
            if not selection or selection == "[Back]" then return nil end

            if proc_map[selection] then
                kill_submenu(proc_map[selection])
            end
        end
    end
}
