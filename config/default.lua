-- Menu-Scripts Configuration
-- Copy to ~/.config/menu-scripts/config.lua to customize

return {
    -- Menu program (dmenu, rofi, tofi, wofi)
    menu_program = "dmenu",
    menu_options = "-i -l 20",

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
