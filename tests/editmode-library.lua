-- Load the exact vendored scripts in companion TOC order. No global library is registered.
local app, scripts, hooks, delivered = {}, {}, {}, nil
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
function LibStub(name)
    assert(name == "AceAddon-3.0", "The standalone library must stay private")
    return {
        GetAddon = function(_, addonName)
            assert(addonName == "BetterGroupLoot")
            return {
                SetEditModeLibrary = function(_, lib)
                    delivered = lib
                end,
            }
        end,
    }
end
local toc = assert(io.open("BetterGroupLoot_EditMode/BetterGroupLoot_EditMode.toc"))
for line in toc:lines() do
    line = line:gsub("\r", "")
    if line:match("%.lua$") then
        local path = "BetterGroupLoot_EditMode/" .. line:gsub("\\", "/")
        assert(loadfile(path))("BetterGroupLoot_EditMode", app)
    end
end
toc:close()
local lib = assert(app.LibEditMode)
assert(delivered == lib and type(lib.AddFrame) == "function" and type(lib.AddFrameSettings) == "function")
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
print("Vendored namespaced LibEditMode and companion TOC initialization passed")
