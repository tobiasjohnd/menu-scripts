local config = require("config")

local M = {}

function M.shell_escape(str)
    if not str then return "" end
    return "'" .. str:gsub("'", "'\\''") .. "'"
end

local function get_menu_cmd()
    local cfg = config:get_config()
    if cfg.menu_options ~= "" then
        return cfg.menu_program .. " " .. cfg.menu_options
    end
    return cfg.menu_program
end

function M.select(options)
    if type(options) ~= "table" then
        error("options must be a table")
    end
    local handle = io.popen("echo " .. M.shell_escape(table.concat(options, "\n")) .. " | " .. get_menu_cmd())
    if not handle then return nil end
    local selection = handle:read("*l")
    handle:close()
    return selection
end

function M.prompt(prompt_text)
    local handle = io.popen("echo '' | " .. get_menu_cmd() .. " -p " .. M.shell_escape(prompt_text))
    if not handle then return nil end
    local result = handle:read("*l")
    handle:close()
    return result and result ~= "" and result:match("^%s*(.-)%s*$") or nil
end

function M.command_exists(cmd)
    local handle = io.popen("which " .. cmd .. " 2>/dev/null")
    if not handle then return false end
    local result = handle:read("*l")
    handle:close()
    return result and result ~= ""
end

return M
