# BetterGroupLoot – Repo Overview (temporary, delete after rework)

## What it does

A small addon that **restyles and extends Blizzard's default GroupLootFrame** (the Need/Greed/Pass roll popup). It does not replace the frame; it modifies `GroupLootFrame1..4` and `GroupLootContainer` in place.

Features:
- New compact style: 38px masked item icon with a quality-colored border overlay, smaller (28px) roll buttons laid out as `[Need][Pass]` on top and `[Greed]` under Need. The corner art is hidden.
- **Roll counts** drawn on each button (how many players picked Need / Greed / Pass).
- **Tooltip per button** lists which players chose that option (class-colored), plus an "Undecided" list.
- **Movable position**: the container is anchored to a proxy frame whose X/Y offset is set in the options.
- **Preview**: a fake, animated roll frame with random Classic items and random counts, so you can position it without a real roll.
- Options panel through the modern `Settings` API: Show Preview, X, Y.

The code was taken from DragonflightUI Classic (hence the `DF*` field names).

## Files

| File | Role |
|---|---|
| `BetterGroupLoot.toc` | Interface `50502` (MoP Classic) and `11508` (Classic Era). Loads only `BetterGroupLoot_standalone.xml`. SavedVariables `BetterGroupLootDB`. `@project-version@` tokens are filled in by the BigWigs packager. |
| `BetterGroupLoot_standalone.xml` | Load order: LibStub → CallbackHandler → `Preview.xml` → `BetterGroupLoot.lua` → `Options.lua`. |
| `BetterGroupLoot.lua` | Core. Registers the library `BetterGroupLoot-1.0` through LibStub, handles events, styles the frames, counts rolls, builds tooltips. |
| `Preview.xml` | Virtual template `BetterGroupLootPreviewTemplate`: a hand-copied version of the old Classic GroupLootFrame XML (backdrop, `$parentSlotTexture`, `$parentCorner`, `$parentDecoration`, IconFrame, Need/Pass/Greed buttons, Timer status bar). |
| `Preview.mixin.lua` | Mixin for the preview: cycles random items every 42s, fakes the timer bar and counts. **Duplicates** the color/overlay helpers from `BetterGroupLoot.lua` on its own local frame. |
| `Options.lua` | Settings category "BetterGroupLoot" (checkbox plus 2 proxy sliders from -3000 to 3000). Runs only when standalone. Hooked onto `frame.PLAYER_LOGIN` via `hooksecurefunc`. |
| `Libs/` | LibStub and CallbackHandler-1.0 (CallbackHandler is loaded but **not used**). |
| `Textures/` | `maskNew.blp` (icon mask), `whiteiconframeEdit.blp` (white border, tinted by quality). |
| `.github/workflows/` | BigWigs packager: a tag push creates a release, a `*-preview` branch push creates an alpha build. CurseForge project ID 1382269. |
| `.vscode/settings.json` | LuaLS globals list and Ketho WoW API annotations. |

## Runtime flow

1. **Load**: `LibStub:NewLibrary("BetterGroupLoot-1.0", 1)` creates `lib`, `lib.frame` (the event frame) and `lib.Defaults`.
   - `standalone = (addonName == 'BetterGroupLoot')`. When standalone, the addon registers `PLAYER_LOGIN`. When embedded, the host calls `lib.frame:SetState(tbl)`, which calls `Embed()` → `PLAYER_LOGIN('EMBED')`.
2. **`PLAYER_LOGIN`**:
   - Creates or fills in `BetterGroupLootDB` from the defaults.
   - `ChangeGroupLootContainer()`:
     - Creates the proxy anchor `BetterGroupLootContainerPreview` (256x100 on UIParent).
     - Creates the fake preview frame from the template.
     - Calls `UpdateGroupLootFrameStyleSimple()` on the preview and on `GroupLootFrame1..4`.
     - Replaces each frame's `OnEnter` with a no-op.
   - `AddEventFunctions()` defines the event handlers. Each one calls `UpdateAllButtons` on all 4 frames.
   - Registers: `PLAYER_ENTERING_WORLD`, `START_LOOT_ROLL`, `LOOT_HISTORY_ROLL_CHANGED`, `LOOT_HISTORY_ROLL_COMPLETE`, `LOOT_ROLLS_COMPLETE`.
   - `Update()`.
3. **`Update()`**:
   - Anchors the proxy at `(state.anchor, UIParent, state.anchorParent, x, y)`.
   - Shows or hides the preview.
   - Sets `GroupLootContainer.ignoreFramePositionManager = true` and anchors the container's BOTTOM to the proxy.
