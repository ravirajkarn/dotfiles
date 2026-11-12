local logger = SafeRequire("lua.utils.logger")

local M = {}

M.config = {
    general = {
        gaps_in = 0,
        gaps_out = 0,
        border_size = 1,
        col = {
            active_border = { colors = { "rgba(33ccffee)", "rgba(00ff99ee)" }, angle = 45 },
            inactive_border = "rgba(595959aa)",
        },
        resize_on_border = false,
        allow_tearing = false,
        layout = "dwindle",
    },

    decoration = {
        rounding = 5,
        rounding_power = 2,
        active_opacity = 1.0,
        inactive_opacity = 1.0,
        shadow = {
            enabled = true,
            range = 4,
            render_power = 3,
            color = 0xee1a1a1a,
        },
        blur = {
            enabled = true,
            size = 3,
            passes = 1,
            vibrancy = 0.1696,
        },
    },

    -- See https://wiki.hypr.land/configuring/layouts/dwindle-layout/ for more
    dwindle = {
        preserve_split = true,
    },

    -- See https://wiki.hypr.land/configuring/layouts/master-layout/ for more
    master = {
        new_status = "master",
    },

    -- See https://wiki.hypr.land/configuring/layouts/scrolling-layout/ for more
    scrolling = {
        fullscreen_on_one_column = true,
    },

    ----------------
    ----  MISC  ----
    ----------------
    misc = {
        force_default_wallpaper = -1,
        disable_hyprland_logo = false,
    },

    ----------------
    ---- LAYERS ----
    ----------------
    layers = {
        allow_new_top_layers_over_existing_fullscreen = true,
    },
}



---Validates opacity and border bounds before applying
local function validate(cfg)
    local dec = cfg.decoration
    if type(dec) == "table" then
        for _, field in ipairs({ "active_opacity", "inactive_opacity" }) do
            local val = dec[field]
            if type(val) == "number" and (val < 0.0 or val > 1.0) then
                local clamped = math.max(0.0, math.min(1.0, val))
                logger.warn(string.format("decoration.%s (%.2f) out of bounds; clamping to %.2f.", field, val, clamped))
                dec[field] = clamped
            end
        end
    end
end

---@return boolean success
function M.apply()
    validate(M.config)

    if type(hl) ~= "table" or type(hl.config) ~= "function" then
        logger.error("Hyprland API ('hl.config') is missing. Cannot apply appearance.")
        return false
    end

    local ok, err = pcall(hl.config, M.config)
    if not ok then
        logger.error("Failed to apply appearance configuration: " .. tostring(err))
        return false
    end

    return true
end

return M
