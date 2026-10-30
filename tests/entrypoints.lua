-- Validate the library and standalone XML load graphs, including nested vendor includes.
local function read(path)
    local file = assert(io.open(path), path)
    local text = file:read("*a")
    file:close()
    return text
end
local function scripts(path, result)
    result = result or {}
    local directory = path:match("^(.*)/")
    local xml = read(path):gsub("<!%-%-.-%-%->", "")
    for kind, name in xml:gmatch("<(%w+)%s+file=[\"']([^\"']+)") do
        local child = directory .. "/" .. name:gsub("\\", "/")
        if kind == "Include" then
            scripts(child, result)
        elseif kind == "Script" then
            read(child)
            result[#result + 1] = child
        end
    end
    return result
end
local LIBRARY = "BetterGroupLoot/BetterGroupLoot-1.0/"
local library = scripts(LIBRARY .. "BetterGroupLoot-1.0.xml")
assert(#library == 12 and library[1] == LIBRARY .. "lib/LibStub/LibStub.lua")
assert(library[#library] == LIBRARY .. "rolls/runtime.lua") -- clears the loading flag
local standalone = scripts("BetterGroupLoot/standalone.xml")
local index, counts = {}, {}
for i, path in ipairs(standalone) do
    index[path] = i
    counts[path] = (counts[path] or 0) + 1
end
for i, path in ipairs(library) do
    assert(path:sub(1, #LIBRARY) == LIBRARY, path)
    assert(counts[path] == 1 and index[path] == i, path) -- the library loads first, once
    -- Self-contained: never the host's private table, never a path to this addon's folder.
    if not path:find("/lib/", #LIBRARY, true) then
        local source = read(path)
        assert(not source:find("=%s*%.%.%."), path .. " uses the addon vararg")
        assert(not source:lower():find("interface[/\\]+addons"), path .. " references an addon path")
    end
end
for path in pairs(index) do
    assert(path:sub(1, #LIBRARY) ~= LIBRARY or counts[path] == 1, path)
end
assert(
    index[LIBRARY .. "lib/LibStub/LibStub.lua"]
        < index["BetterGroupLoot/lib/CallbackHandler-1.0/CallbackHandler-1.0.lua"]
)
assert(
    index["BetterGroupLoot/lib/LibEditMode/namespaced.lua"] < index["BetterGroupLoot/lib/LibEditMode/LibEditMode.lua"]
)
assert(index["BetterGroupLoot/lib/LibEditMode/LibEditMode.lua"] < index["BetterGroupLoot/src/core/ace.lua"])
assert(index["BetterGroupLoot/src/core/db.lua"] < index["BetterGroupLoot/src/core/ace.lua"])
assert(index["BetterGroupLoot/src/core/ace.lua"] < index["BetterGroupLoot/src/core/options.lua"])
assert(index["BetterGroupLoot/src/core/options.lua"] < index["BetterGroupLoot/src/core/standalone.lua"])
assert(standalone[#standalone] == "BetterGroupLoot/BetterGroupLoot.lua")
local toc = read("BetterGroupLoot/BetterGroupLoot.toc")
local entries = {}
for line in toc:gmatch("[^\r\n]+") do
    if not line:match("^#") and not line:match("^%s*$") then
        entries[#entries + 1] = line
    end
end
assert(#entries == 1 and entries[1] == "standalone.xml")
print("Library and standalone XML dependency graphs passed")
