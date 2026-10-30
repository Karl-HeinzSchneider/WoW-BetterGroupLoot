---@type string, BetterGroupLoot
local appName, app = ...

-- Only the standalone TOC loads this adapter. Embedded hosts choose their own
-- library and call controller:RegisterEditMode explicitly, or register the anchor themselves.
local module = {}
app.addon:NewModule("Rolls", module, "AceEvent-3.0")

function app.addon:SetEditModeLibrary(lib)
    app.LibEditMode = lib
end

function module:TryEditMode()
    if not app.rolls or not app.rolls.active or self.loadingEditMode then
        return
    end
    if InCombatLockdown and InCombatLockdown() then
        return
    end
    if not app.LibEditMode then
        -- LibEditMode requires the native templates and manager. Never load its
        -- implementation on clients without those APIs; unlock mode remains usable.
        if
            not (
                C_EditMode
                and C_EditMode.GetLayouts
                and Enum
                and Enum.EditModeSettingDisplayType
                and EditModeManagerFrame
                and EditModeSystemSettingsDialog
                and EventRegistry
                and CreateUnsecuredObjectPool
                and C_AddOns
                and C_AddOns.LoadAddOn
            )
        then
            return
        end
        if self.attemptedEditMode then
            return
        end
        self.attemptedEditMode = true
        self.loadingEditMode = true
        local loaded, reason = C_AddOns.LoadAddOn("BetterGroupLoot_EditMode")
        self.loadingEditMode = false
        if not loaded then
            app.logger:debug("Edit Mode support could not be loaded: %s", tostring(reason))
            return
        end
    end
    if app.LibEditMode then
        app.rolls:RegisterEditMode(app.LibEditMode, {
            name = appName,
            defaults = app.dbDefaults.profile,
        })
        self:UnregisterAllEvents()
    end
end

function module:OnEnable()
    self.attemptedEditMode = false
    local controller, owner = app.StartGroupLoot({
        prefix = appName,
        getProfile = function()
            return app.db.profile
        end,
        defaultPosition = app.dbDefaults.profile.position,
        changed = function()
            app.options:Refresh()
        end,
    })
    app.rolls = controller
    if not controller then
        app.logger:chat("Group loot was not started (%s).", owner.prefix or owner.reason)
        return
    end
    -- Retry when Blizzard loads its UI or combat ends. No Edit Mode capability
    -- is required by the standalone runtime or its older-client unlock fallback.
    self:RegisterEvent("PLAYER_LOGIN", "TryEditMode")
    self:RegisterEvent("ADDON_LOADED", "TryEditMode")
    self:RegisterEvent("PLAYER_REGEN_ENABLED", "TryEditMode")
    self:TryEditMode()
end

function module:OnDisable()
    self:UnregisterAllEvents()
    if app.rolls then
        app.rolls:Stop()
    end
end

function module:OnProfileRefresh()
    if app.rolls then
        app.rolls:OnProfileRefresh()
    end
end
