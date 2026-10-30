-- Reuse the full frame/controller fixture and its baseline ownership assertions.
local fixture = dofile("tests/runtime.lua")
local combat = false
InCombatLockdown = function()
    return combat
end
Enum = { ItemQuality = { Epic = 4 } }
C_Item = {
    DoesItemExistByID = function()
        return false
    end,
}

local function newController(prefix)
    BetterGroupLootRuntimeOwner = nil
    local app = fixture.copy(true)
    app.api.client = "forever"
    app.api.NewChoices = function()
        return { need = {}, greed = {}, transmog = {}, disenchant = {}, pass = {}, undecided = {} }
    end
    assert(loadfile("BetterGroupLoot/src/rolls/editmode.lua"))("Test", app)
    local profile = { position = { x = 600, y = 420 }, scale = 1, spacing = 8, growUp = true, showUndecided = true }
    local changed = 0
    local controller = assert(app.StartGroupLoot({
        prefix = prefix,
        getProfile = function()
            return profile
        end,
        defaultPosition = { x = 600, y = 420 },
        changed = function()
            changed = changed + 1
        end,
    }))
    controller.anchor.SetScale = function(self, scale)
        self.scale = scale
    end
    controller.anchor.GetScale = function(self)
        return self.scale or 1
    end
    controller.mover.SetShown = function(self, shown)
        self.shown = not not shown
    end
    return controller, function(value)
        profile = value
    end, function()
        return changed
    end
end

local function library()
    local lib = { SettingType = { Slider = 1, Checkbox = 2 }, callbacks = {}, registered = 0, refreshes = 0 }
    function lib:AddFrame(frame, moved, default, name)
        self.registered = self.registered + 1
        self.frame, self.moved, self.default, self.name = frame, moved, default, name
    end
    function lib:AddFrameSettings(frame, settings)
        assert(frame == self.frame)
        self.settings = settings
    end
    function lib:AddFrameSettingsButtons(frame, buttons)
        assert(frame == self.frame)
        self.buttons = buttons
    end
    function lib:RegisterCallback(event, callback)
        self.callbacks[event] = callback
    end
    function lib:IsInEditMode()
        return not not self.editing
    end
    function lib:RefreshFrameSettings(frame)
        assert(frame == self.frame)
        self.refreshes = self.refreshes + 1
    end
    function lib:Enter()
        self.editing = true
        self.callbacks.enter()
    end
    function lib:Exit()
        self.editing = false
        self.callbacks.exit()
    end
    return lib
end