4. **`UpdateAllButtons(f)`**:
   - Reads `f.rollID` (set by Blizzard's code).
   - `CreateTableForRollID(rollID)` walks `C_LootHistory.GetItem(idx)` until it finds a matching rollID.
   - Then `C_LootHistory.GetPlayerInfo(idx, i)` buckets players by rollType (0 pass, 1 need, 2 greed, 3 disenchant, nil undecided).
   - Sets the count texts and tints the icon border by item quality from `C_Item.GetItemInfo(link)`.
5. **Button `OnEnter`**: builds the tooltip, then calls `AddTooltipLines(btn, rollType)`, which rebuilds the same tables and lists the names.

### Saved variables (`BetterGroupLootDB`)
- Used: `showPreview`, `anchor`, `anchorParent`, `x` (425), `y` (200).
- Defined but unused: `scale`, `anchorFrame`, `customAnchorFrame`.

### Embedding API (partial)
- `LibStub('BetterGroupLoot-1.0')`, then `lib.frame:SetState(tbl)`.
- Also exposes `lib.Defaults`, `lib.IsStandalone` and `lib.BetterGroupLootDB`.

## Blizzard dependencies (the parts that break on a new client)

The addon relies heavily on the **old Classic GroupLootFrame layout and APIs**:

- **Named frames and regions**:
  - Frames: `GroupLootFrame1..4`, `GroupLootContainer`.
  - Regions: `GroupLootFrameN` + `Corner` / `Decoration` / `SlotTexture` / `IconFrame.Icon` / `SubIconTexture`.
- **Buttons**: `f.NeedButton` / `f.GreedButton` / `f.PassButton`, with file textures `Interface\Buttons\UI-GroupLoot-*`. There is no handling for a `DisenchantButton` or `TransmogButton`.
- **Roll state**: `f.rollID`, set by Blizzard's `GroupLootFrame_OpenNewFrame`.
- **Loot history API (old)**: `C_LootHistory.GetItem(idx)`, `C_LootHistory.GetPlayerInfo(idx, playerIdx)`.
- **Events**: `LOOT_HISTORY_ROLL_CHANGED`, `LOOT_HISTORY_ROLL_COMPLETE`.
- **Positioning**: `ignoreFramePositionManager`, the old UIParent frame position manager.
- **Other APIs**:
  - `BackdropTemplate`, `LootRollButtonTemplate`, `UIPanelCloseButton`.
  - `Settings.*`, `MinimalSliderWithSteppersMixin`.
  - `Item:CreateFromItemID`, `C_Item.GetItemInfo`.
  - `BAG_ITEM_QUALITY_COLORS`, `ITEM_QUALITY_COLORS`, `RAID_CLASS_COLORS` / `CUSTOM_CLASS_COLORS`.
  - `fastrandom`.

## WoW Forever: what we know (verify in the client)

- Forever reportedly runs on the **Mainline (retail) UI architecture and addon API**, not the Classic one.
- TOC: interface **`16001`** (beta) and flavor suffix **`_Camelot`** (e.g. `BetterGroupLoot_Camelot.toc`). Some sources also mention `## Interface-Forever:`.
- The biggest risk, if the retail loot code is used:
  - Retail (10.1+) replaced `C_LootHistory.GetItem` / `GetPlayerInfo` and the `LOOT_HISTORY_ROLL_*` events with an encounter/drop API (`C_LootHistory.GetSortedDropsForEncounter`, `LOOT_HISTORY_UPDATE_DROP`, and others).
  - The retail GroupLootFrame also uses atlas art instead of the `Corner` / `Decoration` / `SlotTexture` named textures.
  - Container positioning may go through Edit Mode or the managed frame container.
- Once in game: check `/dump C_LootHistory`, `/fstack` on a roll frame, and `/dump GroupLootFrame1`.

## Existing bugs and smells found

1. `UpdateAllButtons`: the pass count checks `if tableGreed` instead of `tablePass`. It works by accident.
2. `UpdateGroupLootFrameStyleSimple` creates a **new MaskTexture on every call**, with the same global name `BetterGroupLootIconMask` each time. The overlay textures also all share the global name `BetterGroupLootQuality`. These are global name collisions.
3. The quality-border code, the texcoord table (`qualityToIconBorderAtlas` is unused) and the class color helpers are **duplicated** in `Preview.mixin.lua`.
4. `CreateTableForRollID` runs twice per hover, once for the counts and once for the tooltip. It also scans all history items linearly on every event.
5. The Pass tooltip never shows the "disabled reason"; Need and Greed do.
6. Setting `OnEnter` to a no-op on `GroupLootFrameN` silently removes whatever Blizzard had there.
7. `START_LOOT_ROLL` may be handled before Blizzard sets `f.rollID`, which depends on event order. Later history events correct the counts.
8. Item quality comes from `C_Item.GetItemInfo`, which can return nil if the item is uncached, so the border falls back to common. `GetLootRollItemInfo(rollID)` would be more reliable.
9. The preview only uses Classic item IDs (19431, 22691, …).
10. CallbackHandler is bundled but never used. `lib.Defaults` is assigned twice. The `scale` and anchor-frame settings are dead code.
11. The Pass button texcoords `{1.05, -0.1, 1.05, -0.1}` flip both axes. This is intentional (it reuses the art) but looks odd.
12. The `.vscode` globals list is copied from another addon (aura- and combat-log-related globals).
