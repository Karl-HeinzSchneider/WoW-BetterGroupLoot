# CLAUDE.md

Guidance for Claude Code when working in this repository. This file holds the map and the rules
that apply everywhere; the addon folder has its own `CLAUDE.md` with its load order and file map.

## What this is

BetterGroupLoot is a World of Warcraft addon (Lua 5.1 on top of Ace3) for the client set by the
TOC's `## Interface` (Forever, Anniversary, Era and progression Classic; excluding retail), plus the Node/TypeScript tooling that checks,
links and packages it.

| Part               | What it is                                                                                                                          | Details                                                |
| ------------------ | ----------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------ |
| `BetterGroupLoot/` | The addon: everything in it ships. Settings in `BetterGroupLootDB`. Contains the `BetterGroupLoot-1.0` library other addons embed.  | [BetterGroupLoot/CLAUDE.md](BetterGroupLoot/CLAUDE.md) |
| `src/`             | Root tooling (Node 20+, TypeScript run by `tsx`, no build): check the addons, link them into a client, package them. Never shipped. | see "Tooling" below                                    |
| `.github/`         | The release workflows (BigWigs packager).                                                                                           | see "Releases" below                                   |

A direct child directory with a same-named `.toc` is an addon; the tooling discovers addons that
way, so a second addon (e.g. an `BetterGroupLoot_Options` companion) needs no registration in the
tooling — only a `move-folders` line in `.pkgmeta`. A companion named `BetterGroupLoot_*` must
declare `## Dependencies: BetterGroupLoot` (`npm run check:addons` enforces it).

## Working on the code

WoW addons are plain Lua/XML files loaded by the game; there is no build step. To try a change:
`npm run dev:link -- "<WoW>/Interface/AddOns"` (once; links every addon directory, also honors
`WOW_ADDONS_DIR`) and `/reload` in-game. `/bettergrouploot` opens the options,
`/bettergrouploot loglevel debug` shows the debug log.

## Commands (Node 20+, run from the root after `npm install` once)

| Command                            | Does                                                                                                                                                                                                                                |
| ---------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `npm run check`                    | Everything below that validates, in order: typecheck, addons, Lua syntax, XML schema, formatting. Run it before finishing a change.                                                                                                 |
| `npm run format`                   | Prettier (`.prettierrc.json`, `.prettierignore`) on TS/JSON/Markdown/YAML, then StyLua (`stylua.toml`, `.styluaignore`) on Lua. Leaves XML to the editor. `npm run format:check` only reports.                                      |
| `npm run check:addons`             | Every TOC load entry exists (a `[TextLocale]` entry for every client language), `BetterGroupLoot_*` companions depend on `BetterGroupLoot`, no dependency cycles.                                                                   |
| `npm run check:lua`                | `luac -p` on every addon Lua file (needs a Lua 5.1 `luac` on PATH).                                                                                                                                                                 |
| `npm run check:xml`                | Validates every addon XML against Blizzard's `UI.xsd` via python + lxml; skipped when `../_data/BlizzardInterfaceCode` is absent.                                                                                                   |
| `npm run typecheck`                | `tsc --noEmit` on `src/`.                                                                                                                                                                                                           |
| `npm run dev:link -- <AddOns dir>` | Symlink (junction on Windows) every addon into a client; refuses to replace a path that isn't already our link.                                                                                                                     |
| `npm run package:addons`           | Deterministic `dist/BetterGroupLoot-<version>.zip` of all addons (gitignored), without `CLAUDE.md` files.                                                                                                                           |
| `npm run package:local`            | The BigWigs packager the release workflows use (`.pkgmeta`), run locally without uploading: addon folders and zip in `.release/` (gitignored). Extra `release.sh` options go after `--`. On Windows it needs Git for Windows' bash. |

Static checks also used ad hoc: `lua-language-server --check` (config in `.luarc.json`; both
vendored `lib/` folders, the addon's and the library's, are excluded from LuaLS, StyLua and Prettier).

