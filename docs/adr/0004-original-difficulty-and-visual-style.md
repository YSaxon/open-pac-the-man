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

The current contour geometry is mechanically correct and now draws neon boundaries offset from path
centerlines, leaving the level/background texture visible in corridors and enclosed wall islands.
This better matches original screenshots than the earlier centerline renderer, which painted a black
corridor and created a thick double-wall look. `barrier.raw` is rendered over the ghost-base
entrance, and the HUD uses the recovered `font.raw` sheet.

The remaining fidelity pass should compare side-by-side original captures and tune the layered
alpha, colored body, bright highlight, rounded joins, glow/shadow treatment, citadel overlay
opacity, and any tileset-specific differences between Standard `tile` and X-level `tile2`.
Longer-term, these parameters should live in a reusable maze material/style object so visual tuning
cannot affect path geometry.
