---@type string, BetterGroupLoot
local appName, app = ...

local log = app.logger
local addon = app.addon

-- The addon's options as one AceConfig table, shown in the game's Settings panel (AddOns tab) and
-- in a standalone window (`/bettergrouploot`), so an option is added here once.
---@class BetterGroupLoot.Options : AceModule
local module = {}
app.options = addon:NewModule("Options", module) --[[@as BetterGroupLoot.Options]]

-- The log levels for the select, quietest first, shown as "Info" for "INFO".
local levelNames, levelOrder = {}, {}
for name in pairs(log.level) do
    levelNames[name] = name:sub(1, 1) .. name:sub(2):lower()
    levelOrder[#levelOrder + 1] = name
end
table.sort(levelOrder, function(a, b)
    return log.level[a] < log.level[b]
end)

-- A profile value that moves or restacks the roll frames when changed.
local function layoutSetting(key)
    return {
        get = function()
            return app.db.profile[key]
        end,
        set = function(_, value)
            app.db.profile[key] = value
            app.rolls:ApplySettings()
        end,
    }
end

local function positionSetting(key)
    return {
        get = function()
            return app.db.profile.position[key]
        end,
        set = function(_, value)
            app.db.profile.position[key] = value
            app.rolls:ApplySettings()
        end,
    }
end

local function merge(base, extra)
    for k, v in pairs(extra) do
        base[k] = v
    end
    return base
end

local options = {
    type = "group",
    name = appName,
    args = {
        unlock = {
            type = "toggle",
            order = 10,
            width = "full",
            name = "Unlock the roll frames",
            desc = "Shows the roll frames' anchor with a few preview rolls: drag it to move the rolls, "
                .. "right-click it to lock them again. Same as /bettergrouploot unlock and lock.",
            get = function()
                return app.rolls.unlocked
            end,
            set = function(_, value)
                app.rolls:SetUnlocked(value)
            end,
        },
        layout = {
            type = "group",
            inline = true,
            order = 20,
            name = "Position",
            args = {
                x = merge({
                    type = "range",
                    order = 10,
                    name = "X",
                    desc = "Horizontal offset of the first roll from the bottom center of the screen.",
                    min = -4000,
                    max = 4000,
                    softMin = -1500,
                    softMax = 1500,
                    step = 1,
                }, positionSetting("x")),
                y = merge({
                    type = "range",
                    order = 20,
                    name = "Y",
                    desc = "Height of the first roll above the bottom of the screen.",
                    min = -500,
                    max = 4000,
                    softMin = 0,
                    softMax = 1200,
                    step = 1,
                }, positionSetting("y")),
                scale = merge({
                    type = "range",
                    order = 30,
                    name = "Scale",
                    min = 0.5,
                    max = 2,
                    step = 0.05,
                    isPercent = true,
                }, layoutSetting("scale")),
                spacing = merge({
                    type = "range",
                    order = 40,
                    name = "Spacing",
                    desc = "Gap between two rolls.",
                    min = 0,
                    max = 40,
                    step = 1,
                }, layoutSetting("spacing")),
                growUp = merge({
                    type = "toggle",
                    order = 50,
                    name = "Stack upwards",
                    desc = "New rolls appear above the first one. Off: below it.",
                }, layoutSetting("growUp")),
                reset = {
                    type = "execute",
                    order = 60,
                    name = "Reset position",
                    func = function()
                        app.rolls:ResetPosition()
                    end,
                },
            },
        },
        tooltips = {
            type = "group",
            inline = true,
            order = 30,
            name = "Tooltips",
            args = {
                showUndecided = {
                    type = "toggle",
                    order = 10,
                    width = "full",
                    name = "List undecided players",
                    desc = "The roll buttons' tooltips also list who hasn't chosen yet.",
                    get = function()
                        return app.db.profile.showUndecided
                    end,
                    set = function(_, value)
                        app.db.profile.showUndecided = value
                    end,
                },
            },
        },
        logLevel = {
            type = "select",
            order = 90,
            name = "Log level",
            desc = "How much " .. appName .. " writes to the chat window. Same as /bettergrouploot loglevel <level>.",
            values = levelNames,
            sorting = levelOrder,
            get = function()
                return app.db.profile.logLevel
            end,
            set = function(_, value)
                if log:setLevel(value) then
                    app.db.profile.logLevel = log:getLevelName()
                end
            end,
        },
    },
}

-- Runs after addon:OnInitialize, so app.db is available.
function module:OnInitialize()
    options.args.profiles = LibStub("AceDBOptions-3.0"):GetOptionsTable(app.db)
    options.args.profiles.order = 100

    LibStub("AceConfig-3.0"):RegisterOptionsTable(appName, options)
    LibStub("AceConfigDialog-3.0"):AddToBlizOptions(appName)
end

-- Toggles the options in a standalone window.
function module:Open()
    local dialog = LibStub("AceConfigDialog-3.0")
    if dialog.OpenFrames[appName] then
        dialog:Close(appName)
    else
        dialog:Open(appName)
    end
end

-- Redraws the options wherever they are shown, after a setting changed elsewhere.
function module:Refresh()
    LibStub("AceConfigRegistry-3.0"):NotifyChange(appName)
end

-- A profile switch, copy or reset changes every value.
function module:OnProfileRefresh()
    self:Refresh()
end
