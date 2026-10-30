# BetterGroupLoot (the addon)

The distributable addon: everything in this folder ships; the packager copies it to the top of the
zip (`.pkgmeta`). User settings live in `BetterGroupLootDB` (AceDB).

It replaces the client's group loot roll frames with its own: every roll shows how many players
chose Need, Greed/Transmog or Pass, the buttons' tooltips list who (class-colored, with roll
numbers), and the stack of rolls can be dragged anywhere.

The roll frames are the `BetterGroupLoot-1.0` library (`BetterGroupLoot-1.0/`), which other addons
embed; the rest of this folder is the standalone addon, one host of that library.

## Load order (`BetterGroupLoot.toc`)

The TOC imports `standalone.xml`:

1. `BetterGroupLoot-1.0\BetterGroupLoot-1.0.xml`: the library, including LibStub.
2. `embeds.xml`: the Ace3 libraries the standalone addon uses.
3. `lib\LibEditMode\namespaced.lua` and `embed.xml`: the private LibEditMode.
4. `src\core\db.lua`, `ace.lua`, `options.lua`, `standalone.lua`, then `BetterGroupLoot.lua`.

Every code file must appear in this XML load graph. A new library file goes into
`BetterGroupLoot-1.0.xml` (before `rolls\runtime.lua`, which must stay last).

## `BetterGroupLoot-1.0/` — the library

Self-contained: it uses nothing from the host and creates no frames, events or hooks until
`lib:Start(options)`. See [docs/embedding.md](../docs/embedding.md) for the host contract.

Every file starts with the LibStub header from `core.lua` and returns early unless
`lib.internal.loading` is set, so a copy that LibStub does not choose skips entirely. Files share
state through `lib.internal`, never through `...`.

- `core.lua` — `MAJOR`/`MINOR` and the version gate (a started copy is never upgraded),
  `lib.internal` (the files' shared private table), `lib.defaults` (the profile defaults:
  `position` = the first roll's bottom center relative to the screen's in UIParent units,
  `scale`, `growUp`, `spacing`, `showUndecided`).
- `logger.lua` — `lib:CreateLogger(name)`: the standard leveled, colored chat logger;
  `log("x")` is `log:info("x")`, `log:debug("Looted %s x%d", link, count)` formats,
  `log:chat(...)` is unfiltered user-facing output, `log:dump(tbl)` prints a table at DEBUG.
  `internal.logger` is the logger the API files use: a default one, then the owner's.
- `lib/LibStub/` — vendored, unmodified. The only dependency.
- `LICENSE` — a copy of the repository's MIT license; it travels with every embedded copy. Keep it
  identical to the root `LICENSE`.
- `AGENTS.md` — for whoever embeds the library and their agents: origin (GitHub), author, how to
  use it (links to the docs on GitHub, since `docs/` isn't copied), the license and the requested
  credit. It ships (`.pkgmeta` lists the Markdown it ignores one by one).

### `api/` — the only code that talks to the client's loot API

- `api.lua` — `internal.api`: the contract every client file fulfills (the `BetterGroupLoot.Api`
  class: functions, the `events` table, the normalized `RollItem` / `Roller` / `RollChoices`
  tables), `api.RollType`, `api.NewChoices()`, `api:Implement(client, impl)` (checks that nothing
  is missing) and `api:IsSupported()`.
- `common.lua` — `api.CreateImplementation()` creates shared roll/item/display operations;
  load it after `api.lua` and before either adapter.
- `classic.lua` — Era, Anniversary and progression Classic. Resolves history by exact roll ID
  on each update, restores active rolls using remaining time, and post-hooks
  `GroupLootFrame_OpenNewFrame` to remove default frames. No instant Need or cancel-all event.
- `forever.lua` — WoW Forever (1.6, retail family). Picks itself on interface 16001 when
  `C_LootHistory.GetSortedDropsForEncounter` exists; retail stays unsupported. Rolls come from `START_LOOT_ROLL` /
  `GetLootRollItemInfo`; who chose what comes from the encounter-based loot history, which has no
  rollID: `findDrop()` pairs a roll with a history drop by item link (then item ID), preferring
  open drops and skipping drops already paired with another roll. Rolls without a history entry
  (outside encounters) have no choices (`nil`), and the buttons show no count. `HideBlizzardRollFrames`
  post-hooks `GroupLootContainer_OpenNewFrame` and closes the client's frame through
  `GroupLootContainer_RemoveFrame`.

**Adding a client**: a new `api/<client>.lua` that returns early unless its API exists (and
`internal.api.client` is still nil), builds the same functions and calls
`internal.api:Implement("<client>", impl)`; list it in `BetterGroupLoot-1.0.xml` after `api.lua`.
Nothing in `rolls/` may call the game's loot API directly.

### `rolls/`

- `rollframe.lua` - private `internal.RollButtonMixin` and `internal.RollFrameMixin`: choice
  counts/tooltips, real rolls, previews and item rendering. Tooltip text comes from the
  controller's `strings` (`internal.DefaultStrings()` plus the host's overrides). No global mixins.
