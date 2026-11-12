local logger = SafeRequire("lua.utils.logger")

local M = {}

-- Stores active handles returned by Hyprland (e.g. M.handles.window["suppress-maximize-events"])
M.handles = {
    window    = {},
    workspace = {},
    layer     = {},
}

---@type HL.WorkspaceRuleSpec[]
M.workspace_rules = {
    -- Uncomment for "Smart gaps" / "No gaps when only":
    -- { workspace = "w[tv1]", gaps_out = 0, gaps_in = 0 },
    -- { workspace = "f[1]",   gaps_out = 0, gaps_in = 0 },
}

---@type HL.WindowRuleSpec[]
M.window_rules = {

    -- Example window rules that are useful
    {
        name = "suppress-maximize-events",
        match = { class = ".*" },
        suppress_event = "maximize",
    },

    -- Fix some dragging issues with XWayland
    {
        name = "fix-xwayland-drags",
        match = {
            class = "^$",
            title = "^$",
            xwayland = true,
            float = true,
            fullscreen = false,
            pin = false,
        },
        no_focus = true,
    },

    -- Hyprland-run windowrule
    {
        name = "move-hyprland-run",
        match = { class = "hyprland-run" },
        move = "20 monitor_h-120",
        float = true,
    },
}

---@type HL.LayerRuleSpec[]
M.layer_rules = {
    -- {
    --     name = "no-anim-overlay",
    --     match = { namespace = "^my-overlay$" },
    --     no_anim = true,
    -- },
}

---@return boolean success
function M.apply()
    if type(hl) ~= "table" then
        logger.error("Hyprland API ('hl') is missing. Cannot apply rules.")
        return false
    end

    local all_ok = true

    if type(hl.workspace_rule) == "function" then
        for i, rule in ipairs(M.workspace_rules) do
            local ok, res = pcall(hl.workspace_rule, rule)
            if ok then
                M.handles.workspace[rule.workspace or i] = res
            else
                logger.error(string.format("Failed workspace rule [%s]: %s", tostring(rule.workspace or i), tostring(res)))
                all_ok = false
            end
        end
    end

    if type(hl.window_rule) == "function" then
        for i, rule in ipairs(M.window_rules) do
            local ok, res = pcall(hl.window_rule, rule)
            if ok then
                M.handles.window[rule.name or i] = res
            else
                logger.error(string.format("Failed window rule [%s]: %s", tostring(rule.name or i), tostring(res)))
                all_ok = false
            end
        end
    end

    if type(hl.layer_rule) == "function" then
        for i, rule in ipairs(M.layer_rules) do
            local ok, res = pcall(hl.layer_rule, rule)
            if ok then
                M.handles.layer[rule.name or i] = res
            else
                logger.error(string.format("Failed layer rule [%s]: %s", tostring(rule.name or i), tostring(res)))
                all_ok = false
            end
        end
    end

    return all_ok
end

return M
