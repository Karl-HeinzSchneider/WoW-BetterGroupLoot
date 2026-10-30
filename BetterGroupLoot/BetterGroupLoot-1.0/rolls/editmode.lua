local lib = LibStub("BetterGroupLoot-1.0")
local internal = lib.internal
if not internal.loading then
    return
end

local controller = internal.RollController

local function inCombat()
    return InCombatLockdown and InCombatLockdown()
end

-- Return ordinary LibEditMode rows so a host can compose them with its own
-- Position section and footer without registering a second frame or library.
function controller:GetEditModeSettings(editModeLib, options)
    options = options or {}
    local strings = options.strings or {}
    local defaults = options.defaults or lib.defaults
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
        local scale = setting("scale", editModeLib.SettingType.Slider, "Scale")
        scale.minValue, scale.maxValue, scale.valueStep = 0.5, 2, 0.05
        scale.formatter = function(value)
            return ("%d%%"):format(math.floor(value * 100 + 0.5))
        end
    end
    local spacing = setting("spacing", editModeLib.SettingType.Slider, "Spacing", "Gap between two rolls.")
    spacing.minValue, spacing.maxValue, spacing.valueStep = 0, 40, 1
    setting(
        "growUp",
        editModeLib.SettingType.Checkbox,
        "Stack upwards",
        "New rolls appear above the first one. Off: below it."
    )
    setting(
        "showUndecided",
        editModeLib.SettingType.Checkbox,
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
function controller:RegisterEditMode(editModeLib, options)
    if self.editMode then
        assert(self.editMode.library == editModeLib, "Group loot is already registered with another Edit Mode library")
        return self.editMode
    end
    assert(self.active and not inCombat(), "Start group loot outside combat before registering Edit Mode")
    assert(
        editModeLib
            and type(editModeLib.AddFrame) == "function"
            and type(editModeLib.AddFrameSettings) == "function"
            and type(editModeLib.RegisterCallback) == "function"
            and type(editModeLib.IsInEditMode) == "function"
            and type(editModeLib.RefreshFrameSettings) == "function",
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
        settings = settings(self, editModeLib)
    end
    if settings == nil then
        settings = self:GetEditModeSettings(editModeLib, options)
    end
    local registration = {
        library = editModeLib,
        managePreviews = options.managePreviews ~= false,
        defaultPosition = default,
        followDefaultScale = options.defaultPosition == nil,
    }
    self.editMode = registration
    editModeLib:AddFrame(self.anchor, function(frame, layout, point, x, y)
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
    editModeLib.frameSelections[self.anchor]:SetFrameStrata(self.anchor:GetFrameStrata())
    editModeLib:AddFrameSettings(self.anchor, settings)
    if options.buttons then
        editModeLib:AddFrameSettingsButtons(self.anchor, options.buttons)
    end
    for _, event in ipairs({ "enter", "exit", "layout" }) do
        editModeLib:RegisterCallback(event, function()
            self:RefreshEditMode()
        end)
    end
    self:RegisterEvent("PLAYER_REGEN_DISABLED", "RefreshEditMode")
    self:RegisterEvent("PLAYER_REGEN_ENABLED", "RefreshEditMode")
    self:RefreshEditMode()
    return registration
end
