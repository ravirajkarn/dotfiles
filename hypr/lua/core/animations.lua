local logger = SafeRequire("lua.utils.logger")

local M = {}

M.enabled = true

---@type table<string, any>
M.curves = {
    easeOutQuint   = { type = "bezier", points = { { 0.23, 1 }, { 0.32, 1 } } },
    easeInOutCubic = { type = "bezier", points = { { 0.65, 0.05 }, { 0.36, 1 } } },
    linear         = { type = "bezier", points = { { 0, 0 }, { 1, 1 } } },
    almostLinear   = { type = "bezier", points = { { 0.5, 0.5 }, { 0.75, 1 } } },
    quick          = { type = "bezier", points = { { 0.15, 0 }, { 0.1, 1 } } },
    easy           = { type = "spring", mass = 1, stiffness = 238.1191, damping = 24.21279333 },
}

---@type any
M.leaves = {
    { leaf = "global",        enabled = true, speed = 10,   bezier = "default" },
    { leaf = "border",        enabled = true, speed = 5.39, bezier = "easeOutQuint" },
    { leaf = "windows",       enabled = true, speed = 4.79, spring = "easy" },
    { leaf = "windowsIn",     enabled = true, speed = 4.1,  spring = "easy",         style = "popin 87%" },
    { leaf = "windowsOut",    enabled = true, speed = 1.49, bezier = "linear",       style = "popin 87%" },
    { leaf = "fadeIn",        enabled = true, speed = 1.73, bezier = "almostLinear" },
    { leaf = "fadeOut",       enabled = true, speed = 1.46, bezier = "almostLinear" },
    { leaf = "fade",          enabled = true, speed = 3.03, bezier = "quick" },
    { leaf = "layers",        enabled = true, speed = 3.81, bezier = "easeOutQuint" },
    { leaf = "layersIn",      enabled = true, speed = 4,    bezier = "easeOutQuint", style = "fade" },
    { leaf = "layersOut",     enabled = true, speed = 1.5,  bezier = "linear",       style = "fade" },
    { leaf = "fadeLayersIn",  enabled = true, speed = 1.79, bezier = "almostLinear" },
    { leaf = "fadeLayersOut", enabled = true, speed = 1.39, bezier = "almostLinear" },
    { leaf = "workspaces",    enabled = true, speed = 1.94, bezier = "almostLinear", style = "fade" },
    { leaf = "workspacesIn",  enabled = true, speed = 1.21, bezier = "almostLinear", style = "fade" },
    { leaf = "workspacesOut", enabled = true, speed = 1.94, bezier = "almostLinear", style = "fade" },
    { leaf = "zoomFactor",    enabled = true, speed = 7,    bezier = "quick" },
}

---@return boolean success
function M.apply()
    if type(hl) ~= "table" or type(hl.config) ~= "function" or type(hl.curve) ~= "function" or type(hl.animation) ~= "function" then
        logger.error("Hyprland animation APIs are missing. Cannot apply animations.")
        return false
    end

    local all_ok = true

    local ok_cfg, err_cfg = pcall(hl.config, { animations = { enabled = M.enabled } })
    if not ok_cfg then
        logger.error("Failed to toggle animations: " .. tostring(err_cfg))
        all_ok = false
    end

    for name, spec in pairs(M.curves) do
        local ok, err = pcall(hl.curve, name, spec)
        if not ok then
            logger.error(string.format("Failed to register curve [%s]: %s", name, tostring(err)))
            all_ok = false
        end
    end

    for _, anim in ipairs(M.leaves) do
        local ok, err = pcall(hl.animation, anim)
        if not ok then
            logger.error(string.format("Failed to register animation [%s]: %s", tostring(anim.leaf), tostring(err)))
            all_ok = false
        end
    end

    return all_ok
end

return M
