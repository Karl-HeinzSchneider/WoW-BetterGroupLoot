# BetterGroupLoot – Repo Overview (temporary, delete after rework)

## Rework status (Forever rewrite)

- **Done**:
  - The repo is set up from `WoW-AddonTemplate`. The addon lives in `BetterGroupLoot/`, uses Ace3 and has no minimap button.
  - The old Classic code (the sections below) is removed from the tree; it's still in the git history.
  - Own roll frames (`src/rolls/`), with all loot API calls behind `app.api` (`src/api/api.lua` for the contract, `src/api/forever.lua` for Forever).
- **To verify in game**:
  - Rolls show and clicking a button rolls.
  - Blizzard's frames stay hidden.
  - A roll gets paired with its loot history drop (`/bettergrouploot loglevel debug` prints "Roll N is loot history drop E:K").
  - Counts update as players choose.
  - The Need roll's number appears on the frame.
  - Trash rolls: do they get history entries?
  - Unlock, drag and the sliders.
- The sections below describe the **old** Classic addon and the Forever research that led to the rewrite.

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

| File                             | Role                                                                                                                                                                                                                                         |
| -------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `BetterGroupLoot.toc`            | Interface `50502` (MoP Classic) and `11508` (Classic Era). Loads only `BetterGroupLoot_standalone.xml`. SavedVariables `BetterGroupLootDB`. `@project-version@` tokens are filled in by the BigWigs packager.                                |
| `BetterGroupLoot_standalone.xml` | Load order: LibStub → CallbackHandler → `Preview.xml` → `BetterGroupLoot.lua` → `Options.lua`.                                                                                                                                               |
| `BetterGroupLoot.lua`            | Core. Registers the library `BetterGroupLoot-1.0` through LibStub, handles events, styles the frames, counts rolls, builds tooltips.                                                                                                         |
| `Preview.xml`                    | Virtual template `BetterGroupLootPreviewTemplate`: a hand-copied version of the old Classic GroupLootFrame XML (backdrop, `$parentSlotTexture`, `$parentCorner`, `$parentDecoration`, IconFrame, Need/Pass/Greed buttons, Timer status bar). |
| `Preview.mixin.lua`              | Mixin for the preview: cycles random items every 42s, fakes the timer bar and counts. **Duplicates** the color/overlay helpers from `BetterGroupLoot.lua` on its own local frame.                                                            |
| `Options.lua`                    | Settings category "BetterGroupLoot" (checkbox plus 2 proxy sliders from -3000 to 3000). Runs only when standalone. Hooked onto `frame.PLAYER_LOGIN` via `hooksecurefunc`.                                                                    |
| `Libs/`                          | LibStub and CallbackHandler-1.0 (CallbackHandler is loaded but **not used**).                                                                                                                                                                |
| `Textures/`                      | `maskNew.blp` (icon mask), `whiteiconframeEdit.blp` (white border, tinted by quality).                                                                                                                                                       |
| `.github/workflows/`             | BigWigs packager: a tag push creates a release, a `*-preview` branch push creates an alpha build. CurseForge project ID 1382269.                                                                                                             |
| `.vscode/settings.json`          | LuaLS globals list and Ketho WoW API annotations.                                                                                                                                                                                            |

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

## WoW Forever: what we know

Source: the Blizzard UI export at `../_data/BlizzardInterfaceCode/Interface/AddOns/`. Paths below are relative to that folder.

### How the Forever client picks its UI code

- Forever is game type **`camelot`**, and it belongs to the **`mainline`** family.
- In Blizzard's multi-flavor TOCs:
  - `[Family]\x.lua` resolves to `Mainline\x.lua`.
  - `[Game]\x.lua` resolves to `Camelot\x.lua`.
  - Lines are filtered with `[AllowLoadGameType mainline|camelot|classic|vanilla|…]`.
- Loot code under camelot:
  - `Blizzard_UIPanels_Game.toc` loads `[Family]\GroupLootFrame.lua/.xml [AllowLoadGameType mainline]`. So **Forever uses the retail `Mainline/GroupLootFrame.*` with no changes**; there is no Camelot override.
  - `Blizzard_FrameXML/Camelot/LootHistory.lua` only overrides `LootHistoryFrameMixin:ShouldAutoOpen() → false`. The retail loot history window exists but does not open by itself.
- TOC interface number **`16001`**, confirmed in game with `select(4, GetBuildInfo())`. The export itself only has placeholder numbers. The TOC file is `BetterGroupLoot_Camelot.toc` (from web sources), or a combined `## Interface:` line in the main TOC.

