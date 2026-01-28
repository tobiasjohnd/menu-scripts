local Config = {}

local CONFIG_PATH = (os.getenv("HOME") or "") .. "/.config/menu-scripts/config.lua"
local DEFAULT_PATH = nil
local cached_config = nil

local function load_config()
    local config = {}

    if DEFAULT_PATH then
        local ok, def = pcall(dofile, DEFAULT_PATH)
        if ok and type(def) == "table" then
            for k, v in pairs(def) do config[k] = v end
        end
    end

    local ok, user = pcall(dofile, CONFIG_PATH)
    if ok and type(user) == "table" then
        for k, v in pairs(user) do config[k] = v end
    end

    config.terminal = os.getenv("TERMINAL") or config.terminal
    config.editor = os.getenv("EDITOR") or config.editor
    config.browser = os.getenv("BROWSER") or config.browser

    return config
end

function Config:init(base_path)
    DEFAULT_PATH = base_path .. "/config/default.lua"
    cached_config = nil
end

function Config:get_config()
    if not cached_config then cached_config = load_config() end
    return cached_config
end

function Config:reload()
    cached_config = nil
    return self:get_config()
end

return Config
