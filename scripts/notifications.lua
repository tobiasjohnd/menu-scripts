local menuhelper = require("menuhelpers")

local function dunst_running()
    local h = io.popen("pgrep -x dunst >/dev/null 2>&1 && echo yes || echo no")
    if not h then return false end
    local out = h:read("*a"):match("%S+")
    h:close()
    return out == "yes"
end

local function is_paused()
    local h = io.popen("dunstctl is-paused 2>/dev/null")
    if not h then return false end
    local out = h:read("*a"):match("%S+")
    h:close()
    return out == "true"
end

local function get_history()
    local h = io.popen(
        [[dunstctl history | jq -r '.data[0][] | "\(.appname.data)\t\(.summary.data)\t\(.body.data)"' 2>/dev/null]])
    if not h then return {} end
    local items = {}
    for line in h:lines() do
        local app, summary, body = line:match("^(.-)\t(.-)\t(.*)$")
        if app then
            local display = ""
            if app ~= "" then display = "[" .. app .. "] " end
            if summary ~= "" then display = display .. summary end
            if body ~= "" then display = display .. ": " .. body end
            if display ~= "" then
                items[#items + 1] = display:gsub("\n", " "):sub(1, 120)
            end
        end
    end
    h:close()
    return items
end

return {
    name = "Notifications",
    description = "View notification history and toggle do-not-disturb",
    category = "utilities",

    execute = function()
        if not menuhelper.command_exists("dunstctl") then
            menuhelper.select({ "dunstctl not found (install dunst)" })
            return nil
        end

        if not dunst_running() then
            menuhelper.select({ "dunst is not running" })
            return nil
        end

        while true do
            local dnd_label = is_paused() and "DND: ON" or "DND: OFF"
            local options = { "[Back]", "Clear", dnd_label, "---" }
            local history = get_history()
            if #history == 0 then
                options[#options + 1] = "(no notifications)"
            else
                for _, item in ipairs(history) do
                    options[#options + 1] = item
                end
            end

            local selection = menuhelper.select(options)
            if not selection or selection == "[Back]" then return nil end

            local actions = {
                ["Clear"] = function() os.execute("dunstctl history-clear") end,
                [dnd_label] = function() os.execute("dunstctl set-paused toggle") end,
            }
            local fn = actions[selection]
            if fn then fn() end
        end
    end
}
