local ok_ins, inspect = pcall(require, "lua.utils.inspect")

local logger = { _VERSION = "0.1.0" }

logger.usecolor = true
logger.outfile = "/tmp/hypr-lua.log"
logger.level = "trace" -- Default log level

local modes = {
    { name = "trace", color = "\27[34m", },
    { name = "debug", color = "\27[36m", },
    { name = "info",  color = "\27[32m", },
    { name = "warn",  color = "\27[33m", },
    { name = "error", color = "\27[31m", },
    { name = "fatal", color = "\27[35m", },
}


local levels = {}
for i, v in ipairs(modes) do
    levels[v.name] = i
end

local function get_true_caller()
    for i = 2, 10 do
        local info = debug.getinfo(i, "Sl")
        if not info then break end

        local src = info.short_src
        -- Ignore our internal utility files
        if not string.find(src, "logger.lua", 1, true) and
            not string.find(src, "SafeRequire.lua", 1, true) then
            return src .. ":" .. info.currentline
        end
    end
    return "unknown:0"
end

for i, lvl in ipairs(modes) do
    local nameupper = lvl.name:upper()
    logger[lvl.name] = function(...)
        if i < levels[logger.level] then
            return
        end

        local args = { ... }
        local caller = get_true_caller()

        for i, v in ipairs(args) do
            if type(v) == "table" then
                args[i] = ok_ins and ("\n" .. inspect(v)) or tostring(v)
            else
                args[i] = tostring(v)
            end
        end

        local msg = string.format("%s[%-6s%s]%s %s: %s\n", logger.usecolor and lvl.color or "", nameupper,
            os.date("%H:%M:%S"), logger.usecolor and "\27[0m" or "", caller, table.concat(args, " "))

        -- Output to console with color if enabled
        print(msg)

        -- Write directly to file
        if logger.outfile then
            local f = io.open(logger.outfile, "a")
            if f then
                f:write(msg)
                f:close()
            end
        end
    end
end

return logger
