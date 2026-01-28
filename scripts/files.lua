local menuhelper = require("menuhelpers")
local config = require("config")
local fh = require("file_helpers")

local state = {
    current = fh.home,
    history = {},
    marked = {},
    marked_op = nil,
}

local function navigate(path)
    state.history[#state.history + 1] = state.current
    if #state.history > 50 then table.remove(state.history, 1) end
    state.current = path
end

local function mark(filepath, op)
    state.marked = { filepath }
    state.marked_op = op
end

local function expand_pick(pick)
    return pick and pick ~= "[Back]" and pick ~= "---" and pick:gsub("^~", fh.home)
end

local function pick_path(paths)
    local options = { "[Back]" }
    for _, p in ipairs(paths) do options[#options + 1] = fh.abbreviate_path(p) end
    return expand_pick(menuhelper.select(options))
end

local function bookmark_paths()
    local bmarks = fh.read_bookmarks()
    local abbrevs = {}
    for _, b in ipairs(bmarks) do abbrevs[#abbrevs + 1] = fh.abbreviate_path(b) end
    return bmarks, abbrevs
end

local function item_action(filepath, is_dir)
    local cfg = config:get_config()
    local name = filepath:match("([^/]+)/?$")
    local escaped = menuhelper.shell_escape(filepath)
    local options = { "[Back]" }

    if not is_dir then
        options[#options + 1] = "Open"
        options[#options + 1] = "Edit"
    end
    options[#options + 1] = "Copy Path"
    options[#options + 1] = "Cut"
    options[#options + 1] = "Copy"
    options[#options + 1] = "Rename"
    options[#options + 1] = fh.in_trash(state.current) and "Delete" or "Wastebin"
    if not is_dir and fh.is_archive(name) then
        options[#options + 1] = "Extract Here"
    end

    local action = menuhelper.select(options)
    if not action or action == "[Back]" then return end

    local actions = {
        ["Open"]         = function()
            os.execute("xdg-open " .. escaped .. " &")
            return "exit"
        end,
        ["Edit"]         = function()
            os.execute(cfg.terminal .. " -e " .. cfg.editor .. " " .. escaped .. " &")
            return "exit"
        end,
        ["Copy Path"]    = function() fh.copy_to_clipboard(filepath) end,
        ["Cut"]          = function() mark(filepath, "move") end,
        ["Copy"]         = function() mark(filepath, "copy") end,
        ["Wastebin"]     = function() fh.trash_item(filepath) end,
        ["Extract Here"] = function() fh.extract_archive(filepath, state.current) end,
        ["Rename"]       = function()
            local new_name = menuhelper.prompt("New name for " .. name .. ":")
            if new_name and new_name ~= "" and new_name ~= name then
                os.execute("mv " .. escaped .. " " .. menuhelper.shell_escape(state.current .. "/" .. new_name))
            end
        end,
        ["Delete"]       = function()
            local confirm = menuhelper.select({ "Yes, delete " .. name, "No" })
            if confirm and confirm:match("^Yes") then
                os.execute("rm -rf " .. escaped)
            end
        end,
    }
    local fn = actions[action]
    if fn then return fn() end
end

local function create_prompt(label, cmd)
    return function()
        local name = menuhelper.prompt(label .. " name:")
        if name and name ~= "" then
            os.execute(cmd .. " " .. menuhelper.shell_escape(state.current .. "/" .. name))
        end
    end
end

local function actions_menu()
    local options = { "[Back]", "New File", "New Directory", "History",
        "Bookmark This Dir", "Compress" }
    if #state.marked > 0 then
        table.insert(options, 4, "Paste Here (" .. state.marked_op .. " " .. #state.marked .. ")")
    end

    local selection = menuhelper.select(options)
    if not selection or selection == "[Back]" then return end

    local actions = {
        ["New File"]          = create_prompt("File", "touch"),
        ["New Directory"]     = create_prompt("Directory", "mkdir -p"),
        ["Bookmark This Dir"] = function() fh.add_bookmark(state.current) end,
        ["Compress"]          = function() fh.compress_from_dir(state.current) end,
        ["History"]           = function()
            local reversed = {}
            for i = #state.history, 1, -1 do reversed[#reversed + 1] = state.history[i] end
            local path = pick_path(reversed)
            if path then navigate(path) end
        end,
    }

    if selection:match("^Paste Here") then
        fh.paste_items(state.marked, state.marked_op, state.current)
        if state.marked_op == "move" then
            state.marked = {}
            state.marked_op = nil
        end
    else
        local fn = actions[selection]
        if fn then fn() end
    end
end

local function bookmarks_menu()
    local bmarks, abbrevs = bookmark_paths()
    if #bmarks == 0 then
        menuhelper.select({ "(no bookmarks)" })
        return
    end
    local options = { "[Back]", "Remove Bookmark", "---" }
    for _, a in ipairs(abbrevs) do options[#options + 1] = a end

    local pick = menuhelper.select(options)
    if not pick or pick == "[Back]" then return end
    if pick == "Remove Bookmark" then
        local rm_path = pick_path(bmarks)
        if rm_path then fh.remove_bookmark(rm_path) end
        return
    end
    local path = expand_pick(pick)
    if path then navigate(path) end
end

return {
    name = "File Manager",
    description = "Browse and open files",
    category = "utilities",

    execute = function()
        state.current = fh.home
        state.history = {}
        state.marked = {}
        state.marked_op = nil

        while true do
            local dirs, files = fh.list_dir(state.current)
            local options = { "[Back]", "../", "Actions", "Bookmarks" }

            if #dirs == 0 and #files == 0 then
                options[#options + 1] = "(empty)"
            else
                if #dirs > 0 then
                    options[#options + 1] = "---"
                    for _, d in ipairs(dirs) do options[#options + 1] = d end
                end
                if #files > 0 then
                    options[#options + 1] = "---"
                    for _, f in ipairs(files) do options[#options + 1] = f end
                end
            end

            local selection = menuhelper.select(options)
            if not selection or selection == "[Back]" then return nil end

            local actions = {
                ["../"] = function()
                    navigate(state.current:match("^(.+)/[^/]+$") or "/")
                end,
                ["Actions"] = function() actions_menu() end,
                ["Bookmarks"] = function() bookmarks_menu() end,
                ["---"] = function() end,
                ["(empty)"] = function() end,
            }
            local fn = actions[selection]
            if fn then
                fn()
            elseif selection:match("/$") then
                local dirpath = state.current .. "/" .. selection:sub(1, -2)
                local choice = menuhelper.select({ "[Back]", "Open", "Actions" })
                local dir_actions = {
                    ["Open"] = function() navigate(dirpath) end,
                    ["Actions"] = function() return item_action(dirpath, true) end,
                }
                local dir_fn = dir_actions[choice]
                if dir_fn then
                    local result = dir_fn()
                    if result then return result end
                end
            else
                local result = item_action(state.current .. "/" .. selection, false)
                if result then return result end
            end
        end
    end
}
