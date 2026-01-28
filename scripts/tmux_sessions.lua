local menuhelper = require("menuhelpers")
local config = require("config")

local function sanitize_name(name)
    return name:gsub("%.", "_")
end

local function get_sessions()
    local h = io.popen("tmux list-sessions -F '#{session_name}\t#{session_windows}\t#{session_attached}' 2>/dev/null")
    if not h then return {} end
    local sessions = {}
    for line in h:lines() do
        local name, windows, attached = line:match("^(.-)\t(%d+)\t(%d+)$")
        if name then
            sessions[name] = {
                name = name,
                windows = tonumber(windows),
                attached = tonumber(attached) > 0,
            }
        end
    end
    h:close()
    return sessions
end

local function get_project_dirs(base)
    local escaped = menuhelper.shell_escape(base)
    local h = io.popen("find " .. escaped .. " -mindepth 1 -maxdepth 1 -type d 2>/dev/null | sort")
    if not h then return {} end
    local dirs = {}
    for line in h:lines() do
        local name = line:match("([^/]+)$")
        if name then
            dirs[#dirs + 1] = { name = name, path = line }
        end
    end
    h:close()
    return dirs
end

local function create_session(name, path)
    local cfg = config:get_config()
    local escaped_name = menuhelper.shell_escape(name)
    local escaped_path = menuhelper.shell_escape(path)

    os.execute("tmux new-session -ds " .. escaped_name .. " -c " .. escaped_path)

    local commands = cfg.tmux_session_commands
    if commands then
        for i, cmd in ipairs(commands) do
            os.execute("tmux new-window -t " ..
                escaped_name .. ":" .. (66 + i) .. " -c " .. escaped_path .. " " .. menuhelper.shell_escape(cmd))
        end
        os.execute("tmux select-window -t " .. escaped_name .. ":0")
    end
end

local function attach(name)
    local cfg = config:get_config()
    local terminal = cfg.terminal or os.getenv("TERMINAL") or "xterm"
    os.execute(terminal .. " -e tmux attach -t " .. menuhelper.shell_escape(name) .. " &")
end

local function session_submenu(session)
    local action = menuhelper.select({ "[Cancel]", "Attach", "Kill" })
    if not action or action == "[Cancel]" then return end

    local actions = {
        ["Attach"] = function()
            attach(session.name)
            return "exit"
        end,
        ["Kill"] = function()
            os.execute("tmux kill-session -t " .. menuhelper.shell_escape(session.name))
        end,
    }
    local fn = actions[action]
    if fn then return fn() end
end

return {
    name = "Tmux Sessions",
    description = "Manage tmux sessions and project directories",
    category = "productivity",

    execute = function()
        if not menuhelper.command_exists("tmux") then
            menuhelper.select({ "tmux not found" })
            return nil
        end

        local cfg = config:get_config()
        local base = menuhelper.expand_path(cfg.tmux_projects_dir or "~/Repos/")

        while true do
            local sessions = get_sessions()
            local dirs = get_project_dirs(base)
            local options = { "[Back]", "New Session", "---" }
            local entry_map = {}
            local seen = {}

            -- project dirs with session state
            for _, dir in ipairs(dirs) do
                local session_name = sanitize_name(dir.name)
                local session = sessions[session_name]
                local prefix
                if session and session.attached then
                    prefix = "* "
                elseif session then
                    prefix = "+ "
                else
                    prefix = "- "
                end
                local display = prefix .. dir.name
                options[#options + 1] = display
                entry_map[display] = { session = session, dir = dir }
                seen[session_name] = true
            end

            -- orphan sessions (no matching project dir)
            for name, session in pairs(sessions) do
                if not seen[name] then
                    local prefix = session.attached and "* " or "+ "
                    local display = prefix .. name .. " (" .. session.windows .. " windows)"
                    options[#options + 1] = display
                    entry_map[display] = { session = session }
                end
            end

            local selection = menuhelper.select(options)
            if not selection or selection == "[Back]" then return nil end

            if selection == "New Session" then
                local name = menuhelper.prompt("Session name")
                if name and name ~= "" then
                    local cfg = config:get_config()
                    local terminal = cfg.terminal or os.getenv("TERMINAL") or "xterm"
                    os.execute(terminal .. " -e tmux new-session -s " .. menuhelper.shell_escape(name) .. " &")
                    return "exit"
                end
            elseif entry_map[selection] then
                local entry = entry_map[selection]
                if entry.session then
                    local result = session_submenu(entry.session)
                    if result == "exit" then return "exit" end
                else
                    create_session(sanitize_name(entry.dir.name), entry.dir.path)
                    attach(sanitize_name(entry.dir.name))
                    return "exit"
                end
            end
        end
    end
}
