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
`ShowPreviews()` / `HidePreviews()` when the host owns preview visibility. Edit Mode
registration is optional: starting the runtime does not register anything or load a library.
The optional `src/rolls/editmode.lua` extends the controller with the methods below.

On disable call `controller:Stop()`. It unregisters events, releases all rolls and
previews and makes the installed secure hooks inert, allowing Blizzard frames again.
Ownership remains reserved until reload; restart through StartGroupLoot. WoW secure
post-hooks cannot be removed safely, so there is no live handover between copies.

Manual validation: compare the original layout in game, roll all supported choices,
check tooltips/counts, drag at different scales, switch/reset profiles, reload during
active rolls and exercise both host startup orders. Existing saved settings remain
unchanged.

## Optional Edit Mode registration

The standalone distribution includes `BetterGroupLoot_EditMode`, a load-on-demand
companion containing the same namespaced LibEditMode revision 18 used by Seamless.
Its vendored files are unmodified. The standalone adapter loads it only after it wins
runtime ownership and the client's native Edit Mode APIs/templates are available.
Missing/disabled companion addons or clients without these APIs retain unlock mode.
Embedded hosts do not load this companion or the standalone lifecycle adapter.

With a compatible library supplied by the host, register one custom frame explicitly:

```lua
controller:RegisterEditMode(lib, {
    name = L["Group loot"],
    defaults = hostDefaults,
})
```

By default this registers `controller.anchor`, persists movement via the existing
host `savePosition` binding (or the standalone screen-position schema), and adds four
ordinary settings: scale, spacing, upward growth and undecided-player display. Preview
rolls appear during Edit Mode and are removed on exit, leaving real rolls intact.
The legacy unlock preview stack is reused, and its mover is hidden during Edit Mode.
Combat hides automatic previews and blocks settings/movement writes; previews return
after combat when still editing. Profile changes refresh the current frame settings.
The standalone settings and position remain per AceDB profile, shared across native
Edit Mode layouts, preserving the existing SavedVariables paths.

Registration must happen after startup and outside combat. Repeating registration
with the same library returns the existing registration. Attempting to register the
same controller with a different library raises an error rather than creating two
competing selections. Stop hides the anchor and releases previews; callbacks stay
dormant until restart because LibEditMode has no unregister API.

Options:

- `defaultPosition`: explicit LibEditMode `{ point, x, y }` reset position. Required
  when using custom position callbacks without `host.defaultPosition`. Otherwise the
  registered default derives from that screen position and follows the current scale.
- `onMoved(frame, layoutName, point, x, y)`: replace movement persistence with the
  host's position service. It must break the old anchor when saving a dragged frame.
- `settings`: a complete LibEditMode settings array, or a function `(controller, lib)`
  returning one. This replaces the default settings array, allowing the host to add
  its own Position section and declared footer.
- `buttons`: optional ordinary LibEditMode button declarations. Hosts using an
  extended settings renderer may instead declare their own footer in `settings`.
- `managePreviews = false`: the host controls preview visibility; callbacks do not
  create or remove its preview stack. The standalone mover is still hidden in Edit Mode.
- `defaults`, `strings` and `omitScale`: forwarded to `GetEditModeSettings` when
  using the default settings. Strings may override `scale`, `spacing`, `growUp`,
  `showUndecided` and their corresponding `<key>Description` labels.

For Seamless, supply Core's private library and compose the settings with Core's
extended Position section. The same helper can be used without RegisterEditMode if
the host wants to perform the entire AddFrame flow itself:

```lua
local lib = core:GetEditModeLibrary()
controller:RegisterEditMode(lib, {
    name = L["Group loot"],
    defaultPosition = hostResetPosition,
    onMoved = SaveHostPosition,
    managePreviews = false,
    settings = function(current, suppliedLib)
        local settings = { core:GetEditModePositionSetting(positionBinding) }
        for _, row in ipairs(current:GetEditModeSettings(suppliedLib, {
            defaults = hostDefaults,
            strings = localizedLabels,
            omitScale = true, -- Core's Position section owns Scale.
        })) do
            settings[#settings + 1] = row
        end
        settings[#settings + 1] = explicitlyDeclaredButtonSection
        return settings
    end,
})
```

The settings helper resolves the current profile on every get/set and never creates
frames, registers callbacks or acquires a library. No Core Position controls are
copied into BetterGroupLoot.
