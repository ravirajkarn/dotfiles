-- See https://wiki.hypr.land/Configuring/Variables/#gestures
local logger = SafeRequire("lua.utils.logger")

local M = {}

-- Open/Closed Principle: Add or modify gesture rules here without touching apply()
---@type HL.GestureSpec[]
M.gestures = {
    {
        fingers   = 3,
        direction = "horizontal",
        action    = "workspace",
    },
    -- Example additional gesture:
    -- {
    --     fingers   = 4,
    --     direction = "vertical",
    --     action    = "fullscreen",
    -- },
}

local valid_directions = {
    horizontal = true,
    vertical   = true,
    up         = true,
    down       = true,
    left       = true,
    right      = true,
}

---Single Responsibility: Validates a single gesture specification before execution
---@param spec HL.GestureSpec
---@param index integer
---@return boolean
local function is_valid_gesture(spec, index)
    if type(spec) ~= "table" then
        logger.error(string.format("Gesture spec at index %d is not a table.", index))
        return false
    end

    local fingers = spec.fingers
    if type(fingers) ~= "number" or fingers < 2 or fingers > 5 then
        logger.error(string.format("Gesture spec at index %d has invalid 'fingers' (%s); must be 2..5.", index, tostring(fingers)))
        return false
    end

    local dir = spec.direction
    if type(dir) ~= "string" or not valid_directions[dir] then
        logger.error(string.format("Gesture spec at index %d has invalid 'direction' (%s).", index, tostring(dir)))
        return false
    end

    local action = spec.action
    if type(action) ~= "string" or action:match("^%s*$") then
        logger.error(string.format("Gesture spec at index %d is missing a valid 'action'.", index))
        return false
    end

    return true
end

---Safely applies all touchpad gesture configurations via hl.gesture()
---@return boolean success
function M.apply()
    if type(hl) ~= "table" or type(hl.gesture) ~= "function" then
        logger.error("Hyprland API ('hl.gesture') is missing. Cannot apply gestures.")
        return false
    end

    local all_ok = true

    for i, spec in ipairs(M.gestures) do
        if is_valid_gesture(spec, i) then
            local ok, err = pcall(hl.gesture, spec)
            if not ok then
                logger.error(string.format("Failed to apply gesture [%d-finger %s -> %s]: %s",
                    spec.fingers, spec.direction, spec.action, tostring(err)))
                all_ok = false
            end
        else
            all_ok = false
        end
    end

    return all_ok
end

return M