### GroupLootFrame (source: `Blizzard_UIPanels_Game/Mainline/GroupLootFrame.xml` and `.lua`)

**Templates**

- `GroupLootFrameBaseTemplate`:
  - Inherits `DefaultDialogPanelTemplate`, size **277x67**.
  - Regions:
    - `Background`: `Interface\LootFrame\LootToast` texcoords, set to all points.
    - `Border`: the same LootToast file, 286x76, vertex-colored by item quality.
    - `Name`: FontString, 125x30, at Background TOPLEFT +60,-15.
    - `IconFrame` (Button, 34x34), with `.Icon`, `.Count`, and `.Border` (atlas `loottoast-itemborder-*`, 42x42).
    - `Timer`: StatusBar, 190x8, at BOTTOMLEFT +3,+2, with `.Background` and `.Bar`.
    - `NeedRollAnim`: a frame with an `Animation` group, anchored to `LootButtonContainer.NeedButton`.
- `MKBGroupLootFrameTemplate`:
  - Inherits the base template. Parent is UIParent, `toplevel`, strata `DIALOG`.
  - Adds `LootButtonContainer`, anchored between `Name` and the right edge. It holds 4 buttons from `LootRollButtonTemplate` (32x32, `parentArray="LootButtons"`):

| Button           | `id` (= RollOnLoot type) | Anchor                      | Atlas                                          |
| ---------------- | ------------------------ | --------------------------- | ---------------------------------------------- |
| `NeedButton`     | 1                        | TOPLEFT of container +14,-7 | `lootroll-toast-icon-need-{up,highlight,down}` |
| `PassButton`     | 0                        | RIGHT of Need +6,+2         | `lootroll-toast-icon-pass-*`                   |
| `GreedButton`    | 2                        | BOTTOM of Need, 0,+5        | `lootroll-toast-icon-greed-*`                  |
| `TransmogButton` | 4                        | CENTER on Greed (same spot) | `lootroll-toast-icon-transmog-*`               |

- `LootRollButtonTemplate`:
  - `OnClick`: `RollOnLoot(self:GetParent():GetParent().rollID, self:GetID())`. The button's parent is the container, and the container's parent is the frame.
  - `OnEnter`: `GameTooltip_SetTitle(self.tooltipText)`, plus `self.reason` in red when disabled.
  - Our tooltip needs to keep this behavior, or hook it with `HookScript`.
- `GroupLootFrame1..4` inherit `MKBGroupLootFrameTemplate`, so they are **277x67, not 243x84 as in Classic**.
- **There are no `$parent` named regions.** `GroupLootFrame1Corner`, `…Decoration`, `…SlotTexture` and `…SubIconTexture` do not exist.
- There is **no Disenchant button**. `LootRollType` is Pass=0, Need=1, Greed=2, Disenchant=3, Transmog=4.

**Logic (`GroupLootFrame.lua`)**

- Opening a roll:
  - `START_LOOT_ROLL` → `GameEvent.HandleStartLootRoll` (`Blizzard_Game/Mainline/EventImplementation.lua:386`) → `GroupLootContainer_AddRoll(rollID, rollTime)`.
  - This is skipped entirely when the gamepad UI is enabled (see below).
- `GroupLootContainer_OpenNewFrame`:
  - Finds the first hidden `GroupLootFrameN` and sets `frame.rollID`, `frame.rollTime` and `Timer:SetMinMaxValues(0, rollTime)`.
  - Then calls `GroupLootContainer_AddFrame`, which does `frame:Show()`.
  - If all 4 frames are busy, the roll goes into `GroupLootContainer.waitingRolls`.
  - So **`rollID` is set before `OnShow`**. Hooking `OnShow` (`HookScript`) is the reliable way to know a frame has a new roll. It is better than our own `START_LOOT_ROLL` handler, which may run before Blizzard's.
- `GroupLootFrame_OnShow` → `GroupLootFrame_SetupItemDisplay(self)`:
  - Calls `GetLootRollItemInfo(rollID)`, which returns texture, name, count, quality, bindOnPickUp, canNeed, canGreed, canDisenchant, reasonNeed, reasonGreed, reasonDisenchant, deSkillRequired, canTransmog.
  - Sets the icon, `IconFrame.Border` atlas via `ColorManager.GetAtlasDataForLootBorderItemQuality(quality)`, the name, and the Name/Border vertex color.
  - Enables or disables Need/Greed with `.reason`. Shows **Transmog instead of Greed** when `canTransmog`.
  - The function can be hooked with `hooksecurefunc("GroupLootFrame_SetupItemDisplay", …)` to restyle after Blizzard's own setup.
