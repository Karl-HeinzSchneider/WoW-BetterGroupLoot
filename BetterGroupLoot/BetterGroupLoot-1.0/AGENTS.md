# BetterGroupLoot-1.0

This folder is **BetterGroupLoot-1.0**, a LibStub library for World of Warcraft that replaces the
client's group loot roll frames. Every roll shows how many players chose Need, Greed/Transmog,
Disenchant or Pass. The buttons' tooltips list who chose what, and the stack of rolls can be moved
anywhere, including through Edit Mode.

- **Source:** <https://github.com/Karl-HeinzSchneider/WoW-BetterGroupLoot>, in
  `BetterGroupLoot/BetterGroupLoot-1.0/`. Take updates from there instead of editing this copy.
- **Author:** Karl-Heinz Schneider ([Karl-HeinzSchneider](https://github.com/Karl-HeinzSchneider) on
  GitHub).
- **Standalone addon:** BetterGroupLoot, built on this same library.

## Using it

1. Copy this whole folder into your addon unchanged, for example to `libs/BetterGroupLoot-1.0/`.
2. Include `BetterGroupLoot-1.0.xml` from your addon's XML or TOC. Loading the library does nothing
   on its own.
3. From your addon, call `LibStub("BetterGroupLoot-1.0"):Start({ name = "YourAddon", ... })` once
   your saved settings are available. Pass your own logger, profile getter and strings, or rely on
   the defaults.

The full host contract covers all `Start` options, ownership between several addons, the
controller methods and the optional Edit Mode registration. It is in
[docs/embedding.md](https://github.com/Karl-HeinzSchneider/WoW-BetterGroupLoot/blob/main/docs/embedding.md).
The supported clients are listed in
[docs/client-compatibility.md](https://github.com/Karl-HeinzSchneider/WoW-BetterGroupLoot/blob/main/docs/client-compatibility.md).

## License and credit

The library is MIT licensed. **Keep the `LICENSE` file in this folder**: the license requires its
copyright and permission notice to ship with every copy.

Credit is appreciated, though the license doesn't require it: keep this `AGENTS.md` in the folder,
and mention BetterGroupLoot in your addon's credits or description, for example "Group loot rolls
by BetterGroupLoot-1.0 (Karl-Heinz Schneider)".
