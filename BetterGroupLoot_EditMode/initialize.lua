---@type string, BetterGroupLoot.EditModeCompanion
local _, app = ...

-- This companion has its own private library, just like Seamless. It is loaded
-- by the standalone adapter only after the client's Edit Mode APIs are ready.
local addon = LibStub("AceAddon-3.0"):GetAddon("BetterGroupLoot") --[[@as BetterGroupLoot.Addon]]
addon:SetEditModeLibrary(app.LibEditMode)
