-- Validate both real XML load graphs, including nested vendor includes.
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
local embedded = scripts("BetterGroupLoot/embedded.xml")
assert(#embedded == 9)
local standalone = scripts("BetterGroupLoot/standalone.xml")
local index, counts = {}, {}
for i, path in ipairs(standalone) do
    index[path] = i
    counts[path] = (counts[path] or 0) + 1
end
for _, path in ipairs(embedded) do
    assert(path:match("^BetterGroupLoot/src/api/") or path:match("^BetterGroupLoot/src/rolls/"))
    assert(counts[path] == 1, path)
end
assert(
    index["BetterGroupLoot/lib/LibEditMode/namespaced.lua"] < index["BetterGroupLoot/lib/LibEditMode/LibEditMode.lua"]
)
assert(index["BetterGroupLoot/lib/LibEditMode/LibEditMode.lua"] < index["BetterGroupLoot/src/core/ace.lua"])
assert(index["BetterGroupLoot/src/core/logger.lua"] < index[embedded[1]])
assert(index["BetterGroupLoot/src/core/ace.lua"] < index["BetterGroupLoot/src/core/options.lua"])
assert(index[embedded[#embedded]] < index["BetterGroupLoot/src/core/standalone.lua"])
assert(standalone[#standalone] == "BetterGroupLoot/BetterGroupLoot.lua")
local toc = read("BetterGroupLoot/BetterGroupLoot.toc")
local entries = {}
for line in toc:gmatch("[^\r\n]+") do
    if not line:match("^#") and not line:match("^%s*$") then
        entries[#entries + 1] = line
    end
end
assert(#entries == 1 and entries[1] == "standalone.xml")
print("Single-addon standalone and embedded XML dependency graphs passed")
