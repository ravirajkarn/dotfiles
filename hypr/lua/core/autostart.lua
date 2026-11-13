-- See https://wiki.hypr.land/configuring/core/autostart/
local logger = SafeRequire("lua.utils.logger")
local display = SafeRequire("lua.hardware.display")
-- local apps   = SafeRequire("lua.core.apps")

local M      = {}

-- logger.trace()

---@type string[]
M.commands   = {
    "systemctl --user start hyprpolkitagent",
    "hyprpaper",
    "hyprpm reload -n && hyprctl reload",
    string.format("gBar bar %s", display.monitors[1].output),
    -- apps and apps.terminal or "kitty",
    -- "nm-applet",
    -- "waybar & hyprpaper",
}

---@param cmd string
---@param index integer
---@return boolean
local function is_valid_command(cmd, index)
    if type(cmd) ~= "string" or cmd:match("^%s*$") then
        logger.error(string.format("Autostart command at index %d is empty or not a string.", index))
        return false
    end
    return true
end

---@return boolean success
function M.apply()
    if #M.commands == 0 then
        return true
    end

    if type(hl) ~= "table" or type(hl.on) ~= "function" or type(hl.exec_cmd) ~= "function" then
        logger.error("Hyprland API ('hl.on' or 'hl.exec_cmd') is missing. Cannot register autostart.")
        return false
    end

    local valid_cmds = {}
    local all_valid = true

    for i, cmd in ipairs(M.commands) do
        if is_valid_command(cmd, i) then
            table.insert(valid_cmds, cmd)
        else
            all_valid = false
        end
    end

    if #valid_cmds == 0 then
        return all_valid
    end

    local ok, err = pcall(hl.on, "hyprland.start", function()
        for _, cmd in ipairs(valid_cmds) do
            local cmd_ok, cmd_err = pcall(hl.exec_cmd, cmd)
            if not cmd_ok then
                logger.error(string.format("Autostart command failed [%s]: %s", cmd, tostring(cmd_err)))
            end
        end
    end)

    if not ok then
        logger.error("Failed to register 'hyprland.start' hook: " .. tostring(err))
        return false
    end

    return all_valid
end

return M
