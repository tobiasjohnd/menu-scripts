local menuhelper = require("menuhelpers")

local home = os.getenv("HOME") or "/home"
local trash_files = home .. "/.local/share/Trash/files"
local trash_info = home .. "/.local/share/Trash/info"
local bookmarks_file = home .. "/.config/menu-scripts/file_bookmarks.txt"
local home_pattern = "^" .. home:gsub("%-", "%%-")

local M = {}
M.home = home

function M.abbreviate_path(path)
    return path:gsub(home_pattern, "~")
end

function M.copy_to_clipboard(text)
    if not text or text == "" then return end
    local session_type = os.getenv("XDG_SESSION_TYPE") or ""
    local cmd
    if session_type == "wayland" and menuhelper.command_exists("wl-copy") then
        cmd = "wl-copy"
    elseif menuhelper.command_exists("xclip") then
        cmd = "xclip -i -selection clipboard"
    else
        menuhelper.select({ "No clipboard tool found" })
        return
    end
    local h = io.popen(cmd, "w")
    if h then
        h:write(text); h:close()
    end
end

function M.is_archive(name)
    return name:match("%.tar%.[gbx]z[2]?$") or name:match("%.tgz$")
        or name:match("%.zip$") or name:match("%.7z$") or name:match("%.rar$")
end

function M.list_dir(path)
    local dirs, files = {}, {}
    local h = io.popen("ls -1AF --group-directories-first " .. menuhelper.shell_escape(path) .. " 2>/dev/null")
    if not h then return dirs, files end
    for line in h:lines() do
        local suffix = line:sub(-1)
        if suffix == "/" then
            dirs[#dirs + 1] = line
        elseif suffix == "@" then
            local name = line:sub(1, -2)
            local check = io.popen("test -d " .. menuhelper.shell_escape(path .. "/" .. name) .. " && echo d")
            local is_d = check and check:read("*a"):match("d")
            if check then check:close() end
            if is_d then dirs[#dirs + 1] = name .. "/" else files[#files + 1] = name end
        elseif suffix == "*" or suffix == "|" or suffix == "=" or suffix == ">" then
            files[#files + 1] = line:sub(1, -2)
        else
            files[#files + 1] = line
        end
    end
    h:close()
    return dirs, files
end

function M.trash_item(filepath)
    os.execute("mkdir -p " .. menuhelper.shell_escape(trash_files) ..
        " " .. menuhelper.shell_escape(trash_info))
    local name = filepath:match("([^/]+)$")
    local dest = trash_files .. "/" .. name
    local i = 1
    while io.open(dest, "r") do
        io.close(io.open(dest, "r"))
        dest = trash_files .. "/" .. name .. "." .. i
        i = i + 1
    end
    local trash_name = dest:match("([^/]+)$")
    local f = io.open(trash_info .. "/" .. trash_name .. ".trashinfo", "w")
    if f then
        f:write("[Trash Info]\nPath=" .. filepath ..
            "\nDeletionDate=" .. os.date("%Y-%m-%dT%H:%M:%S") .. "\n")
        f:close()
    end
    os.execute("mv " .. menuhelper.shell_escape(filepath) .. " " .. menuhelper.shell_escape(dest))
end

function M.in_trash(current)
    return current:find(trash_files, 1, true) == 1
end

local function read_bookmarks()
    local bmarks = {}
    local f = io.open(bookmarks_file, "r")
    if not f then return bmarks end
    for line in f:lines() do
        if line ~= "" then bmarks[#bmarks + 1] = line end
    end
    f:close()
    return bmarks
end

local function write_bookmarks(bmarks)
    os.execute("mkdir -p " .. menuhelper.shell_escape(bookmarks_file:match("(.*/)")))
    local f = io.open(bookmarks_file, "w")
    if f then
        for _, b in ipairs(bmarks) do f:write(b .. "\n") end
        f:close()
    end
end

-- Re-export read for files.lua bookmarks_menu
M.read_bookmarks = read_bookmarks

function M.add_bookmark(path)
    local bmarks = read_bookmarks()
    for _, b in ipairs(bmarks) do
        if b == path then return end
    end
    local f = io.open(bookmarks_file, "a")
    if f then
        f:write(path .. "\n"); f:close()
    end
end

function M.remove_bookmark(path)
    local bmarks = read_bookmarks()
    local filtered = {}
    for _, b in ipairs(bmarks) do
        if b ~= path then filtered[#filtered + 1] = b end
    end
    write_bookmarks(filtered)
end

function M.compress_from_dir(cwd)
    local dirs, files = M.list_dir(cwd)
    local all = {}
    for _, d in ipairs(dirs) do all[#all + 1] = d end
    for _, f in ipairs(files) do all[#all + 1] = f end
    if #all == 0 then
        menuhelper.select({ "(empty directory)" })
        return
    end
    local pick = menuhelper.select(all)
    if not pick then return end

    local formats = { "tar.gz", "tar.bz2", "tar.xz", "zip", "7z" }
    local format = menuhelper.select(formats)
    if not format then return end

    local name = menuhelper.prompt("Archive name (without extension):")
    if not name then return end

    local item_name = pick:match("/$") and pick:sub(1, -2) or pick
    local escaped_item = menuhelper.shell_escape(item_name)
    local escaped_cwd = menuhelper.shell_escape(cwd)
    local escaped_archive = menuhelper.shell_escape(cwd .. "/" .. name .. "." .. format)

    local cmds = {
        ["tar.gz"]  = "tar czf " .. escaped_archive .. " -C " .. escaped_cwd .. " " .. escaped_item,
        ["tar.bz2"] = "tar cjf " .. escaped_archive .. " -C " .. escaped_cwd .. " " .. escaped_item,
        ["tar.xz"]  = "tar cJf " .. escaped_archive .. " -C " .. escaped_cwd .. " " .. escaped_item,
        ["zip"]     = "cd " .. escaped_cwd .. " && zip -r " .. escaped_archive .. " " .. escaped_item,
        ["7z"]      = "cd " .. escaped_cwd .. " && 7z a " .. escaped_archive .. " " .. escaped_item,
    }
    local cmd = cmds[format]
    if cmd then os.execute(cmd) end
end

function M.extract_archive(filepath, cwd)
    local escaped = menuhelper.shell_escape(filepath)
    local dest = menuhelper.shell_escape(cwd)
    local extract_cmds = {
        ["tar%.gz$"]  = "tar xzf " .. escaped .. " -C " .. dest,
        ["tgz$"]      = "tar xzf " .. escaped .. " -C " .. dest,
        ["tar%.bz2$"] = "tar xjf " .. escaped .. " -C " .. dest,
        ["tar%.xz$"]  = "tar xJf " .. escaped .. " -C " .. dest,
        ["zip$"]      = "unzip -o " .. escaped .. " -d " .. dest,
        ["7z$"]       = "7z x " .. escaped .. " -o" .. dest,
        ["rar$"]      = "unrar x " .. escaped .. " " .. dest,
    }
    for pattern, cmd in pairs(extract_cmds) do
        if filepath:match("%." .. pattern) then
            os.execute(cmd)
            return
        end
    end
end

function M.paste_items(items, op, dest)
    local cmd_prefix = op == "copy" and "cp -r " or "mv "
    local escaped_dest = menuhelper.shell_escape(dest .. "/")
    for _, item in ipairs(items) do
        os.execute(cmd_prefix .. menuhelper.shell_escape(item) .. " " .. escaped_dest)
    end
end

return M
