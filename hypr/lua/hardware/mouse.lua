local logger = SafeRequire("lua.utils.logger")

local M = {}

-- 1. Global mouse/input configuration
-- See https://wiki.hypr.land/configuring/core/config-options/#touchpad
---@type HL.ConfigOpt.Input
M.mouseConfig = {
    follow_mouse = 1,
    sensitivity = 1,
    touchpad = {
        natural_scroll = true,
    },
}

-- 2. Per-device hardware specifications (Open/Closed Principle)
-- See https://wiki.hypr.land/configuring/core/devices/
---@type HL.DeviceSpec[]
M.devices = {
    {
        name = "elan06fa:00-04f3:32b9-touchpad", -- Fixed: removed leading space
        accel_profile = "adaptive",
    },
    {
        name = "elan06fa:00-04f3:32b9-mouse",
    },
}

---Validates the global input configuration and clamps out-of-bounds values
---@param cfg HL.ConfigOpt.Input
local function validate_input(cfg)
    local sens = cfg.sensitivity
    if type(sens) == "number" then
        if sens < -1.0 or sens > 1.0 then
            local clamped = math.max(-1.0, math.min(1.0, sens))
            logger.warn(string.format("Mouse sensitivity (%.2f) out of bounds. Clamping to %.2f.", sens, clamped))
            cfg.sensitivity = clamped
        end
    end

    local follow = cfg.follow_mouse
    if type(follow) == "number" then
        if follow < 0 or follow > 3 then
            logger.warn(string.format("follow_mouse (%d) is invalid. Defaulting to 1.", follow))
            cfg.follow_mouse = 1
        end
    end
end

---Validates a single per-device specification and trims accidental whitespace
---@param dev HL.DeviceSpec
---@param index integer
---@return boolean
local function is_valid_device(dev, index)
    if type(dev) ~= "table" then
        logger.error(string.format("Device spec at index %d is not a table.", index))
        return false
    end

    local name = dev.name
    if type(name) ~= "string" or name == "" then
        logger.error(string.format("Device spec at index %d is missing a valid 'name'.", index))
        return false
    end

    -- Automatically strip accidental leading/trailing spaces in device names
    local trimmed = name:match("^%s*(.-)%s*$")
    if trimmed ~= name then
        logger.warn(string.format("Trimmed whitespace from device name [%s] -> [%s].", name, trimmed))
        dev.name = trimmed
    end

    return true
end

---Safely applies both global input and per-device configurations to Hyprland
---@return boolean success
function M.apply()
    validate_input(M.mouseConfig)

    if type(hl) ~= "table" or type(hl.config) ~= "function" or type(hl.device) ~= "function" then
        logger.error("Hyprland API ('hl.config' or 'hl.device') is missing. Are you running inside Hyprland?")
        return false
    end

    local all_ok = true

    -- Apply global input config
    local ok_cfg, err_cfg = pcall(hl.config, { input = M.mouseConfig })
    if not ok_cfg then
        logger.error("Failed to apply global mouse configuration: " .. tostring(err_cfg))
        all_ok = false
    end

    -- Apply each individual device config independently
    for i, dev in ipairs(M.devices) do
        if is_valid_device(dev, i) then
            local ok_dev, err_dev = pcall(hl.device, dev)
            if not ok_dev then
                logger.error(string.format("Failed to apply device [%s]: %s", tostring(dev.name), tostring(err_dev)))
                all_ok = false
            end
        else
            all_ok = false
        end
    end

    return all_ok
end

return M
