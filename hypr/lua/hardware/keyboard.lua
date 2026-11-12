-- See https://wiki.hypr.land/Configuring/Variables/#input
local logger = SafeRequire("lua.utils.logger")

local M = {}

-- 1. Global keyboard configuration
---@type HL.ConfigOpt.Input
M.keyboardConfig = {
	kb_layout  = "us",
	kb_variant = "",
	kb_model   = "",
	kb_options = "",
	kb_rules   = "",
	-- Optional repeat settings:
	-- repeat_rate = 25,
	-- repeat_delay = 600,
}

-- 2. Per-device keyboard overrides (Open/Closed Principle)
---@type HL.DeviceSpec[]
M.devices = {
	-- Example per-keyboard override:
	-- {
	--     name = "at-translated-set-2-keyboard",
	--     kb_options = "caps:escape",
	-- },
}

---Single Responsibility: Validates and sanitizes keyboard input properties
---@param cfg HL.ConfigOpt.Input
local function validate_input(cfg)
	local str_fields = { "kb_layout", "kb_variant", "kb_model", "kb_options", "kb_rules" }

	for _, field in ipairs(str_fields) do
		local val = cfg[field]
		if val ~= nil and type(val) ~= "string" then
			logger.warn(string.format("Keyboard field '%s' must be a string; resetting to empty string.", field))
			cfg[field] = ""
		end
	end

	local layout = cfg.kb_layout
	if type(layout) ~= "string" or layout:match("^%s*$") then
		logger.warn("Keyboard 'kb_layout' cannot be empty; defaulting to 'us'.")
		cfg.kb_layout = "us"
	end

	local rate = cfg.repeat_rate
	if type(rate) == "number" and (rate < 1 or rate > 200) then
		local clamped = math.max(1, math.min(200, rate))
		logger.warn(string.format("repeat_rate (%d) out of bounds [1..200]; clamping to %d.", rate, clamped))
		cfg.repeat_rate = clamped
	end

	local delay = cfg.repeat_delay
	if type(delay) == "number" and delay < 50 then
		logger.warn(string.format("repeat_delay (%d) too low; clamping to 50ms.", delay))
		cfg.repeat_delay = 50
	end
end

---Single Responsibility: Validates per-device keyboard specification
---@param dev HL.DeviceSpec
---@param index integer
---@return boolean
local function is_valid_device(dev, index)
	if type(dev) ~= "table" then
		logger.error(string.format("Keyboard device spec at index %d is not a table.", index))
		return false
	end

	local name = dev.name
	if type(name) ~= "string" or name == "" then
		logger.error(string.format("Keyboard device spec at index %d is missing a valid 'name'.", index))
		return false
	end

	local trimmed = name:match("^%s*(.-)%s*$")
	if trimmed ~= name then
		logger.warn(string.format("Trimmed whitespace from keyboard device [%s] -> [%s].", name, trimmed))
		dev.name = trimmed
	end

	return true
end

---Safely applies keyboard configuration and device overrides to Hyprland
---@return boolean success
function M.apply()
	validate_input(M.keyboardConfig)

	if type(hl) ~= "table" or type(hl.config) ~= "function" or type(hl.device) ~= "function" then
		logger.error("Hyprland API ('hl.config' or 'hl.device') is missing. Cannot apply keyboard config.")
		return false
	end

	local all_ok = true

	local ok_cfg, err_cfg = pcall(hl.config, { input = M.keyboardConfig })
	if not ok_cfg then
		logger.error("Failed to apply global keyboard configuration: " .. tostring(err_cfg))
		all_ok = false
	end

	for i, dev in ipairs(M.devices) do
		if is_valid_device(dev, i) then
			local ok_dev, err_dev = pcall(hl.device, dev)
			if not ok_dev then
				logger.error(string.format("Failed to apply keyboard device [%s]: %s", tostring(dev.name),
					tostring(err_dev)))
				all_ok = false
			end
		else
			all_ok = false
		end
	end

	return all_ok
end

return M
