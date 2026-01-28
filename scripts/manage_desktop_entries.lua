local menuhelper = require("menuhelpers")
local config = require("config")
local desktop_entry = require("desktop_entry")

local function toggle_hide(entry)
    local file = io.open(entry.filepath, "r")
    if not file then return end
    local content = file:read("*all")
    file:close()
    if not content then return end

    if not content:find("Hidden=") then
        local _, end_idx = content:find("%[Desktop Entry%]\n")
        if end_idx then
            content = content:sub(1, end_idx) .. "Hidden=true\n" .. content:sub(end_idx + 1)
        end
    else
        content = entry.hidden
            and content:gsub("Hidden=true", "Hidden=false")
            or content:gsub("Hidden=false", "Hidden=true")
    end

    file = io.open(entry.filepath, "w")
    if file then
        file:write(content)
        file:close()
    end
end

local function edit_file(entry)
    local cfg = config:get_config()
    os.execute(cfg.terminal .. ' -e ' .. cfg.editor .. ' "' .. entry.filepath .. '"')
end

local function restore_file(entry)
    if not entry.in_user_dir then return end
    for _, dir in ipairs(desktop_entry.SYSTEM_DESKTOP_ENTRIES) do
        for _, filepath in ipairs(desktop_entry:get_desktop_files(dir)) do
            local parsed = desktop_entry:parse_desktop_file(filepath)
            if parsed and parsed.name == entry.name then
                os.execute('cp "' .. filepath .. '" "' .. entry.filepath .. '"')
                return
            end
        end
    end
end

local function rename_file(entry)
    local new_name = menuhelper.prompt("New name for " .. entry.name .. ":")
    if not new_name or new_name == entry.name then return end

    local file = io.open(entry.filepath, "r")
    if not file then return end
    local content = file:read("*all")
    file:close()
    if not content then return end

    content = content:gsub("Name=.+\n", "Name=" .. new_name .. "\n", 1)

    file = io.open(entry.filepath, "w")
    if file then
        file:write(content)
        file:close()
    end
end

return {
    name = "Manage Desktop Entries",
    description = "Hide, rename, edit, or restore .desktop files",
    category = "options",

    execute = function()
        local show_hidden = false

        while true do
            local entries = desktop_entry:get_desktop_entries()
            local toggle_label = show_hidden and "Hide Hidden" or "Show Hidden"
            local options = { "[Back]", toggle_label, "---" }

            local names = {}
            for _, entry in ipairs(entries) do
                if show_hidden or not entry.hidden then
                    names[#names + 1] = entry.name
                end
            end
            table.sort(names)

            if #names == 0 then
                options[#options + 1] = "(no entries)"
            else
                for _, name in ipairs(names) do
                    options[#options + 1] = name
                end
            end

            local selection = menuhelper.select(options)

            if not selection or selection == "[Back]" then
                return nil
            elseif selection == "Show Hidden" or selection == "Hide Hidden" then
                show_hidden = not show_hidden
            elseif selection ~= "---" and selection ~= "(no entries)" then
                local entry = desktop_entry:get_entry_by_name(entries, selection)
                if entry then
                    if not entry.in_user_dir then
                        entry = desktop_entry:copy_desktop_file_to_user_dir(entry)
                    end

                    local action = menuhelper.select({ "[Cancel]", "Toggle Hide", "Rename", "Edit", "Restore" })
                    if action and action ~= "[Cancel]" then
                        local entry_actions = {
                            ["Toggle Hide"] = function() toggle_hide(entry) end,
                            ["Rename"]      = function() rename_file(entry) end,
                            ["Edit"]        = function()
                                edit_file(entry); return "exit"
                            end,
                            ["Restore"]     = function() restore_file(entry) end,
                        }
                        local fn = entry_actions[action]
                        if fn then
                            local result = fn()
                            if result then return result end
                        end
                    end
                end
            end
        end
    end
}
