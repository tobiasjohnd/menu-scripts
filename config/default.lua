-- Menu-Scripts Configuration
-- Copy to ~/.config/menu-scripts/config.lua to customize

return {
    -- Menu program (dmenu, rofi, tofi, wofi)
    menu_program = "rofi -dmenu",
    menu_options = "-i",

    -- Applications
    terminal = "alacritty",
    editor = "nvim",
    browser = "firefox",

    -- Search
    search_engine = "https://duckduckgo.com/?q=",
    bookmarks_file = "~/.config/menu-scripts/bookmarks.txt",

    -- Productivity
    tmux_projects_dir = "~/Repos/",
    tmux_session_commands = { "nvim ." },
}
