local menuhelper = require("menuhelpers")

local bw_cmd_prefix = nil

local function detect_bw()
    if menuhelper.command_exists("bw") then
        bw_cmd_prefix = "bw"
    else
        -- Check for flatpak bitwarden
        local h = io.popen("flatpak list --app --columns=application 2>/dev/null")
        if h then
            local out = h:read("*a")
            h:close()
            if out:match("com%.bitwarden%.desktop") then
                bw_cmd_prefix = "flatpak run --command=bw com.bitwarden.desktop"
            end
        end
    end
    return bw_cmd_prefix ~= nil
end

local function read_cmd(cmd)
    local h = io.popen(cmd)
    if not h then return "" end
    local out = h:read("*a")
    h:close()
    return out
end

local function bw(session, args)
    local env = session and ("BW_SESSION=" .. menuhelper.shell_escape(session) .. " ") or ""
    return read_cmd(env .. bw_cmd_prefix .. " " .. args .. " 2>/dev/null")
end

local function get_status(session)
    local out = bw(session, "status")
    return out:match('"status"%s*:%s*"(%w+)"') or "unknown"
end

local function unlock_vault()
    local password = menuhelper.prompt("Master password:")
    if not password then return nil end
    local session = read_cmd(
        "echo " .. menuhelper.shell_escape(password) .. " | " ..
        bw_cmd_prefix .. " unlock --raw 2>/dev/null"
    )
    session = session:match("%S+")
    if not session or session == "" then
        menuhelper.select({ "Unlock failed" })
        return nil
    end
    return session
end

local function list_items(session)
    local out = bw(session, 'list items | jq -r \'.[] | select(.type == 1) | "\\(.id)\\t\\(.name)"\'')
    local items = {}
    for line in out:gmatch("[^\n]+") do
        local id, name = line:match("^(.-)\t(.+)$")
        if id and name then
            items[#items + 1] = { id = id, name = name }
        end
    end
    table.sort(items, function(a, b) return a.name:lower() < b.name:lower() end)
    return items
end

local function search_items(session, query)
    local out = bw(session,
        "list items --search " .. menuhelper.shell_escape(query) ..
        ' | jq -r \'.[] | select(.type == 1) | "\\(.id)\\t\\(.name)"\'')
    local items = {}
    for line in out:gmatch("[^\n]+") do
        local id, name = line:match("^(.-)\t(.+)$")
        if id and name then
            items[#items + 1] = { id = id, name = name }
        end
    end
    table.sort(items, function(a, b) return a.name:lower() < b.name:lower() end)
    return items
end

local function copy_to_clipboard(text)
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
        h:write(text)
        h:close()
    end
end

local function item_action(session, item)
    local options = { "[Cancel]", "Copy Password", "Copy Username", "Copy TOTP" }
    local action = menuhelper.select(options)
    if not action or action == "[Cancel]" then return end

    local actions = {
        ["Copy Password"] = function()
            local pw = bw(session, "get password " .. menuhelper.shell_escape(item.id))
            pw = pw:match("(.-)%s*$")
            if pw and pw ~= "" then
                copy_to_clipboard(pw)
            else
                menuhelper.select({ "No password found" })
            end
        end,
        ["Copy Username"] = function()
            local user = bw(session, "get username " .. menuhelper.shell_escape(item.id))
            user = user:match("(.-)%s*$")
            if user and user ~= "" then
                copy_to_clipboard(user)
            else
                menuhelper.select({ "No username found" })
            end
        end,
        ["Copy TOTP"] = function()
            local totp = bw(session, "get totp " .. menuhelper.shell_escape(item.id))
            totp = totp:match("(.-)%s*$")
            if totp and totp ~= "" then
                copy_to_clipboard(totp)
            else
                menuhelper.select({ "No TOTP found" })
            end
        end,
    }
    local fn = actions[action]
    if fn then fn() end
end

return {
    name = "Bitwarden",
    description = "Access Bitwarden vault",
    category = "utilities",

    execute = function()
        if not detect_bw() then
            menuhelper.select({ "Bitwarden CLI not found (install bw or flatpak)" })
            return nil
        end

        -- Check status and unlock if needed
        local session = nil
        local status = get_status(session)

        if status == "unauthenticated" then
            menuhelper.select({ "Not logged in. Run 'bw login' first." })
            return nil
        end

        if status == "locked" then
            session = unlock_vault()
            if not session then return nil end
        end

        while true do
            local items = list_items(session)
            local options = { "[Back]", "Lock Vault", "Search", "---" }
            local item_map = {}

            if #items == 0 then
                options[#options + 1] = "(no items)"
            else
                for _, item in ipairs(items) do
                    options[#options + 1] = item.name
                    item_map[item.name] = item
                end
            end

            local selection = menuhelper.select(options)
            if not selection or selection == "[Back]" then return nil end

            local menu_actions = {
                ["Lock Vault"] = function()
                    bw(session, "lock")
                    return "exit"
                end,
                ["Search"] = function()
                    local query = menuhelper.prompt("Search vault:")
                    if not query then return end
                    local results = search_items(session, query)
                    if #results == 0 then
                        menuhelper.select({ "(no results)" })
                        return
                    end
                    local search_options = { "[Back]" }
                    local search_map = {}
                    for _, item in ipairs(results) do
                        search_options[#search_options + 1] = item.name
                        search_map[item.name] = item
                    end
                    local pick = menuhelper.select(search_options)
                    if pick and pick ~= "[Back]" and search_map[pick] then
                        item_action(session, search_map[pick])
                    end
                end,
            }
            local fn = menu_actions[selection]
            if fn then
                local result = fn()
                if result then return result end
            elseif item_map[selection] then
                item_action(session, item_map[selection])
            end
        end
    end
}
