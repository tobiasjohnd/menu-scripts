local Navigator = { current_folder = nil }

function Navigator:get_current_folder()
    return self.current_folder
end

function Navigator:navigate_to(folder)
    self.current_folder = folder
end

function Navigator:go_back()
    self.current_folder = nil
end

function Navigator:is_at_root()
    return self.current_folder == nil
end

function Navigator:reset()
    self.current_folder = nil
end

return Navigator
