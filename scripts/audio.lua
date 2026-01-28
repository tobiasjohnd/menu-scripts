local menuhelper = require("menuhelpers")

local function read_cmd(cmd)
    local h = io.popen(cmd)
    if not h then return "" end
    local out = h:read("*a")
    h:close()
    return out
end

local function get_volume()
    local out = read_cmd("pactl get-sink-volume @DEFAULT_SINK@ 2>/dev/null")
    local percent = out:match("(%d+)%%")
    return percent and tonumber(percent) or nil
end

local function set_volume(percent)
    if percent < 0 then percent = 0 end
    if percent > 150 then percent = 150 end
    os.execute("pactl set-sink-volume @DEFAULT_SINK@ " .. percent .. "%")
end

local function get_mute()
    local out = read_cmd("pactl get-sink-mute @DEFAULT_SINK@ 2>/dev/null")
    return out:match("yes") ~= nil
end

local function toggle_mute()
    os.execute("pactl set-sink-mute @DEFAULT_SINK@ toggle")
end

local function get_default_sink()
    return read_cmd("pactl get-default-sink 2>/dev/null"):match("%S+") or ""
end

local function get_default_source()
    return read_cmd("pactl get-default-source 2>/dev/null"):match("%S+") or ""
end

local function get_sinks()
    local out = read_cmd([[pactl -f json list sinks 2>/dev/null | jq -r '.[] | "\(.name)\t\(.description)"']])
    local sinks = {}
    for line in out:gmatch("[^\n]+") do
        local name, desc = line:match("^(.-)\t(.+)$")
        if name then sinks[#sinks + 1] = { name = name, description = desc } end
    end
    return sinks
end

local function get_sources()
    local out = read_cmd([[pactl -f json list sources 2>/dev/null | jq -r '.[] | "\(.name)\t\(.description)"']])
    local sources = {}
    for line in out:gmatch("[^\n]+") do
        local name, desc = line:match("^(.-)\t(.+)$")
        if name and not name:match("%.monitor$") then
            sources[#sources + 1] = { name = name, description = desc }
        end
    end
    return sources
end

local function get_playing()
    local out = read_cmd(
    [[pactl -f json list sink-inputs 2>/dev/null | jq -r '.[] | "\(.properties["application.name"] // "unknown")\t\(.sink)"']])
    local sink_desc = {}
    for _, s in ipairs(get_sinks()) do sink_desc[tostring(s.name)] = s.description end
    -- Also map by index
    local idx_out = read_cmd([[pactl -f json list sinks 2>/dev/null | jq -r '.[] | "\(.index)\t\(.description)"']])
    for line in idx_out:gmatch("[^\n]+") do
        local idx, desc = line:match("^(.-)\t(.+)$")
        if idx then sink_desc[idx] = desc end
    end

    local playing = {}
    for line in out:gmatch("[^\n]+") do
        local app, sink = line:match("^(.-)\t(.+)$")
        if app then
            playing[#playing + 1] = {
                app = app,
                sink = sink_desc[sink] or sink,
            }
        end
    end
    return playing
end

local function volume_submenu()
    local current = get_volume()
    local options = { "[Back]", "Custom", "---" }
    for i = 100, 0, -10 do
        local marker = (current and current == i) and "* " or "  "
        options[#options + 1] = marker .. i .. "%"
    end

    local selection = menuhelper.select(options)
    if not selection or selection == "[Back]" then return end

    if selection == "Custom" then
        local input = menuhelper.prompt("Volume % (0-150):")
        local val = tonumber(input)
        if val then set_volume(val) end
    elseif selection:match("%d+%%$") then
        local val = tonumber(selection:match("(%d+)%%$"))
        if val then set_volume(val) end
    end
end

local function device_submenu(label, devices, current_name, set_fn)
    local options = { "[Back]" }
    local device_map = {}
    for _, dev in ipairs(devices) do
        local prefix = dev.name == current_name and "* " or "  "
        local display = prefix .. dev.description
        options[#options + 1] = display
        device_map[display] = dev.name
    end

    local selection = menuhelper.select(options)
    if not selection or selection == "[Back]" then return end

    local name = device_map[selection]
    if name then set_fn(name) end
end

return {
    name = "Audio",
    description = "Manage audio volume and devices",
    category = "options",

    execute = function()
        if not menuhelper.command_exists("pactl") then
            menuhelper.select({ "pactl not found (install pipewire-pulse or pulseaudio)" })
            return nil
        end

        while true do
            local vol = get_volume()
            local muted = get_mute()
            local vol_label = "Volume: " .. (vol and (vol .. "%") or "unknown")
            local mute_label = muted and "Mute: ON" or "Mute: OFF"

            local options = { "[Back]", vol_label, mute_label, "Output Device", "Input Device" }

            local playing = get_playing()
            if #playing > 0 then
                options[#options + 1] = "---"
                for _, p in ipairs(playing) do
                    options[#options + 1] = "  " .. p.app .. " → " .. p.sink
                end
            end

            local selection = menuhelper.select(options)
            if not selection or selection == "[Back]" then return nil end

            local actions = {
                [vol_label] = volume_submenu,
                [mute_label] = toggle_mute,
                ["Output Device"] = function()
                    device_submenu("Output", get_sinks(), get_default_sink(), function(name)
                        os.execute("pactl set-default-sink " .. menuhelper.shell_escape(name))
                    end)
                end,
                ["Input Device"] = function()
                    device_submenu("Input", get_sources(), get_default_source(), function(name)
                        os.execute("pactl set-default-source " .. menuhelper.shell_escape(name))
                    end)
                end,
            }
            local fn = actions[selection]
            if fn then fn() end
        end
    end
}
