-- See https://wiki.hypr.land/configuring/core/binds/
local logger     = SafeRequire("lua.utils.logger")
local apps       = SafeRequire("lua.core.apps")
local screenshot = SafeRequire("lua.core.screenshot")



local M   = {}

M.mainMod = "SUPER"

-- Stores active bind handles by name or key (e.g., M.handles["close_window"]:set_enabled(false))
M.handles = {}

---@class BindSpec
---@field id? string
---@field key string
---@field action any
---@field opts? table

---Single Responsibility: Builds the complete list of keybinding specifications
---Deferred inside a function so `hl.dsp.*` is only evaluated when `hl` is verified present
---@return BindSpec[]
local function build_bindings()
	local mod         = M.mainMod
	local term        = (apps and apps.terminal) or "kitty"
	local fileManager = (apps and apps.fileManager) or "dolphin"
	local menu        = (apps and apps.menu) or "hyprlauncher"
	local browse      = (apps and apps.browser) or "firefox"
	---@type BindSpec[]
	local binds       = {
		-- Application & Window Management
		{ key = mod .. " + Q",     action = hl.dsp.exec_cmd(term) },
		{ id = "close_window_alt", key = "ALT + F4",              action = hl.dsp.window.close() },
		{
			key    = mod .. " + M",
			action = hl.dsp.exec_cmd(
				"command -v hyprshutdown >/dev/null 2>&1 && hyprshutdown || hyprctl dispatch 'hl.dsp.exit()'"),
		},
		{ key = mod .. " + E",             action = hl.dsp.exec_cmd(fileManager) },
		{ key = mod .. " + V",             action = hl.dsp.window.float({ action = "toggle" }) },
		{ key = mod .. " + R",             action = hl.dsp.exec_cmd(menu) },
		{ key = mod .. " + P",             action = hl.dsp.window.pseudo() },
		{ key = mod .. " + J",             action = hl.dsp.layout("togglesplit") },
		{ key = mod .. " + W",             action = hl.dsp.exec_cmd(browse) },

		-- Directional Focus (Arrow Keys)
		{ key = mod .. " + left",          action = hl.dsp.focus({ direction = "left" }) },
		{ key = mod .. " + right",         action = hl.dsp.focus({ direction = "right" }) },
		{ key = mod .. " + up",            action = hl.dsp.focus({ direction = "up" }) },
		{ key = mod .. " + down",          action = hl.dsp.focus({ direction = "down" }) },

		-- -- Special Workspace (Scratchpad)
		-- { key = mod .. " + S",          action = hl.dsp.workspace.toggle_special("magic") },
		-- { key = mod .. " + SHIFT + S",  action = hl.dsp.window.move({ workspace = "special:magic" }) },

		-- Mouse Workspace Scroll & Window Drag/Resize
		{ key = mod .. " + mouse_down",    action = hl.dsp.focus({ workspace = "e+1" }) },
		{ key = mod .. " + mouse_up",      action = hl.dsp.focus({ workspace = "e-1" }) },
		{ key = mod .. " + mouse:272",     action = hl.dsp.window.drag(),                      opts = { mouse = true } },
		{ key = mod .. " + mouse:273",     action = hl.dsp.window.resize(),                    opts = { mouse = true } },

		-- Screenshot
		{ key = "PRINT",                   action = screenshot and screenshot.quick_full },
		{ key = "SHIFT + PRINT",           action = screenshot and screenshot.quick_region },
		{ key = mod .. " + PRINT",         action = screenshot and screenshot.quick_window },
		{ key = mod .. " + SHIFT + PRINT", action = screenshot and screenshot.region },

		-- Laptop Multimedia Keys (PipeWire / WirePlumber & Brightness)
		{
			key    = "XF86AudioRaiseVolume",
			action = hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"),
			opts   = { locked = true, repeating = true },
		},
		{
			key    = "XF86AudioLowerVolume",
			action = hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"),
			opts   = { locked = true, repeating = true },
		},
		{
			key    = "XF86AudioMute",
			action = hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"),
			opts   = { locked = true, repeating = true },
		},
		{
			key    = "XF86AudioMicMute",
			action = hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"),
			opts   = { locked = true, repeating = true },
		},
		{
			key    = "XF86MonBrightnessUp",
			action = hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%+"),
			opts   = { locked = true, repeating = true },
		},
		{
			key    = "XF86MonBrightnessDown",
			action = hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%-"),
			opts   = { locked = true, repeating = true },
		},

		-- Media Playback Controls (playerctl)
		{ key = "XF86AudioNext",  action = hl.dsp.exec_cmd("playerctl next"),       opts = { locked = true } },
		{ key = "XF86AudioPause", action = hl.dsp.exec_cmd("playerctl play-pause"), opts = { locked = true } },
		{ key = "XF86AudioPlay",  action = hl.dsp.exec_cmd("playerctl play-pause"), opts = { locked = true } },
		{ key = "XF86AudioPrev",  action = hl.dsp.exec_cmd("playerctl previous"),   opts = { locked = true } },

	}


	-- Workspace Switching & Window Movement [1..10 -> keys 1..9, 0]
	for i = 1, 10 do
		local key = tostring(i % 10)
		table.insert(binds, {
			key    = mod .. " + " .. key,
			action = hl.dsp.focus({ workspace = i }),
		})
		table.insert(binds, {
			key    = mod .. " + SHIFT + " .. key,
			action = hl.dsp.window.move({ workspace = i }),
		})
	end

	return binds
end

---Single Responsibility: Validates a single keybinding specification
---@param spec BindSpec
---@param index integer
---@return boolean
local function is_valid_bind(spec, index)
	if type(spec) ~= "table" then
		logger.error(string.format("Bind spec at index %d is not a table.", index))
		return false
	end

	local key = spec.key
	if type(key) ~= "string" or key:match("^%s*$") then
		logger.error(string.format("Bind spec at index %d is missing a valid 'key' string.", index))
		return false
	end

	if spec.action == nil then
		logger.error(string.format("Bind [%s] at index %d has a nil 'action'.", key, index))
		return false
	end

	if spec.opts ~= nil and type(spec.opts) ~= "table" then
		logger.warn(string.format("Bind [%s] has non-table 'opts'; ignoring opts.", key))
		spec.opts = nil
	end

	return true
end

---Single Responsibility: Safely applies all keybindings to Hyprland via hl.bind()
---@return boolean success
function M.apply()
	if type(hl) ~= "table" or type(hl.bind) ~= "function" or type(hl.dsp) ~= "table" then
		logger.error("Hyprland API ('hl.bind' or 'hl.dsp') is missing. Cannot apply shortcuts.")
		return false
	end

	local ok_build, bindings = pcall(build_bindings)
	if not ok_build or type(bindings) ~= "table" then
		logger.error("Failed to construct keybindings table: " .. tostring(bindings))
		return false
	end

	local all_ok = true

	for i, spec in ipairs(bindings) do
		if is_valid_bind(spec, i) then
			local ok, res
			if spec.opts then
				ok, res = pcall(hl.bind, spec.key, spec.action, spec.opts)
			else
				ok, res = pcall(hl.bind, spec.key, spec.action)
			end

			if ok then
				M.handles[spec.id or spec.key] = res
			else
				logger.error(string.format("Failed to register bind [%s]: %s", spec.key, tostring(res)))
				all_ok = false
			end
		else
			all_ok = false
		end
	end
	-- logger.trace("all ok")
	return all_ok
end

return M
