-- Every copy of the library must cooperate before any UI or hooks are installed.
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
            if key == "RegisterEvent" then
                return function()
                    events = events + 1
                end
            end
            if key == "UnregisterAllEvents" then
                return noop
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
function wipe(t)
    for key in pairs(t) do
        t[key] = nil
    end
    return t
end
GetBuildInfo = function()
    return "", "", "", 0
end
GameTooltip = {
    IsOwned = function()
        return false
    end,
}

local library = dofile("tests/library.lua")

-- Stands in for a client adapter, so the controller runs without a game.
local function inject(lib, supported)
    local api = lib.internal.api
    api.client = supported and "test" or nil
    api.HideBlizzardRollFrames = function(active)
        hooks = hooks + 1
        lib.hookActive = active
    end
    api.events = { rollStarted = "START", rollCancelled = "CANCEL", choicesChanged = { "CHOICES" } }
    api.GetActiveRolls = function()
        return {}
    end
    api.IsRollUIActive = function()
        return true
    end
    api.GetRollItem = function()
        return { count = 1, quality = 4, name = "Item", canGreed = true }
    end
    api.GetRollChoices = function()
        return nil
    end
    api.GetRollTimeLeft = function()
        return 1000
    end
    api.GetQualityBorderAtlas = function()
        return "border"
    end
    api.GetQualityColor = function()
        return 1, 1, 1
    end
    api.ForgetRoll = noop
    return lib
end

-- The library in a new UI session.
local function fresh(supported)
    library.reset()
    return inject(library.load(), supported)
end

local profile = { position = { x = 600, y = 420 }, scale = 1, spacing = 8, growUp = true }
local function host(name)
    return {
        name = name,
        getProfile = function()
            return profile
        end,
        defaultPosition = { x = 600, y = 420 },
    }
end

-- Loading does nothing: no frames, hooks, events or globals until a host starts it.
local lib = fresh(true)
assert(created == 0 and hooks == 0 and events == 0)
assert(BetterGroupLootRollFrameMixin == nil and BetterGroupLootRollButtonMixin == nil)
assert(BetterGroupLootRuntimeOwner == nil and lib:GetOwner() == nil and lib.internal.loading == nil)
local controller = assert(lib:Start(host("SeamlessUIGroupLoot")))
assert(controller.anchor.name == "SeamlessUIGroupLootAnchor")
assert(hooks == 1 and events == 4 and lib.hookActive())
assert(lib:GetOwner() == BetterGroupLootRuntimeOwner and BetterGroupLootRuntimeOwner.controller == controller)
local before = created
-- Another host gets nothing; nothing is created for it.
local other, owner = lib:Start(host("BetterGroupLoot"))
assert(other == nil and owner.prefix == "SeamlessUIGroupLoot")
assert(created == before and hooks == 1 and events == 4)
-- A started library is never upgraded, by a copy of the same or a newer version.
local internal = lib.internal
assert(library.load() == lib and lib.internal == internal and internal.loading == nil)
assert(library.load({ minor = 99 }) == lib and lib.minor == 1 and lib.internal == internal)
assert(lib:Start(host("BetterGroupLoot")) == nil)
-- The owner starting again is idempotent and never recreates the UI.
assert(lib:Start(host("SeamlessUIGroupLoot")) == controller)
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
assert(not lib.hookActive() and #controller.frames == 0)
assert(lib:Start(host("BetterGroupLoot")) == nil)
assert(lib:Start(host("SeamlessUIGroupLoot")) == controller)
-- The API installs a hook once; its predicate follows active state on restart.
assert(lib.hookActive())
controller:Stop()
print("Runtime ownership, isolated frames, pooling, profiles and lifecycle passed")

-- Before any Start, a newer copy replaces the code; an older one stays out.
lib = fresh(true)
assert(library.load({ minor = 2 }) == lib and lib.minor == 2 and lib.internal.loading == nil)
local upgraded = lib.internal
assert(library.load() == lib and lib.minor == 2 and lib.internal == upgraded and upgraded.loading == nil)
inject(lib, true)
assert(lib:Start(host("Upgraded")).anchor.name == "UpgradedAnchor")
assert(lib:GetOwner().minor == 2)
-- An older release that predates the library still owns the frames through the global.
lib = fresh(true)
BetterGroupLootRuntimeOwner = { prefix = "OldRelease", version = 1, reason = "owned" }
local blocked, legacy = lib:Start(host("BetterGroupLoot"))
assert(blocked == nil and legacy.prefix == "OldRelease")
-- An unsupported client reserves nothing.
lib = fresh(false)
local count = created
local unsupported, reason = lib:Start(host("Unsupported"))
assert(unsupported == nil and reason.reason == "unsupported")
assert(BetterGroupLootRuntimeOwner == nil and created == count)
print("Library versions, upgrades and legacy ownership passed")

-- Only a name is required: settings default to an unsaved copy of lib.defaults, the logger to
-- the standard one; a host's logger and strings are used as given.
lib = fresh(true)
local minimal = assert(lib:Start({ name = "Minimal" }))
assert(minimal:GetProfile().spacing == lib.defaults.spacing and minimal:GetProfile() ~= lib.defaults)
assert(minimal:GetProfile().position ~= lib.defaults.position)
assert(minimal.logger.prefix:find("Minimal", 1, true) and lib.internal.logger == minimal.logger)
assert(minimal.strings.nobody == "Nobody yet.")
lib = fresh(true)
local hostLogger = { debug = noop, error = noop, chat = noop }
local custom = host("CustomHost")
custom.logger = hostLogger
custom.strings = { need = "Bedarf" }
local hosted = assert(lib:Start(custom))
assert(hosted.logger == hostLogger and lib.internal.logger == hostLogger)
assert(hosted.strings.need == "Bedarf" and hosted.strings.pass == "Pass")
print("Start defaults, host logger and strings passed")

-- Invalid and failed startup must never let another host take over partial UI.
lib = fresh(true)
assert(not pcall(function()
    lib:Start(host("bad-prefix"))
end))
assert(BetterGroupLootRuntimeOwner == nil and lib:GetOwner() == nil)
local failing = host("FailedHost")
failing.getProfile = function()
    error("Profile unavailable")
end
assert(not pcall(function()
    lib:Start(failing)
end))
local denied, failedOwner = lib:Start(host("OtherHost"))
assert(denied == nil and failedOwner.prefix == "FailedHost")
assert(failedOwner.controller == nil)
print("Startup validation and failed-start ownership checks passed")

-- Also expose the fixture to the optional Edit Mode integration tests.
return { fresh = fresh }
