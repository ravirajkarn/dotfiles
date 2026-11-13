local logger = SafeRequire("lua.utils.logger")

local M = {}

---@type table
M.plugin_opts = {
    default_mode     = "fullscreen",
    allow_quick      = true,
    screenshot_mode  = "sdr",
    show_hdr_control = false,
    helper           = (os.getenv("HOME") or "~") .. "/.local/bin/hyprcapture-ui",
}

---@return boolean
local function is_plugin_loaded()
    return type(hl) == "table"
        and type(hl.plugin) == "table"
        and type(hl.plugin.hyprcapture) == "table"
end

---@return boolean
local function allow_hyprpm()
    if type(hl.permission) ~= "function" then
        return true
    end

    local ok, err = pcall(hl.permission, "/usr/(bin|local/bin)/hyprpm", "plugin", "allow")
    if not ok then
        logger.error("Failed to set hyprpm plugin permission: " .. tostring(err))
        return false
    end
    return true
end

---@return boolean
local function apply_plugin_config()
    if type(hl.config) ~= "function" then
        logger.error("Hyprland API ('hl.config') is missing. Cannot configure HyprCapture.")
        return false
    end

    if not is_plugin_loaded() then
        logger.warn("HyprCapture not in memory yet; deferring plugin.hyprcapture config until reload.")
        return true
    end

    local ok, err = pcall(hl.config, {
        plugin = {
            hyprcapture = M.plugin_opts,
        },
    })

    if not ok then
        logger.error("Failed to apply HyprCapture plugin config: " .. tostring(err))
        return false
    end

    return true
end

---@return boolean success
function M.apply()
    if type(hl) ~= "table" then
        logger.error("Hyprland API ('hl') is missing. Cannot apply HyprCapture.")
        return false
    end

    local p_ok = allow_hyprpm()
    local c_ok = apply_plugin_config()

    return p_ok and c_ok
end

return M
