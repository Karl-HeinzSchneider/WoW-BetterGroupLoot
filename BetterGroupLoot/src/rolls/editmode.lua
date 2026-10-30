---@type string, BetterGroupLoot
local _, app = ...

local controller = app.RollController

local function inCombat()
    return InCombatLockdown and InCombatLockdown()
end

-- Return ordinary LibEditMode rows so a host can compose them with its own
-- Position section and footer without registering a second frame or library.
function controller:GetEditModeSettings(lib, options)
    options = options or {}
    local strings = options.strings or {}
    local defaults = options.defaults or { scale = 1, spacing = 8, growUp = true, showUndecided = true }
    local settings = {}
    local function setting(key, kind, name, desc)
        local row = {
            key = key,
            kind = kind,
            name = strings[key] or name,
            desc = strings[key .. "Description"] or desc,
            default = defaults[key],
            get = function()
                return self:GetProfile()[key]
            end,
            set = function(_, value)
                if not self.active or inCombat() then
                    return
                end
                self:GetProfile()[key] = value
                self:ApplySettings()
                self:RefreshOptions()
            end,
            disabled = function()
                return not self.active or inCombat()
            end,
        }
        settings[#settings + 1] = row
        return row
    end
    if not options.omitScale then
        local scale = setting("scale", lib.SettingType.Slider, "Scale")
        scale.minValue, scale.maxValue, scale.valueStep = 0.5, 2, 0.05
        scale.formatter = function(value)
            return ("%d%%"):format(math.floor(value * 100 + 0.5))
        end
    end
    local spacing = setting("spacing", lib.SettingType.Slider, "Spacing", "Gap between two rolls.")
    spacing.minValue, spacing.maxValue, spacing.valueStep = 0, 40, 1
    setting("growUp", lib.SettingType.Checkbox, "Stack upwards", "New rolls appear above the first one. Off: below it.")
    setting(
        "showUndecided",
        lib.SettingType.Checkbox,
        "List undecided players",
        "The roll buttons' tooltips also list who hasn't chosen yet."
    )
    return settings
end

function controller:RefreshEditMode()
    if not self.editMode then
        return
    end
    self:RefreshPreviews()
    if self.active then
        self.editMode.library:RefreshFrameSettings(self.anchor)
    end
end

-- Explicit opt-in. Embedded hosts never acquire or load a library implicitly.
function controller:RegisterEditMode(lib, options)
    if self.editMode then
        assert(self.editMode.library == lib, "Group loot is already registered with another Edit Mode library")
        return self.editMode
    end
    assert(self.active and not inCombat(), "Start group loot outside combat before registering Edit Mode")
    assert(
        lib
            and type(lib.AddFrame) == "function"
            and type(lib.AddFrameSettings) == "function"
            and type(lib.RegisterCallback) == "function"
            and type(lib.IsInEditMode) == "function"
            and type(lib.RefreshFrameSettings) == "function",
        "A compatible Edit Mode library is required"
    )
    options = options or {}
    local default = options.defaultPosition
    if not default then
        local position = assert(self.host.defaultPosition, "A default Edit Mode position is required")
        local scale = self.anchor:GetScale()
        default = { point = "BOTTOM", x = position.x / scale, y = position.y / scale }
    end
    local settings = options.settings
    if type(settings) == "function" then
        settings = settings(self, lib)
    end
    if settings == nil then
        settings = self:GetEditModeSettings(lib, options)
    end
    local registration = {
        library = lib,
        managePreviews = options.managePreviews ~= false,
        defaultPosition = default,
        followDefaultScale = options.defaultPosition == nil,
    }
    self.editMode = registration
    lib:AddFrame(self.anchor, function(frame, layout, point, x, y)
        if not self.active or inCombat() then
            return
        end
        if options.onMoved then
            options.onMoved(frame, layout, point, x, y)
        else
            self:SavePosition()
        end
    end, default, options.name or self.host.prefix)
    -- The native selection template explicitly uses MEDIUM. Our rolls inherit
    -- DIALOG from the anchor, so match their strata to keep the selection's high
    -- frame level above the roll buttons for mouse selection and dragging.
    lib.frameSelections[self.anchor]:SetFrameStrata(self.anchor:GetFrameStrata())
    lib:AddFrameSettings(self.anchor, settings)
    if options.buttons then
        lib:AddFrameSettingsButtons(self.anchor, options.buttons)
    end
    for _, event in ipairs({ "enter", "exit", "layout" }) do
        lib:RegisterCallback(event, function()
            self:RefreshEditMode()
        end)
    end
    self:RegisterEvent("PLAYER_REGEN_DISABLED", "RefreshEditMode")
    self:RegisterEvent("PLAYER_REGEN_ENABLED", "RefreshEditMode")
    self:RefreshEditMode()
    return registration
end
