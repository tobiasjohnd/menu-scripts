local MenuBuilder = {}

local scripts_base_path = ""
local flat_mode = true

function MenuBuilder:init(scripts_path)
    scripts_base_path = scripts_path
end

function MenuBuilder:set_flat_mode(enabled)
    flat_mode = enabled
end

local function load_all_scripts()
    local scripts = {}
    local handle = io.popen('find "' .. scripts_base_path .. '" -maxdepth 1 -type f -name "*.lua" 2>/dev/null')
    if not handle then return scripts end

    for filepath in handle:lines() do
        local ok, script = pcall(dofile, filepath)
        if ok and type(script) == "table" and script.name and type(script.execute) == "function" then
            script.filepath = filepath
            scripts[#scripts + 1] = script
        end
    end
    handle:close()
    return scripts
end

local function generate_folders(scripts)
    local seen, folders = {}, {}
    for _, script in ipairs(scripts) do
        if script.category and not seen[script.category] then
            seen[script.category] = true
            folders[#folders + 1] = {
                name = script.category:sub(1, 1):upper() .. script.category:sub(2),
                category = script.category,
            }
        end
    end
    table.sort(folders, function(a, b) return a.name < b.name end)
    return folders
end

function MenuBuilder:build_menu(current_folder)
    local all_scripts = load_all_scripts()
    local options, item_map = {}, {}

    if not current_folder then
        if not flat_mode then
            for _, folder in ipairs(generate_folders(all_scripts)) do
                local display = folder.name .. "/"
                options[#options + 1] = display
                item_map[display] = { type = "folder", folder = folder }
            end
        end

        for _, script in ipairs(all_scripts) do
            if flat_mode or not script.category then
                local display = "!" .. script.name
                options[#options + 1] = display
                item_map[display] = { type = "script", script = script }
            end
        end

        local desktop_entry = require("desktop_entry")
        for _, app in ipairs(desktop_entry:get_desktop_entries()) do
            if not app.hidden and app.exec then
                options[#options + 1] = app.name
                item_map[app.name] = { type = "desktop_app", app = app }
            end
        end
    else
        options[#options + 1] = "../"
        item_map["../"] = { type = "parent" }

        for _, script in ipairs(all_scripts) do
            if script.category == current_folder.category then
                local display = "!" .. script.name
                options[#options + 1] = display
                item_map[display] = { type = "script", script = script }
            end
        end
    end

    return options, item_map
end

function MenuBuilder:execute_script(script)
    if not script or not script.execute then return nil end
    local ok, result = pcall(script.execute)
    if not ok then
        require("menuhelpers").select({ "Script error: " .. tostring(result) })
        return nil
    end
    return result
end

return MenuBuilder
