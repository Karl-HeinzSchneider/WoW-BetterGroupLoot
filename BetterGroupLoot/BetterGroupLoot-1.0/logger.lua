local lib = LibStub("BetterGroupLoot-1.0")
local internal = lib.internal
if not internal.loading then
    return
end

-- The standard leveled chat logger. lib:CreateLogger(name) makes one tagged with the name;
-- `log("msg")` is `log:info("msg")`, `log:debug("Looted %s x%d", link, count)` formats,
-- `log:chat(...)` is unfiltered user-facing output, `log:dump(tbl)` prints a table at DEBUG.
-- A host supplying its own logger to Start needs `debug`, `error` and `chat` with format args.

---@class BetterGroupLoot.Logger
---@operator call(...): nil
---@field prefix string
---@field threshold BetterGroupLoot.LogLevel
local logger = {}

---@alias BetterGroupLoot.LogLevel integer

-- Higher number = more verbose. A message is shown when its level <= logger.threshold.
---@type table<string, BetterGroupLoot.LogLevel>
logger.level = {
    NONE = -1,
    ERROR = 0,
    WARN = 1,
    INFO = 2,
    VERBOSE = 3,
    DEBUG = 4,
    SILLY = 5,
}

local levelNames = {}
for name, value in pairs(logger.level) do
    levelNames[value] = name
end

local levelColors = {
    [logger.level.ERROR] = "ff5555",
    [logger.level.WARN] = "ffaa00",
    [logger.level.INFO] = "55ff55",
    [logger.level.VERBOSE] = "55aaff",
    [logger.level.DEBUG] = "aaaaaa",
    [logger.level.SILLY] = "777777",
}

-- Accepts a numeric level or a level name ("DEBUG", case-insensitive). Returns nil if invalid.
local function resolveLevel(level)
    if type(level) == "number" then
        return levelNames[level] and level or nil
    elseif type(level) == "string" then
        return logger.level[level:upper()]
    end
end

---@param level BetterGroupLoot.LogLevel|string
---@return boolean
function logger:setLevel(level)
    local resolved = resolveLevel(level)
    if not resolved then
        self:error("Unknown log level: %s", tostring(level))
        return false
    end
    self.threshold = resolved
    return true
end

function logger:getLevelName(level)
    return levelNames[level or self.threshold] or "UNKNOWN"
end

---@param level BetterGroupLoot.LogLevel
---@return boolean
function logger:isEnabled(level)
    return level <= self.threshold
end

-- Core output. `fmt` is passed through string.format when extra args are given,
-- otherwise it is printed as-is (so stray '%' in plain messages don't blow up).
---@param level BetterGroupLoot.LogLevel
---@param fmt any
---@param ... any
function logger:print(level, fmt, ...)
    if level < 0 or not self:isEnabled(level) then
        return
    end

    local msg
    if select("#", ...) > 0 then
        local ok, result = pcall(string.format, tostring(fmt), ...)
        msg = ok and result or ("format error: " .. tostring(result))
    else
        msg = tostring(fmt)
    end

    local color = levelColors[level] or "ffffff"
    print(("%s |cff%s[%s]|r %s"):format(self.prefix, color, levelNames[level], msg))
end

-- Level shortcuts: logger:info("Looted %s x%d", link, count)
function logger:error(...)
    self:print(self.level.ERROR, ...)
end
function logger:warn(...)
    self:print(self.level.WARN, ...)
end
function logger:info(...)
    self:print(self.level.INFO, ...)
end
function logger:verbose(...)
    self:print(self.level.VERBOSE, ...)
end
function logger:debug(...)
    self:print(self.level.DEBUG, ...)
end
function logger:silly(...)
    self:print(self.level.SILLY, ...)
end

-- Plain user-facing chat output, never filtered by level and without a level tag.
function logger:chat(fmt, ...)
    local msg = select("#", ...) > 0 and tostring(fmt):format(...) or tostring(fmt)
    print(self.prefix .. ": " .. msg)
end

-- Dump a table one level deep; useful for inspecting event payloads while debugging.
function logger:dump(tbl, label)
    if not self:isEnabled(self.level.DEBUG) then
        return
    end
    if type(tbl) ~= "table" then
        self:debug("%s = %s", label or "value", tostring(tbl))
        return
    end
    self:debug("%s = {", label or "table")
    for k, v in pairs(tbl) do
        self:debug("    [%s] = %s", tostring(k), tostring(v))
    end
    self:debug("}")
end

local metatable = {
    __index = logger,
    -- Allow `log("msg")` as shorthand for `log:info("msg")`.
    __call = function(self, ...)
        self:info(...)
    end,
}

---@param name string shown in front of every message
---@return BetterGroupLoot.Logger
function lib:CreateLogger(name)
    return setmetatable({
        prefix = "|cff33ccff" .. tostring(name) .. "|r",
        threshold = logger.level.INFO,
    }, metatable)
end

-- Used until a host starts the library with its own logger.
internal.logger = lib:CreateLogger("BetterGroupLoot")
