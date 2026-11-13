local logger = SafeRequire("lua.utils.logger")

local capture = {}

---@class ScreenshotConfig
local config = {
    -- Swap between "hyprcapture" and "cli"
    active_engine = "hyprcapture",

    cli = {
        quick_full   = "grimblast --notify copysave output",
        quick_region = "grimblast --notify copysave area",
        quick_window = "grimblast --notify copysave active",
        region       = "grimblast --notify edit area",
    },
}

---Checks if HyprCapture is loaded in memory at the moment a key is pressed
---@return boolean
local function is_plugin_loaded()
    return type(hl) == "table"
        and type(hl.plugin) == "table"
        and type(hl.plugin.hyprcapture) == "table"
end

---Creates a deferred closure that safely invokes a HyprCapture method at keypress time
---@param method "open"|"open_editor"|"quick"
---@param mode? "region"|"fullscreen"|"window"|""
---@return function
local function plugin_action(method, mode)
    return function()
        if not is_plugin_loaded() then
            logger.error("HyprCapture plugin not loaded in memory. Run 'hyprpm reload'.")
            return
        end

        local fn = hl.plugin.hyprcapture[method]
        if type(fn) ~= "function" then
            logger.error(string.format("HyprCapture method '%s' is invalid.", tostring(method)))
            return
        end

        local ok, err = pcall(fn, mode)
        if not ok then
            logger.error(string.format("HyprCapture '%s(%s)' failed: %s", method, tostring(mode or ""), tostring(err)))
        end
    end
end

---@class ScreenshotActions
---@field quick_full function|table   Immediate fullscreen capture
---@field quick_region function|table Fast region selection without editor
---@field quick_window function|table Immediate active window capture
---@field region function|table       Region selection with annotation editor
---@field resolve fun(): ScreenshotActions

---@return ScreenshotActions
local function build_actions()
    ---@type ScreenshotActions

    if config.active_engine == "hyprcapture" then
        capture.quick_full   = plugin_action("quick", "fullscreen")
        capture.quick_region = plugin_action("open", "region")
        capture.quick_window = plugin_action("quick", "window")
        capture.region       = plugin_action("open_editor", "")
    else
        if type(hl) == "table" and type(hl.dsp) == "table" and type(hl.dsp.exec_cmd) == "function" then
            capture.quick_full   = hl.dsp.exec_cmd(config.cli.quick_full)
            capture.quick_region = hl.dsp.exec_cmd(config.cli.quick_region)
            capture.quick_window = hl.dsp.exec_cmd(config.cli.quick_window)
            capture.region       = hl.dsp.exec_cmd(config.cli.region)
        else
            logger.error("Hyprland dispatcher API ('hl.dsp.exec_cmd') is unavailable for CLI screenshots.")
        end
    end

    return capture
end

local actions = build_actions()

-- Allow both `screenshot.quick_full` and `screenshot.resolve().quick_full`
actions.resolve = function()
    return actions
end

return actions