`npm run check:compat` runs the offline client-adapter regressions in `tests/compat.lua`, `tests/editmode.lua` (including the runtime fixture in `tests/runtime.lua`), and
`tests/editmode-library.lua` and XML load-graph tests in `tests/entrypoints.lua`
(Lua 5.1 on PATH); it is also included in `npm run check`. `tests/library.lua` loads the library
from its XML for the other tests, optionally as another minor version. Tests never ship in the package.

## Tooling (`src/`)

ESM with `.js` extensions in relative imports; `tsx` runs the `.ts` directly; strict `tsc`.

- `config.ts` — `ROOT`, `CLIENT_LOCALES` (every `[TextLocale]` value), `packageName()` (the
  `package-as` of `.pkgmeta`, used for zip names and as the main addon's name).
- `addons.ts` — `addonDirectories()` (every direct child with a same-named `.toc`),
  `addonVersion`, `walkFiles`.
- `check-addons.ts`, `check-lua.ts`, `check-xml.ts`, `link-addons.ts`, `package-addons.ts`,
  `package-local.ts` — one per `npm run` script above.
- `zip.ts` — `createZip` (stored, fixed timestamps), `directoryEntries`, `fileNamePart` (a TOC
  version as a file name), shared by the two packaging scripts.

## Releases

`.github/workflows/` runs the BigWigs packager on a pushed `v*` tag (`release-tag.yml`) and from
Actions > Run workflow (`release.yml`, `beta.yml`, `alpha.yml`, which tag the head of `main`
first); all four call `package.yml`. The tag decides the type: `v1.1.0-beta1` is a beta,
`v1.1.0-alpha1` an alpha, anything else a release. `## Version: @project-version@` in the TOC is
filled in by the packager.

What goes into the zip is set by `.pkgmeta` — **a new root file or folder that is not an addon
must be added to its `ignore` list**, or it ships inside the addon's folder. Uploads need the
repository secrets `CF_API_KEY`, `WAGO_API_TOKEN`, `WOWI_API_TOKEN` and the project ids in the TOC
(`## X-Curse-Project-ID`, `## X-Wago-ID`, `## X-WoWI-ID`); a site without both is skipped.

## WoW addon constraints

- Lua 5.1 with Blizzard's restricted API. No `require`, `io`, `os`, or `loadstring` of external
  files; every code file must be listed in its addon's TOC, in dependency order, or it will not
  load.
- Addons share one global namespace. Keep state in the private table passed to each file. A file
  of the standalone addon (`BetterGroupLoot/src/`) that uses it starts with

  ```lua
  ---@type string, BetterGroupLoot
  local appName, app = ...
  ```

  (`local _, app = ...` when the name is unused, or LuaLS flags it). The `---@type` line gives the
  language server completion on `app.*`. When a file adds a member to `app`, add a matching
  `---@field` to `BetterGroupLoot/src/types.lua`.

  Library files (`BetterGroupLoot/BetterGroupLoot-1.0/`) never use `...`: inside a host it is the
  host's table. They start with the LibStub header described in `BetterGroupLoot-1.0/core.lua`
  and share state through `lib.internal` (`tests/entrypoints.lua` enforces it).

- The sanctioned globals are SavedVariables, LibStub's `BetterGroupLoot-1.0`, host-prefixed
  public anchor/roll frames, and `BetterGroupLootRuntimeOwner`, the ownership record that also
  cooperates with releases from before the library. Frame mixins remain private; never replace
  an existing runtime owner.
- Persistent state lives only in tables declared via `## SavedVariables`; they are populated after
  `ADDON_LOADED`, not at file-load time (AceDB `OnInitialize` is the first safe place).
- Ace3 types (`AceAddon`, `AceDBObject-3.0`, `AceDB.Schema`, …) come from the `ketho.wow-api`
  VS Code extension (`.vscode/settings.json` → `Lua.workspace.library`), not from `lib/`;
  inherit from them rather than redeclaring the API.

## XML files

Every XML file starts with `<Ui xmlns="http://www.blizzard.com/wow/ui/">` and **no**
`xsi:schemaLocation` — the client ignores it and a wrong path makes the VS Code XML extension
report errors. Schema validation comes from `xml.fileAssociations` in `.vscode/settings.json`
(mapping `**/*.xml` to `../_data/BlizzardInterfaceCode/.../Blizzard_SharedXML/UI.xsd`) and from
`npm run check:xml`. Lua mixin files must be listed in the TOC _before_ the XML that references
them.

## Line endings

Every text file uses LF, in the repository and in the working tree. `.gitattributes`
(`* text=auto eol=lf`) overrides `core.autocrlf` (true system-wide in Git for Windows);
`.editorconfig`, VS Code's `files.eol`, Prettier (`endOfLine`) and StyLua (`line_endings`) write
LF. Binary types (`.tga`, `.blp`, `.png`, `.jpg`, `.zip`) are marked `binary` there; add a new
binary type to `.gitattributes` before committing it.

## Files with backslashes

Lua strings for texture paths need `\\` (`"Interface\\Icons\\INV_Misc_Bag_10"`). Shell heredocs
and inline Python strip the doubled backslash; write such files with the Write/Edit tools (or a
script file with raw strings).

## Optional: Blizzard's own UI source and art for reference

A developer may place Blizzard's exported interface files in `../_data/` (a sibling of the repo,
`E:\Projects\_data\` here — outside the repo, so nothing needs gitignoring):

- `../_data/BlizzardInterfaceCode/` — from `/run ExportInterfaceFiles("code")`: Lua/XML of all
  FrameXML/AddOns.
- `../_data/BlizzardInterfaceArt/` — from `/run ExportInterfaceFiles("art")`: every texture as
  `.blp` under `BlizzardInterfaceArt/Interface/...`.

If they exist, **read them, never edit them**:

- Code: look up exact API signatures/return values, event payloads, frame templates and global
  strings. Prefer it over memory; this client's API differs from retail and from Classic.
- Art: verify that a texture path used in code exists (case-insensitive) and browse for suitable
  icons/textures by name. `.blp` can't be viewed; the file list is what matters. Atlas names
  (`atlas="..."`) are _not_ in the export — find them in XML usages under `BlizzardInterfaceCode`.

Never list anything from these folders in a TOC or copy files out of them into the repo.

## Textures and Blizzard frames: reuse art, remake code

- **Don't create new textures unless there is no other way.** Prefer the game's own textures
  and atlases (they scale with the frame and need no shipping; the client does not load `.png`).
  If something really must be drawn, ask first.
- **Don't hard-reference a frame from retail or Classic WoW.** Don't inherit its templates, call
  its mixins, anchor to its frames or name it as the thing being copied in comments or docs.
  Learn how it is built, then remake the look with our own template and mixin; naming it as "an
  example" in a comment is fine. Its _art_ (atlases, textures) may be reused freely.
- On WoW Forever, code the client itself ships (`Blizzard_*/Camelot/` and shared templates it
  loads such as `Blizzard_SharedXML`) may be leaned on directly: inheriting from e.g.
  `PortraitFrameBaseTemplate` or `PagingControlsTemplate` is fine. Verify the file is loaded by
  this client before depending on it.
- A screenshot the user shares is a look reference, not a template to reproduce pixel by pixel.

## The library and the standalone addon

This repository defines the `BetterGroupLoot-1.0` LibStub library and ships one addon folder that
contains it. `BetterGroupLoot/BetterGroupLoot-1.0/` is self-contained (its only dependency,
LibStub, lives in its own `lib/`) and does nothing until a host calls `lib:Start(options)`.
Another addon copies that folder, includes `BetterGroupLoot-1.0.xml` and calls Start from its own
wrapper; see [docs/embedding.md](docs/embedding.md).

BetterGroupLoot.toc loads standalone.xml: the library first, then Ace3 and the private
LibEditMode, then the standalone addon (`src/`), which is a host like any other: it starts the
library with its AceDB profile and its logger. Nothing in the library may depend on `src/`.

Within 1.0, Start's options and the controller's methods stay backward compatible (a newer minor
replaces an older one before anything starts); bump `MINOR` in `core.lua` with every change to the
library. A breaking change is `BetterGroupLoot-2.0`, which must keep honoring
`BetterGroupLootRuntimeOwner`. Edit Mode is a supported-client requirement; do not add capability
probes or separate loader addons. Keep vendored LibEditMode revision 18 unmodified.
