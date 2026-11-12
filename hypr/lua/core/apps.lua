-- local logger = SafeRequire("lua.utils.logger")

-- ---@class AppRegistry
-- ---@field terminal string
-- ---@field fileManager string
-- ---@field menu string
-- ---@field browser string
-- local apps = {
--     terminal    = "kitty",
--     fileManager = "dolphin",
--     menu        = "hyprlauncher",
--     browser     = "google-chrome-stable",
-- }

-- -- Protect the registry from accidental runtime mutation
-- return setmetatable({}, {
--     __index = apps,
--     __newindex = function(_, key, _)
--         if logger then
--             logger.error(string.format("Attempted to mutate read-only app registry key [%s].", tostring(key)))
--         end
--     end,
-- })

local apps = {
    terminal    = "kitty",
    fileManager = "dolphin",
    menu        = "hyprlauncher",
    browser     = "google-chrome-stable",
}

return apps