- `frames.lua` - `internal.CreateRollFrame(parent, name)`, the original 277x67 layout and
  game art constructed in Lua, with private mixins and unnamed child frames.
- `rolls.lua` - `internal.RollController`: anchor, pooled frames, layout, roll events (through
  its own event frame, `RegisterEvent(event, method)`), preview generation and the legacy
  unlock mover. Settings use `host.getProfile()`, logging `self.logger`.
- `editmode.lua` - optional `RegisterEditMode(editModeLib, options)` registration and composable
  `GetEditModeSettings(editModeLib, options)` rows. Never looks up a global library.
- `runtime.lua` - `lib:Start(options)` and `lib:GetOwner()`. Start checks the owner first, then
  validates, normalizes the options and creates/starts a controller. The first startup reserves
  ownership until reload; other hosts get `nil, owner` without UI/events/hooks. Stop makes hooks
  inert. Last file of the library: clears `internal.loading`.

## `src/` — the standalone addon

### `src/core/`

- `db.lua` — `app.dbDefaults` for AceDB: `profile` = `lib.defaults` plus `logLevel`,
  `char` = per-character data, `global.dbVersion` for future migrations.
- `ace.lua` — `app.logger` (`lib:CreateLogger(appName)`) and `app.addon`, the AceAddon object
  (AceConsole, AceEvent). `OnInitialize` opens `app.db`, wires the profile callbacks to
  `OnProfileRefresh` (log level, then every module's `OnProfileRefresh`) and registers
  `/bettergrouploot`; `OnSlashCommand` handles `options` (the default), `unlock`/`lock`,
  `loglevel <level>` and `reset`.
- `options.lua` — `app.options`: the user options as **one** AceConfig table (plus the AceDBOptions
  profiles tab), registered in the game's Settings panel (`AddToBlizOptions`) and opened in a
  standalone AceConfigDialog window by `Open()`. A new option goes only here. `Refresh()` redraws
  them after a setting changed elsewhere (e.g. the anchor was dragged).
- `standalone.lua` — the Rolls AceModule: `lib:Start` with the AceDB profile and `app.logger`
  on enable (`app.rolls` is the controller), Edit Mode registration with the private
  LibEditMode (deferred past combat), Stop on disable, profile changes forwarded.

### Annotations (not in the TOC)

- `src/types.lua` — the private-table class `BetterGroupLoot` (`app.*` fields) and
  `BetterGroupLoot.DB`. When a file adds a member to `app`, add a matching `---@field` here. The
  library annotates itself (`BetterGroupLoot.Lib`, `BetterGroupLoot.Internal`,
  `BetterGroupLoot.StartOptions`, ...).

### Other

- `lib/` — the standalone addon's vendored libraries, only those it loads: CallbackHandler,
  AceAddon, AceEvent, AceDB, AceDBOptions, AceConsole, AceGUI, AceConfig (loaded by
  `embeds.xml`) and LibEditMode. Excluded from LuaLS, StyLua and Prettier; update by replacing a
  folder, don't patch. A newly used Ace library is copied in and added to `embeds.xml`; nothing
  unused is vendored. LibStub comes with the library.
- `assets/` — textures the game files cannot provide (`assets/core/coffee.tga` is the TOC notes'
  donation icon). The library must not use them: inside a host it lives at another path.

## Conventions

- Standalone prototype-style Ace modules: define methods on a local `module` table and pass it to
  `addon:NewModule("Name", module, …)`; state lives on the object Ace returns. The library's roll
  controller uses a private prototype. A module that depends on profile settings defines
  `OnProfileRefresh`.
- New roll settings get a default in `BetterGroupLoot-1.0/core.lua` (`lib.defaults`) and an entry
  in `options.lua`; settings of the standalone addon only go into `db.lua`.
- Game loot API calls go through `internal.api` only (see `api/`).
- Every library change bumps `MINOR` in `core.lua`.

## Regression tests

`npm run check:compat` runs client, runtime (via the Edit Mode fixture), Edit Mode adapter
and vendored-library smoke tests with Lua 5.1. They load the library from its XML
(`tests/library.lua`).
Runtime tests cover loading without side effects, ownership between hosts, never upgrading a
started library, upgrading a dormant one, the legacy global owner, Start's defaults, host
loggers and strings, private prefixed frames, pooling and profile changes.

`lib/LibEditMode/` is the same unmodified namespaced revision 18 used by Seamless.
standalone.xml loads it into this addon's private table. Embedding hosts supply their own
library when registering. Edit Mode is assumed available on supported clients; standalone
registration only defers while in combat.