- `GroupLootFrame_OnEvent` handles:
  - `CANCEL_LOOT_ROLL(rollID)` → remove.
  - `CANCEL_ALL_LOOT_ROLLS`.
  - `MAIN_SPEC_NEED_ROLL(rollID, roll, isWinning)` → `GroupLootFrame_StartNeedAnimation`, which hides all buttons, plays the dice animation for 5s, then removes the frame.
- `GroupLootFrame_OnUpdate` updates the timer from `GetLootRollTimeLeft(rollID)`.
- `GroupLootFrame_EnableLootButton` and `GroupLootFrame_DisableLootButton` set alpha to 1 or 0.35 and desaturate the normal texture.
- The IconFrame tooltip is `GroupLootFrameIconFrame_OnEnter` → `GameTooltip:SetLootRollItem(rollID)`.

**Container and positioning**

- `GroupLootContainer`:
  - A `ContainedAlertFrame`, inherits **`BottomManagedFrameTemplate`**, size 256x1, `layoutIndex=3`. It is also registered as an external AlertFrame subsystem, so alerts stack above it.
  - `GroupLootContainer_Update` places frames at `CENTER` of container `BOTTOM`, with y = `reservedSize(100) * (i - 0.5)`. It sets the container height to `100 * lastIdx`, then calls `self.layoutParent:Layout()`.
- The managed frame system (`Blizzard_ManagedFrameSystem/Shared/ManagedFrameSystem.lua`):
  - `ManagedFrameMixin:OnShow` calls `layoutParent:AddManagedFrame(self)`.
  - That returns early when **`frame.ignoreFramePositionManager`** is set.
  - Otherwise it reparents the container into `BottomManagedFrameContainer` and lays it out.
  - So **our current approach still works**: set `ignoreFramePositionManager = true`, then `ClearAllPoints` and `SetPoint` it ourselves.
  - It must be set before the first show. If the container was already managed (reparented), it has to be reparented back to UIParent.

**Gamepad mode**

- When `InputUtil.IsGamepadUIEnabled()`, rolls go to a different frame, `GamepadGroupLootRollFrame`: a scroll list of `GamepadGroupLootRollFrameTemplate` cards with different button anchors.
- `GroupLootFrame1..4` are not used then. Scope decision: ignore gamepad mode, or support it later.

### C_LootHistory (source: `Blizzard_APIDocumentationGenerated/LootHistoryDocumentation.lua`)

**Functions**

- `GetAllEncounterInfos()` returns `EncounterLootInfo[]`, each `{encounterName, encounterID, startTime, duration}`.
- `GetInfoForEncounter(encounterID)` returns `EncounterLootInfo?`.
- `GetSortedDropsForEncounter(encounterID)` returns `EncounterLootDropInfo[]?`.
- `GetSortedInfoForDrop(encounterID, lootListKey)` returns `EncounterLootDropInfo?`.
- `GetLootHistoryTime()` returns a number, on the same clock as `startTime`.
- The three encounter functions are flagged `SecretArguments = "AllowedWhenUntainted"`. They are fine with normal numbers we get from events or returns, but must not be passed "secret" values.

**`EncounterLootDropInfo` fields**

- `lootListKey`, `itemHyperlink`, `playerRollState`.
- `currentLeader?`, `isTied`, `winner?`, `allPassed`.
- `rollInfos[]`, each an `EncounterLootDropRollInfo`: `{playerName, playerGUID, playerClass, isSelf, state, isWinner, roll?}`.
- `startTime`, `duration`.

**`Enum.EncounterLootDropRollState`**

| Value | State                |
| ----- | -------------------- |
| 0     | NeedMainSpec         |
| 1     | NeedOffSpec          |
| 2     | Transmog             |
| 3     | Greed                |
| 4     | NoRoll (= undecided) |
| 5     | Pass                 |

The **numbers are not the same as the `RollOnLoot` types**, so we need a mapping.

**Events**

- `LOOT_HISTORY_UPDATE_DROP(encounterID, lootListKey)`: fires when someone rolls. This is the one we want.
- `LOOT_HISTORY_UPDATE_ENCOUNTER(encounterID)`.
- `LOOT_HISTORY_CLEAR_HISTORY`.
- `LOOT_HISTORY_GO_TO_ENCOUNTER(encounterID)`.
- `LOOT_HISTORY_ONE_HUNDRED_ROLL(encounterID, lootListKey)`.
- The old `GetItem`, `GetPlayerInfo`, `LOOT_HISTORY_ROLL_CHANGED` and `LOOT_HISTORY_ROLL_COMPLETE` **do not exist**.

