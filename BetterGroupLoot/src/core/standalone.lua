---@type string, BetterGroupLoot
local appName, app = ...

-- standalone.xml supplies the private library. Embedded hosts supply their own
-- library and explicitly register the controller, or register its anchor themselves.
local module = {}
app.addon:NewModule("Rolls", module, "AceEvent-3.0")

function module:RegisterEditMode()
    if not app.rolls or not app.rolls.active then
        return
    end
    if InCombatLockdown() then
        self:RegisterEvent("PLAYER_REGEN_ENABLED", "RegisterEditMode")
        return
    end
    app.rolls:RegisterEditMode(app.LibEditMode, {
        name = appName,
        defaults = app.dbDefaults.profile,
    })
    self:UnregisterAllEvents()
end

function module:OnEnable()
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
    self:RegisterEditMode()
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
