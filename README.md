# BetterGroupLoot

Better group loot rolls for WoW Forever: see how many players chose Need, Greed, Transmog or Pass,
who they are, and move the rolls anywhere on the screen.

## Features

- Its own roll frames in place of the default ones, built on the game's loot toast art.
- A count on every roll button: how many players chose Need, Greed, Transmog or Pass so far.
- The buttons' tooltips list those players, class-colored and with their roll numbers, plus (if
  enabled) everyone who hasn't chosen yet.
- Your own Need roll's number is shown on the frame when the game rolls it.
- Move the rolls anywhere: unlock them, drag the anchor, lock them again. Scale, spacing and
  stacking direction are adjustable, and every setting is per profile.

Roll counts come from the game's loot history. Rolls the loot history doesn't list (outside boss
encounters) show no counts.

## Installation

Download it from the GitHub releases and put the `BetterGroupLoot` folder into
`..\World of Warcraft\<client>\Interface\AddOns`.

## Usage

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
