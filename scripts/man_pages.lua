local menuhelper = require("menuhelpers")
local config = require("config")

local function get_man_pages()
    local h = io.popen("man -k . 2>/dev/null | sort")
    if not h then return {} end
    local pages = {}
    for line in h:lines() do
        local name, section, desc = line:match("^(%S+)%s+%((%S+)%)%s+%-%s+(.+)$")
        if name then
            pages[#pages + 1] = { name = name, section = section, description = desc }
        end
    end
    h:close()
    return pages
end

return {
    name = "Man Pages",
    description = "Browse and read man pages",
    category = "search",

    execute = function()
        if not menuhelper.command_exists("man") then
            menuhelper.select({ "man not found" })
            return nil
        end

        local pages = get_man_pages()
        if #pages == 0 then
            menuhelper.select({ "(no man pages found)" })
            return nil
        end

        local options = { "[Back]", "---" }
        local page_map = {}

        for _, p in ipairs(pages) do
            local display = p.name .. "(" .. p.section .. ") - " .. p.description
            options[#options + 1] = display
            page_map[display] = p
        end

        local selection = menuhelper.select(options)
        if not selection or selection == "[Back]" then return nil end

        local page = page_map[selection]
        if page then
            local cfg = config:get_config()
            local terminal = cfg.terminal or os.getenv("TERMINAL") or "xterm"
            os.execute(terminal .. " -e man " .. page.section .. " " .. menuhelper.shell_escape(page.name) .. " &")
            return "exit"
        end

        return nil
    end
}
