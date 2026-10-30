-- BetterGroupLoot-1.0: group loot roll frames as a LibStub library. Every copy (the standalone
-- addon, each embedding host) loads the same files; LibStub keeps the newest minor version.
--
-- A started copy has installed secure hooks that cannot be removed, so it is never upgraded: a
-- newer copy loading afterwards stays out. Before any Start, a newer copy replaces the code.
-- Every later file of this library starts with
--   local lib = LibStub("BetterGroupLoot-1.0")
--   local internal = lib.internal
--   if not internal.loading then
--       return
--   end
-- and runtime.lua, the last file, clears `loading`.
local MAJOR, MINOR = "BetterGroupLoot-1.0", 1

---@class BetterGroupLoot.Lib
---@field internal BetterGroupLoot.Internal
---@field defaults BetterGroupLoot.Profile profile defaults, for merging into a host's saved settings
local existing = LibStub:GetLibrary(MAJOR, true)
local started = existing and existing.internal and existing.internal.owner
local lib = not started and LibStub:NewLibrary(MAJOR, MINOR)
if not lib then
    -- This copy stays out; make sure its remaining files skip as well.
    if existing and existing.internal then
        existing.internal.loading = nil
    end
    return
end

-- Shared between the library's own files only; never part of the public API.
---@class BetterGroupLoot.Internal
---@field loading boolean? set while this copy's files load
---@field logger BetterGroupLoot.Logger the owner's logger once started, a default one before
---@field owner table? the ownership record once a host started the library
---@field api BetterGroupLoot.Api
---@field DefaultStrings fun(): table<string, string>
---@field RollController BetterGroupLoot.Rolls
---@field RollButtonMixin table
---@field RollFrameMixin table
---@field CreateRollFrame fun(parent: Frame, name: string): BetterGroupLootRollFrameMixin
lib.internal = { loading = true }
lib.minor = MINOR

-- The settings a host's getProfile() returns. Hosts with their own position service
-- (applyPosition/savePosition/resetPosition) need no position and scale.
---@class BetterGroupLoot.Profile
lib.defaults = {
    -- Bottom center of the first roll frame, relative to the bottom center of the screen, in
    -- UIParent units: changing the scale keeps the rolls on that spot.
    position = {
        x = 600,
        y = 420,
    },
    scale = 1,
    -- New rolls stack above the first one (false: below it).
    growUp = true,
    -- Gap between two roll frames.
    spacing = 8,
    -- The roll buttons' tooltips also list the players who haven't chosen yet.
    showUndecided = true,
}
