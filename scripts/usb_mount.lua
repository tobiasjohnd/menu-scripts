local menuhelper = require("menuhelpers")

local function get_removable_devices()
    local h = io.popen('lsblk -o NAME,SIZE,LABEL,MOUNTPOINT,RM,TYPE -rn 2>/dev/null')
    if not h then return {} end
    local devices = {}
    for line in h:lines() do
        local name, size, label, mountpoint, rm, dtype = line:match(
            "^(%S+)%s+(%S+)%s+(%S*)%s*(%S*)%s+(%S+)%s+(%S+)$")
        if name and rm == "1" and dtype == "part" then
            devices[#devices + 1] = {
                name = name,
                path = "/dev/" .. name,
                size = size,
                label = (label and label ~= "") and label or name,
                mounted = mountpoint ~= nil and mountpoint ~= "",
                mountpoint = mountpoint,
            }
        end
    end
    h:close()
    return devices
end

local function mount_device(dev)
    os.execute("udisksctl mount -b " .. menuhelper.shell_escape(dev.path))
end

local function unmount_device(dev)
    os.execute("udisksctl unmount -b " .. menuhelper.shell_escape(dev.path))
end

local function eject_device(dev)
    -- Unmount first, then power off the drive
    local disk = dev.path:match("^(/dev/%a+)") or dev.path
    os.execute("udisksctl unmount -b " .. menuhelper.shell_escape(dev.path) .. " 2>/dev/null")
    os.execute("udisksctl power-off -b " .. menuhelper.shell_escape(disk))
end

return {
    name = "USB Drives",
    description = "Mount, unmount, and eject USB drives",
    category = "options",

    execute = function()
        if not menuhelper.command_exists("udisksctl") then
            menuhelper.select({ "udisksctl not found (install udisks2)" })
            return nil
        end

        while true do
            local devices = get_removable_devices()
            local options = { "[Back]", "Refresh", "---" }
            local device_map = {}

            if #devices == 0 then
                options[#options + 1] = "(no USB drives detected)"
            else
                for _, dev in ipairs(devices) do
                    local status = dev.mounted and ("mounted: " .. dev.mountpoint) or "not mounted"
                    local prefix = dev.mounted and "* " or "  "
                    local display = prefix .. dev.label .. " (" .. dev.size .. ") [" .. status .. "]"
                    options[#options + 1] = display
                    device_map[display] = dev
                end
            end

            local selection = menuhelper.select(options)
            if not selection or selection == "[Back]" then return nil end

            if selection == "Refresh" then
                -- loops back
            elseif device_map[selection] then
                local dev = device_map[selection]
                local dev_options = { "[Cancel]" }
                if dev.mounted then
                    dev_options[#dev_options + 1] = "Unmount"
                    dev_options[#dev_options + 1] = "Eject"
                    dev_options[#dev_options + 1] = "Open"
                else
                    dev_options[#dev_options + 1] = "Mount"
                    dev_options[#dev_options + 1] = "Eject"
                end

                local action = menuhelper.select(dev_options)
                if action and action ~= "[Cancel]" then
                    local dev_actions = {
                        ["Mount"]   = function() mount_device(dev) end,
                        ["Unmount"] = function() unmount_device(dev) end,
                        ["Eject"]   = function() eject_device(dev) end,
                        ["Open"]    = function()
                            local cfg = require("config"):get_config()
                            os.execute(cfg.terminal .. " -e " .. (cfg.file_manager or "ls") .. " "
                                .. menuhelper.shell_escape(dev.mountpoint) .. " &")
                            return "exit"
                        end,
                    }
                    local fn = dev_actions[action]
                    if fn then
                        local result = fn()
                        if result then return result end
                    end
                end
            end
        end
    end
}
