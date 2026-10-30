---@type string, BetterGroupLoot
local appName, app = ...

-- The standalone addon is a host of BetterGroupLoot-1.0 like any embedding addon: it starts the
-- library with its saved profile and logger, and registers it with the private LibEditMode
-- that standalone.xml loads.
local library = LibStub("BetterGroupLoot-1.0")

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
    app.rolls:RegisterEditMode(app.LibEditMode, { name = appName })
    self:UnregisterAllEvents()
end

function module:OnEnable()
    local controller, owner = library:Start({
        name = appName,
        logger = app.logger,
        getProfile = function()
            return app.db.profile
        end,
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
