# BetterGroupLoot (the addon)

The distributable addon: everything in this folder ships; the packager copies it to the top of the
zip (`.pkgmeta`). User settings live in `BetterGroupLootDB` (AceDB).

It replaces the client's group loot roll frames with its own: every roll shows how many players
chose Need, Greed/Transmog or Pass, the buttons' tooltips list who (class-colored, with roll
numbers), and the stack of rolls can be dragged anywhere.

## Load order (`BetterGroupLoot.toc`)

The TOC imports `standalone.xml`. It loads dependencies and the private Edit Mode
library, core database/options, `embedded.xml`, standalone lifecycle and the final
BetterGroupLoot.lua file. Every code file must appear in this XML load graph.

`embedded.xml` is the host-facing import: client API contract/common/adapters,
private roll mixins, frame factory, controller, runtime ownership entry point and
optional Edit Mode registration helpers. It loads no library or standalone code.
See `docs/embedding.md` for the host contract and ownership limitations.

## Files

### `src/core/`

- `logger.lua` — `app.logger`: leveled, colored chat logging; `log("x")` is `log:info("x")`,
  `log:debug("Looted %s x%d", link, count)` formats, `log:chat(...)` is unfiltered user-facing
  output, `log:dump(tbl)` prints a table at DEBUG. The threshold comes from `profile.logLevel`.
- `db.lua` — `app.dbDefaults` for AceDB: `profile` = user settings (`logLevel`, `position` = the
  first roll's bottom center relative to the screen's in UIParent units, `scale`, `growUp`,
  `spacing`, `showUndecided`), `char` = per-character data, `global.dbVersion` for future
  migrations.
- `ace.lua` — `app.addon`, the AceAddon object (AceConsole, AceEvent). `OnInitialize` opens
  `app.db`, wires the profile callbacks to `OnProfileRefresh` (log level, then every module's
  `OnProfileRefresh`) and registers `/bettergrouploot`; `OnSlashCommand` handles `options` (the
  default), `unlock`/`lock`, `loglevel <level>` and `reset`.
- `options.lua` — `app.options`: the user options as **one** AceConfig table (plus the AceDBOptions
  profiles tab), registered in the game's Settings panel (`AddToBlizOptions`) and opened in a
  standalone AceConfigDialog window by `Open()`. A new option goes only here. `Refresh()` redraws
  them after a setting changed elsewhere (e.g. the anchor was dragged).

### `src/api/` — the only code that talks to the client's loot API

- `api.lua` — `app.api`: the contract every client file fulfills (the `BetterGroupLoot.Api` class:
  functions, the `events` table, the normalized `RollItem` / `Roller` / `RollChoices` tables),
  `api.RollType`, `api.NewChoices()`, `api:Implement(client, impl)` (checks that nothing is
  missing) and `api:IsSupported()`.
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

**Adding a client**: a new `src/api/<client>.lua` that returns early unless its API
exists (and `app.api.client` is still nil), builds the same functions and calls
`app.api:Implement("<client>", impl)`; list it in the TOC after `api.lua`. Nothing in `src/rolls/`
may call the game's loot API directly.

### `src/rolls/`

- `rollframe.lua` - private `app.RollButtonMixin` and `app.RollFrameMixin`: choice
  counts/tooltips, real rolls, previews and item rendering. No global mixins.
- `frames.lua` - `app.CreateRollFrame(parent, name)`, the original 277x67 layout and
  game art constructed in Lua, with private mixins and unnamed child frames.
- `rolls.lua` - `app.RollController`: anchor, pooled frames, layout, roll events,
  preview generation and optional legacy unlock mover. Settings use `host.getProfile()`.
- `editmode.lua` - optional `RegisterEditMode(lib, options)` registration and composable
  `GetEditModeSettings(lib, options)` rows. Never looks up a global library.
- `runtime.lua` - `app.StartGroupLoot(host)` checks the shared owner first, then
  creates/starts a controller. The first startup reserves ownership until reload;
  other copies return `nil, owner` without UI/events/hooks. Stop makes hooks inert.
- `src/core/standalone.lua` - the standalone Rolls AceModule starts/stops the
  controller and forwards profile changes. Embedded hosts must not load this file.

### Annotations (not in the TOC)

- `src/types.lua` — the private-table class `BetterGroupLoot` (`app.*` fields) and
  `BetterGroupLoot.DB`. When a file adds a member to `app`, add a matching `---@field` here.

### Other

- `lib/` — vendored Ace3, LibStub, CallbackHandler, LibDBIcon (+ LibDataBroker). Excluded from
  LuaLS, StyLua and Prettier; update by replacing the folder, don't patch. `embeds.xml` loads the
  ones in use (LibDBIcon and LibDataBroker are not loaded; there is no minimap button).
- `assets/` — textures the game files cannot provide (`assets/core/coffee.tga` is the TOC notes'
  donation icon).

## Conventions

- Standalone prototype-style Ace modules: define methods on a local `module` table and pass it to
  `addon:NewModule("Name", module, …)`; state lives on the object Ace returns. The shared roll controller uses a private prototype.
  A module that depends on profile settings defines `OnProfileRefresh`.
- New user settings get a default in `db.lua` and an entry in `options.lua`.
- Game loot API calls go through `app.api` only (see `src/api/`).

## Regression tests

`npm run check:compat` runs client, runtime (via the Edit Mode fixture), Edit Mode adapter
and vendored-library smoke tests with Lua 5.1.
Runtime tests cover independently loaded copies, both ownership orders, no startup
side effects in the losing copy, private prefixed frames, pooling and profile changes.

`lib/LibEditMode/` is the same unmodified namespaced revision 18 used by Seamless.
standalone.xml loads it into this addon's private table. Embedded hosts import
embedded.xml instead and supply their own library. Edit Mode is assumed available
on supported clients; standalone registration only defers while in combat.
