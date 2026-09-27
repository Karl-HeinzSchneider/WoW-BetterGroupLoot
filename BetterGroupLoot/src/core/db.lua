---@type string, BetterGroupLoot
local _, app = ...

-- AceDB-3.0 defaults. Missing keys in the SavedVariables fall back to these values,
-- and values equal to the default are not written to disk.

-- User settings, switchable per character via AceDBOptions.
---@class BetterGroupLoot.DB.Profile
local profile = {
    logLevel = "INFO",
    -- Bottom center of the first roll frame, relative to the bottom center of the screen, in
    -- UIParent units: changing the scale keeps the rolls on that spot.
    position = {
        x = 0,
        y = 250,
    },
    scale = 1,
    -- New rolls stack above the first one (false: below it).
    growUp = true,
    -- Gap between two roll frames.
    spacing = 4,
    -- The roll buttons' tooltips also list the players who haven't chosen yet.
    showUndecided = true,
}

-- Data tied to one character.
---@class BetterGroupLoot.DB.Char
local char = {}

-- Account-wide data shared by every character.
---@class BetterGroupLoot.DB.Global
local global = {
    dbVersion = 1,
}

---@class BetterGroupLoot.DBDefaults : AceDB.Schema
app.dbDefaults = {
    profile = profile,
    char = char,
    global = global,
}
