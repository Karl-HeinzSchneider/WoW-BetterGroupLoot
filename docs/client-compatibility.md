# Client compatibility

BetterGroupLoot replaces group-loot roll frames, tracks choices from client loot history,
and stores movable frame settings through AceDB. The UI consumes normalized data from `app.api`.

| Client                      | Interfaces declared | Loot history       | Choices                       |
| --------------------------- | ------------------- | ------------------ | ----------------------------- |
| Forever                     | 16001               | Encounter/drop API | Need, Greed, Transmog, Pass   |
| Era, Hardcore, SoD          | 11508, 11509        | Roll-indexed API   | Need, Greed, Pass             |
| Anniversary (TBC)           | 20505, 20506        | Roll-indexed API   | Need, Greed, Pass             |
| Progression Classic (Mists) | 50503, 50504        | Roll-indexed API   | Need, Greed, Disenchant, Pass |

Buttons follow `GetLootRollItemInfo` permissions, so the client decides whether Disenchant is
available. Retail has no declared interface and neither adapter selects it.

## Investigation

- Anniversary and Era exports use `Blizzard_UIPanels_Game/Classic/LootFrame.lua` and
  `Blizzard_FrameXML/Classic/LootHistory.lua`. Their history exposes `GetNumItems`,
  `GetItem` (roll ID, link, player count), and `GetPlayerInfo` (name, class, choice,
  roll, winner, self). Updates use the FULL_UPDATE, ROLL_CHANGED and ROLL_COMPLETE history events.
- Classic recovery uses `GetActiveLootRollIDs` and `GetLootRollTimeLeft`, as the client itself
  does after entering the world. It does not depend on Forever's `C_Loot.GetLootRollDuration`.
- The Classic adapter suppresses default frames through their container removal function,
  preserving layout bookkeeping and leaving the game's confirmation popups in use.
- Exports contain unused client-family files. The `wow_classic_beta` snapshot includes
  mainline and Camelot history implementations but lacks its Classic-family history/frame
  files. Progression Classic's frame and history implementations were additionally checked against
  the current 5.5.4 [frame source](https://github.com/Gethe/wow-ui-source/blob/classic/Interface/AddOns/Blizzard_UIPanels_Game/Classic/LootFrame.lua)
  and [history source](https://github.com/Gethe/wow-ui-source/blob/classic/Interface/AddOns/Blizzard_FrameXML/Classic/LootHistory.lua).
- Classic loot-roll toast button atlases are not assumed. XML uses existing group-loot button
  textures; Lua selects toast atlases only when the client reports them available. Item-border
  colors fall back to Classic's `LOOT_BORDER_BY_QUALITY`.
- Interface declarations were cross-checked against the
  [BigWigs manifest](https://github.com/BigWigsMods/BigWigs/blob/master/BigWigs.toc).

## Validation and remaining game tests

`npm run check:compat` runs offline Lua regression checks covering client selection, retail
exclusion, item permissions, Disenchant dispatch, history reordering, identical item links,
missing history, active-roll recovery and default-frame suppression. These mocks verify the
adapter's behavior, not the game engine or rendering.

Before release, test each client in game:

1. Open options, unlock previews, move/scale the stack, switch profiles and reload.
2. Start several group-loot rolls, including two copies of the same item. Check counts,
   player tooltips, timer, Need/Greed/Pass and applicable Disenchant/Transmog buttons.
3. Confirm a bind-on-pickup roll, then verify cancellation, timeout and completion remove frames.
4. Reload or cross a loading screen during a roll; confirm recovery and no duplicate default UI.
5. Check disabled Need/Disenchant tooltips and item quality borders.
6. On Forever, verify instant Need results and gamepad behavior still work.

Personal loot and master-loot distribution remain handled by the game's UI.
