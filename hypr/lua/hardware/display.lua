-- See https://wiki.hypr.land/configuring/core/monitors/

local logger = SafeRequire("lua.utils.logger")

local M = {}

-- Open/Closed Principle: Add or modify monitor tables here without touching apply()
---@type HL.MonitorSpec[]
M.monitors = {
    -- Primary laptop display
    {
        output   = "eDP-1",
        mode     = "preferred",
        position = "auto",
        scale    = 1.0,
    },
    -- Example external monitor:
    -- {
    --     output   = "DP-1",
    --     mode     = "1920x1080@144",
    --     position = "0x0",
    --     scale    = "1",
    -- },

    -- Fallback rule for any hotplugged monitor not explicitly listed above
    {
        output   = "",
        mode     = "preferred",
        position = "auto",
        scale    = 1.0,
    },
}
---Single Responsibility: Validates a single monitor specification before execution
---@param spec HL.MonitorSpec
---@param index integer
---@return boolean
local function is_valid_spec(spec, index)
    if type(spec) ~= "table" then
        logger.error(string.format("Monitor spec at index %d is not a table.", index))
        return false
    end
    if type(spec.output) ~= "string" then
        logger.error(string.format("Monitor spec at index %d is missing a string 'output'.", index))
        return false
    end
    -- Ensure scale is passed as a string if HL.MonitorSpec expects string
    if spec.scale ~= nil and type(spec.scale) ~= "number" then
        logger.warn(string.format("Monitor [%s] scale is invalid; defaulting to 1.", spec.output))
        spec.scale = 1
    end
    return true
end

---Safely applies all monitor configurations via hl.monitor()
---@return boolean success
function M.apply()
    if type(hl) ~= "table" or type(hl.monitor) ~= "function" then
        logger.error("Hyprland API ('hl.monitor') is missing. Cannot apply displays.")
        return false
    end

    local all_ok = true
    for i, spec in ipairs(M.monitors) do
        if is_valid_spec(spec, i) then
            local ok, err = pcall(hl.monitor, spec)
            if not ok then
                local target = spec.output ~= "" and spec.output or "fallback"
                logger.error(string.format("Failed to apply monitor [%s]: %s", target, tostring(err)))
                all_ok = false
            end
        else
            all_ok = false
        end
    end

    return all_ok
end

return M
