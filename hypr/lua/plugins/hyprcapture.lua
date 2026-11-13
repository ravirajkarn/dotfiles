local logger = SafeRequire("lua.utils.logger")

local M = {}

-- 1. Native Plugin Configuration
---@type table
M.plugin_opts = {
    -- HDR and output settings
    screenshot_mode  = "sdr", -- "sdr" or "hdr"
    show_hdr_control = false, -- Hide HDR toggle in UI if SDR only
    default_mode     = "fullscreen",
    allow_quick      = true,  -- Required for hl.plugin.hyprcapture.quick()
}

---@return boolean
function M.apply()
    if type(hl.config) ~= "function" then
        logger.error("Hyprland API ('hl.config') is missing. Cannot configure HyprCapture.")
        return false
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

return M
