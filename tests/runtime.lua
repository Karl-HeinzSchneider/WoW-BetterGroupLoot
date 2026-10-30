-- Two independently loaded copies must cooperate before any UI or hooks are installed.
local function noop() end
local created, hooks, events = 0, 0, 0
local function region(parent, name)
    local object = { parent = parent, name = name, scripts = {} }
    setmetatable(object, {
        __index = function(_, key)
            if key == "GetParent" then
                return function(self)
                    return self.parent
                end
            end
            if key == "SetFrameStrata" then
                return function(self, strata)
                    self.strata = strata
                end
            end
            if key == "GetFrameStrata" then
                return function(self)
                    return self.strata or (self.parent and self.parent:GetFrameStrata()) or "MEDIUM"
                end
            end
            if key == "GetFrameLevel" then
                return function()
                    return 1
                end
            end
            if key == "GetScale" then
                return function()
                    return 1
                end
            end
            if key == "GetCenter" then
                return function()
                    return 700
                end
            end
            if key == "GetBottom" then
                return function()
                    return 400
                end
            end
            if key == "GetWidth" then
                return function()
                    return 1000
                end
            end
            if key == "CreateTexture" or key == "CreateFontString" then
                return function(self)
                    return region(self)
                end
            end
            if key == "GetNormalTexture" or key == "GetHighlightTexture" or key == "GetPushedTexture" then
                return function(self)
                    return region(self)
                end
            end
            if key == "SetScript" then
                return function(self, script, callback)
                    self.scripts[script] = callback
                end
            end
            if
                key:match("^Set")
                or key:match("^Register")
                or key == "Hide"
                or key == "Show"
                or key == "ClearAllPoints"
            then
                return noop
            end
        end,
    })
    return object
end
UIParent = region()
function CreateFrame(_, name, parent)
    created = created + 1
    local frame = region(parent, name)
    if name then
        assert(not _G[name])
        _G[name] = frame
    end
    return frame
end
function Mixin(target, source)
    for key, value in pairs(source) do
        target[key] = value
    end
end
function CreateObjectPool(create, reset)
    local free = {}
    return {
        Acquire = function()
            return table.remove(free) or create()
        end,
        Release = function(_, frame)
            reset(nil, frame)
            free[#free + 1] = frame
        end,
    }
end
function LibStub(name)
    assert(name == "AceEvent-3.0")
    return {
        Embed = function(_, target)
            target.RegisterEvent = function()
                events = events + 1
            end
            target.UnregisterAllEvents = noop
        end,
    }
end
GameTooltip = {
    IsOwned = function()
        return false
    end,
}
local function copy(supported)
    local app = { logger = { debug = noop, chat = noop } }
    app.api = {
        IsSupported = function()
            return supported
        end,
        HideBlizzardRollFrames = function(active)
            hooks = hooks + 1
            app.hookActive = active
        end,
        events = { rollStarted = "START", rollCancelled = "CANCEL", choicesChanged = { "CHOICES" } },
        GetActiveRolls = function()
            return {}
        end,
        IsRollUIActive = function()
            return true
        end,
        GetRollItem = function()
            return { count = 1, quality = 4, name = "Item", canGreed = true }
        end,
        GetRollChoices = function()
            return nil
        end,
        GetRollTimeLeft = function()
            return 1000
        end,
        GetQualityBorderAtlas = function()
            return "border"
        end,
        GetQualityColor = function()
            return 1, 1, 1
        end,
        ForgetRoll = noop,
    }
    for _, file in ipairs({ "rollframe", "frames", "rolls", "runtime" }) do
        assert(loadfile("BetterGroupLoot/src/rolls/" .. file .. ".lua"))("Test", app)
    end
    return app
end
local profile = { position = { x = 600, y = 420 }, scale = 1, spacing = 8, growUp = true }
local function host(prefix)
    return {
        prefix = prefix,
        getProfile = function()
            return profile
        end,
        defaultPosition = { x = 600, y = 420 },
    }
end
local first, second = copy(true), copy(true)
assert(created == 0 and hooks == 0 and events == 0)
assert(BetterGroupLootRollFrameMixin == nil and BetterGroupLootRollButtonMixin == nil)
local controller = assert(first.StartGroupLoot(host("SeamlessUIGroupLoot")))
assert(controller.anchor.name == "SeamlessUIGroupLootAnchor")
assert(hooks == 1 and events == 4 and first.hookActive())
local before = created
local other, owner = second.StartGroupLoot(nil)
assert(other == nil and owner.prefix == "SeamlessUIGroupLoot")
assert(created == before and hooks == 1 and events == 4)
-- A repeat start is idempotent and never recreates the UI.
assert(first.StartGroupLoot(host("Ignored")) == controller)
assert(created == before and hooks == 1)
controller:AddRoll(7, 1000)
assert(#controller.frames == 1)
local frame = controller.frames[1]
assert(frame.name == "SeamlessUIGroupLootRollFrame1" and frame.controller == controller)
controller:RemoveFrame(frame)
controller:AddRoll(8, 1000)
assert(controller.frames[1] == frame)
profile = { position = { x = 12, y = 34 }, scale = 2, spacing = 1 }
assert(controller:GetProfile() == profile)
controller:OnProfileRefresh()
controller:Stop()
assert(not first.hookActive() and #controller.frames == 0)
assert(second.StartGroupLoot(host("BetterGroupLoot")) == nil)
assert(first.StartGroupLoot(host("Ignored")) == controller)
-- The API installs a hook once; its predicate follows active state on restart.
assert(first.hookActive())
controller:Stop()
-- Also exercise the reverse load order in a fresh UI session.
BetterGroupLootRuntimeOwner = nil
local standalone = copy(true)
assert(standalone.StartGroupLoot(host("BetterGroupLoot")))
assert(copy(true).StartGroupLoot(host("OtherHost")) == nil)
BetterGroupLootRuntimeOwner = nil
local count = created
local unsupported, reason = copy(false).StartGroupLoot(host("Unsupported"))
assert(unsupported == nil and reason.reason == "unsupported")
assert(BetterGroupLootRuntimeOwner == nil and created == count)
print("Runtime ownership, isolated frames, pooling, profiles and lifecycle passed")

-- Invalid and failed startup must never let another copy take over partial UI.
assert(not pcall(function()
    copy(true).StartGroupLoot(host("bad-prefix"))
end))
assert(BetterGroupLootRuntimeOwner == nil)
local failing = host("FailedHost")
failing.getProfile = function()
    error("Profile unavailable")
end
assert(not pcall(function()
    copy(true).StartGroupLoot(failing)
end))
local blocked, failedOwner = copy(true).StartGroupLoot(nil)
assert(blocked == nil and failedOwner.prefix == "FailedHost")
assert(failedOwner.controller == nil)
print("Startup validation and failed-start ownership checks passed")

-- Also expose the isolated-copy fixture to the optional Edit Mode integration tests.
return { copy = copy }
