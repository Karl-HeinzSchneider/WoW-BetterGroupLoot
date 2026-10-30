---@type string, BetterGroupLoot
local appName, app = ...

-- Only the standalone TOC loads this adapter. Embedded hosts load api/ and rolls/
-- with their private table, then explicitly call app.StartGroupLoot(host).
local module = {}
app.addon:NewModule("Rolls", module)

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
    end
end

function module:OnDisable()
    if app.rolls then
        app.rolls:Stop()
    end
end

function module:OnProfileRefresh()
    if app.rolls then
        app.rolls:OnProfileRefresh()
    end
end
