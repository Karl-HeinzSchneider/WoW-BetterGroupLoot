# Embedding BetterGroupLoot

The standalone addon and embedded hosts use the same `src/api/` and `src/rolls/`
files. Vendor those directories together at a pinned commit. No build or XML name
substitution is required. Load them in the order shown in BetterGroupLoot.toc;
exclude `src/core/standalone.lua` and all standalone database/options/bootstrap files.
Supply the same private table to every shared file.

Before loading the API files, provide `app.logger` with `debug`, `error` and `chat`
methods accepting format strings. Optionally provide `app.rollStrings` before loading
rollframe.lua: a complete table with `need`, `greed`, `transmog`, `disenchant`, `pass`,
`undecided`, `offSpec`, `noData` and `nobody` text. The host owns localization.
Libraries needed at runtime are LibStub and AceEvent-3.0 (and its dependencies).

After the host database is available, explicitly start the controller:

```lua
local controller, owner = app.StartGroupLoot({
    prefix = "SeamlessUIGroupLoot",
    getProfile = function() return app.db.profile end,
    defaultPosition = { x = 600, y = 420 },
    changed = function() RefreshHostOptions() end,
    moverText = L["Drag to move, right-click to lock"],
})
if not controller then
    -- Show host-localized status using owner.prefix or owner.reason.
    return
end
```

The call checks `BetterGroupLootRuntimeOwner` before host validation, client checks,
frame creation, event registration or override installation. First startup wins,
regardless of version or whether it is standalone. A later copy returns `nil, owner`;
it must not use the owner's controller. Repeating startup on the owning private
app table returns/restarts its existing controller. An unsupported client returns
`nil, { reason = "unsupported" }` without reserving ownership.

The owner record has `prefix`, protocol `version = 1`, `reason = "owned"`, and the
controller after initialization. This version identifies the ownership protocol;
it is not permission to replace an older implementation. Startup failures retain
the reservation because partially created UI or installed hooks cannot be undone
reliably. Recovery requires reload.

Only implementations using this protocol cooperate. Older standalone releases and
unrelated loot replacement addons cannot be detected reliably by this marker.

The prefix must be a valid global identifier and unique to the host. It names
`<prefix>Anchor` and pooled `<prefix>RollFrame1`, `RollFrame2`, etc. Children and
mixins are private. No frames are created at shared-file load time.

The getter must resolve the current profile every time. The default position path
uses `position.x`, `position.y` (UIParent units), `scale`, `spacing`, `growUp` and
`showUndecided`, preserving the standalone schema. A host with its own positioning
service supplies all three callbacks `applyPosition(anchor)`, `savePosition(anchor)`
and `resetPosition(anchor)` instead; applyPosition also owns scale in that case.
The host still provides spacing/growUp/showUndecided through getProfile.

Use `controller:OnProfileRefresh()` after profile switches, `ApplySettings()` after
layout changes, `SetUnlocked(boolean)` for the legacy mover/previews, and
`ShowPreviews()` / `HidePreviews()` when adding a host Edit Mode adapter. Register
`controller.anchor` with the host's Edit Mode service. Edit Mode is deliberately
outside the shared runtime and is not implemented by this refactor.

On disable call `controller:Stop()`. It unregisters events, releases all rolls and
previews and makes the installed secure hooks inert, allowing Blizzard frames again.
Ownership remains reserved until reload; restart through StartGroupLoot. WoW secure
post-hooks cannot be removed safely, so there is no live handover between copies.

Manual validation: compare the original layout in game, roll all supported choices,
check tooltips/counts, drag at different scales, switch/reset profiles, reload during
active rolls and exercise both host startup orders. Existing saved settings remain
unchanged.
