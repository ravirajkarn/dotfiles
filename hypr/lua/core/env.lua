-- See https://wiki.hypr.land/configuring/core/environment-variables/
local logger = SafeRequire("lua.utils.logger")

local M = {}

-- Open/Closed Principle: Add environment variables here without modifying apply()
---@type table<string, string|number>
M.variables = {
    XCURSOR_SIZE    = "24",
    HYPRCURSOR_SIZE = "24",
}

---Single Responsibility: Validates an environment key-value pair
---@param key any
---@param val any
---@return boolean
local function is_valid_pair(key, val)
    if type(key) ~= "string" or key:match("^%s*$") then
        logger.error(string.format("Invalid environment variable key [%s].", tostring(key)))
        return false
    end
    if val == nil or (type(val) ~= "string" and type(val) ~= "number") then
        logger.error(string.format("Environment variable [%s] has an invalid value (%s).", key, tostring(val)))
        return false
    end
    return true
end

---Single Responsibility: Exports all valid environment variables to Hyprland
---@return boolean success
function M.apply()
    if type(hl) ~= "table" or type(hl.env) ~= "function" then
        logger.error("Hyprland API ('hl.env') is missing. Cannot apply environment variables.")
        return false
    end

    local all_ok = true

    for key, val in pairs(M.variables) do
        if is_valid_pair(key, val) then
            local ok, err = pcall(hl.env, key, tostring(val))
            if not ok then
                logger.error(string.format("Failed to set env [%s]: %s", key, tostring(err)))
                all_ok = false
            end
        else
            all_ok = false
        end
    end

    return all_ok
end

return M