**How Blizzard uses it** (`Blizzard_FrameXML/Mainline/LootHistory.lua`)

- `LootHistoryElementMixin:SetTooltip` is a good reference for the tooltip:
  - It walks `dropInfo.rollInfos`.
  - It skips "multiple item instance win protection" rolls.
  - It collects `NoRoll` players into a "Waiting on: …" line, class-colored through `RAID_CLASS_COLORS[roll.playerClass]`.

### Linking a roll frame to a history drop (open problem)

- **No API maps `rollID` to `(encounterID, lootListKey)`.**
  - `START_LOOT_ROLL` has `(rollID, rollTime, lootHandle?)`.
  - `GetLootRollItemInfo` and `GetLootRollItemLink(rollID)` return no encounter info.
- Proposed matching:
  1. Get `link = GetLootRollItemLink(rollID)`.
  2. Search `GetAllEncounterInfos()`, newest first. Blizzard itself treats `[1]` as the most recent.
  3. In each encounter, search `GetSortedDropsForEncounter` for a drop with `itemHyperlink == link` that is still open (no `winner`, not `allPassed`).
  4. Cache `rollID → {encounterID, lootListKey}`.
  5. On `LOOT_HISTORY_UPDATE_DROP(e, k)`, refresh the frame(s) mapped to it.
- Two identical items from the same boss are ambiguous. Break the tie by excluding keys already claimed by another open frame, and by the order of `startTime`.
- Rolls outside an encounter (trash, chests) may have **no history entry at all**. In that case the counts should show `*` or be hidden.
- **Verify in game** that trash and dungeon rolls show up in `GetAllEncounterInfos()`.

### Still to check in game (during an active roll)

- `/dump GroupLootFrame1.rollID, GetLootRollItemLink(GroupLootFrame1.rollID)`
- `/dump C_LootHistory.GetAllEncounterInfos()`, then `/dump C_LootHistory.GetSortedDropsForEncounter(<id>)`. Check that `itemHyperlink` matches the roll link exactly, and whether trash rolls appear.
- `/etrace` during a roll, to confirm the order `START_LOOT_ROLL` → `LOOT_HISTORY_UPDATE_ENCOUNTER` / `LOOT_HISTORY_UPDATE_DROP`.

### Impact on our code (summary)

| Current code                                       | Forever reality                                                                                                                       |
| -------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------- |
| `_G[name.."Corner"/"Decoration"/"SlotTexture"]`    | nil, so the addon errors. Use parentKeys: `Background`, `Border`, `Name`, `IconFrame.*`, `Timer`.                                     |
| `f.NeedButton` / `f.GreedButton` / `f.PassButton`  | `f.LootButtonContainer.NeedButton` and the others, plus `TransmogButton` (shares Greed's spot).                                       |
| File textures `UI-GroupLoot-*` plus texcoord hacks | Atlases `lootroll-toast-icon-*` are already set. Probably just resize and re-anchor.                                                  |
| Our quality overlay and mask textures              | Blizzard sets `IconFrame.Border` (atlas) and tints `Border` itself. The overlay can probably go.                                      |
| `C_LootHistory.GetItem` / `GetPlayerInfo`          | Rewrite on `GetSortedDropsForEncounter` / `GetSortedInfoForDrop` plus the rollID matching.                                            |
| `LOOT_HISTORY_ROLL_CHANGED` / `_COMPLETE`          | `LOOT_HISTORY_UPDATE_DROP` / `_UPDATE_ENCOUNTER`.                                                                                     |
| Registering `START_LOOT_ROLL` ourselves            | Use `HookScript("OnShow")` on the roll frames, or `hooksecurefunc("GroupLootFrame_SetupItemDisplay")`.                                |
| `ignoreFramePositionManager`                       | Still valid with the Mainline managed frame system.                                                                                   |
| Preview template (Classic XML copy)                | Rebuild it from `MKBGroupLootFrameTemplate` with a fake `rollID`, or copy the base layout. The Classic item IDs are fine for Forever. |
| Rolls read as 0/1/2/3                              | Map the `EncounterLootDropRollState` values: Need = 0 or 1, Transmog = 2, Greed = 3, undecided = 4, Pass = 5.                         |

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
