#!/usr/bin/env lua

local script_path = debug.getinfo(1, "S").source:match("@?(.*/)") or "./"
local BASE_PATH = script_path:gsub("/$", "")

package.path = package.path .. ";" .. BASE_PATH .. "/lua/?.lua"

local menuhelpers = require("menuhelpers")
local config = require("config")
local menu_builder = require("menu_builder")
local navigator = require("navigator")
local desktop_helper = require("desktop_entry")

local use_folders = false
for _, a in ipairs(arg or {}) do
    if a == "--folders" or a == "-f" then use_folders = true end
end

config:init(BASE_PATH)
menu_builder:init(BASE_PATH .. "/scripts")
menu_builder:set_flat_mode(not use_folders)

local handlers = {
    parent = function() navigator:go_back() end,
    folder = function(item) navigator:navigate_to(item.folder) end,
    desktop_app = function(item)
        desktop_helper:launch_app(item.app)
        return true
    end,
    script = function(item)
        local action = menu_builder:execute_script(item.script)
        if action == "exit" then return true end
        if action == "back" and not navigator:is_at_root() then navigator:go_back() end
    end,
}

while true do
    local folder = navigator:get_current_folder()
    local options, item_map = menu_builder:build_menu(folder)
    local selection = menuhelpers.select(options)

    if not selection then
        if navigator:is_at_root() then break end
        navigator:go_back()
    else
        local item = item_map[selection]
        if handlers[item.type] and handlers[item.type](item) then break end
    end
end
