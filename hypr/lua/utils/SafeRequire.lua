local logger = require("lua.utils.logger")

---Safely requires a Lua module, routing errors to logger.
---@generic T
---@param module_path `T`
---@return any|nil
_G.SafeRequire = function(module_path)
    local ok, res = pcall(require, module_path)
    if not ok then
        local err_msg = string.format("Failed to load module [%s]: %s", module_path, tostring(res))
        logger.error(err_msg)
        return nil
    end
    return res
end
