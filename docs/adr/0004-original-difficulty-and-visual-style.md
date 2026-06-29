# ADR 0004: Preserve original difficulty modes and isolate visual style

Status: difficulty behavior implemented; first Aqua rendering pass implemented.

## Recovered facts

The 1.5.1 executable persists four numeric values: Easy 1, Normal 2, Hard 3, and Master 4. Its
localized strings expose all four labels, and local/online score names distinguish every value.
Easy ghosts use a 0.8 velocity component; Normal, Hard, and Master use 0.9. Easy and Normal have
one-in-three and one-in-27 random branch overrides respectively. Hard and Master are deterministic
and prioritize the target axis with greater separation.

Master is the remembered darkness mode and is explicitly incompatible with two-player games. The
archive's 300×300 `spot.raw` is centered on the player and surrounded by four opaque viewport-sized
sprites. Difficulty is session-owned and is not a per-player handicap.

## Decision

- Restore Easy, Normal, Hard, and Master as explicit original-compatible session modes.
- Keep each mode's high scores separate, matching the original categories.
- Implement Master's darkness from the supplied `spot.raw` and retain the original single-player
  restriction instead of inventing multiplayer spotlight composition.
- Keep maze topology and collision independent from its renderer. Aqua/glass styling belongs to a
  presentation theme, not level data or navigation code.

## Maze presentation follow-up

The current maze renderer splits each 44-pixel logical cell into a 4×4 field of 11-pixel subtiles.
Playable routes carve two-subtile-wide dark corridors; the remaining non-playable subtile field is
filled with the level background and framed with the recovered `tile`/`tile2` primitive frames. This
replaces the earlier procedural tube/contour renderer and matches the key original layering rule:
tiling belongs to the wall/island field, not the corridors. `barrier.raw` is rendered over the
ghost-base entrance, and the HUD uses the recovered `font.raw` sheet.

The remaining fidelity pass should compare side-by-side original captures and tune the layered
outer-boundary tunnel caps, diagonal four-corridor junctions, alpha/glow treatment, citadel overlay
opacity, and any tileset-specific differences between Standard `tile` and X-level `tile2`. The
subtile-frame mapping now has tests so visual tuning cannot silently move the renderer back to the
wrong playable-corridor tiling model.
