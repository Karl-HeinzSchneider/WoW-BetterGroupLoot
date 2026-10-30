# Embedding BetterGroupLoot-1.0

The roll frames are a LibStub library, `BetterGroupLoot-1.0`, in
`BetterGroupLoot/BetterGroupLoot-1.0/`. The standalone BetterGroupLoot addon is one host of it;
any other addon can be another. The library is self-contained: its only dependency, LibStub,
ships in its own `lib/`, and it uses nothing from the host's private table.

## Setup

1. Copy `BetterGroupLoot/BetterGroupLoot-1.0/` into the host, at a pinned commit (for example to
   `libs/BetterGroupLoot-1.0/`). Copy it whole: its `LICENSE` (MIT) must ship with every copy, and
   its `AGENTS.md` says where the library comes from and who made it. Keeping that file and
   crediting BetterGroupLoot in the host is appreciated.
2. Include it from the host's XML or TOC, like any other library:

   ```xml
   <Include file="libs\BetterGroupLoot-1.0\BetterGroupLoot-1.0.xml" />
   ```

   Loading does nothing: no frames, events, hooks or globals besides LibStub's entry.

3. Start it from a small wrapper once the host's saved settings are available:

   ```lua
   local BGL = LibStub("BetterGroupLoot-1.0")

   local controller, owner = BGL:Start({
       name = "SeamlessUIGroupLoot",
       logger = app.logger,
       getProfile = function() return app.db.profile.groupLoot end,
       strings = L.groupLoot,
       changed = function() RefreshHostOptions() end,
   })
   if not controller then
       -- Show host-localized status using owner.prefix or owner.reason.
       return
   end
   ```

Merge `BGL.defaults` into the host's own defaults for the table `getProfile` returns, for
example `defaults.profile.groupLoot = CopyTable(BGL.defaults)` with AceDB.

## Start options

Only `name` is required.

- `name`: the host. It is the log tag of the default logger and the frame prefix: `<prefix>Anchor`
  and pooled `<prefix>RollFrame1`, `RollFrame2`, etc. Children and mixins are private.
- `prefix`: the frame prefix when `name` is not a valid global identifier. It must be unique to the
  host.
- `logger`: an object with `debug`, `error` and `chat` methods that take format strings. Without
  it, the library creates the standard logger with `BGL:CreateLogger(name)`. The host can also
  use `BGL:CreateLogger` for its own logging, as the standalone addon does.
- `getProfile`: returns the current settings and is called every time, so profile switches just
  work. It uses `position.x`, `position.y` (UIParent units), `scale`, `spacing`, `growUp` and
  `showUndecided` (see `BGL.defaults`). Without it, the library uses an unsaved copy of the
  defaults.
- `defaultPosition`: `{ x, y }` reset position. The default is `BGL.defaults.position`.
- `applyPosition(anchor)`, `savePosition(anchor)`, `resetPosition(anchor)`: a host with its own
  positioning service supplies all three instead. `applyPosition` then also owns the scale, and
  the host still provides spacing/growUp/showUndecided through `getProfile`.
- `strings`: overrides for the tooltip text: `need`, `greed`, `transmog`, `disenchant`, `pass`,
  `undecided`, `offSpec`, `noData` and `nobody`. The defaults use the client's global strings
  where they exist. The host owns localization.
- `moverText`: label of the legacy unlock mover.
- `changed()`: called when a setting changed inside the library (dragged, unlocked, Edit Mode).

## Ownership

Only one copy can replace the client's roll frames, because secure post-hooks can't be removed.
The first `Start` in a UI session wins, whatever its version and whether it is standalone. Any
later host gets `nil, owner` and nothing is created for it; it must not use the owner's
controller. The owner calling `Start` again (with the same prefix) gets its controller back,
restarted after `Stop`. An unsupported client returns `nil, { reason = "unsupported" }` without
reserving ownership. `BGL:GetOwner()` returns the record at any time.

The owner record has `prefix`, protocol `version = 1`, the library `minor`, `reason = "owned"`, and
the controller after initialization. It is also stored in the global
`BetterGroupLootRuntimeOwner`, so the library cooperates with releases from before it. Startup
failures keep the reservation, because partially created UI or installed hooks can't be undone
reliably; recovery requires a reload.

All hosts share one copy of the code: LibStub keeps the newest minor version that has loaded.
A newer copy replaces an older one only while nobody has started it. Once started, the library is
never upgraded, and a newer copy loading later (a load-on-demand addon) stays out.

## Controller

Use `controller:OnProfileRefresh()` after profile switches, `ApplySettings()` after layout changes,
`SetUnlocked(boolean)` for the legacy mover/previews, `ResetPosition()`, and
`ShowPreviews()` / `HidePreviews()` when the host owns preview visibility.

On disable call `controller:Stop()`. It unregisters events, releases all rolls and previews and
makes the installed secure hooks inert, so the client's frames work again. Ownership remains
reserved until reload; restart through `Start`. There is no live handover between hosts.

Manual validation: compare the original layout in game, roll all supported choices, check
tooltips/counts, drag at different scales, switch/reset profiles, reload during active rolls and
exercise both host startup orders. Existing saved settings remain unchanged.

## Optional Edit Mode registration

The standalone addon's `standalone.xml` loads the same namespaced LibEditMode revision 18 used by Seamless
from `lib/LibEditMode/`. Its vendored files are unmodified. Edit Mode is part of the
supported client contract; standalone registration uses the library directly after
winning runtime ownership. There is no capability-probing or addon-loading flow.
Embedding hosts provide their own LibEditMode when registering; the library never looks one up.

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
  `showUndecided` and their corresponding `<key>Description` labels. `defaults` (the
  rows' reset values) falls back to `BGL.defaults`.

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
