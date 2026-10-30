# BetterGroupLoot

Better group loot rolls for WoW Forever, Classic Anniversary, Classic Era (including Hardcore
and Season of Discovery), and progression Classic (Mists): see how many players chose Need,
Greed, Disenchant, Transmog or Pass,
who they are, and move the rolls anywhere on the screen.

## Features

- Its own roll frames in place of the default ones, built on the game's loot toast art.
- A count on every roll button: how many players chose Need, Greed, Disenchant, Transmog or Pass so far.
- The buttons' tooltips list those players, class-colored and with their roll numbers, plus (if
  enabled) everyone who hasn't chosen yet.
- Disenchant is offered when the client allows it; Transmog is available on Forever.
- Your own instant Need roll's number is shown on Forever when the game rolls it.
- Native Edit Mode integration on supported clients: select the roll stack to move it or adjust
  scale, spacing, growth direction and undecided-player tooltips.
- Move the rolls anywhere: unlock them, drag the anchor, lock them again. Scale, spacing and
  stacking direction are adjustable, and every setting is per profile.

Roll counts come from the game's loot history. Classic clients match entries by roll ID;
Forever matches encounter drops to rolls. Rolls the loot history doesn't list show no counts.
Retail WoW is not supported. This replaces group loot rolls; personal loot and master loot
continue to use the game's UI.

## Installation

Download it from the GitHub releases and put the `BetterGroupLoot` and
`BetterGroupLoot_EditMode` folders into
`..\World of Warcraft\<client>\Interface\AddOns`.

The Edit Mode companion loads on demand only when the client provides the required native
Edit Mode APIs. Clients without them keep the existing unlock-and-drag controls.

## Usage

Open the game's Edit Mode and select **BetterGroupLoot**. Three preview rolls show the stack's
position and growth direction. Its settings menu uses the same per-profile settings as the
addon options; switching native Edit Mode layouts does not create separate addon profiles.

- `/bettergrouploot` — open the options (also in the game's Settings > AddOns)
- `/bettergrouploot unlock` / `lock` — show the anchor with preview rolls to drag them into place
  (right-click the anchor to lock)
- `/bettergrouploot loglevel <level>` — set how much the addon writes to chat (`none`, `error`,
  `warn`, `info`, `verbose`, `debug`, `silly`)
- `/bettergrouploot reset` — reset the current profile

## Development

Node 20+; run `npm install` once. `npm run dev:link -- "<WoW>/Interface/AddOns"` links the addon
into a client, `/reload` picks up changes. `npm run format` formats everything, `npm run check`
validates it. Releases are built by the GitHub workflows in `.github/workflows/`.

## License

[MIT](LICENSE)
