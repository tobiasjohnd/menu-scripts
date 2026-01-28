local menuhelper = require("menuhelpers")
local config = require("config")

local function get_bookmark_file()
    local cfg = config:get_config()
    return cfg.bookmarks_file:gsub("^~", os.getenv("HOME") or "")
end

local function read_bookmarks()
    local bookmarks = {}
    local file = io.open(get_bookmark_file(), "r")
    if not file then return bookmarks end
    for line in file:lines() do
        local name, url = line:match("^(.-)%|(.+)$")
        if name and url then bookmarks[#bookmarks + 1] = { name = name, url = url } end
    end
    file:close()
    return bookmarks
end

local function write_bookmarks(bookmarks)
    local path = get_bookmark_file()
    os.execute("mkdir -p " .. menuhelper.shell_escape(path:match("(.*/)")))
    local file = io.open(path, "w")
    if not file then return false end
    for _, b in ipairs(bookmarks) do file:write(b.name .. "|" .. b.url .. "\n") end
    file:close()
    return true
end

return {
    name = "Web Search",
    description = "Search the web and manage bookmarks",
    category = "search",

    execute = function()
        local function do_search()
            local cfg = config:get_config()
            local query = menuhelper.prompt("Search:")
            if not query then return end
            local encoded = query:gsub("([^%w%-%.%_%~])", function(c)
                return string.format("%%%02X", string.byte(c))
            end)
            os.execute(cfg.browser .. " " .. menuhelper.shell_escape(cfg.search_engine .. encoded) .. " &")
            return "exit"
        end

        while true do
            local bookmarks = read_bookmarks()
            local url_map = {}
            local options = { "[Back]", "Search", "Add Bookmark", "Remove Bookmark", "---" }

            if #bookmarks == 0 then
                options[#options + 1] = "(no bookmarks)"
            else
                for _, b in ipairs(bookmarks) do
                    options[#options + 1] = b.name
                    url_map[b.name] = b.url
                end
            end

            local selection = menuhelper.select(options)
            if not selection or selection == "[Back]" then return nil end

            local actions = {
                ["Search"] = function()
                    return do_search()
                end,
                ["Add Bookmark"] = function()
                    local name = menuhelper.prompt("Bookmark name:")
                    if name then
                        local url = menuhelper.prompt("Bookmark URL:")
                        if url then
                            if not url:match("^https?://") and not url:match("^www%.") then url = "https://" .. url end
                            bookmarks[#bookmarks + 1] = { name = name, url = url }
                            write_bookmarks(bookmarks)
                        end
                    end
                end,
                ["Remove Bookmark"] = function()
                    if #bookmarks == 0 then return end
                    local names = {}
                    for _, b in ipairs(bookmarks) do names[#names + 1] = b.name end
                    local pick = menuhelper.select(names)
                    if pick then
                        local filtered = {}
                        for _, b in ipairs(bookmarks) do
                            if b.name ~= pick then filtered[#filtered + 1] = b end
                        end
                        write_bookmarks(filtered)
                    end
                end,
            }
            local fn = actions[selection]
            if fn then
                local result = fn()
                if result then return result end
            elseif url_map[selection] then
                local cfg = config:get_config()
                os.execute(cfg.browser .. " " .. menuhelper.shell_escape(url_map[selection]) .. " &")
                return "exit"
            end
        end
    end
}
