-- Loads BetterGroupLoot-1.0 the way the client does: every script of its XML, in order, with
-- no vararg (library files never use `...`). Shared by the offline tests.
local XML = "BetterGroupLoot/BetterGroupLoot-1.0/BetterGroupLoot-1.0.xml"

local function read(path)
    local file = assert(io.open(path), path)
    local text = file:read("*a")
    file:close()
    return text
end

local M = {}

---@return string[] script paths in load order
function M.scripts()
    local directory = XML:match("^(.*)/")
    local result = {}
    for kind, name in read(XML):gsub("<!%-%-.-%-%->", ""):gmatch("<(%w+)%s+file=[\"']([^\"']+)") do
        assert(kind == "Script", "the library XML includes only scripts")
        result[#result + 1] = directory .. "/" .. name:gsub("\\", "/")
    end
    return result
end

-- A new UI session: no LibStub, no library, no owner.
function M.reset()
    LibStub = nil
    BetterGroupLootRuntimeOwner = nil
end

-- Loads one copy of the library. `minor` replaces core.lua's MINOR (a newer or older copy);
-- `after(path, lib)` runs after each file.
function M.load(options)
    options = options or {}
    for _, path in ipairs(M.scripts()) do
        local chunk
        if options.minor and path:match("/core%.lua$") then
            local source, count = read(path):gsub('(MINOR = "[^"]+", )%d+', "%1" .. options.minor)
            assert(count == 1, "core.lua declares MINOR once")
            chunk = assert((loadstring or load)(source, "@" .. path))
        else
            chunk = assert(loadfile(path))
        end
        chunk()
        if options.after then
            options.after(path, LibStub and LibStub("BetterGroupLoot-1.0", true))
        end
    end
    return LibStub("BetterGroupLoot-1.0")
end

return M
