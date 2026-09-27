# BetterGroupLoot (the addon)

The distributable addon: everything in this folder ships; the packager copies it to the top of the
zip (`.pkgmeta`). User settings live in `BetterGroupLootDB` (AceDB).

It replaces the client's group loot roll frames with its own: every roll shows how many players
chose Need, Greed/Transmog or Pass, the buttons' tooltips list who (class-colored, with roll
numbers), and the stack of rolls can be dragged anywhere.

## Load order (`BetterGroupLoot.toc`)

The TOC is the manifest and the source of truth for the load order; **every new Lua/XML file must
be listed**. The order follows these rules:

1. `embeds.xml` first: every vendored library in dependency order (LibStub → CallbackHandler →
   Ace\*).
2. `src\core\`: `logger.lua` first (everything logs), `db.lua` (the defaults `ace.lua` needs),
   `ace.lua` (creates `app.addon`), then `options.lua`.
3. `src\api\`: `api.lua` (the contract) before the client files (`forever.lua`), which fill it in.
4. `src\rolls\`: `rollframe.lua` (the mixins) before `rollframe.xml` (the templates naming them),
   then `rolls.lua` (the module creating frames from them).
5. `BetterGroupLoot.lua` last; it only logs.

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
- `forever.lua` — WoW Forever (1.6, retail family). Picks itself when
  `C_LootHistory.GetSortedDropsForEncounter` exists. Rolls come from `START_LOOT_ROLL` /
  `GetLootRollItemInfo`; who chose what comes from the encounter-based loot history, which has no
  rollID: `findDrop()` pairs a roll with a history drop by item link (then item ID), preferring
  open drops and skipping drops already paired with another roll. Rolls without a history entry
  (outside encounters) have no choices (`nil`), and the buttons show no count. `HideBlizzardRollFrames`
  post-hooks `GroupLootContainer_OpenNewFrame` and closes the client's frame through
  `GroupLootContainer_RemoveFrame`.

**Adding a client** (e.g. Classic): a new `src/api/<client>.lua` that returns early unless its API
exists (and `app.api.client` is still nil), builds the same functions and calls
`app.api:Implement("<client>", impl)`; list it in the TOC after `api.lua`. Nothing in `src/rolls/`
may call the game's loot API directly.

### `src/rolls/`

- `rollframe.lua` — `BetterGroupLootRollButtonMixin` (one choice: count, tooltip listing the
  players, click rolls) and `BetterGroupLootRollFrameMixin` (a roll: `SetRoll(rollID, duration)` for
  a real roll, `SetPreview(preview)` for a fake one, `UpdateChoices()`, `ShowNeedRoll()` for the own
  instant Need roll's number, `Reset()` for the pool). Greed and Transmog count and list both.
- `rollframe.xml` — `BetterGroupLootRollButtonTemplate` and `BetterGroupLootRollFrameTemplate`
  (277×67), our own templates on the game's loot toast art (`Interface\LootFrame\LootToast`) and
  the `lootroll-toast-icon-*` / `loottoast-itemborder-*` atlases.
- `rolls.lua` — `app.rolls`, the "Rolls" module: the movable anchor (`BetterGroupLootAnchor`), the
  frame pool, stacking (`Layout`), the roll events from `api.events`, `SyncActiveRolls` after a
  loading screen, and the unlock mode (`SetUnlocked`: a drag handle over the first slot plus three
  preview rolls).

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

- Prototype-style Ace modules: define methods on a local `module` table and pass it to
  `addon:NewModule("Name", module, …)`; state lives on the object Ace returns (see `rolls.lua`).
  A module that depends on profile settings defines `OnProfileRefresh`.
- New user settings get a default in `db.lua` and an entry in `options.lua`.
- Game loot API calls go through `app.api` only (see `src/api/`).
