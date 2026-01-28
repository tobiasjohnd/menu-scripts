local menuhelper = require("menuhelpers")

local function detect_tool()
    local session = os.getenv("XDG_SESSION_TYPE") or ""
    if session == "wayland" and menuhelper.command_exists("wl-copy") then return "wayland" end
    if menuhelper.command_exists("xclip") then return "x11" end
    return nil
end

return {
    name = "Clipboard Manager",
    description = "Manage clipboard content",
    category = "utilities",

    execute = function()
        local tool = detect_tool()
        if not tool then
            menuhelper.select({ "Clipboard tool not found (need xclip or wl-clipboard)" })
            return nil
        end

        local cmds = {
            wayland = { get = "wl-paste 2>/dev/null", clear = "wl-copy --clear" },
            x11 = { get = "xclip -o -selection clipboard 2>/dev/null", clear = 'echo -n "" | xclip -i -selection clipboard' },
        }

        local function get_content()
            local h = io.popen(cmds[tool].get)
            if not h then return nil end
            local c = h:read("*a")
            h:close()
            return c ~= "" and c or nil
        end

        local function set_content(text)
            if not text or text == "" then return end
            local cmd = tool == "wayland"
                and ("echo " .. menuhelper.shell_escape(text) .. " | wl-copy")
                or ("echo " .. menuhelper.shell_escape(text) .. " | xclip -i -selection clipboard")
            os.execute(cmd)
        end

        local function get_history()
            if not menuhelper.command_exists("copyq") then return {} end
            local h = io.popen("copyq count 2>/dev/null")
            if not h then return {} end
            local count = tonumber(h:read("*a"))
            h:close()
            if not count or count == 0 then return {} end
            local items = {}
            local max = count > 50 and 50 or count
            for i = 0, max - 1 do
                local p = io.popen("copyq read " .. i .. " 2>/dev/null")
                if p then
                    local text = p:read("*a")
                    p:close()
                    if text and text ~= "" then
                        items[#items + 1] = text:gsub("\n", " "):sub(1, 100)
                    end
                end
            end
            return items
        end

        while true do
            local current = get_content()
            local options = { "[Back]", "Copy Text", "Clear" }

            if current then
                options[#options + 1] = "---"
                options[#options + 1] = "Current: " .. current:gsub("\n", " "):sub(1, 80)
            end

            local history = get_history()
            if #history > 0 then
                options[#options + 1] = "---"
                for _, item in ipairs(history) do
                    options[#options + 1] = item
                end
            end

            local selection = menuhelper.select(options)
            if not selection or selection == "[Back]" then return nil end

            local actions = {
                ["Copy Text"] = function()
                    local text = menuhelper.prompt("Enter text:")
                    if text then set_content(text) end
                end,
                ["Clear"] = function() os.execute(cmds[tool].clear) end,
            }
            local fn = actions[selection]
            if fn then
                fn()
            elseif selection ~= "---" and not selection:match("^Current:") then
                set_content(selection)
            end
        end
    end
}