local controller, replaceProfile, changes = newController("EditModeStandalone")
assert(controller.editMode == nil) -- Loading shared code and starting remains opt-in.
local lib = library()
controller:RegisterEditMode(lib, { name = "Group loot" })
assert(lib.registered == 1 and lib.frame == controller.anchor and lib.name == "Group loot")
assert(#lib.settings == 4 and lib.default.point == "BOTTOM")
assert(controller:RegisterEditMode(lib) == controller.editMode and lib.registered == 1)
assert(not pcall(function()
    controller:RegisterEditMode(library())
end))
assert(lib.settings[1].formatter(1.25) == "125%")
lib.settings[1].set(nil, 2)
assert(controller:GetProfile().scale == 2 and lib.default.x == 300 and lib.default.y == 210)
lib.settings[2].set(nil, 12)
lib.settings[3].set(nil, false)
lib.settings[4].set(nil, false)
assert(controller:GetProfile().spacing == 12 and not controller:GetProfile().growUp)
assert(not controller:GetProfile().showUndecided and changes() == 4)
replaceProfile({ position = { x = 100, y = 100 }, scale = 1, spacing = 4, growUp = true, showUndecided = true })
controller:OnProfileRefresh()
assert(lib.settings[2].get() == 4)
lib.settings[2].set(nil, 5)
assert(controller:GetProfile().spacing == 5)

controller:AddRoll(42, 1000)
lib:Enter()
assert(#controller.frames == 4 and controller.frames[1].rollID == 42)
lib.callbacks.layout()
assert(#controller.frames == 4) -- No duplicate preview stack.
controller:SetUnlocked(true)
assert(#controller.frames == 4 and not controller.mover.shown)
lib:Exit()
assert(#controller.frames == 4 and controller.mover.shown)
controller:SetUnlocked(false)
assert(#controller.frames == 1)
lib:Enter()
combat = true
controller:RefreshEditMode()
assert(#controller.frames == 1 and lib.settings[2].disabled())
lib.settings[2].set(nil, 39)
assert(controller:GetProfile().spacing == 5)
combat = false
controller:RefreshEditMode()
assert(#controller.frames == 4)
lib:Exit()
assert(#controller.frames == 1 and controller.frames[1].rollID == 42)
-- Native drag/reset callbacks store the final screen position through the host.
lib.moved(controller.anchor, "Modern", "TOP", 1, 2)
assert(controller:GetProfile().position.x == 200 and controller:GetProfile().position.y == 400)
controller:Stop()
lib:Enter()
assert(#controller.frames == 0 and lib.settings[1].disabled())
controller:Start()
assert(lib.registered == 1 and #controller.frames == 3)
controller:Stop()

-- Seamless can supply its own extended rows, position callback and preview control.
local embedded = newController("EditModeEmbedded")
local extended = library()
local position = { kind = "ExtendedPosition" }
local moved, buttons = nil, { { text = "Host action" } }
embedded:RegisterEditMode(extended, {
    name = "Host-localized title",
    defaultPosition = { point = "CENTER", x = 1, y = 2 },
    managePreviews = false,
    settings = function(current, injected)
        local rows = current:GetEditModeSettings(injected, {
            omitScale = true,
            strings = { spacing = "Host-localized spacing" },
        })
        table.insert(rows, 1, position)
        return rows
    end,
    onMoved = function(...)
        moved = { ... }
    end,
    buttons = buttons,
})
assert(#extended.settings == 4 and extended.settings[1] == position)
assert(extended.settings[2].key == "spacing" and extended.settings[2].name == "Host-localized spacing")
assert(extended.buttons == buttons)
extended:Enter()
assert(#embedded.frames == 0)
embedded:ShowPreviews()
extended:Exit()
assert(#embedded.frames == 3) -- Host owns preview visibility when opted out.
extended.moved(embedded.anchor, "Layout", "RIGHT", 3, 4)
assert(moved[1] == embedded.anchor and moved[2] == "Layout" and moved[5] == 4)
assert(embedded:GetProfile().position.x == 600)
embedded:Stop()

-- Standalone always uses the private library loaded by standalone.xml.
local standalone, addon = nil, {}
local registerCount, starts, waits = 0, 0, 0
function addon:NewModule(_, module)
    standalone = module
    module.RegisterEvent = function(_, event, handler)
        assert(event == "PLAYER_REGEN_ENABLED" and handler == "RegisterEditMode")
        waits = waits + 1
    end
    module.UnregisterAllEvents = function() end
end
local fakeController = {
    active = true,
    RegisterEditMode = function(_, injected)
        assert(injected == lib)
        registerCount = registerCount + 1
    end,
    Stop = function(self)
        self.active = false
    end,
}
local app = {
    addon = addon,
    LibEditMode = lib,
    StartGroupLoot = function()
        starts = starts + 1
        fakeController.active = true
        return fakeController
    end,
    dbDefaults = { profile = { position = {} } },
    db = { profile = {} },
    logger = { chat = function() end },
}
assert(loadfile("BetterGroupLoot/src/core/standalone.lua"))("BetterGroupLoot", app)
standalone:OnEnable()
assert(starts == 1 and registerCount == 1)
standalone:OnDisable()
combat = true
standalone:OnEnable()
assert(registerCount == 1 and waits == 1)
combat = false
standalone:RegisterEditMode()
assert(registerCount == 2)
standalone:OnDisable()
app.StartGroupLoot = function()
    return nil, { prefix = "OtherHost" }
end
standalone:OnEnable()
assert(registerCount == 2) -- A losing runtime never registers the frame.
print("Optional Edit Mode settings, previews, movement, lifecycle and standalone registration passed")
