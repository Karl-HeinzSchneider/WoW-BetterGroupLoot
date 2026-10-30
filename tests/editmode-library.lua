-- Load the actual private library through the standalone XML entry point.
local app, scripts, hooks = {}, {}, {}
Enum = { EditModeSettingDisplayType = { Checkbox = 1, Dropdown = 2, Slider = 3, Divider = 4, Expander = 5 } }
function CopyTable(source)
    local copy = {}
    for key, value in pairs(source) do
        copy[key] = value
    end
    return copy
end
function CreateUnsecuredObjectPool()
    return { Acquire = function() end }
end
EventRegistry = {
    RegisterFrameEventAndCallback = function() end,
    RegisterCallback = function() end,
}
EditModeManagerFrame = {
    HookScript = function(_, event, callback)
        scripts[event] = callback
    end,
}
EditModeSystemSettingsDialog = { HookScript = function() end }
function hooksecurefunc(_, method, callback)
    hooks[method] = callback
end
function securecallfunction(callback, ...)
    return callback(...)
end
function LibStub()
    error("The standalone library must stay private")
end
local function loadXml(path)
    local file = assert(io.open(path))
    local xml = file:read("*a")
    file:close()
    local directory = path:match("^(.*)/")
    for kind, name in xml:gmatch("<(%w+)%s+file=[\"']([^\"']+)") do
        local child = directory .. "/" .. name:gsub("\\", "/")
        if kind == "Include" then
            loadXml(child)
        elseif kind == "Script" then
            assert(loadfile(child))("BetterGroupLoot", app)
        end
    end
end
local entry = assert(io.open("BetterGroupLoot/standalone.xml"))
local manifest = entry:read("*a")
entry:close()
assert(manifest:find('file="lib\\LibEditMode\\namespaced.lua"', 1, true))
assert(manifest:find('file="lib\\LibEditMode\\embed.xml"', 1, true))
assert(loadfile("BetterGroupLoot/lib/LibEditMode/namespaced.lua"))("BetterGroupLoot", app)
loadXml("BetterGroupLoot/lib/LibEditMode/embed.xml")
local lib = assert(app.LibEditMode)
assert(type(lib.AddFrame) == "function" and type(lib.AddFrameSettings) == "function")
assert(type(lib.internal.CreateDialog) == "function" and type(lib.internal.GetPool) == "function")
assert(lib.internal:GetPool(lib.SettingType.Slider) and lib.internal:GetPool(lib.SettingType.Checkbox))
local entered, exited = 0, 0
lib:RegisterCallback("enter", function()
    entered = entered + 1
end)
lib:RegisterCallback("exit", function()
    exited = exited + 1
end)
assert(not lib:IsInEditMode())
scripts.OnShow()
assert(lib:IsInEditMode() and entered == 1)
scripts.OnHide()
assert(not lib:IsInEditMode() and exited == 1)
print("Vendored namespaced LibEditMode and standalone XML initialization passed")
