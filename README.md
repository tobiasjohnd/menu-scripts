# Menu-Scripts

A Dmenu script for general system management stuff, was originally part of my awesome WM config but it took on a life of its own so moved it all to a separate project. Works with any dmenu-compatible launcher (dmenu, rofi, tofi, wofi).

By default, all scripts and applications are shown in a flat list. Use `--folders` to group scripts into category-based folders (this feature is a work in progress).

## Requirements

- Lua 5.1+
- dmenu-compatible menu program
- dependencies for indevidual scripts below.

## Installation

```bash
git clone https://github.com/tobiasjohnd/menu-scripts.git
cd Menu-Scripts

# Run in flat mode (default)
lua main.lua

# Run in folder mode
lua main.lua --folders
```

Bind `lua /path/to/main.lua` to a key in your window manager.

## Configuration

Copy the default config to your user directory:

```bash
mkdir -p ~/.config/menu-scripts
cp config/default.lua ~/.config/menu-scripts/config.lua
```

Edit `~/.config/menu-scripts/config.lua`:

```lua
return {
    menu_program = "dmenu",      -- or rofi, tofi, wofi
    menu_options = "-i -l 20",
    terminal = "alacritty",
    editor = "nvim",
    browser = "firefox",
    bookmarks_file = "~/.config/menu-scripts/bookmarks.txt",
    tmux_projects_dir = "~/Repos/",
    tmux_session_commands = { "nvim ." },
}
```

Environment variables `$TERMINAL`, `$EDITOR`, and `$BROWSER` override config values.

## Adding Scripts

Create a Lua file in `scripts/`:

```lua
local menuhelper = require("menuhelpers")

return {
    name = "My Script",
    category = "utilities",  -- optional: used to group scripts in --folders mode, ignored otherwise

    execute = function()
        local selection = menuhelper.select({ "[Back]", "Action 1", "Action 2" })
        if not selection or selection == "[Back]" then return nil end

        local actions = {
            ["Action 1"] = function() --[[ do something ]] end,
            ["Action 2"] = function() --[[ do something ]] end,
        }
        local fn = actions[selection]
        if fn then fn() end

        return nil  -- stay in menu, or "exit" to quit
    end
}
```

## Menu Prefixes

- `!` - Script (e.g., `!Web Search`)
- `/` suffix - Folder (e.g., `Search/`, only in `--folders` mode)
- `../` - Go back to parent (inside folders)
- No prefix - Desktop application

## Scripts

| Script | Description | Dependencies |
|--------|-------------|-------------|
| Audio | Volume control, output/input device switching | `pulseaudio-utils`, `jq` |
| Bitwarden | Access Bitwarden vault, copy passwords/usernames/TOTP | `bitwarden-cli` or flatpak, `jq` |
| Bluetooth | Manage bluetooth devices (scan, connect, pair, trust) | `bluez` |
| Brightness | Adjust screen brightness (10% presets) | `brightnessctl` |
| Clipboard Manager | View, copy, clear clipboard content and history | `xclip` or `wl-clipboard`, `copyq` |
| Desktop Entries | Hide, rename, edit, or restore .desktop files | - |
| DNF Packages | Search, install, remove packages and run updates | `libnotify` |
| File Manager | Browse, open, edit, cut/copy/paste, rename, compress, extract, bookmarks | `xdg-utils` |
| Man Pages | Browse and read man pages | - |
| Monitor | Manage monitors and display settings (resolution, position, primary) | `xrandr` |
| Notifications | View notification history, toggle do-not-disturb | `dunst`, `jq` |
| Power Menu | Logout, reboot, or shutdown | - |
| Process Killer | Kill running processes | - |
| Screenshot | Take screenshots | `flameshot` |
| Systemd Services | Manage systemd services (start, stop, enable, disable, logs) | - |
| Tmux Sessions | Manage tmux sessions and project directories | `tmux` |
| USB Drives | Mount, unmount, and eject USB drives | `udisks2` |
| Web Search | Search the web and manage bookmarks | - |
| WiFi | Manage WiFi connections | `NetworkManager` |

All scripts require **Lua 5.1+** and a **dmenu-compatible menu program**. Scripts that use clipboard operations need `xclip` (X11) or `wl-clipboard` (Wayland).

## Credits

The file manager script was heavily inspired by [dmenufm](https://github.com/huijunchen9260/dmenufm) by huijunchen9260.

The tmux sessions script was inspired by [tmux-sessionizer](https://github.com/ThePrimeagen/tmux-sessionizer) by ThePrimeagen.
