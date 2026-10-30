---@type string, BetterGroupLoot
local _, app = ...

-- AceDB-3.0 defaults. Missing keys in the SavedVariables fall back to these values,
-- and values equal to the default are not written to disk.

local library = LibStub("BetterGroupLoot-1.0")

-- User settings, switchable per character via AceDBOptions: the library's settings (position,
-- scale, growUp, spacing, showUndecided; see BetterGroupLoot-1.0/core.lua) plus the addon's own.
---@class BetterGroupLoot.DB.Profile : BetterGroupLoot.Profile
local profile = CopyTable(library.defaults)
profile.logLevel = "INFO"

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
