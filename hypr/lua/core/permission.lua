-- ~/.config/hypr/lua/core/permissions.lua
-- See https://wiki.hypr.land/configuring/core/advanced-configuration/permissions/
-- Note: Permission changes require a full Hyprland restart to take effect.
local logger = SafeRequire("lua.utils.logger")

local M = {}

M.enforce = false

---@class PermissionSpec
---@field regex string
---@field permission "screencopy"|"plugin"|"keyboard"
---@field mode "allow"|"ask"|"deny"

-- Open/Closed Principle: Add or modify security rules here without touching apply()
---@type PermissionSpec[]
M.rules = {
    -- { regex = "/usr/(bin|local/bin)/grim", permission = "screencopy", mode = "allow" },
    -- { regex = "/usr/(lib|libexec|lib64)/xdg-desktop-portal-hyprland", permission = "screencopy", mode = "allow" },
    {
        regex = "/usr/(bin|local/bin)/hyprpm",
        permission = "plugin",
        mode = "allow"
    },
}

local valid_modes = {
    allow = true,
    ask   = true,
    deny  = true,
}

---Single Responsibility: Validates a single permission specification
---@param spec PermissionSpec
---@param index integer
---@return boolean
local function is_valid_rule(spec, index)
    if type(spec) ~= "table" then
        logger.error(string.format("Permission rule at index %d is not a table.", index))
        return false
    end

    local regex = spec.regex
    if type(regex) ~= "string" or regex:match("^%s*$") then
        logger.error(string.format("Permission rule at index %d is missing a valid 'regex'.", index))
        return false
    end

    local perm = spec.permission
    if type(perm) ~= "string" or perm:match("^%s*$") then
        logger.error(string.format("Permission rule [%s] is missing a valid 'permission' type.", regex))
        return false
    end

    local mode = spec.mode
    if type(mode) ~= "string" or not valid_modes[mode] then
        logger.error(string.format("Permission rule [%s] has invalid mode (%s); must be 'allow', 'ask', or 'deny'.",
            regex, tostring(mode)))
        return false
    end

    return true
end

---Single Responsibility: Applies ecosystem enforcement and permission rules to Hyprland
---@return boolean success
function M.apply()
    if type(hl) ~= "table" then
        logger.error("Hyprland API ('hl') is missing. Cannot apply permissions.")
        return false
    end

    local all_ok = true

    -- 1. Toggle ecosystem permission enforcement
    if M.enforce then
        if type(hl.config) ~= "function" then
            logger.error("Hyprland API ('hl.config') is missing for permission enforcement.")
            return false
        end

        local ok, err = pcall(hl.config, { ecosystem = { enforce_permissions = true } })
        if not ok then
            logger.error("Failed to enable ecosystem permission enforcement: " .. tostring(err))
            all_ok = false
        end
    end

    if #M.rules == 0 then
        return all_ok
    end

    -- 2. Apply individual binary permission rules
    if type(hl.permission) ~= "function" then
        logger.error("Hyprland API ('hl.permission') is missing. Cannot apply permission rules.")
        return false
    end

    for i, rule in ipairs(M.rules) do
        if is_valid_rule(rule, i) then
            local ok, err = pcall(hl.permission, rule.regex, rule.permission, rule.mode)
            if not ok then
                logger.error(string.format("Failed to apply permission [%s -> %s]: %s", rule.regex, rule.permission,
                    tostring(err)))
                all_ok = false
            end
        else
            all_ok = false
        end
    end

    return all_ok
end

return M
