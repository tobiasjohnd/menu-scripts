local DesktopEntry = {}

DesktopEntry.SYSTEM_DESKTOP_ENTRIES = { "/usr/share/applications", "/usr/local/share/applications" }
DesktopEntry.USER_DESKTOP_ENTRIES = os.getenv("HOME") .. "/.local/share/applications"

function DesktopEntry:get_desktop_files(directory)
    local files = {}
    local p = io.popen('find "' .. directory .. '" -type f -name "*.desktop" 2>/dev/null')
    if p then
        for file in p:lines() do files[#files + 1] = file end
        p:close()
    end
    return files
end

function DesktopEntry:parse_desktop_file(filepath)
    local file = io.open(filepath, "r")
    if not file then return nil end

    local entry = { name = nil, exec = nil, terminal = false, hidden = false, icon = nil }
    local in_section = false

    for line in file:lines() do
        if line:match("^%[Desktop Entry%]") then
            in_section = true
        elseif line:match("^%[.+%]") then
            in_section = false
        elseif in_section then
            local key, value = line:match("^(%w+)=(.+)")
            if key and value then
                if key == "Name" and not entry.name then
                    entry.name = value
                elseif key == "Exec" and not entry.exec then
                    entry.exec = value
                elseif key == "Terminal" then
                    entry.terminal = value:lower() == "true"
                elseif key == "NoDisplay" or key == "Hidden" then
                    entry.hidden = entry.hidden or value:lower() == "true"
                elseif key == "OnlyShowIn" then
                    entry.hidden = true
                elseif key == "Icon" and not entry.icon then
                    entry.icon = value
                end
            end
        end
    end
    file:close()

    return entry.name and entry or nil
end

function DesktopEntry:get_desktop_entries()
    local entries, seen = {}, {}

    local dirs = { self.USER_DESKTOP_ENTRIES }
    for _, dir in ipairs(self.SYSTEM_DESKTOP_ENTRIES) do dirs[#dirs + 1] = dir end

    for _, directory in ipairs(dirs) do
        for _, filepath in ipairs(self:get_desktop_files(directory)) do
            local parsed = self:parse_desktop_file(filepath)
            if parsed and not seen[parsed.name] then
                seen[parsed.name] = true
                entries[#entries + 1] = {
                    filepath = filepath,
                    name = parsed.name,
                    exec = parsed.exec,
                    terminal = parsed.terminal,
                    hidden = parsed.hidden,
                    icon = parsed.icon,
                    in_user_dir = (directory == self.USER_DESKTOP_ENTRIES),
                }
            end
        end
    end

    return entries
end

function DesktopEntry:get_entry_by_name(entries, name)
    for _, entry in ipairs(entries) do
        if entry.name == name then return entry end
    end
    return nil
end

function DesktopEntry:copy_desktop_file_to_user_dir(entry)
    os.execute('mkdir -p "' .. self.USER_DESKTOP_ENTRIES .. '"')
    local filename = entry.filepath:match("([^/]+)$")
    local new_filepath = self.USER_DESKTOP_ENTRIES .. "/" .. filename
    os.execute('cp "' .. entry.filepath .. '" "' .. new_filepath .. '"')
    entry.filepath = new_filepath
    entry.in_user_dir = true
    return entry
end

function DesktopEntry:launch_app(entry)
    local cmd = entry.exec and entry.exec:gsub("%%[fFuUicdk]", ""):gsub("%s+", " "):match("^%s*(.-)%s*$")
    if not cmd or cmd == "" then return end

    if entry.terminal then
        local config = require("config")
        local cfg = config:get_config()
        cmd = cfg.terminal .. " -e " .. cmd
    end

    os.execute("cd " .. (os.getenv("HOME") or "~") .. " && " .. cmd .. " &")
end

return DesktopEntry
